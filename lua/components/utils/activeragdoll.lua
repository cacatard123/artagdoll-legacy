ActiveRagdoll = ActiveRagdoll or {}
ActiveRagdoll.Animators = ActiveRagdoll.Animators or {}

local IsValid = IsValid
local Angle = Angle
local Vector = Vector
local ents_Create = ents.Create

local ZERO_ANGLE = Angle(0, 0, 0)
local DEFAULT_ANIM_MODEL = "models/AREAnims/model_anim.mdl"
local PARENT_MODEL = "models/hunter/plates/plate.mdl"
local CONTROLLER_CLASS = "active_ragdoll_controller"

local ANGLE_STANDARD = Angle(-90, -90, 0) 

local DEFAULTBONELIST = {
    "ValveBiped.Bip01_Pelvis",
    "ValveBiped.Bip01_Spine",
    "ValveBiped.Bip01_Spine1",
    "ValveBiped.Bip01_Spine2",
    "ValveBiped.Bip01_Spine4",
    "ValveBiped.Bip01_Head1",
    "ValveBiped.Bip01_L_Thigh",
    "ValveBiped.Bip01_L_Calf",
    "ValveBiped.Bip01_L_Foot",
    "ValveBiped.Bip01_R_Thigh",
    "ValveBiped.Bip01_R_Calf",
    "ValveBiped.Bip01_R_Foot",
    "ValveBiped.Bip01_L_UpperArm",
    "ValveBiped.Bip01_L_Forearm",
    "ValveBiped.Bip01_L_Hand",
    "ValveBiped.Bip01_R_UpperArm",
    "ValveBiped.Bip01_R_Forearm",
    "ValveBiped.Bip01_R_Hand",
}

local function GetValidAnimData(ragdoll)
    local animData = ActiveRagdoll.Animators[ragdoll]
    if animData and IsValid(animData.controller) then
        return animData
    end
    return nil
end

local function CreateParentEnt(ragdoll)
    if not IsValid(ragdoll) then return nil end
    
    local bonePos = ragdoll:GetBonePosition(0)
    if not bonePos then return nil end
    
    local parentent = ents_Create("prop_dynamic")
    if not IsValid(parentent) then return nil end
    
    parentent:SetModel(PARENT_MODEL)
    parentent:SetPos(bonePos)
    parentent:Spawn()
    parentent:SetNoDraw(true)
    parentent:DrawShadow(false)
    
    parentent:SetMoveType(MOVETYPE_NONE) 
    
    return parentent
end

function ActiveRagdoll:CreateAnimator(ragdoll, model, boneList)
    if not IsValid(ragdoll) then return nil end

    local animData = GetValidAnimData(ragdoll)
    if animData then
        return animData.controller
    end

    local parentent = CreateParentEnt(ragdoll)
    if not IsValid(parentent) then return nil end
    
    local contr = ents_Create(CONTROLLER_CLASS)
    if not IsValid(contr) then
        if IsValid(parentent) then parentent:Remove() end
        return nil
    end

    contr.Model = model or DEFAULT_ANIM_MODEL

    if contr.SetTarget then
        contr:SetTarget(ragdoll)
    end

    if contr.SetParent then
        contr:SetParent(parentent)
    end
    
    contr:SetPos(parentent:GetPos())
    contr:SetParent(parentent) 

    if boneList then
        if contr.SetBoneList then
            contr:SetBoneList(boneList)
        end
    end

    contr:Spawn()
    contr:Activate()

    parentent:SetAngles(ZERO_ANGLE)
    contr:SetAngles(ANGLE_STANDARD)

    self.Animators[ragdoll] = {
        controller = contr,
        parent = parentent,
        currentBoneList = boneList
    }
    
    return contr
end

function ActiveRagdoll:GetAnimator(ragdoll, model, boneList)
    local animData = GetValidAnimData(ragdoll)
    if animData then
        return animData.controller
    end
    return self:CreateAnimator(ragdoll, model, boneList)
end

function ActiveRagdoll:GetParent(ragdoll)
    local animData = self.Animators[ragdoll]
    return animData and animData.parent or nil
end

function ActiveRagdoll:PlayAnimation(ragdoll, animation, playbackRate, bonelist)
    local animData = GetValidAnimData(ragdoll)
    if not animData then return end

    local contr = animData.controller
    if not contr.LookupSequence then return end
    
    if bonelist then
        contr:SetBoneList(bonelist)
        animData.currentBoneList = bonelist
    elseif animData.currentBoneList then
    else
        contr:SetBoneList(DEFAULTBONELIST)
        animData.currentBoneList = DEFAULTBONELIST
    end

    local seq = contr:LookupSequence(animation)
    if seq and seq ~= -1 then
        if contr.ResetSequence then
            contr:ResetSequence(seq)
        end
        if contr.SetPlaybackRate then
            contr:SetPlaybackRate(playbackRate or 1)
        end
    else
        print("Animation not found:", animation)
    end
end

function ActiveRagdoll:ChangeModel(ragdoll, model)
    if not model then return end
    
    local animData = GetValidAnimData(ragdoll)
    if not animData then return end
    
    if IsValid(animData.controller) and animData.controller.SetModel then
        animData.controller:SetModel(model)
    end
end

function ActiveRagdoll:ChangeBoneList(ragdoll, boneList)
    local animData = GetValidAnimData(ragdoll)
    if not animData then return end
    
    animData.currentBoneList = boneList
    
    local contr = animData.controller
    if IsValid(contr) and contr.SetBoneList then
        contr:SetBoneList(boneList)
    end
end

function ActiveRagdoll:SetStrength(ragdoll, amount)
    local animData = GetValidAnimData(ragdoll)
    if not animData then return end

    local contr = animData.controller
    if IsValid(contr) then
        if contr.SetReactionStrength then
            contr:SetReactionStrength(amount)
        elseif contr.reaction_strength then
            contr.reaction_strength = amount
        end
    end
end

function ActiveRagdoll:StopAnimation(ragdoll)
    local animData = GetValidAnimData(ragdoll)
    if not animData then return end
    
    local contr = animData.controller
    if IsValid(contr) and contr.ResetSequence then
        contr:ResetSequence(0)
    end
end

function ActiveRagdoll:RemoveAnimator(ragdoll)
    local animData = self.Animators[ragdoll]
    if not animData then return end

    if IsValid(animData.controller) then
        animData.controller:Remove()
    end
    
    if IsValid(animData.parent) then
        animData.parent:Remove()
    end

    self.Animators[ragdoll] = nil
end

function ActiveRagdoll:HasAnimator(ragdoll)
    return GetValidAnimData(ragdoll) ~= nil
end

function ActiveRagdoll:GetController(ragdoll)
    local animData = GetValidAnimData(ragdoll)
    return animData and animData.controller or nil
end