local BEHAVIOR = table.Copy(BehaviorBase)
BEHAVIOR.Name = "Protective"

function BEHAVIOR:OnEnter(previousStateName, enterData)
     local ragdoll = self.Ragdoll

    if ActiveRagdoll and ActiveRagdoll.PlayAnimation then
        ActiveRagdoll:ChangeModel(ragdoll, "models/Humans/Group01/male_07.mdl")
        ActiveRagdoll:PlayAnimation(ragdoll, "cower_idle", 1)
    end
end

function BEHAVIOR:OnThink()
    local data = self
    local ragdoll = data.Ragdoll
end

function BEHAVIOR:OnLeave()
        if ActiveRagdoll and ActiveRagdoll.PlayAnimation then
        ActiveRagdoll:ChangeModel(ragdoll, "models/AREAnims/model_anim.mdl")
        ActiveRagdoll:StopAnimation(ragdoll)
    end
end

AR_Manager:RegisterBehavior(BEHAVIOR.Name, BEHAVIOR)