if not _G.IKSystem_Unity_FABRIK then 
    local IKSystem = {}
    local activeChains = {}

    local DEFAULT_CONFIG = {
        maxAngularSpeed = 15000,
        angularDampening = 0.2,
        arriveTime = 0.01,
        iterations = 20,
        snapBackStrength = 0.75,
        smoothTime = 0.03,
        positionSmoothTime = 0.1,
        debug = true,
        poleStrength = 0.25,
        bendBias = 0.12,
        toleranceThreshold = 0.002,
        angleSmoothTime = 0.03
    }

    local math_max, math_min, math_acos, math_sqrt, math_abs = math.max, math.min, math.acos, math.sqrt, math.abs
    local vector, angle = Vector, Angle
    local curtime = CurTime

    local function SmoothDamp(current, target, velocity, smoothTime, dt)
        smoothTime = math_max(0.0001, smoothTime)
        local omega = 2 / smoothTime
        local x = omega * dt
        local exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
        local change = current - target
        local temp = (velocity + change * omega) * dt
        velocity = (velocity - temp * omega) * exp
        return target + (change + temp) * exp, velocity
    end

    local function SmoothDampVector(current, target, velocity, smoothTime, dt)
        if not current or not target or not velocity then 
            return current or vector(0, 0, 0), velocity or vector(0, 0, 0)
        end
        local x, vx = SmoothDamp(current.x, target.x, velocity.x, smoothTime, dt)
        local y, vy = SmoothDamp(current.y, target.y, velocity.y, smoothTime, dt)
        local z, vz = SmoothDamp(current.z, target.z, velocity.z, smoothTime, dt)
        return vector(x, y, z), vector(vx, vy, vz)
    end

    local function SmoothDampAngle(current, target, velocity, smoothTime, dt)
        local function NormalizeAngle(a)
            a = a % 360
            if a > 180 then a = a - 360 end
            if a < -180 then a = a + 360 end
            return a
        end
        current = NormalizeAngle(current)
        target = NormalizeAngle(target)
        local diff = target - current
        if diff > 180 then diff = diff - 360 end
        if diff < -180 then diff = diff + 360 end
        local adjustedTarget = current + diff
        return SmoothDamp(current, adjustedTarget, velocity, smoothTime, dt)
    end

    local function VectorsToAngle(forward, right, up)
        local mat = Matrix()
        mat:SetForward(forward)
        mat:SetRight(right)
        mat:SetUp(up)
        return mat:GetAngles()
    end

    local function CalculatePoleTarget(positions, localPoleOffset, entity, midBoneIndex, pelvisIdx)
        if not IsValid(entity) then return nil end
        
        local n = #positions
        if n < 3 or not localPoleOffset then return nil end

        local midIdx = math.floor(n / 2) + 1
        local midPos = positions[midIdx]
        if not midPos then return nil end

        if pelvisIdx then
            local pelvisMatrix = entity:GetBoneMatrix(pelvisIdx)
            if pelvisMatrix then
                local pForward, pRight, pUp = pelvisMatrix:GetForward(), pelvisMatrix:GetRight(), pelvisMatrix:GetUp()
                local pelvisPos = pelvisMatrix:GetTranslation()

                local poleBase = pelvisPos
                    + pForward * localPoleOffset.x
                    + pRight * localPoleOffset.y
                    + pUp * localPoleOffset.z

                local stability = 0.65
                return LerpVector(stability, midPos, poleBase)
            end
        end

        local boneMatrix = entity:GetBoneMatrix(midBoneIndex)
        if not boneMatrix then return nil end
        local boneForward = boneMatrix:GetForward()
        local boneRight = boneMatrix:GetRight()
        local boneUp = boneMatrix:GetUp()
        local bonePos = boneMatrix:GetTranslation()
        return bonePos + boneForward * localPoleOffset.x +
               boneRight * localPoleOffset.y +
               boneUp * localPoleOffset.z
    end

    local function ApplyPoleConstraint(positions, polePos, strength)
        if not polePos or #positions < 3 then return end
        
        local n = #positions
        local root, tip = positions[1], positions[n]
        if not root or not tip then return end
        
        local limbDir = (tip - root):GetNormalized()
        
        for i = 2, n - 1 do
            if not positions[i] then continue end
            
            local toJoint = positions[i] - root
            local projection = limbDir * toJoint:Dot(limbDir)
            local projectedPoint = root + projection
            
            local perpendicular = positions[i] - projectedPoint
            local perpDist = perpendicular:Length()
            
            if perpDist > 0.001 then
                local toPole = polePos - projectedPoint
                local desiredPerp = toPole - limbDir * toPole:Dot(limbDir)
                
                if desiredPerp:LengthSqr() > 0.001 then
                    desiredPerp:Normalize()
                    
                    local blendedPerp = LerpVector(strength, perpendicular:GetNormalized(), desiredPerp)
                    blendedPerp:Normalize()
                    
                    positions[i] = projectedPoint + blendedPerp * perpDist
                end
            end
        end
    end

    local function EnforceBend(positions, boneLengths, bendBias)
        local n = #positions
        if n < 3 then return end
        local mid = math.floor(n / 2) + 1
        if not positions[1] or not positions[n] or not positions[mid] then return end
        
        local root, tip = positions[1], positions[n]
        local limbDir = (tip - root):GetNormalized()
        local dist = (tip - root):Length()
        local maxReach = 0
        for i = 1, #boneLengths do maxReach = maxReach + boneLengths[i] end
        
        local extension = dist / maxReach
        if extension > 0.92 then
            local bendAmount = (extension - 0.92) / 0.08
            bendAmount = math.Clamp(bendAmount, 0, 1) * bendBias
            
            local toMid = positions[mid] - root
            local projection = limbDir * toMid:Dot(limbDir)
            local perpOffset = toMid - projection
            
            if perpOffset:LengthSqr() < 1e-6 then
                perpOffset = limbDir:Cross(vector(0, 0, 1)):GetNormalized()
                if perpOffset:LengthSqr() < 1e-6 then
                    perpOffset = limbDir:Cross(vector(1, 0, 0)):GetNormalized()
                end
            else
                perpOffset:Normalize()
            end
            
            positions[mid] = positions[mid] + perpOffset * maxReach * bendAmount
        end
    end

    local function ResolveIK_Analytic3(positions, targetPos, boneLengths, polePos)
        if not positions or #positions < 3 then return positions or {} end
        if not positions[1] or not targetPos then return positions end
        if not boneLengths or not boneLengths[1] or not boneLengths[2] then return positions end
        
        local rootPos = positions[1]
        local upper, lower = boneLengths[1], boneLengths[2]
        local maxReach = upper + lower
        
        local toTarget = targetPos - rootPos
        local dist = toTarget:Length()
        
        if dist > maxReach - 0.01 then
            dist = maxReach - 0.01
        end
        
        local targetDir = toTarget:GetNormalized()
        
        local cosUpperAngle = (upper * upper + dist * dist - lower * lower) / (2 * upper * dist)
        cosUpperAngle = math.Clamp(cosUpperAngle, -1, 1)
        local upperAngle = math_acos(cosUpperAngle)
        
        local planeNormal
        if polePos then
            local toPole = polePos - rootPos
            planeNormal = targetDir:Cross(toPole)
            
            if planeNormal:LengthSqr() < 1e-6 then
                planeNormal = targetDir:Cross(vector(0, 0, 1))
                if planeNormal:LengthSqr() < 1e-6 then
                    planeNormal = targetDir:Cross(vector(1, 0, 0))
                end
            end
        else
            planeNormal = targetDir:Cross(vector(0, 0, 1))
            if planeNormal:LengthSqr() < 1e-6 then
                planeNormal = targetDir:Cross(vector(1, 0, 0))
            end
        end
        planeNormal:Normalize()
        
        local bendAxis = planeNormal:Cross(targetDir):GetNormalized()
        
        local elbowDir = targetDir * math.cos(upperAngle) + bendAxis * math.sin(upperAngle)
        elbowDir:Normalize()
        
        positions[2] = rootPos + elbowDir * upper
        
        local toLower = (targetPos - positions[2]):GetNormalized()
        positions[3] = positions[2] + toLower * lower
        
        return positions
    end

    local function ResolveIK_FABRIK(positions, targetPos, boneLengths, startDirections, completeLength, polePos, config)
        local numJoints = #positions
        if numJoints < 2 then return positions end
        if not positions[1] or not targetPos then return positions end
        
        local basePos = positions[1]
        local distToTarget = (targetPos - basePos):Length()

        if distToTarget >= completeLength * 0.998 then
            local dir = (targetPos - basePos):GetNormalized()
            for i = 2, numJoints do
                if not boneLengths[i - 1] then break end
                positions[i] = positions[i - 1] + dir * boneLengths[i - 1]
            end
            return positions
        end

        for i = 2, numJoints do
            if positions[i] and positions[i - 1] and startDirections[i - 1] then
                local naturalPos = positions[i - 1] + startDirections[i - 1]
                positions[i] = LerpVector(config.snapBackStrength, positions[i], naturalPos)
            end
        end

        if polePos then 
            ApplyPoleConstraint(positions, polePos, config.poleStrength * 0.4) 
        end
        EnforceBend(positions, boneLengths, config.bendBias)

        local prevError = math.huge
        local stagnationCount = 0
        
        for iter = 1, config.iterations do
            positions[numJoints] = targetPos
            
            for i = numJoints, 2, -1 do
                if not positions[i] or not positions[i - 1] or not boneLengths[i - 1] then break end
                
                local dir = positions[i - 1] - positions[i]
                local len = dir:Length()
                
                if len < 1e-6 then 
                    dir = vector(0, 0, 1)
                else 
                    dir = dir / len
                end
                
                positions[i - 1] = positions[i] + dir * boneLengths[i - 1]
            end

            positions[1] = basePos
            
            for i = 1, numJoints - 1 do
                if not positions[i] or not positions[i + 1] or not boneLengths[i] then break end
                
                local dir = positions[i + 1] - positions[i]
                local len = dir:Length()
                
                if len < 1e-6 then 
                    dir = vector(0, 0, 1)
                else 
                    dir = dir / len
                end
                
                positions[i + 1] = positions[i] + dir * boneLengths[i]
            end

            if iter % 3 == 0 and polePos then
                ApplyPoleConstraint(positions, polePos, config.poleStrength * 0.35)
            end

            if positions[numJoints] then
                local error = (positions[numJoints] - targetPos):Length()
                
                if error < config.toleranceThreshold then 
                    break 
                end
                
                local errorChange = math_abs(error - prevError)
                if errorChange < 0.00005 then
                    stagnationCount = stagnationCount + 1
                    if stagnationCount > 2 then
                        break
                    end
                else
                    stagnationCount = 0
                end
                
                prevError = error
            end
        end
        
        if polePos then
            ApplyPoleConstraint(positions, polePos, config.poleStrength * 0.2)
        end
        
        return positions
    end

    local IKChain = {}
    IKChain.__index = IKChain

    function IKChain:new(entity, boneNames, name, localPoleOffset, customConfig)
        if not IsValid(entity) then return nil end
        
        local chain = setmetatable({}, IKChain)
        chain.entity = entity
        chain.name = name or "IKChain"
        chain.localPoleOffset = localPoleOffset
        chain.active = false
        chain.destroyed = false
        chain.lastUpdateTime = curtime()
        chain.boneIndices = {}
        
        chain.physObjects = {} 
        
        chain.config = {}
        for k, v in pairs(DEFAULT_CONFIG) do
            chain.config[k] = v
        end
        if customConfig then
            for k, v in pairs(customConfig) do
                chain.config[k] = v
            end
        end

        for i, boneName in ipairs(boneNames) do
            local physObj = nil
            local boneIdx = nil

            if UniversalBone and UniversalBone.FindBone then
                local pObj, pID = UniversalBone.FindBone(entity, boneName)
                if IsValid(pObj) then
                    physObj = pObj
                    boneIdx = entity:TranslatePhysBoneToBone(pID)
                end
            end

            if not boneIdx or boneIdx == -1 then
                boneIdx = entity:LookupBone(boneName)
            end

            if not boneIdx then 
                print("Could not resolve bone: " .. tostring(boneName))
                return nil 
            end
            
            chain.boneIndices[i] = boneIdx
            chain.physObjects[i] = physObj
        end

        chain.pelvisIndex = nil
        if UniversalBone and UniversalBone.FindBone then
            local _, pID = UniversalBone.FindBone(entity, "Pelvis")
            if pID then
                 chain.pelvisIndex = entity:TranslatePhysBoneToBone(pID)
            end
        end
        
        if not chain.pelvisIndex then
             local candidates = {"ValveBiped.Bip01_Pelvis", "Pelvis", "Hips", "Hip", "Root"}
             for _, name in ipairs(candidates) do
                 local idx = entity:LookupBone(name)
                 if idx then chain.pelvisIndex = idx break end
             end
        end

        chain.positions, chain.boneLengths, chain.startDirections = {}, {}, {}
        chain.completeLength = 0
        for i, idx in ipairs(chain.boneIndices) do
            local pos = entity:GetBonePosition(idx)
            if not pos then return nil end
            chain.positions[i] = pos
        end

        for i = 1, #chain.positions - 1 do
            if not chain.positions[i] or not chain.positions[i + 1] then return nil end
            local dir = chain.positions[i + 1] - chain.positions[i]
            chain.boneLengths[i] = dir:Length()
            chain.startDirections[i] = dir
            chain.completeLength = chain.completeLength + chain.boneLengths[i]
        end

        chain.smoothedPositions, chain.positionVelocities = {}, {}
        for i = 1, #chain.positions do
            chain.smoothedPositions[i] = chain.positions[i] + vector()
            chain.positionVelocities[i] = vector()
        end

        chain.smoothedAngles = {}
        chain.angleVelocities = {}
        for i = 1, #chain.positions - 1 do
            local boneMatrix = entity:GetBoneMatrix(chain.boneIndices[i])
            if boneMatrix then
                chain.smoothedAngles[i] = boneMatrix:GetAngles()
                chain.angleVelocities[i] = Angle(0, 0, 0)
            else
                chain.smoothedAngles[i] = Angle(0, 0, 0)
                chain.angleVelocities[i] = Angle(0, 0, 0)
            end
        end

        if #chain.positions > 0 and chain.positions[#chain.positions] then
            chain.target = chain.positions[#chain.positions] + vector()
        else
            chain.target = vector(0, 0, 0)
        end
        
        chain.prevUp = vector(0, 0, 1)
        return chain
    end

    function IKChain:SetTarget(pos)
        if self.destroyed then return end
        if pos then
            self.target = vector(pos.x, pos.y, pos.z)
            self.active = true
        end
    end
    
    function IKChain:SetConfig(newConfig)
        if self.destroyed then return end
        if newConfig then
            for k, v in pairs(newConfig) do
                self.config[k] = v
            end
        end
    end
    
    function IKChain:GetConfig()
        return self.config
    end

    function IKChain:Update()
        if self.destroyed then return end
        if not self.active then return end
        if not IsValid(self.entity) then 
            self:Destroy()
            return 
        end
        
        if not self.target or not self.positions or not self.positions[1] then 
            return 
        end
        
        local dt = math.Clamp(curtime() - self.lastUpdateTime, 0, 0.1)
        self.lastUpdateTime = curtime()
        
        local rootBone = self.boneIndices[1]
        if rootBone then
            local rootPos = self.entity:GetBonePosition(rootBone)
            if rootPos then
                self.positions[1] = rootPos
            end
        end

        local midIdx = math.floor(#self.positions / 2) + 1
        local polePos = CalculatePoleTarget(self.positions, self.localPoleOffset, self.entity, self.boneIndices[midIdx], self.pelvisIndex)

        local solved
        if #self.positions == 3 then
            solved = ResolveIK_Analytic3(self.positions, self.target, self.boneLengths, polePos)
        else
            solved = ResolveIK_FABRIK(self.positions, self.target, self.boneLengths, self.startDirections, self.completeLength, polePos, self.config)
        end

        if solved then
            for i = 1, #solved do
                if solved[i] and self.smoothedPositions[i] and self.positionVelocities[i] then
                    self.smoothedPositions[i], self.positionVelocities[i] = SmoothDampVector(
                        self.smoothedPositions[i], solved[i], self.positionVelocities[i],
                        self.config.positionSmoothTime, dt
                    )
                end
            end
        end

        self:ApplyRotations(dt)
        if self.config.debug then self:DrawDebug(dt) end
    end

    function IKChain:ApplyRotations(dt)
        if self.destroyed or not IsValid(self.entity) then return end
        
        for i = 1, #self.smoothedPositions - 1 do
            if not self.smoothedPositions[i] or not self.smoothedPositions[i + 1] then continue end
            
            local phys = self.physObjects[i]

            if IsValid(phys) then
                local targetPos = self.smoothedPositions[i]
                local nextPos = self.smoothedPositions[i + 1]
                local boneDir = (nextPos - targetPos):GetNormalized()
                
                local boneMatrix = self.entity:GetBoneMatrix(self.boneIndices[i])
                if not boneMatrix then continue end
                
                local currentUp = boneMatrix:GetUp()
                local projectedUp = currentUp - boneDir * currentUp:Dot(boneDir)
                
                if projectedUp:LengthSqr() > 1e-6 then
                    projectedUp:Normalize()
                else
                    projectedUp = boneDir:Cross(vector(0, 0, 1))
                    if projectedUp:LengthSqr() < 1e-6 then projectedUp = boneDir:Cross(vector(1, 0, 0)) end
                    projectedUp:Normalize()
                end
                
                local right = boneDir:Cross(projectedUp):GetNormalized()
                local up = right:Cross(boneDir):GetNormalized()
                local targetAngle = VectorsToAngle(boneDir, right, up)
                
                if self.smoothedAngles[i] and self.angleVelocities[i] then
                    local p, vp = SmoothDampAngle(self.smoothedAngles[i].p, targetAngle.p, self.angleVelocities[i].p, self.config.angleSmoothTime, dt)
                    local y, vy = SmoothDampAngle(self.smoothedAngles[i].y, targetAngle.y, self.angleVelocities[i].y, self.config.angleSmoothTime, dt)
                    local r, vr = SmoothDampAngle(self.smoothedAngles[i].r, targetAngle.r, self.angleVelocities[i].r, self.config.angleSmoothTime, dt)
                    
                    self.smoothedAngles[i] = Angle(p, y, r)
                    self.angleVelocities[i] = Angle(vp, vy, vr)

                    phys:ComputeShadowControl({
                        angle = self.smoothedAngles[i],
                        secondstoarrive = self.config.arriveTime,
                        maxangular = self.config.maxAngularSpeed,
                        maxangulardamp = self.config.maxAngularSpeed,
                        dampfactor = self.config.angularDampening,
                        deltatime = dt,
                        teleportdistance = 0
                    })
                end
            end
        end
    end

    function IKChain:DrawDebug(dt)
        if self.destroyed or not IsValid(self.entity) then return end
        if not self.smoothedPositions or not self.target then return end
        
        local t = dt * 3
        for i = 1, #self.smoothedPositions - 1 do
            if self.smoothedPositions[i] and self.smoothedPositions[i + 1] then
                debugoverlay.Line(self.smoothedPositions[i], self.smoothedPositions[i + 1], t, Color(100, 255, 150), false)
            end
        end
        debugoverlay.Sphere(self.target, 5, t, Color(255, 50, 50), false)
    end

    function IKChain:Destroy()
        self.destroyed = true
        self.active = false
        self.entity = nil
        self.positions = nil
        self.smoothedPositions = nil
        self.target = nil
        self.physObjects = nil
    end

    function IKChain:Stop() 
        self.active = false 
    end
    
    function IKChain:IsActive() 
        return self.active and not self.destroyed 
    end
    
    function IKChain:GetTarget() 
        return self.target 
    end

    function IKSystem.CreateChain(ent, bones, name, localPoleOffset, customConfig)
        if not IsValid(ent) then return end
        local chain = IKChain:new(ent, bones, name, localPoleOffset, customConfig)
        if not chain then return end
        local id = ent:EntIndex()
        activeChains[id] = activeChains[id] or {}
        table.insert(activeChains[id], chain)
        return chain
    end

    function IKSystem.UpdateAll()
        for id, chains in pairs(activeChains) do
            local e = Entity(id)
            if not IsValid(e) then
                for _, chain in ipairs(chains) do
                    if chain and chain.Destroy then chain:Destroy() end
                end
                activeChains[id] = nil
            else
                for _, c in ipairs(chains) do 
                    if c and not c.destroyed then c:Update() end
                end
            end
        end
    end
    
    function IKSystem.RemoveEntityChains(ent)
        if not IsValid(ent) then return end
        local id = ent:EntIndex()
        if activeChains[id] then
            for _, chain in ipairs(activeChains[id]) do
                if chain and chain.Destroy then chain:Destroy() end
            end
            activeChains[id] = nil
        end
    end

    hook.Add("Think", "IKSystem_UnityFABRIK_Update", IKSystem.UpdateAll)
    hook.Add("EntityRemoved", "IKSystem_UnityFABRIK_Cleanup", function(ent)
        local id = ent:EntIndex()
        if activeChains[id] then
            for _, chain in ipairs(activeChains[id]) do
                if chain and chain.Destroy then chain:Destroy() end
            end
            activeChains[id] = nil
        end
    end)

    _G.IKSystem_Unity_FABRIK = IKSystem
end

return _G.IKSystem_Unity_FABRIK