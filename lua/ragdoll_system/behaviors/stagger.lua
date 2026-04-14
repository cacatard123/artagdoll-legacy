local IKSystem = include("Components/Utils/IKChain.lua")

local STATIC_VALUES = {
    RaycastDistance = 200,
    GravityConstant = 600,
    
    MaxStepUpHeight = 10,
    MaxStepDownHeight = 65,
    GroundPredictionTime = 0.25,
    SearchHeightBuffer = 15,
    
    FootHullMins = Vector(-2, -2, 0),
    FootHullMaxs = Vector(2, 2, 2),
    
    MaxVelocity = 255,
    PelvisStabilizationForce = 500,
    PelvisStabilizationThreshold = 200,
    PelvisDamping = 0.85,
    ReactionDelay = 0.51035243272781,

    MaxStepRadius = 20,
}

local DYNAMIC_CVARS = {
    BalanceRadius       = "ar_BalanceRadius",
    StepReachMultiplier = "ar_StepReachMultiplier",
    StepSpeed           = "ar_StepSpeed",
    StepHeight          = "ar_StepHeight",
    MinStepThreshold    = "ar_MinStepThreshold",
}

local CONFIG = setmetatable({}, {
    __index = function(t, key)
        local cvarName = DYNAMIC_CVARS[key]
        if cvarName then
            local cv = GetConVar(cvarName)
            if cv then 
                return cv:GetFloat()
            end
        end

        return STATIC_VALUES[key]
    end,
    
    __newindex = function(t, key, value)
        STATIC_VALUES[key] = value
        print("real changed")
    end
})

local function GetBonePhys(ragdoll, boneName)
    local boneID = ragdoll:LookupBone(boneName)
    if not boneID then return nil end
    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local phys = ragdoll:GetPhysicsObjectNum(i)
        if IsValid(phys) and ragdoll:TranslatePhysBoneToBone(i) == boneID then
            return phys
        end
    end
    return nil
end

local function RaycastDown(pos, ragdoll, distance)
    distance = distance or CONFIG.RaycastDistance
    local tr = util.TraceHull({
        start = pos + Vector(0, 0, 10),
        endpos = pos + Vector(0, 0, -distance),
        mins = CONFIG.FootHullMins,
        maxs = CONFIG.FootHullMaxs,
        mask = MASK_SOLID_BRUSHONLY,
        filter = ragdoll
    })
    if tr.Hit then
        local slopeAngle = math.deg(math.acos(math.Clamp(tr.HitNormal.z, -1, 1)))
        if slopeAngle < 80 then
            return tr.HitPos, tr.HitNormal, slopeAngle
        end
    end
    return nil, nil, nil
end

local function FindGroundPosition(pos, ragdoll, currentFootZ)
    currentFootZ = currentFootZ or pos.z
    
    local searchStart = Vector(pos.x, pos.y, currentFootZ + CONFIG.MaxStepUpHeight + CONFIG.SearchHeightBuffer)
    
    local traceDepth = 100 
    local searchEnd = Vector(pos.x, pos.y, currentFootZ - traceDepth)
    
    local tr = util.TraceHull({
        start = searchStart,
        endpos = searchEnd,
        mins = CONFIG.FootHullMins,
        maxs = CONFIG.FootHullMaxs,
        mask = MASK_SOLID_BRUSHONLY,
        filter = ragdoll
    })
    
    if tr.Hit then
        local slopeAngle = math.deg(math.acos(math.Clamp(tr.HitNormal.z, -1, 1)))
        local heightDiff = tr.HitPos.z - currentFootZ

        if slopeAngle < 60 and heightDiff <= CONFIG.MaxStepUpHeight and heightDiff >= -CONFIG.MaxStepDownHeight then
            return tr.HitPos, tr.HitNormal, slopeAngle, heightDiff
        end
    end
    
    local searchPatterns = { {radius = 5, angles = 8}, {radius = 10, angles = 12} }
    for _, pattern in ipairs(searchPatterns) do
        for i = 0, pattern.angles - 1 do
            local angle = (i / pattern.angles) * math.pi * 2
            local offset = Vector(math.cos(angle) * pattern.radius, math.sin(angle) * pattern.radius, 0)
            
            local offTr = util.TraceHull({
                start = searchStart + offset,
                endpos = searchEnd + offset,
                mins = CONFIG.FootHullMins,
                maxs = CONFIG.FootHullMaxs,
                mask = MASK_SOLID_BRUSHONLY,
                filter = ragdoll
            })
            
            if offTr.Hit then
                local ang = math.deg(math.acos(math.Clamp(offTr.HitNormal.z, -1, 1)))
                local hd = offTr.HitPos.z - currentFootZ
                if ang < 60 and hd <= CONFIG.MaxStepUpHeight + 5 and hd >= -(CONFIG.MaxStepDownHeight + 10) then
                    return offTr.HitPos, offTr.HitNormal, ang, hd
                end
            end
        end
    end
    
    return nil, nil, nil, nil
end

local function PredictGroundPosition(currentPos, velocity, ragdoll, currentFootZ)
    currentFootZ = currentFootZ or currentPos.z
    velocity = velocity or Vector(0, 0, 0)
    
    local horizontalVel = Vector(velocity.x, velocity.y, 0)
    
    local samples = {
        CONFIG.GroundPredictionTime,
        0
    }
    
    for _, time in ipairs(samples) do
        local futurePos = currentPos + (horizontalVel * time)
        local ground, normal, angle, heightDiff = FindGroundPosition(futurePos, ragdoll, currentFootZ)
        
        if ground then
            return ground, normal, angle, heightDiff
        end
    end
    
    return nil, nil, nil, nil
end

local function CalculateCoM(ragdoll)
    if not IsValid(ragdoll) then return Vector(0, 0, 0) end
    
    local totalMass = 0
    local weightedPos = Vector(0, 0, 0)
    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local phys = ragdoll:GetPhysicsObjectNum(i)
        if IsValid(phys) then
            local mass = phys:GetMass()
            if mass and mass > 0 then
                totalMass = totalMass + mass
                weightedPos = weightedPos + (phys:GetPos() * mass)
            end
        end
    end
    return totalMass > 0 and (weightedPos / totalMass) or Vector(0, 0, 0)
end

local function CalculateCapturePoint(comPos, comVel, comHeight, gravity)
    local pos2D = Vector(comPos.x, comPos.y, 0)
    local vel2D = Vector(comVel.x, comVel.y, 0)
    
    comHeight = math.max(comHeight, 1)
    gravity = math.max(gravity, 1)
    
    local timeConstant = math.sqrt(comHeight / gravity)
    return pos2D + (vel2D * timeConstant)
end

local function GetSupportCenter(data)
    local center = Vector(0, 0, 0)
    local count = 0
    
    for i = 1, #data.footPositions do
        if data.footPositions[i] then
            center = center + data.footPositions[i]
            count = count + 1
        end
    end
    
    return count > 0 and (center / count) or Vector(0, 0, 0)
end

local function InitLegs(ragdoll, data)
    data.footPositions = {}
    data.targetPositions = {}
    data.stepOrigin = {}
    data.legProgress = {}
    data.lastStepTime = {}
    data.footVelocities = {}
    data.lastFootPositions = {}
    data.stepUrgency = {}

    data.velocityHistory = {} 
    data.maxVelocitySamples = 12

    local totalMass = 0
    local weightedPos = Vector(0, 0, 0)
    local weightedVel = Vector(0, 0, 0)
    
    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local phys = ragdoll:GetPhysicsObjectNum(i)
        if IsValid(phys) then
            local mass = phys:GetMass()
            if mass > 0 then
                totalMass = totalMass + mass
                weightedPos = weightedPos + (phys:GetPos() * mass)
                weightedVel = weightedVel + (phys:GetVelocity() * mass)
            end
        end
    end
    
    local comPos = totalMass > 0 and (weightedPos / totalMass) or ragdoll:GetPos()
    local comVel = totalMass > 0 and (weightedVel / totalMass) or Vector(0,0,0)
    
    for i = 1, data.maxVelocitySamples do
        table.insert(data.velocityHistory, Vector(comVel.x, comVel.y, comVel.z))
    end
    
    data.comPrevious = comPos

    for i = 1, 2 do
        local boneName = (i == 1) and "ValveBiped.Bip01_L_Foot" or "ValveBiped.Bip01_R_Foot"
        local footPhys = GetBonePhys(ragdoll, boneName)
        
        local vecPos = Vector(0,0,0)
        if IsValid(footPhys) then
            vecPos = footPhys:GetPos()
        else
            local chain = data.ikChains[(i == 1) and "leftLeg" or "rightLeg"]
            if chain then 
                local t = chain:GetTarget()
                if t then vecPos = Vector(t.x, t.y, t.z) end
            end
        end

        local groundPos, _, _, _ = FindGroundPosition(vecPos, ragdoll, vecPos.z)
        if groundPos then
            vecPos = groundPos
        end

        data.footPositions[i] = vecPos
        data.targetPositions[i] = vecPos
        data.stepOrigin[i] = vecPos
        data.lastFootPositions[i] = vecPos
        
        data.legProgress[i] = 0 
        data.lastStepTime[i] = 0 
        
        data.footVelocities[i] = Vector(comVel.x, comVel.y, 0)
        data.stepUrgency[i] = 1.0
    end

    local speed = comVel:Length()
    if speed > 30 then
        local groundPos = RaycastDown(comPos, ragdoll, CONFIG.RaycastDistance)
        local comHeight = groundPos and (comPos.z - groundPos.z) or 50
        local capturePoint = CalculateCapturePoint(comPos, comVel, comHeight, CONFIG.GravityConstant)

        local bestLeg = 1
        local maxDist = -1
        
        for i = 1, 2 do
            if data.footPositions[i] then
                local dist = data.footPositions[i]:Distance(capturePoint)
                if dist > maxDist then
                    maxDist = dist
                    bestLeg = i
                end
            end
        end

        if maxDist > CONFIG.MinStepThreshold then
            local stepTarget = capturePoint
            local gPos, _, _, hDiff = FindGroundPosition(stepTarget, ragdoll, data.footPositions[bestLeg].z)
            
            if gPos then
                data.targetPositions[bestLeg] = gPos
                data.stepOrigin[bestLeg] = data.footPositions[bestLeg]
                data.legProgress[bestLeg] = 1.0 
                data.lastStepTime[bestLeg] = CurTime()
                
                debugoverlay.Cross(gPos, 20, 1, Color(0, 255, 0), true)
                debugoverlay.Text(gPos, "INIT STEP", 1)
            end
        end
    end
end

local function IsLegEligibleToStep(legIndex, data)
    if not data.legProgress[legIndex] then return false end
    if data.legProgress[legIndex] > 0.05 then return false end
    
    local otherLegIndex = (legIndex == 1) and 2 or 1
    
    if data.legProgress[otherLegIndex] and data.legProgress[otherLegIndex] > 0.01 then 
        return false 
    end
    
    if data.legProgress[otherLegIndex] and data.legProgress[otherLegIndex] > 0 then
        return false
    end
    
    if CurTime() - (data.lastStepTime[legIndex] or 0) < CONFIG.ReactionDelay then return false end
    
    return true
end

local function UpdateLegTargets(ragdoll, data)
    if not IsValid(ragdoll) then return end
    if not IsValid(data.spinePhys) then return end

    local dt = FrameTime()
    if dt <= 0 or dt > 1 then return end

    local comPos = CalculateCoM(ragdoll)
    
    local rawComVel = (comPos - data.comPrevious) / dt
    data.comPrevious = Vector(comPos.x, comPos.y, comPos.z)

    if not data.velocityHistory then data.velocityHistory = {} end
    if not data.maxVelocitySamples then data.maxVelocitySamples = 10 end

    table.insert(data.velocityHistory, rawComVel)

    while #data.velocityHistory > data.maxVelocitySamples do
        table.remove(data.velocityHistory, 1)
    end

    local sumVel = Vector(0, 0, 0)
    for _, v in ipairs(data.velocityHistory) do
        sumVel = sumVel + v
    end
    
    local comVel = sumVel / #data.velocityHistory

    local groundPos, groundNormal = RaycastDown(comPos, ragdoll, CONFIG.RaycastDistance)
    local comHeight = groundPos and (comPos.z - groundPos.z) or 50
    comHeight = math.max(comHeight, 10)
    
    local capturePoint = CalculateCapturePoint(comPos, comVel, comHeight, CONFIG.GravityConstant)
    local supportCenter = GetSupportCenter(data)
    local instabilityDist = capturePoint:Distance(Vector(supportCenter.x, supportCenter.y, 0))

    debugoverlay.Cross(capturePoint, 15, 0.03, Color(255, 0, 0), false)
    debugoverlay.Sphere(comPos, 8, 0.03, Color(0, 255, 0), false)
    debugoverlay.Line(supportCenter, Vector(capturePoint.x, capturePoint.y, supportCenter.z), 0.03, Color(255, 255, 0), false)

    local isStepping = false
    for i = 1, 2 do
        if data.legProgress[i] and data.legProgress[i] > 0.05 then
            isStepping = true
            break
        end
    end

    if not isStepping and instabilityDist > CONFIG.BalanceRadius then
        local legToStep = nil
        local maxDist = CONFIG.MinStepThreshold
        
        local bestScore = -math.huge
        
        for i = 1, 2 do
            if IsLegEligibleToStep(i, data) then
                local footPos = data.footPositions[i]
                if footPos then
                    local dist = capturePoint:Distance(Vector(footPos.x, footPos.y, 0))
                    
                    local toCapture = (capturePoint - Vector(footPos.x, footPos.y, 0))
                    toCapture:Normalize()
                    local comVel2D = Vector(comVel.x, comVel.y, 0)
                    local velLength = comVel2D:Length()
                    local velocityAlignment = 0
                    
                    if velLength > 10 then
                        comVel2D:Normalize()
                        velocityAlignment = toCapture:Dot(comVel2D)
                    end
                    
                    local score = dist + (velocityAlignment * 20)
                    
                    if score > bestScore and dist > maxDist then
                        bestScore = score
                        maxDist = dist
                        legToStep = i
                    end
                end
            end
        end

        if legToStep then
            local footPos = data.footPositions[legToStep]
            local toCapture = (capturePoint - Vector(footPos.x, footPos.y, 0))
            toCapture:Normalize()
            
            local velocityMagnitude = comVel:Length()
            local velocityFactor = math.Clamp(velocityMagnitude / 200, 0.7, 1.5)
            local stepDistance = maxDist * CONFIG.StepReachMultiplier * velocityFactor
            
            local otherLeg = (legToStep == 1) and 2 or 1
            local otherFootPos = data.footPositions[otherLeg]
            local lateralVector = Vector(-toCapture.y, toCapture.x, 0)
            local lateralOffset = lateralVector * ((legToStep == 1) and -3 or 3)
            
            local stepTarget2D = footPos + (toCapture * stepDistance) + lateralOffset

            local bodyCenter2D = Vector(comPos.x, comPos.y, footPos.z)
            local distFromBody = stepTarget2D:Distance(bodyCenter2D)
            
            if distFromBody > CONFIG.MaxStepRadius then
                local direction = (stepTarget2D - bodyCenter2D):GetNormalized()
                stepTarget2D = bodyCenter2D + (direction * CONFIG.MaxStepRadius)
            end

            local currentFootZ = footPos.z
            
            local groundTarget, groundNorm, slopeAngle, heightDiff = PredictGroundPosition(
                stepTarget2D, 
                comVel,
                ragdoll,
                currentFootZ
            )
            
            if not groundTarget then
                groundTarget, groundNorm, slopeAngle, heightDiff = FindGroundPosition(
                    stepTarget2D,
                    ragdoll,
                    currentFootZ
                )
            end
            
            if not groundTarget then
                groundTarget, groundNorm, slopeAngle, heightDiff = FindGroundPosition(
                    footPos,
                    ragdoll,
                    currentFootZ
                )
            end
            
            if not groundTarget then
                groundTarget = stepTarget2D
                heightDiff = 0
            end
            
            if groundTarget then
                data.stepOrigin[legToStep] = Vector(footPos.x, footPos.y, footPos.z)
                data.targetPositions[legToStep] = Vector(groundTarget.x, groundTarget.y, groundTarget.z)
                
                local urgency = math.Clamp(instabilityDist / CONFIG.BalanceRadius, 1.0, 2.0)
                data.stepUrgency[legToStep] = urgency
                
                data.legProgress[legToStep] = 1.0
                data.lastStepTime[legToStep] = CurTime()
                
                local debugColor = heightDiff and heightDiff > 2 and Color(255, 128, 0) or Color(0, 255, 255)
                debugoverlay.Cross(groundTarget, 10, 0.5, debugColor, false)
                debugoverlay.Line(footPos, groundTarget, 0.5, debugColor, false)
                
                if heightDiff then
                    local label = heightDiff > 0 and string.format("Step UP: %.1f", heightDiff) or string.format("Step DOWN: %.1f", math.abs(heightDiff))
                    debugoverlay.Text(groundTarget + Vector(0, 0, 5), label, 0.5)
                end
            end
        end
    end

    for i = 1, 2 do
        local legName = (i == 1) and "left" or "right"
        local chain = data.ikChains[legName.."Leg"]
        
        if chain then
            local target = chain:GetTarget()
            
            if target and (data.legProgress[i] or 0) < 0.05 then
                local oldPos = data.lastFootPositions[i] or target
                local currentZ = target.z
                
                local comVel2D = Vector(comVel.x, comVel.y, 0)
                local velocityLength = comVel2D:Length()
                
                local searchPos = target
                if velocityLength > 30 then
                    local driftAmount = math.Clamp(velocityLength / 200, 0, 0.3) * dt
                    searchPos = target + (comVel2D * driftAmount)
                end
                
                local ground, normal, angle = FindGroundPosition(searchPos, ragdoll, currentZ)
                
                if ground then
                    local newPos = LerpVector(0.3, target, ground)
                    data.footPositions[i] = Vector(newPos.x, newPos.y, newPos.z)
                    
                    if dt > 0 then
                        data.footVelocities[i] = (newPos - oldPos) / dt
                    end
                    
                    data.lastFootPositions[i] = Vector(newPos.x, newPos.y, newPos.z)
                else
                    data.footPositions[i] = target
                    data.lastFootPositions[i] = target
                end
            end
        end
    end
end

local function AnimateLegs(ragdoll, data)
    if not IsValid(ragdoll) then return end
    
    local dt = FrameTime()
    if dt <= 0 or dt > 1 then return end
    
    local normalizedSpeed = CONFIG.StepSpeed * 0.35
    
    for i = 1, 2 do
        local legName = (i == 1) and "left" or "right"
        local chain = data.ikChains[legName.."Leg"]
        
        if chain and data.legProgress[i] and data.stepOrigin[i] and data.targetPositions[i] then
            
            data.legProgress[i] = math.max(0, data.legProgress[i] - (dt * normalizedSpeed))
            local progress = data.legProgress[i]
            
            if progress > 0 then
                local t = 1.0 - progress
                local smoothT = t * t * (3 - 2 * t)

                local startPos = data.stepOrigin[i]
                local endPos = data.targetPositions[i]
                
                local currentPos = LerpVector(smoothT, startPos, endPos)
                local liftFactor = math.sin(t * math.pi)
                local archZ = liftFactor * CONFIG.StepHeight
                
                local finalTarget = currentPos + Vector(0, 0, archZ)
                chain:SetTarget(finalTarget)
                data.footPositions[i] = finalTarget
            else
                local target = data.targetPositions[i]
                chain:SetTarget(target)
                data.footPositions[i] = target
            end
        end
    end
end


local BEHAVIOR = table.Copy(BehaviorBase)
BEHAVIOR.Name = "Stagger"

function BEHAVIOR:OnEnter()
    local ragdoll = self.Ragdoll
    if not IsValid(ragdoll) then return end

    local list = {  
    "ValveBiped.Bip01_Spine2"       ,
    "ValveBiped.Bip01_R_Forearm"   ,
    "ValveBiped.Bip01_L_Forearm"   ,
    "ValveBiped.Bip01_R_Upperarm"   ,
    "ValveBiped.Bip01_L_Upperarm"   ,
    "ValveBiped.Bip01_L_Hand"       ,
    "ValveBiped.Bip01_R_Hand"       ,
    "ValveBiped.Bip01_R_Thigh"  ,
    "ValveBiped.Bip01_R_Calf"       ,
    "ValveBiped.Bip01_Head1"        ,
    "ValveBiped.Bip01_L_Thigh"  ,           
    "ValveBiped.Bip01_L_Calf"       ,               
    }

    if ActiveRagdoll and ActiveRagdoll.PlayAnimation then
        ActiveRagdoll:ChangeModel(ragdoll, "models/AREAnims/model_anim.mdl")
        ActiveRagdoll:PlayAnimation(ragdoll, "Balance", 1.25, list)
    end

    self.ikChains = {}
    self.ikChains.leftLeg = IKSystem.CreateChain(ragdoll, {
        "ValveBiped.Bip01_L_Thigh","ValveBiped.Bip01_L_Calf","ValveBiped.Bip01_L_Foot"
    }, "leftLeg", Vector(0,0,50))

    self.ikChains.rightLeg = IKSystem.CreateChain(ragdoll, {
        "ValveBiped.Bip01_R_Thigh","ValveBiped.Bip01_R_Calf","ValveBiped.Bip01_R_Foot"
    }, "rightLeg", Vector(0,0,50))

    self.spinePhys = GetBonePhys(ragdoll, "ValveBiped.Bip01_Spine2")
    self.pelvisPhys = GetBonePhys(ragdoll, "ValveBiped.Bip01_Pelvis")
    
    local upForceCvar = GetConVar("ar_uprightForce")
    self.spineForce = upForceCvar and upForceCvar:GetFloat() or 480
    
    self.spineForceStartTime = CurTime()

    InitLegs(ragdoll, self)
end

function BEHAVIOR:OnThink()
    if not IsValid(self.Ragdoll) then return end
    if not IsValid(self.spinePhys) then return end

    local dt = FrameTime()
    if dt <= 0 or dt > 0.5 then
        return
    end

    if IsValid(self.pelvisPhys) then
        local pelvisVel = self.pelvisPhys:GetVelocity()
        local pelvisSpeed = pelvisVel:Length()
        
        if pelvisSpeed > CONFIG.MaxVelocity then
        self.spineForce = 0

        if self.ikChains then
            for _, chain in pairs(self.ikChains) do
                if chain and chain.Stop then chain:Stop() end
            end
        end
            return
        end
        
        if pelvisSpeed > CONFIG.PelvisStabilizationThreshold then
            local dampingForce = pelvisVel * -CONFIG.PelvisDamping
            self.pelvisPhys:AddVelocity(dampingForce * FrameTime())
            
            local excessSpeed = pelvisSpeed - CONFIG.PelvisStabilizationThreshold
            local stabilizationDir = pelvisVel:GetNormalized() * -1
            local stabilizationForce = stabilizationDir * (excessSpeed * CONFIG.PelvisStabilizationForce * FrameTime())
            self.pelvisPhys:ApplyForceCenter(stabilizationForce)
            
            local pelvisPos = self.pelvisPhys:GetPos()
            debugoverlay.Line(pelvisPos, pelvisPos + stabilizationDir * 30, 0.05, Color(255, 0, 255), false)
            debugoverlay.Text(pelvisPos + Vector(0, 0, 30), string.format("Stabilizing: %.1f", pelvisSpeed), 0.05)
        end
    end

    if self.Controller and self.Controller.dmgpos and not self.dmgInit then
        self.dmgInit = true
        self.dmgpos = self.Controller.dmgpos
        local ragPos = self.Ragdoll:GetPos()
        local dir = ragPos - self.dmgpos
        dir.z = 0
        dir:Normalize()
        self.damageDirection = dir
        self.damageForce = 50
        self.damageStartTime = CurTime()
    end

    UpdateLegTargets(self.Ragdoll, self)
    AnimateLegs(self.Ragdoll, self)

    if dt > 0 then
        if self.spineForce and self.spineForce > 0 then
            self.spinePhys:ApplyForceCenter(Vector(0, 0, self.spineForce))
        end
    end

    if self.damageStartTime and CurTime() - self.damageStartTime >= 1 then
        self.damageForce = 0
    end

    if self.spineForceStartTime and CurTime() - self.spineForceStartTime > GetConVar("ar_TimeBeforeDecay"):GetFloat() then
        self.spineForce = Lerp(FrameTime() * 2, self.spineForce, 0)
    end

    if self.spineForce and self.spineForce < 220 then
     --   self.spineForce = 100

        if self.ikChains then
            for _, chain in pairs(self.ikChains) do
                if chain and chain.Stop then chain:Stop() end
            end
        end
    end

    if self.damageDirection and self.damageForce and self.damageForce > 0 then
        if IsValid(self.pelvisPhys) then
            local forceVec = self.damageDirection * self.damageForce

            self.pelvisPhys:ApplyForceCenter(forceVec)
            
            if IsValid(self.spinePhys) then
                self.spinePhys:ApplyForceCenter(forceVec * 0.5)
            end

            local pelvisPos = self.pelvisPhys:GetPos()
            debugoverlay.Line(pelvisPos, pelvisPos + forceVec:GetNormalized() * 50, 0.05, Color(255, 100, 0), false)
            debugoverlay.Text(pelvisPos + Vector(0, 0, 20), string.format("Force: %.1f", self.damageForce), 0.05)
        end
        
        self.damageForce = Lerp(FrameTime() * 0.5, self.damageForce, 0)
    end
end

function BEHAVIOR:OnLeave()
    if self.ikChains then
        for _, chain in pairs(self.ikChains) do
            if chain then
                if chain.Stop then chain:Stop() end
                if chain.Reset then chain:Reset() end
            end
        end
        if IKSystem and IKSystem.RemoveEntityChains then
            IKSystem.RemoveEntityChains(self.Ragdoll)
        end
    end
    
    if ActiveRagdoll and ActiveRagdoll.StopAnimation and IsValid(self.Ragdoll) then
        ActiveRagdoll:StopAnimation(self.Ragdoll)
        ActiveRagdoll:ChangeModel(self.Ragdoll, "models/AREAnims/model_anim.mdl")
    end
end

AR_Manager:RegisterBehavior(BEHAVIOR.Name, BEHAVIOR)