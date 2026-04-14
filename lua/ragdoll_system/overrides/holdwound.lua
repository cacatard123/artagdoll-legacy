local OVERRIDEBEHAVIOR = table.Copy(OverrideBase)
OVERRIDEBEHAVIOR.Name = "HoldWound"

local activeConstraints = {}
local activeNoCollides = {}

local function SafeGetBoneName(ent, id)
    if not IsValid(ent) or not id or id == -1 then return "" end
    local success, name = pcall(function() return ent:GetBoneName(id) end)
    return success and name and string.lower(name) or ""
end

local function LookupPhysBone(ragdoll, bonename)
    if not IsValid(ragdoll) then return nil end
    local _, physID = UniversalBone.FindBone(ragdoll, bonename)
    return physID
end

local function FindClosestPhysBoneFromDamage(ragdoll, dmgpos)
    if not IsValid(ragdoll) or not dmgpos then return nil end

    local closest_phys_bone, closest_distance = nil, math.huge

    for phys_bone = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local phys = ragdoll:GetPhysicsObjectNum(phys_bone)
        if IsValid(phys) then
            local boneID = ragdoll:TranslatePhysBoneToBone(phys_bone)
            local boneName = SafeGetBoneName(ragdoll, boneID)
            if boneName:find("hand") or boneName:find("foot") then continue end

            local min, max = phys:GetAABB()
            if min and max then
                local center = phys:LocalToWorld((min + max) * 0.5)
                local dist = center:DistToSqr(dmgpos)
                if dist < closest_distance then
                    closest_distance = dist
                    closest_phys_bone = phys_bone
                end
            end
        end
    end

    return closest_phys_bone
end

local function IsArmInjured(ragdoll, side, woundPhysNum)
    if not IsValid(ragdoll) or not woundPhysNum then return false end
    local armBones = side == "Left" and {
        LookupPhysBone(ragdoll, "ValveBiped.Bip01_L_UpperArm"),
        LookupPhysBone(ragdoll, "ValveBiped.Bip01_L_Forearm"),
        LookupPhysBone(ragdoll, "ValveBiped.Bip01_L_Hand")
    } or {
        LookupPhysBone(ragdoll, "ValveBiped.Bip01_R_UpperArm"),
        LookupPhysBone(ragdoll, "ValveBiped.Bip01_R_Forearm"),
        LookupPhysBone(ragdoll, "ValveBiped.Bip01_R_Hand")
    }
    return table.HasValue(armBones, woundPhysNum)
end

local function GetWoundSideGeometrically(ragdoll, dmgpos)
    local _, pelvisPhysID = UniversalBone.FindBone(ragdoll, "ValveBiped.Bip01_Pelvis")
    
    if not pelvisPhysID then return "Right" end
    
    local pelvisID = ragdoll:TranslatePhysBoneToBone(pelvisPhysID)
    
    local matrix = ragdoll:GetBoneMatrix(pelvisID)
    if not matrix then return "Right" end
    
    local rightDir = matrix:GetRight()
    local centerPos = matrix:GetTranslation()
    return (dmgpos - centerPos):Dot(rightDir) > 0 and "Right" or "Left"
end

local function GetHandData(ragdoll, side)
    local boneName = side == "Right" and "ValveBiped.Bip01_R_Hand" or "ValveBiped.Bip01_L_Hand"
    
    local phys, physID = UniversalBone.FindBone(ragdoll, boneName)
    
    if IsValid(phys) then
        local boneID = ragdoll:TranslatePhysBoneToBone(physID)
        return phys, boneID, physID
    end
    return nil
end

local function DeactivateArm(ragdoll, side)
    if not IsValid(ragdoll) then return end
    local armBones = side == "Left" and {
        LookupPhysBone(ragdoll, "ValveBiped.Bip01_L_UpperArm"),
        LookupPhysBone(ragdoll, "ValveBiped.Bip01_L_Forearm"),
        LookupPhysBone(ragdoll, "ValveBiped.Bip01_L_Hand")
    } or {
        LookupPhysBone(ragdoll, "ValveBiped.Bip01_R_UpperArm"),
        LookupPhysBone(ragdoll, "ValveBiped.Bip01_R_Forearm"),
        LookupPhysBone(ragdoll, "ValveBiped.Bip01_R_Hand")
    }
    for i = 2, #armBones do
        if armBones[i] and ragdoll.DeactivateBone then ragdoll:DeactivateBone(armBones[i]) end
    end
end

local function CreateLengthConstraint(ragdoll, phys_hand, phys_wound, dmgpos, handBoneID, woundBoneID, offset)
    if not (IsValid(phys_hand) and IsValid(phys_wound)) then return nil, nil end

    phys_hand:Wake()
    phys_wound:Wake()

    local nocollide = constraint.NoCollide(ragdoll, ragdoll, handBoneID, woundBoneID)

    local length = phys_hand:GetEntity() ~= phys_wound:GetEntity() and 3 or 0.6
    local force_limit = phys_hand:GetEntity() ~= phys_wound:GetEntity() and 1500 or 10000

    local c = ents.Create("phys_lengthconstraint")
    if not IsValid(c) then return nil, nocollide end
    c:SetPos(phys_hand:LocalToWorld(offset or Vector(5, 0, 0)))
    c:SetKeyValue("attachpoint", tostring(dmgpos))
    c:SetKeyValue("minlength", "0.3")
    c:SetKeyValue("length", tostring(length))
    c:SetKeyValue("forcelimit", force_limit)
    c:SetPhysConstraintObjects(phys_hand, phys_wound)
    c:Spawn()
    c:Activate()

    return c, nocollide
end

function OVERRIDEBEHAVIOR:OnActivate(duration)
    if not IsValid(self.Ragdoll) then return end
    if self.Controller and self.Controller.isHeadshot then return end
    if not (self.Controller and self.Controller.dmgpos) then return end

    local cvChance = GetConVar("ar_holdwound_chance")
    local cvMin = GetConVar("ar_holdwound_minduration")
    local cvMax = GetConVar("ar_holdwound_maxduration")

    local valChance = cvChance and cvChance:GetFloat()
    local valMin = cvMin and cvMin:GetFloat()
    local valMax = cvMax and cvMax:GetFloat()

    print("[HoldWound DEBUG] Chance:", valChance, " Min:", valMin, " Max:", valMax)

    if valChance <= 0 then return self:OnDeactivate() end
    if valChance < 100 and math.random() > (valChance / 100) then
        return self:OnDeactivate()
    end

    self.IsActive = true
    self.FoundDmgPos = false
    self.ConstraintsCreated = false

    if valMin > valMax then valMin = valMax end
    self.HoldTime = math.Rand(valMin, valMax)

    timer.Simple(self.HoldTime, function()
        if IsValid(self.Ragdoll) and self.IsActive then
            self:OnDeactivate()
        end
    end)
end

function OVERRIDEBEHAVIOR:OnThink()
    if not SERVER then return end
    if not IsValid(self.Ragdoll) then return self:OnDeactivate() end
    if self.Controller and self.Controller.isHeadshot then return end

    if not self.ConstraintsCreated and self.Controller and self.Controller.dmgpos then
        self.FoundDmgPos = true
        local success = pcall(function() self:CreateWoundGrab() end)
        if not success then ErrorNoHalt("Failed to create wound grab constraints\n") end
        self.ConstraintsCreated = true
    end
end

function OVERRIDEBEHAVIOR:CreateWoundGrab()
    if not SERVER then return end
    local ragdoll = self.Ragdoll
    if not IsValid(ragdoll) then return end

    local dmgpos = self.Controller and self.Controller.dmgpos
    if not dmgpos then return end

    local phys_bone_wound_id = FindClosestPhysBoneFromDamage(ragdoll, dmgpos)
    if not phys_bone_wound_id then return end
    local phys_wound = ragdoll:GetPhysicsObjectNum(phys_bone_wound_id)
    if not IsValid(phys_wound) then return end

    local wound_bone_name = SafeGetBoneName(ragdoll, ragdoll:TranslatePhysBoneToBone(phys_bone_wound_id))
    local woundBoneID = ragdoll:TranslatePhysBoneToBone(phys_bone_wound_id)
    if wound_bone_name:find("hand") then return end

    dmgpos = dmgpos + Vector(1, 0, 0)

    local ragIndex = ragdoll:EntIndex()
    activeConstraints[ragIndex] = activeConstraints[ragIndex] or {}
    activeNoCollides[ragIndex] = activeNoCollides[ragIndex] or {}

    local leftInjured = IsArmInjured(ragdoll, "Left", phys_bone_wound_id)
    local rightInjured = IsArmInjured(ragdoll, "Right", phys_bone_wound_id)

    local woundSide = "Right"
    if wound_bone_name:find("_l_") or wound_bone_name:find("left") then
        woundSide = "Left"
    elseif wound_bone_name:find("_r_") or wound_bone_name:find("right") then
        woundSide = "Right"
    else
        woundSide = GetWoundSideGeometrically(ragdoll, dmgpos)
    end

    local valTwoHand = (GetConVar("ar_holdwound_twohand_chance") or {GetFloat=function() return 0 end}):GetFloat()
    local wantTwoHand = valTwoHand > 0 and (math.random() <= valTwoHand / 100)

    local function AttachHand(side)
        if side == "Left" and leftInjured then return end
        if side == "Right" and rightInjured then return end

        local phys_hand, boneID_Hand, physID_Hand = GetHandData(ragdoll, side)
        if not IsValid(phys_hand) then return end
        DeactivateArm(ragdoll, side)
        if ragdoll.DeactivateBone then ragdoll:DeactivateBone(phys_bone_wound_id) end

        local c, nocollide = CreateLengthConstraint(ragdoll, phys_hand, phys_wound, dmgpos, boneID_Hand, woundBoneID)
        if IsValid(c) then table.insert(activeConstraints[ragIndex], c) end
        if IsValid(nocollide) then table.insert(activeNoCollides[ragIndex], nocollide) end
    end

    if leftInjured and rightInjured then return
    elseif leftInjured then AttachHand("Right")
    elseif rightInjured then AttachHand("Left")
    elseif wantTwoHand then AttachHand("Left"); AttachHand("Right")
    else
        AttachHand(woundSide == "Right" and "Left" or "Right")
    end
end

function OVERRIDEBEHAVIOR:OnDeactivate()
    local ragdoll = self.Ragdoll
    local function CleanList(list, id)
        if list[id] then
            for _, ent in ipairs(list[id]) do if IsValid(ent) then SafeRemoveEntity(ent) end end
            list[id] = nil
        end
    end
    if IsValid(ragdoll) then
        ragdoll.WoundGrabbing = nil
        local id = ragdoll:EntIndex()
        CleanList(activeConstraints, id)
        CleanList(activeNoCollides, id)
    else
        for id, _ in pairs(activeConstraints) do
            CleanList(activeConstraints, id)
            CleanList(activeNoCollides, id)
        end
    end
    self.IsActive = false
end

AR_Manager:RegisterOverrideBehavior(OVERRIDEBEHAVIOR.Name, OVERRIDEBEHAVIOR)