local BEHAVIOR = table.Copy(BehaviorBase)
BEHAVIOR.Name = "Injured"

BEHAVIOR.LastAnimIndex = nil
BEHAVIOR.NextAnimTime = 0

BEHAVIOR.BlendState = "IDLE" -- Can be "IDLE", "OUT", "IN"
BEHAVIOR.BlendMult = 1.0
BEHAVIOR.BlendSpeed = 2.0

BEHAVIOR.AnimSets = {
    {
        name = "Dying1",
        model = "models/AREAnims/model_anim.mdl",
        bones = {
            "ValveBiped.Bip01_Pelvis", "ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_R_UpperArm",
            "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand",
            "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand", "ValveBiped.Bip01_R_Calf",
            "ValveBiped.Bip01_Head1", "ValveBiped.Bip01_L_Calf",
        },
        speedMin = 1,
        speedMax = 1.5
    },
    {
        name = "Dying2",
        model = "models/AREAnims/model_anim.mdl",
        bones = {
            "ValveBiped.Bip01_Pelvis", "ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_R_UpperArm",
            "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_R_Forearm",
            "ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_Head1",
            "ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_L_Calf",
        },
        speedMin = 1,
        speedMax = 1.5
    },
    {
        name = "Dying3",
        model = "models/AREAnims/model_anim.mdl",
        bones = {
            "ValveBiped.Bip01_Pelvis", "ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_R_UpperArm",
            "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_R_Forearm",
            "ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_Head1",
            "ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_L_Calf",
        },
        speedMin = 1,
        speedMax = 1.35
    },
    {
        name = "Dying4",
        model = "models/AREAnims/model_anim.mdl",
        bones = {
            "ValveBiped.Bip01_Pelvis", "ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_R_UpperArm",
            "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_R_Hand",
            "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_Head1",
        },
        speedMin = 1,
        speedMax = 1.25
    },
    {
        name = "Dying5",
        model = "models/AREAnims/model_anim.mdl",
        bones = {
            "ValveBiped.Bip01_Pelvis", "ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_R_UpperArm",
            "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_R_Forearm",
            "ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_Head1",
            "ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_L_Calf",
        },
        speedMin = 1,
        speedMax = 1.5
    }
}

function BEHAVIOR:PlayInjuredAnim()
    local ragdoll = self.Ragdoll
    if not IsValid(ragdoll) then return end

    local chosenIndex
    if #self.AnimSets > 1 then
        repeat
            chosenIndex = math.random(#self.AnimSets)
        until chosenIndex ~= self.LastAnimIndex
        self.LastAnimIndex = chosenIndex
    else
        chosenIndex = 1
    end
    
    local chosen = self.AnimSets[chosenIndex]
    local animSpeed = math.Rand(chosen.speedMin or 1, chosen.speedMax or 1.5)

    if ActiveRagdoll and ActiveRagdoll.ChangeModel and ActiveRagdoll.PlayAnimation then
        ActiveRagdoll:ChangeModel(ragdoll, chosen.model)
        ActiveRagdoll:PlayAnimation(ragdoll, chosen.name, animSpeed, chosen.bones)
    end
end

function BEHAVIOR:OnEnter(previousStateName, enterData)
    local ragdoll = self.Ragdoll
    if not IsValid(ragdoll) then return end

    self:PlayInjuredAnim()

    self.NextAnimTime = CurTime() + math.Rand(3, 6)
    
    self.BlendState = "IDLE"
    self.BlendMult = 1.0

    self.isAtMinStrength = false
    self.lastStrength = nil
    
    self.enableDeathPose = GetConVar("ar_enableDeathPoses"):GetBool()
    self.minStrength = self.enableDeathPose and 0.5 or 0.0
end

function BEHAVIOR:OnThink()
    local ragdoll = self.Ragdoll
    if not IsValid(ragdoll) then return end

    if self.BlendState == "IDLE" then
        if CurTime() >= self.NextAnimTime then
            self.BlendState = "OUT"
        end

    elseif self.BlendState == "OUT" then
        self.BlendMult = math.Approach(self.BlendMult, 0, FrameTime() * self.BlendSpeed)
        
        if self.BlendMult <= 0 then
            self:PlayInjuredAnim()
            self.BlendState = "IN"
        end

    elseif self.BlendState == "IN" then
        self.BlendMult = math.Approach(self.BlendMult, 1, FrameTime() * self.BlendSpeed)
        
        if self.BlendMult >= 1 then
            self.BlendState = "IDLE"
            self.NextAnimTime = CurTime() + math.Rand(3.0, 6.0)
        end
    end
    
    local health = ragdoll.AR_Health
    if not ActiveRagdoll or not health then return end

    local targetValue = math.Clamp((health / 55) * 3, 0, 3)
    local rawStrength = math.max(targetValue, self.minStrength)
    
    local finalStrength = rawStrength * self.BlendMult

    if self.lastStrength ~= finalStrength or self.BlendState ~= "IDLE" then
        self.lastStrength = finalStrength
        
        if finalStrength <= 0.05 then
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
    if IsValid(ragdoll) and ActiveRagdoll and ActiveRagdoll.StopAnimation then
        ActiveRagdoll:StopAnimation(ragdoll)
    end
    
    self.lastStrength = nil
    self.enableDeathPose = nil
    self.minStrength = nil
    self.NextAnimTime = nil 
    self.BlendState = nil
end

AR_Manager:RegisterBehavior(BEHAVIOR.Name, BEHAVIOR)