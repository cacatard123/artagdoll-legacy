local IKSystem = include("Components/Utils/IKChain.lua")

local BEHAVIOR = table.Copy(BehaviorBase)
BEHAVIOR.Name = "Falling"

local DEBUG_GIZMOS = true 

local BRACE_CONFIG = {
    LookAheadTime = 0.65, 

    BraceSpeed = 0.08,
    MinVelocity = 50,
}

local IK_SETTINGS = {
    arriveTime = 0.05,
    positionSmoothTime = 0.1,
    maxAngularSpeed = 25000, 
    debug = true 
}

    local list = {  
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


function BEHAVIOR:OnEnter(previousStateName, enterData)
    local ragdoll = self.Ragdoll

    if ActiveRagdoll and ActiveRagdoll.PlayAnimation then
        ActiveRagdoll:ChangeModel(ragdoll, "models/AREAnims/model_anim.mdl")
        ActiveRagdoll:PlayAnimation(ragdoll, "Falling", 1.31, list)
    end

    self.LeftChain = IKSystem.CreateChain(ragdoll, {"ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand"}, "LeftBrace", Vector(0, 20, 10), IK_SETTINGS)
    self.RightChain = IKSystem.CreateChain(ragdoll, {"ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand"}, "RightBrace", Vector(0, 20, 10), IK_SETTINGS)

    self.IsBracing = false
end

function BEHAVIOR:OnThink()
    local ragdoll = self.Ragdoll
    if not IsValid(ragdoll) then return end

    local phys = ragdoll:GetPhysicsObject()
    if not IsValid(phys) then return end

    local velocity = phys:GetVelocity()
    local speed = velocity:Length()

    local predictedOffset = velocity * BRACE_CONFIG.LookAheadTime

    if speed > BRACE_CONFIG.MinVelocity then
        
        local spineBone = ragdoll:LookupBone("ValveBiped.Bip01_Spine2") or 0
        local startPos = ragdoll:GetBonePosition(spineBone)
        
        local endPos = startPos + predictedOffset

        local tr = util.TraceLine({
            start = startPos,
            endpos = endPos,
            filter = {ragdoll},
            mask = MASK_SOLID
        })

        if tr.Hit then
            if not self.IsBracing then
                self.IsBracing = true
            end

            local hitPos = tr.HitPos
            local hitNormal = tr.HitNormal
            local braceDir = velocity:GetNormalized()
            
            local rightOffset = braceDir:Cross(Vector(0,0,1)):GetNormalized() * 12
            local wallOffset = hitNormal * 5 

            local leftTarget = hitPos - rightOffset + wallOffset
            local rightTarget = hitPos + rightOffset + wallOffset

            if self.LeftChain then self.LeftChain:SetTarget(leftTarget) end
            if self.RightChain then self.RightChain:SetTarget(rightTarget) end

            if DEBUG_GIZMOS then
                debugoverlay.Line(startPos, hitPos, 0.1, Color(255, 0, 0), true)
                debugoverlay.Cross(hitPos, 5, 0.1, Color(255, 255, 0), true)
                debugoverlay.Sphere(leftTarget, 3, 0.1, Color(0, 255, 255, 50), true)
                debugoverlay.Sphere(rightTarget, 3, 0.1, Color(0, 255, 255, 50), true)
            end
        else
            if self.IsBracing then
                self.IsBracing = false
            end

            if self.LeftChain then self.LeftChain:Stop() end
            if self.RightChain then self.RightChain:Stop() end

            if DEBUG_GIZMOS then
                debugoverlay.Line(startPos, endPos, 0.1, Color(0, 255, 0, 50), true)
            end
        end
    else
        if self.IsBracing then
            self.IsBracing = false
        end
        if self.LeftChain then self.LeftChain:Stop() end
        if self.RightChain then self.RightChain:Stop() end
    end
end

function BEHAVIOR:OnLeave()
    local ragdoll = self.Ragdoll
    
    if ActiveRagdoll and ActiveRagdoll.PlayAnimation then
        ActiveRagdoll:ChangeModel(ragdoll, "models/AREAnims/model_anim.mdl")
        ActiveRagdoll:StopAnimation(ragdoll)
    end

    if self.LeftChain then self.LeftChain:Destroy() end
    if self.RightChain then self.RightChain:Destroy() end
    self.LeftChain = nil
    self.RightChain = nil
end

AR_Manager:RegisterBehavior(BEHAVIOR.Name, BEHAVIOR)