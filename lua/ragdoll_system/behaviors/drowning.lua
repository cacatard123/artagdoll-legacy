local BEHAVIOR = table.Copy(BehaviorBase)
BEHAVIOR.Name = "Drowning"

BEHAVIOR.minStrength = 0.1 
BEHAVIOR.lastStrength = -1
BEHAVIOR.isAtMinStrength = false

function BEHAVIOR:OnEnter(previousStateName, enterData)
    local ragdoll = self.Ragdoll

    if ActiveRagdoll and ActiveRagdoll.PlayAnimation then
        ActiveRagdoll:ChangeModel(ragdoll, "models/AREAnims/model_anim.mdl")
        ActiveRagdoll:PlayAnimation(ragdoll, "Drowning", 0.7)
    end
end

function BEHAVIOR:OnThink()
    local ragdoll = self.Ragdoll
    if not IsValid(ragdoll) then return end
    
    local health = ragdoll.AR_Health
    if not ActiveRagdoll or not health then return end

    local targetValue = math.Clamp((health / 55) * 3, 0, 3)
    local finalStrength = math.max(targetValue, self.minStrength or 0)

    if self.lastStrength ~= finalStrength then
        self.lastStrength = finalStrength
        
        if finalStrength == self.minStrength then
            if not self.isAtMinStrength then
                self.isAtMinStrength = true
                ActiveRagdoll:SetStrength(ragdoll, finalStrength)
            end
        else
            self.isAtMinStrength = false
            ActiveRagdoll:SetStrength(ragdoll, finalStrength)
        end
    end
end

function BEHAVIOR:OnLeave()
    local ragdoll = self.Ragdoll 
    if not IsValid(ragdoll) then return end

    if ActiveRagdoll and ActiveRagdoll.PlayAnimation then
        ActiveRagdoll:ChangeModel(ragdoll, "models/AREAnims/model_anim.mdl")
        ActiveRagdoll:StopAnimation(ragdoll)
    end
end

AR_Manager:RegisterBehavior(BEHAVIOR.Name, BEHAVIOR)