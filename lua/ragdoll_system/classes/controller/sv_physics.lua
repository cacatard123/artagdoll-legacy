local util_TraceLine = util.TraceLine
local vector_origin = Vector(0, 0, 0)

function ActiveRagdollController:UpdatePhysicsData()
    if not self or not IsValid(self.Ragdoll) or not self.Data then 
        return 
    end
    
    local data = self.Data
    local ragdoll = self.Ragdoll
    local phys = ragdoll:GetPhysicsObject()
    
    if IsValid(phys) then
        local pos = phys:GetPos()
        
        if not pos or pos == vector_origin then
            data.isTouchingRaycast = false
            data.isCloseToGround = false
            return
        end
        
        local tr = util_TraceLine({
            start = pos,
            endpos = pos - Vector(0, 0, 53),
            mask = MASK_SOLID_BRUSHONLY,
            filter = ragdoll
        })

        data.isTouchingRaycast = tr.Hit or false
        data.isCloseToGround = tr.Hit and (tr.Fraction * 53 < 25) or false
    else
        data.isTouchingRaycast = false
        data.isCloseToGround = false
    end
end

function ActiveRagdollController:ChooseBestBehavior()
    if not self or not IsValid(self.Ragdoll) or not self.Data or not self.CONST then
        return nil
    end
    
    local data = self.Data
    local ragdoll = self.Ragdoll
    local C = self.CONST

    local isOnFire = false
    local fireSuccess, fireResult = pcall(function() return ragdoll:IsOnFire() end)
    if fireSuccess then
        isOnFire = fireResult
    end

    if isOnFire then
        data.protectiveExitRequestTime = nil
        return "Burning"
    end

    local waterLevel = 0
    local waterSuccess, waterResult = pcall(function() return ragdoll:WaterLevel() end)
    if waterSuccess then
        waterLevel = waterResult or 0
    end

    if waterLevel >= 1 then
        data.protectiveExitRequestTime = nil
        return "Drowning" 
    end

    local pelvisPhys = nil
    if self.BoneIDs and self.BoneIDs.Pelvis then
        local physBone = ragdoll:TranslateBoneToPhysBone(self.BoneIDs.Pelvis)
        if physBone then
            pelvisPhys = ragdoll:GetPhysicsObjectNum(physBone)
        end
    end

    local velocity = IsValid(pelvisPhys) and pelvisPhys:GetVelocity() or Vector(0, 0, 0)
    local speed = velocity:Length()
    local verticalVel = velocity.z
    local horizontalSpeed = velocity:Length2D()

    local uprightness = 0
    if self.BoneIDs and self.BoneIDs.Spine then
        local matrix = ragdoll:GetBoneMatrix(self.BoneIDs.Spine)
        if matrix then 
            local forward = matrix:GetForward()
            if forward then
                uprightness = forward:Dot(Vector(0, 0, 1))
            end
        end
    end

    local scores = { Falling = 0, Protective = 0, Stagger = 0, Injured = 0 }
    local underwater = waterLevel >= 2
    local now = CurTime()
    
    local momentumBonus = 0.3
    if self.CurrentBehaviorName and scores[self.CurrentBehaviorName] ~= nil then
        scores[self.CurrentBehaviorName] = momentumBonus
    end

    if not data.isTouchingRaycast then
        if not underwater then
            local fallIntensity = math.max(0, -verticalVel / 100)
            local motionIntensity = horizontalSpeed / 200
            
            if verticalVel < C.FALLING_VERTICAL_FAST then
                scores.Falling = 3 + fallIntensity
                scores.Protective = 3 + fallIntensity * 0.8
                
            elseif horizontalSpeed > C.FALLING_MIN_SPEED or verticalVel < C.FALLING_MIN_VERTICAL then
                local baseScore = 2 + motionIntensity
                scores.Falling = baseScore
                scores.Protective = baseScore * 0.9
                
            elseif speed > C.AIRBORNE_MIN_SPEED then
                local uprightBonus = math.max(0, (uprightness - C.UPRIGHTNESS_THRESHOLD) * 2)
                local baseScore = 1 + (speed / 300)
                scores.Falling = baseScore + uprightBonus
                scores.Protective = baseScore + uprightBonus * 0.7
                
            else
                scores.Injured = 2.5 - uprightness
            end
        end
        
    else
        if horizontalSpeed > C.GROUND_SLIDE_THRESHOLD then
            local slideIntensity = horizontalSpeed / 300
            scores.Falling = 10 + slideIntensity
            
        else
            local canStagger = uprightness > C.UPRIGHTNESS_THRESHOLD
            local uprightQuality = (uprightness - C.UPRIGHTNESS_THRESHOLD) / (1 - C.UPRIGHTNESS_THRESHOLD)
            uprightQuality = math.max(0, math.min(1, uprightQuality))
            
            if not data.isCloseToGround then
                if canStagger then 
                    scores.Stagger = 1.5 + uprightQuality
                    
                    if horizontalSpeed > C.GROUND_FAST_SPEED then 
                        scores.Stagger = scores.Stagger + 1.5
                    elseif horizontalSpeed > 50 then
                        scores.Stagger = scores.Stagger + 0.5
                    end
                end
                
                if scores.Stagger < 1 then 
                    scores.Injured = 2 - uprightness * 0.5
                end
                
            else
                if canStagger and horizontalSpeed > 50 then
                    local speedFactor = math.min(1, horizontalSpeed / C.GROUND_FAST_SPEED)
                    scores.Stagger = 1 + speedFactor
                    
                    if uprightness > C.UPRIGHTNESS_GOOD and horizontalSpeed > C.GROUND_STAGGER_SPEED then 
                        scores.Stagger = 3 + uprightQuality * 0.5
                    end
                    
                    scores.Stagger = scores.Stagger + uprightQuality * 0.3
                    
                else
                    local injuredBase = 3
                    
                    if horizontalSpeed > 20 then
                        injuredBase = injuredBase - (horizontalSpeed / 100)
                    end
                    
                    scores.Injured = math.max(1, injuredBase - uprightness)
                end
            end
        end
    end
    
    for behavior, score in pairs(scores) do
        if score > 5 then
            scores[behavior] = 5 + (score - 5) * 0.3
        end
    end

    local potentialBehavior, highestScore = nil, -1
    for behavior, score in pairs(scores) do
        if score > highestScore then
            potentialBehavior = behavior
            highestScore = score
        end
    end

    if potentialBehavior == "Stagger" then
        if data.lastStaggerTime and (now - data.lastStaggerTime) < 2 then
            return (scores.Injured > 1.5) and "Injured" or self.CurrentBehaviorName
        end
        data.lastStaggerTime = now
    end

    if self.CurrentBehaviorName == "Protective" and potentialBehavior ~= "Protective" then
        if not data.protectiveExitRequestTime then
            data.protectiveExitRequestTime = now
            return "Protective"
        elseif (now - data.protectiveExitRequestTime) < 0.5 then
            if highestScore > scores.Protective + 1 then
                data.protectiveExitRequestTime = nil
            else
                return "Protective"
            end
        end
    end
    
    if potentialBehavior ~= "Protective" then
        data.protectiveExitRequestTime = nil
    end

    if highestScore < 0.5 and self.CurrentBehaviorName then
        return self.CurrentBehaviorName
    end

    return potentialBehavior
end

function ActiveRagdollController:OnPhysicsCollide(data, phys)
    if not self or not data or not phys then return end
    if not self.ActiveOverrides and not self.CurrentBehavior then return end
    
    if self.ActiveOverrides then
        for name, override in pairs(self.ActiveOverrides) do
            if override and override.OnPhysicsCollide then
                local success, err = pcall(override.OnPhysicsCollide, override, data, phys)
                if not success then
                    ErrorNoHalt("[Controller] Override collision error (" .. name .. "): " .. tostring(err) .. "\n")
                end
            end
        end
    end
    
    if self.CurrentBehavior and self.CurrentBehavior.OnPhysicsCollide then
        local success, err = pcall(self.CurrentBehavior.OnPhysicsCollide, self.CurrentBehavior, data, phys)
        if not success then
            ErrorNoHalt("[Controller] Behavior collision error: " .. tostring(err) .. "\n")
        end
    end
end