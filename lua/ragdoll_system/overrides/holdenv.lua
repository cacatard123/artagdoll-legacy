local IKSystem = include("Components/Utils/IKChain.lua")

local OVERRIDEBEHAVIOR = table.Copy(OverrideBase)
OVERRIDEBEHAVIOR.Name = "HoldEnv"

local STATIC_VALUES = {
    ropeLength = 1.6,
    ropeWidth = 0,
    addLength = 0,
    blendOutTime = 0.5,
    ignoreFloors = true,
    searchInterval = 0.1
}

local DYNAMIC_CVARS = {
    searchRadius    = "ar_holdenv_search_radius",
    minGrabDist     = "ar_holdenv_min_dist",
    maxGrabDist     = "ar_holdenv_max_dist",
    releaseVelocity = "ar_holdenv_release_vel",
    minHoldTime     = "ar_holdenv_min_hold",
    maxHoldTime     = "ar_holdenv_max_hold",
    searchCooldown  = "ar_holdenv_cooldown",
    maxGrabs        = "ar_holdenv_max_grabs"
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
    end
})

local HAND_CONFIGS = {
    left = {
        bones = {
            "ValveBiped.Bip01_L_UpperArm",
            "ValveBiped.Bip01_L_Forearm",
            "ValveBiped.Bip01_L_Hand"
        },
        poleOffset = Vector(10, 15, 0),
    },
    right = {
        bones = {
            "ValveBiped.Bip01_R_UpperArm",
            "ValveBiped.Bip01_R_Forearm",
            "ValveBiped.Bip01_R_Hand"
        },
        poleOffset = Vector(10, 15, 0),
    }
}

local function GetPhysBoneName(ent, physObj)
    if not IsValid(ent) or not IsValid(physObj) then return "" end
    for i = 0, ent:GetPhysicsObjectCount() - 1 do
        if ent:GetPhysicsObjectNum(i) == physObj then
            local boneID = ent:TranslatePhysBoneToBone(i)
            return string.lower(ent:GetBoneName(boneID) or "")
        end
    end
    return ""
end

local function FindHandPhys(ragdoll, side)
    if not IsValid(ragdoll) then return nil, nil end
    
    local config = HAND_CONFIGS[side]
    if not config then return nil, nil end
    
    local targetBoneName = config.bones[3]
    return UniversalBone.FindBone(ragdoll, targetBoneName)
end

function OVERRIDEBEHAVIOR:CreateGrabAnchor(grabPos)
    local anchor = ents.Create("prop_dynamic")
    anchor:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    anchor:SetPos(grabPos)
    anchor:SetAngles(Angle(0, 0, 0))
    anchor:Spawn()
    anchor:Activate()
    
    anchor:SetRenderMode(RENDERMODE_NONE)
    anchor:SetNoDraw(true)
    anchor:DrawShadow(false)
    
    anchor:SetSolid(SOLID_NONE)

    return anchor
end

function OVERRIDEBEHAVIOR:CreateRopeConstraint(anchor, ragdoll, physBoneID)
    if not IsValid(anchor) or not IsValid(ragdoll) or not physBoneID then return nil end
    
    local rope = constraint.Rope(
        anchor, ragdoll, 0, physBoneID,
        Vector(0, 0, 0), Vector(0, 0, 0),
        CONFIG.ropeLength, CONFIG.addLength,
        0, CONFIG.ropeWidth, "cable/rope", false
    )
    
    if rope and rope.Entity and IsValid(rope.Entity) then
        rope.Entity:SetNoDraw(true)
    end
    
    return rope
end

function OVERRIDEBEHAVIOR:FindGrabPoint(handPos, ragdoll)
    local directions = {
        Vector(1, 0, 0), Vector(-1, 0, 0),
        Vector(0, 1, 0), Vector(0, -1, 0),
        Vector(0, 0, -1),
        Vector(0.7, 0.7, 0), Vector(-0.7, 0.7, 0),
        Vector(0.7, -0.7, 0), Vector(-0.7, -0.7, 0),
    }

    local bestTrace = nil
    local bestScore = -1

    for _, dir in ipairs(directions) do
        local trace = util.TraceLine({
            start = handPos,
            endpos = handPos + dir * CONFIG.searchRadius,
            filter = ragdoll,
            mask = MASK_SOLID_BRUSHONLY
        })

        if trace.Hit and not trace.HitSky then
            
            if CONFIG.ignoreFloors and trace.HitNormal.z > 0.7 then 
                goto skip_direction 
            end

            local dist = trace.Fraction * CONFIG.searchRadius

            local wallFactor = 1 - math.abs(trace.HitNormal.z)
            local score = (1 - trace.Fraction) * (1 + wallFactor)

            if dist >= CONFIG.minGrabDist and dist <= CONFIG.maxGrabDist then
                score = score * 1.5
            end

            if score > bestScore then
                bestScore = score
                bestTrace = trace
            end
        end
        
        ::skip_direction::
    end

    return bestTrace
end

function OVERRIDEBEHAVIOR:OnActivate(duration)
    local ragdoll = self.Ragdoll
    if not IsValid(ragdoll) then return end
    
    self.grabState = {
        leftHand = { cooldownUntil = 0 },
        rightHand = { cooldownUntil = 0 },
        activationTime = CurTime(),
        lastSearchTime = 0,
        searchInterval = CONFIG.searchInterval,
        currentlyGrabbingHand = nil,
        grabCount = 0,
    }
    
    self.ikChains = {}
    
    for side, config in pairs(HAND_CONFIGS) do
        local chain = IKSystem.CreateChain(
            ragdoll, config.bones, "Grab_" .. side, config.poleOffset, 
            {
                iterations = 20, snapBackStrength = 0.3, smoothTime = 0.02,
                positionSmoothTime = 0.08, poleStrength = 0.4, bendBias = 0.15,
                toleranceThreshold = 0.5, angleSmoothTime = 0.02, debug = true
            }
        )
        
        if chain then
            self.ikChains[side] = chain
            chain:Stop()
        end
    end
end

function OVERRIDEBEHAVIOR:UpdateGrabForHand(side, handConfig)
    local ragdoll = self.Ragdoll
    if not IsValid(ragdoll) or not self.ikChains[side] then return end
    
    local chain = self.ikChains[side]
    local state = self.grabState[side .. "Hand"]
    
    local handPhys, handPhysID = FindHandPhys(ragdoll, side)
    if not IsValid(handPhys) or not handPhysID then return end
    
    local handPos = handPhys:GetPos()

    if ragdoll.WoundGrabbing and ragdoll.WoundGrabbing[side] then
        if state.grabbing then self:ReleaseGrab(ragdoll, side, state, chain) end
        if state.blendingOut then
            chain:Stop()
            state.blendingOut = false
        end
        return
    end

    if state.blendingOut then
        local timeLeft = (state.blendStartTime + CONFIG.blendOutTime) - CurTime()
        if timeLeft <= 0 then
            state.blendingOut = false
            chain:Stop()
        else
            chain:SetTarget(handPos)
        end
        return
    end

    if not state.grabbing and 
       self.grabState.currentlyGrabbingHand == nil and
       self.grabState.grabCount < CONFIG.maxGrabs and
       CurTime() >= state.cooldownUntil and
       CurTime() - self.grabState.lastSearchTime > self.grabState.searchInterval then
        
        self.grabState.lastSearchTime = CurTime()
        
        if IsValid(handPhys) then
            local vel = handPhys:GetVelocity()
            if vel:Length() > 50 then
                local trace = self:FindGrabPoint(handPos, ragdoll)
                
                if trace and trace.Hit then
                    local grabPos = trace.HitPos + trace.HitNormal * 2
                    state.anchor = self:CreateGrabAnchor(grabPos)
                    
                    if IsValid(state.anchor) then
                        state.rope = self:CreateRopeConstraint(state.anchor, ragdoll, handPhysID)
                        
                        if state.rope then
                            state.grabbing = true
                            state.grabPos = grabPos
                            state.grabNormal = trace.HitNormal
                            state.grabTime = CurTime()
                            
                            self.grabState.currentlyGrabbingHand = side
                            self.grabState.grabCount = self.grabState.grabCount + 1
                            
                            chain:SetTarget(grabPos)
                            chain.active = true
                        else
                            SafeRemoveEntity(state.anchor)
                            state.anchor = nil
                        end
                    end
                end
            end
        end
    end
    
    if state.grabbing then
        local shouldRelease = false
        local holdDuration = CurTime() - state.grabTime
        
        if not IsValid(state.anchor) then shouldRelease = true end
        if holdDuration >= CONFIG.maxHoldTime then shouldRelease = true end
        
        if IsValid(handPhys) then
            local vel = handPhys:GetVelocity()
            if vel:Length() > CONFIG.releaseVelocity then shouldRelease = true end
            if state.grabPos and handPos:Distance(state.grabPos) > CONFIG.maxGrabDist * 2 then shouldRelease = true end
        end
        
        if shouldRelease and holdDuration > CONFIG.minHoldTime then
            self:ReleaseGrab(ragdoll, side, state, chain)
        end
        
        if state.grabPos then chain:SetTarget(state.grabPos) end
    end
end

function OVERRIDEBEHAVIOR:ReleaseGrab(ragdoll, side, state, chain)
    if state.rope then constraint.RemoveConstraints(ragdoll, "Rope") end
    if IsValid(state.anchor) then SafeRemoveEntity(state.anchor) end
    
    state.grabbing = false
    state.grabPos = nil
    state.grabNormal = nil
    state.anchor = nil
    state.rope = nil
    state.cooldownUntil = CurTime() + CONFIG.searchCooldown
    
    self.grabState.currentlyGrabbingHand = nil
    
    state.blendingOut = true
    state.blendStartTime = CurTime()
end

function OVERRIDEBEHAVIOR:OnThink()
    local ragdoll = self.Ragdoll
    if not IsValid(ragdoll) or not self.ikChains then return end

    for side, config in pairs(HAND_CONFIGS) do
        self:UpdateGrabForHand(side, config)
    end
    
    for side, state in pairs({left=self.grabState.leftHand, right=self.grabState.rightHand}) do
        if state and state.grabPos then
            debugoverlay.Sphere(state.grabPos, 5, 0.1, Color(100, 255, 100), true)
        end
    end
end

function OVERRIDEBEHAVIOR:OnDeactivate()
    local ragdoll = self.Ragdoll
    if not IsValid(ragdoll) then return end
    
    if self.grabState then
        for side, _ in pairs(HAND_CONFIGS) do
            local state = self.grabState[side .. "Hand"]
            if state then
                if state.rope then constraint.RemoveConstraints(ragdoll, "Rope") end
                if IsValid(state.anchor) then SafeRemoveEntity(state.anchor) end
            end
        end
    end
    
    if self.ikChains then
        for _, chain in pairs(self.ikChains) do
            if chain and chain.Destroy then chain:Destroy() end
        end
        self.ikChains = nil
    end
    
    self.grabState = nil
end

AR_Manager:RegisterOverrideBehavior(OVERRIDEBEHAVIOR.Name, OVERRIDEBEHAVIOR)