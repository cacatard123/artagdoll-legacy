local OVERRIDEBEHAVIOR = table.Copy(OverrideBase)
OVERRIDEBEHAVIOR.Name = "WallStunt"
OVERRIDEBEHAVIOR.Debug = true

local LAUNCH_FORCE = 90
local UPWARD_BOOST = 80
local TORQUE_STRENGTH = 110
local DIAGONAL_TORQUE = 255

function OVERRIDEBEHAVIOR:OnActivate(duration)
    self.IsActive = true
    self.hittedWall = false
    self.flipping = false
    self.flipStartTime = 0
    self.flipDuration = 0.7
    self.torqueDuration = 0.8
    self.appliedInitialForce = false
    self.flipDir = nil
    self.spinAxis = nil
    self.diagonalAxis = nil
    self.flipPoint = Vector(0,0,0)
    self.initialVelocity = 0

    if ActiveRagdoll and ActiveRagdoll.PlayAnimation then
        ActiveRagdoll:ChangeModel(ragdoll, "models/AREAnims/model_anim.mdl")
        ActiveRagdoll:PlayAnimation(ragdoll, "StuntWall", 1)
    end
end

function OVERRIDEBEHAVIOR:OnThink()
    local ragdoll = self.Ragdoll
    if not IsValid(ragdoll) then return end

    local pelvisBone = ragdoll:LookupBone("ValveBiped.Bip01_Pelvis")
    if not pelvisBone then return end
    local pelvisPhys = ragdoll:GetPhysicsObjectNum(pelvisBone)
    if not IsValid(pelvisPhys) then return end

    local spineBone = ragdoll:LookupBone("ValveBiped.Bip01_Spine2")
    local spinePhys = spineBone and ragdoll:GetPhysicsObjectNum(spineBone)
    
    local headBone = ragdoll:LookupBone("ValveBiped.Bip01_Head1")
    local headPhys = headBone and ragdoll:GetPhysicsObjectNum(headBone)
    
    if self.flipping then
        local timeElapsed = CurTime() - self.flipStartTime
        local progress = math.Clamp(timeElapsed / self.flipDuration, 0, 1)
        
        if progress >= 1 then
            self.flipping = false
            self.appliedInitialForce = false
            self.spinAxis = nil
            self.diagonalAxis = nil
            self.flipDir = nil
            return
        end

        if not self.spinAxis or not self.flipDir or not self.diagonalAxis then
            return
        end

        if timeElapsed < self.torqueDuration then
            local primaryCurve = 1 - math.pow(progress, 1.5)
            local primaryTorque = TORQUE_STRENGTH * primaryCurve
            
            local diagonalCurve = math.sin(progress * math.pi) * 1.2
            local diagonalTorque = DIAGONAL_TORQUE * diagonalCurve
            
            pelvisPhys:ApplyTorqueCenter(-self.spinAxis * primaryTorque)
            pelvisPhys:ApplyTorqueCenter(-self.diagonalAxis * diagonalTorque)
            
            if spinePhys then
                spinePhys:ApplyTorqueCenter(-self.spinAxis * primaryTorque * 0.8)
                spinePhys:ApplyTorqueCenter(-self.diagonalAxis * diagonalTorque * 0.6)
            end
        end

        if spinePhys then
            local forceCurve = math.exp(-progress * 2.0)
            local continuousForce = self.flipDir * (LAUNCH_FORCE * 0.4 * forceCurve)
            
            pelvisPhys:AddVelocity(continuousForce * FrameTime() * 50)
            spinePhys:AddVelocity(continuousForce * FrameTime() * 60)
            
            if headPhys then
                headPhys:AddVelocity(continuousForce * FrameTime() * 30)
            end
        end

        if not self.appliedInitialForce and spinePhys then
            local pelvisMass = pelvisPhys:GetMass()
            local spineMass = spinePhys:GetMass()
            
            local velocityBoost = math.max(self.initialVelocity / 300, 1.0)
            local totalForce = (LAUNCH_FORCE + UPWARD_BOOST) * velocityBoost
            
            local massRatio = spineMass / (pelvisMass + spineMass)
            local pelvisForce = self.flipDir * (totalForce * (1 - massRatio))
            local spineForce = self.flipDir * (totalForce * massRatio * 1.2)
            
            pelvisPhys:ApplyForceCenter(pelvisForce)
            spinePhys:ApplyForceCenter(spineForce)
            pelvisPhys:AddAngleVelocity(self.spinAxis * -150)

            self.appliedInitialForce = true
        end

        if self.Debug then
            local pelvisPos = pelvisPhys:GetPos()
            debugoverlay.Line(pelvisPos, self.flipPoint, 0.1, Color(255,255,255), true)
            debugoverlay.Line(pelvisPos, pelvisPos + self.spinAxis * 50, 0.1, Color(255,0,0,255), true)
            debugoverlay.Line(pelvisPos, pelvisPos + self.diagonalAxis * 50, 0.1, Color(255,128,0,255), true)
            debugoverlay.Line(pelvisPos, pelvisPos + self.flipDir * 50, 0.1, Color(0,255,0,255), true)
        end

        return
    end

    if self.hittedWall then return end

    local pelvisPos = pelvisPhys:GetPos()
    local pelvisVel = pelvisPhys:GetVelocity()
    local horizontalVel = Vector(pelvisVel.x, pelvisVel.y, 0)
    local horizontalSpeed = horizontalVel:Length()
    
    --if horizontalSpeed < 1 then return end -- we dontneed thatt

    local dir = horizontalVel:GetNormalized()
    local traceStart = pelvisPos + Vector(0,0,-7.5)

    local lowerTrace = util.TraceLine({
        start = traceStart,
        endpos = traceStart + dir * 7,
        mask = MASK_SOLID,
        filter = ragdoll
    })
    if not lowerTrace.Hit or math.abs(lowerTrace.HitNormal.z) > 0.5 then return end

    local upperStart = pelvisPos + Vector(0,0,10)
    local upperTrace = util.TraceLine({
        start = upperStart,
        endpos = upperStart + dir * 60,
        mask = MASK_SOLID,
        filter = ragdoll
    })
    if upperTrace.Hit then return end

    local hitPos = lowerTrace.HitPos
    local edgeSearchStart = hitPos + lowerTrace.HitNormal * 2

    local upTrace = util.TraceLine({
        start = edgeSearchStart,
        endpos = edgeSearchStart + Vector(0,0,20),
        mask = MASK_SOLID,
        filter = ragdoll
    })
    local topEdgePos = upTrace.Hit and upTrace.HitPos or edgeSearchStart + Vector(0,0,20)

    local groundSearchZ = pelvisPos.z - 150
    local bottomTrace = util.TraceLine({
        start = edgeSearchStart + Vector(0,0,5),
        endpos = Vector(edgeSearchStart.x, edgeSearchStart.y, groundSearchZ),
        mask = MASK_SOLID,
        filter = ragdoll
    })
    if not bottomTrace.Hit then return end

    local bottomPos = bottomTrace.HitPos
    local wallHeight = topEdgePos.z - bottomPos.z
    if wallHeight < 35 or wallHeight > 80 then return end

    local speedFactor = math.Clamp(horizontalSpeed / 250, 1.0, 1.6)
    local verticalOffset = 15 + (wallHeight * 0.35) * speedFactor
    local horizontalOffset = (45 + wallHeight * 0.15) * speedFactor
    local flipPoint = topEdgePos + Vector(0,0, verticalOffset) + dir * horizontalOffset

    self.hittedWall = true
    self.flipping = true
    self.flipStartTime = CurTime()
    self.flipPoint = flipPoint
    self.appliedInitialForce = false
    self.initialVelocity = horizontalSpeed

    local toFlipPoint = self.flipPoint - pelvisPos
    self.flipDir = toFlipPoint:GetNormalized()
    
    local rightVector = dir:Cross(Vector(0,0,1))
    self.spinAxis = rightVector:GetNormalized()
    
    local upVector = Vector(0, 0, 1)
    self.diagonalAxis = (self.spinAxis + dir * 0.6 + upVector * 0.4):GetNormalized()

    local currentVel = pelvisPhys:GetVelocity()
    pelvisPhys:SetVelocity(currentVel * 0.6)
    
    local currentAngVel = pelvisPhys:GetAngleVelocity()
    pelvisPhys:SetAngleVelocity(currentAngVel * 0.5)

    if self.Debug then
        debugoverlay.Line(pelvisPos, flipPoint, 2, Color(255,255,255), true)
        debugoverlay.Line(bottomPos, topEdgePos, 2, Color(0,255,0), true)
        debugoverlay.Sphere(bottomPos, 4, 2, Color(0,0,255), true)
        debugoverlay.Sphere(topEdgePos, 4, 2, Color(255,250,0), true)
        debugoverlay.Sphere(flipPoint, 6, 2, Color(255,0,255), true)
        debugoverlay.Line(pelvisPos, pelvisPos + self.spinAxis * 50, 2, Color(255,0,0,255), true)
        debugoverlay.Line(pelvisPos, pelvisPos + self.diagonalAxis * 50, 2, Color(255,128,0,255), true)
        debugoverlay.Line(pelvisPos, pelvisPos + self.flipDir * 50, 2, Color(0,255,0,255), true)
    end
end

function OVERRIDEBEHAVIOR:OnDeactivate()
    self.IsActive = false
    self.hittedWall = false
    self.flipping = false
    self.appliedInitialForce = false
    self.flipDir = nil
    self.spinAxis = nil
    self.diagonalAxis = nil
end

AR_Manager:RegisterOverrideBehavior(OVERRIDEBEHAVIOR.Name, OVERRIDEBEHAVIOR)