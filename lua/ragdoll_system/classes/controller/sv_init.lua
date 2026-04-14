local SoundManager = include("ragdoll_system/utils/sv_soundmanager.lua")
local AnimatedHands = include("ragdoll_system/utils/sv_animatedhands.lua")

function ActiveRagdollController:New(ragdoll)
    local controller = setmetatable({}, self)
    
    controller.Ragdoll = ragdoll
    controller.EntIndex = ragdoll:EntIndex()
    
    controller.CurrentBehavior = nil
    controller.CurrentBehaviorName = ""
    controller.IsTransitioning = false
    controller.PendingBehavior = nil
    
    controller.isDead = false
    controller.isHeadshot = false
    controller.deathInit = false
    controller.deathTime = 0
    controller.wasOnFire = false
    
    controller.BoneIDs = {
        Pelvis = ragdoll:LookupBone("ValveBiped.Bip01_Pelvis"),
        Spine = ragdoll:LookupBone("ValveBiped.Bip01_Spine")
    }

    if SoundManager then
        controller.SoundManager = SoundManager:New(ragdoll)
    end
    
    controller.Behaviors = {}
    controller.Overrides = {}
    controller.ActiveOverrides = {}

    controller.Data = {
        protectiveExitRequestTime = nil,
        stateLocked = 0,
        lastStateChange = 0
    }
    
    for name, class in pairs(AR_Manager.Behaviors) do
        controller.Behaviors[name] = class:New(controller)
    end
    
    for name, class in pairs(AR_Manager.OverrideBehaviors) do
        controller.Overrides[name] = class:New(controller)
    end

    ragdoll.AR_Health = self.CONST.HEALTH_MAX
    ragdoll.AR_LastHealthDrain = CurTime()
    ragdoll.CanTakeDamage = GetConVar("ar_BulletDamage"):GetBool()

    return controller
end

function ActiveRagdollController:Initialize(initialBehavior, ...)
    local ragdoll = self.Ragdoll
    
    if initialBehavior and self.Behaviors[initialBehavior] then
        self:ForceChangeBehavior(initialBehavior, ...)

        if GetConVar("ar_enableWoundGrab"):GetBool() then
           self:ActivateOverride("HoldWound", 999)
        end

        if GetConVar("ar_enableHoldEnv"):GetBool() then
            self:ActivateOverride("HoldEnv", 10)
        end

        if GetConVar("ar_enableWallStunt"):GetBool() then
            self:ActivateOverride("WallStunt", 10)
        end

        if AnimatedHands then AnimatedHands:AddEntity(self.Ragdoll) end

        if GetConVar("ar_ragdollShoot"):GetBool() then
           -- self:SetupNPCTarget()
        end
    else
        ErrorNoHalt("Failed to initialize with behavior: " .. tostring(initialBehavior) .. "\n")
    end
end

function ActiveRagdollController:SetupNPCTarget()
    local target = ents.Create("NpcTarget")
    if IsValid(target) then
        target:SetOwner(self.Ragdoll)
        target:Spawn()
        target:Activate()
        self.TargetForNpc = target
        
        self.Ragdoll:CallOnRemove("remove_npctarget_" .. target:EntIndex(), function() 
            if IsValid(target) then target:Remove() end 
        end)
    end
end

function ActiveRagdollController:Cleanup()
    if not self then return end
    
    if self.EntIndex then
        timer.Remove("AR_DeathCleanup_" .. self.EntIndex)
        timer.Remove("AR_Transition_" .. self.EntIndex)
    end
    
    if ActiveRagdoll and ActiveRagdoll.RemoveAnimator and IsValid(self.Ragdoll) then
         ActiveRagdoll:RemoveAnimator(self.Ragdoll)
    end

    if self.SoundManager then
        self.SoundManager:Cleanup()
        self.SoundManager = nil
    end

    if self.CurrentBehavior then
        pcall(self.CurrentBehavior.OnLeave, self.CurrentBehavior)
    end
    
    self:DeactivateAllBehaviors()
    self:DeactivateAllOverrides()

    if IsValid(self.TargetForNpc) then
        self.TargetForNpc:Remove()
    end
    
    if AnimatedHands then
        AnimatedHands:RemoveEntity(self.Ragdoll)
    end
end