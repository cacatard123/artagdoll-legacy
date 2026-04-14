local BEHAVIOR = table.Copy(BehaviorBase)
BEHAVIOR.Name = "DeathPose"

BEHAVIOR.LastPoseIndex = nil

function BEHAVIOR:OnEnter(previousStateName, enterData)
    local ragdoll = self.Ragdoll

    if ActiveRagdoll and ActiveRagdoll.PlayAnimation then
        ActiveRagdoll:ChangeModel(ragdoll, "models/AREAnims/model_anim.mdl")

        local Poses = {"DeathPose1", "DeathPose2", "DeathPose3", "DeathPose4"}
        local RandomIndex
        repeat
            RandomIndex = math.random(1, #Poses)
        until RandomIndex ~= self.LastPoseIndex or #Poses == 1

        self.LastPoseIndex = RandomIndex

    if ActiveRagdoll then
        ActiveRagdoll:SetStrength(ragdoll, 1.5)
    end

        ActiveRagdoll:PlayAnimation(ragdoll, Poses[RandomIndex], 1)
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
