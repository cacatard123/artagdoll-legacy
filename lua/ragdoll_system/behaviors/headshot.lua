local Stiffness = include("Components/RagdollPhysics/RagdollStiffness.lua")

local BEHAVIOR = table.Copy(BehaviorBase)
BEHAVIOR.Name = "Headshot"

BEHAVIOR.LastHeadshotAnimIndex = nil

function BEHAVIOR:OnEnter(previousStateName, enterData)
    local ragdoll = self.Ragdoll

    if ActiveRagdoll and ActiveRagdoll.PlayAnimation then
        
        local AnimData = {
            { 
                Anim = "HeadshotCurl", 
                Model = "models/AREAnims/model_anim.mdl",
                Bones = {
                    "ValveBiped.Bip01_Head1",
                  --  "ValveBiped.Bip01_Spine4",
                    "ValveBiped.Bip01_Spine2",
                    "ValveBiped.Bip01_L_UpperArm",
                    "ValveBiped.Bip01_L_Forearm",
                    "ValveBiped.Bip01_L_Hand",
                    "ValveBiped.Bip01_R_UpperArm",
                    "ValveBiped.Bip01_R_Forearm",
                    "ValveBiped.Bip01_R_Hand",
                    "ValveBiped.Bip01_R_Calf",
                    "ValveBiped.Bip01_L_Calf",
                    "ValveBiped.Bip01_R_Foot",
                    "ValveBiped.Bip01_L_Foot",
                }
            }
        }

        local RandomIndex
        repeat
            RandomIndex = math.random(1, #AnimData)
        until RandomIndex ~= self.LastHeadshotAnimIndex or #AnimData == 1

        self.LastHeadshotAnimIndex = RandomIndex
        
        local SelectedEntry = AnimData[RandomIndex]

        if ActiveRagdoll then
            ActiveRagdoll:ChangeModel(ragdoll, SelectedEntry.Model) 
            ActiveRagdoll:SetStrength(ragdoll, 3)  
        end

        ActiveRagdoll:PlayAnimation(ragdoll, SelectedEntry.Anim, 1, SelectedEntry.Bones)
        
        timer.Simple(1, function()
            if IsValid(ragdoll) then 
                Stiffness.ActivateHeadshot(ragdoll, 20)
            end
        end)
    end
end

function BEHAVIOR:OnLeave()
    local ragdoll = self.Ragdoll

    if ActiveRagdoll and ActiveRagdoll.PlayAnimation then
        ActiveRagdoll:ChangeModel(ragdoll, "models/AREAnims/model_anim.mdl")
        ActiveRagdoll:StopAnimation(ragdoll)
    end
end

AR_Manager:RegisterBehavior(BEHAVIOR.Name, BEHAVIOR)