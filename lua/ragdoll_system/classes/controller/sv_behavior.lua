function ActiveRagdollController:Think(dt)
    if not self or not IsValid(self.Ragdoll) then return end
    if not dt or dt <= 0 then return end
    
    if self.ActiveOverrides and next(self.ActiveOverrides) then
        for name, instance in pairs(self.ActiveOverrides) do
            if instance and instance.OnThink then
                local success, err = pcall(instance.OnThink, instance)
                if not success then 
                    ErrorNoHalt("[Controller] Override Error (" .. name .. "): " .. tostring(err) .. "\n") 
                end
            end
        end
    end

    if self.isDead then
        self:HandleDeathLogic()
        return
    end

    if self.CurrentBehavior and self.CurrentBehavior.OnThink then
        local success, err = pcall(self.CurrentBehavior.OnThink, self.CurrentBehavior)
        if not success then 
            ErrorNoHalt("[Controller] Behavior Error (" .. (self.CurrentBehaviorName or "unknown") .. "): " .. tostring(err) .. "\n") 
        end
    end

    if self.UpdateHealth then
        pcall(self.UpdateHealth, self)
    end
    
    if self.UpdatePhysicsData then
        pcall(self.UpdatePhysicsData, self)
    end
    
    local now = CurTime()
    if self.IsTransitioning or (self.Data and self.Data.stateLocked > now) then return end

    local targetBehavior = self:ChooseBestBehavior()
    if targetBehavior and targetBehavior ~= self.CurrentBehaviorName then
        self:ChangeBehavior(targetBehavior)
    end
end

function ActiveRagdollController:HandleDeathLogic()
    if not self or not IsValid(self.Ragdoll) then return end
    
    if self.deathInit then 
        if self.CurrentBehaviorName == "DeathPose" and self.CurrentBehavior and self.CurrentBehavior.OnThink then
            pcall(self.CurrentBehavior.OnThink, self.CurrentBehavior)
        end

        if CurTime() - self.deathTime > 2.0 then 
            self:Cleanup() 
        end
        return 
    end

    self.deathInit = true
    self.deathTime = CurTime()
    self:DeactivateAllBehaviors()
    self:DeactivateAllOverrides()

    if self.isHeadshot then
        local headshotCvar = GetConVar("ar_enableHeadShotReact")
        if headshotCvar and headshotCvar:GetBool() then
            self:ForceChangeBehavior("Headshot")
            
            local ragdoll = self.Ragdoll
            timer.Simple(math.Rand(2, 3), function() 
                if IsValid(ragdoll) and self and IsValid(self.Ragdoll) then 
                    pcall(self.Cleanup, self)
                end 
            end)
        else
            self:Cleanup()
        end
    else
        local deathPoseCvar = GetConVar("ar_enableDeathPoses")
        if deathPoseCvar and deathPoseCvar:GetBool() then
            self:ForceChangeBehavior("DeathPose")
        else
            if ActiveRagdoll and ActiveRagdoll.RemoveAnimator then 
                pcall(ActiveRagdoll.RemoveAnimator, ActiveRagdoll, self.Ragdoll) 
            end
        end
    end
end

function ActiveRagdollController:ChangeBehavior(behaviorName, ...)
    if not self or not IsValid(self.Ragdoll) or not behaviorName then return false end
    if self.isDead or self.CurrentBehaviorName == behaviorName then return false end
    if not self.Behaviors or not self.Data then return false end

    local now = CurTime()
    local data = self.Data

    if self.IsTransitioning or (data.stateLocked > now) or (now - data.lastStateChange < 0.3) then
        self.PendingBehavior = {name = behaviorName, args = {...}}
        return false
    end

    local newBehavior = self.Behaviors[behaviorName]
    if not newBehavior then 
        ErrorNoHalt("[Controller] Behavior '" .. tostring(behaviorName) .. "' not found\n")
        return false 
    end

    self.IsTransitioning = true
    data.lastStateChange = now
    data.stateLocked = now + 0.35
    
    if self.CurrentBehavior and self.CurrentBehavior.OnLeave then 
        pcall(self.CurrentBehavior.OnLeave, self.CurrentBehavior) 
    end

    self.CurrentBehavior = newBehavior
    self.CurrentBehaviorName = behaviorName
    
    if newBehavior.OnEnter then
        local success, err = pcall(newBehavior.OnEnter, newBehavior, self.CurrentBehaviorName, ...)
        if not success then
            ErrorNoHalt("[Controller] Behavior enter failed (" .. behaviorName .. "): " .. tostring(err) .. "\n")
        end
    end
    
    self:UpdateSound(behaviorName)
    
    self.IsTransitioning = false

    if self.PendingBehavior then
        local pending = self.PendingBehavior
        self.PendingBehavior = nil
        
        local ragdoll = self.Ragdoll
        timer.Simple(0.1, function()
            if IsValid(ragdoll) and self and not self.isDead then
                pcall(self.ChangeBehavior, self, pending.name, unpack(pending.args or {}))
            end
        end)
    end
    
    return true
end

function ActiveRagdollController:ForceChangeBehavior(behaviorName, ...)
    if not self or not IsValid(self.Ragdoll) or not behaviorName then return false end
    if not self.Behaviors then return false end
    
    local newBehavior = self.Behaviors[behaviorName]
    if not newBehavior then 
        ErrorNoHalt("[Controller] Force behavior '" .. tostring(behaviorName) .. "' not found\n")
        return false 
    end

    if self.CurrentBehavior and self.CurrentBehavior.OnLeave then 
        pcall(self.CurrentBehavior.OnLeave, self.CurrentBehavior) 
    end
    
    self:DeactivateAllOverrides()

    self.IsTransitioning = false
    if self.Data then
        self.Data.stateLocked = 0
    end
    
    self.CurrentBehavior = newBehavior
    self.CurrentBehaviorName = behaviorName
    
    if newBehavior.OnEnter then
        local success, err = pcall(newBehavior.OnEnter, newBehavior, "FORCE", ...)
        if not success then
            ErrorNoHalt("[Controller] Force behavior enter failed (" .. behaviorName .. "): " .. tostring(err) .. "\n")
        end
    end
    
    self:UpdateSound(behaviorName)

    return true
end

function ActiveRagdollController:UpdateSound(behaviorName)
    if not self.SoundManager then return end
    
    local sfxCvar = GetConVar("ar_enableSFX")
    if not sfxCvar or not sfxCvar:GetBool() then return end
    
    if not behaviorName or behaviorName == "" then return end
    
    if behaviorName == "Burning" then
        if self.SoundManager.PlayLoop then
            pcall(self.SoundManager.PlayLoop, self.SoundManager, "burn")
        end
    elseif behaviorName == "Drowning" then
        if self.SoundManager.StopLoop then 
            pcall(self.SoundManager.StopLoop, self.SoundManager) 
        end
    elseif behaviorName == "Falling" or behaviorName == "Protective" then
        if self.SoundManager.PlayLoop then
            pcall(self.SoundManager.PlayLoop, self.SoundManager, "flying")
        end
    else
        if self.SoundManager.PlayLoop then
            pcall(self.SoundManager.PlayLoop, self.SoundManager, "bullet")
        end
    end
end

function ActiveRagdollController:ActivateOverride(name, duration, ...)
    if not self or not name or name == "" then return false end
    if not self.Overrides or not self.ActiveOverrides then return false end
    
    local override = self.Overrides[name]
    if not override then 
        ErrorNoHalt("[Controller] Override '" .. name .. "' not found\n")
        return false 
    end
    
    if self.ActiveOverrides[name] then 
        self:DeactivateOverride(name) 
    end
    
    self.ActiveOverrides[name] = override
    
    if override.OnActivate then
        local success, err = pcall(override.OnActivate, override, duration, ...)
        if not success then
            ErrorNoHalt("[Controller] Override activation failed (" .. name .. "): " .. tostring(err) .. "\n")
            self.ActiveOverrides[name] = nil
            return false
        end
    end
    
    if duration and duration > 0 and self.EntIndex then
        local timerName = "AR_Override_" .. name .. "_" .. self.EntIndex
        timer.Create(timerName, duration, 1, function()
            if self and IsValid(self.Ragdoll) then 
                pcall(self.DeactivateOverride, self, name) 
            end
        end)
    end
    
    return true
end

function ActiveRagdollController:DeactivateOverride(name)
    if not self or not name or name == "" then return false end
    if not self.ActiveOverrides then return false end
    
    local override = self.ActiveOverrides[name]
    if not override then return false end

    if self.EntIndex then
        timer.Remove("AR_Override_" .. name .. "_" .. self.EntIndex)
    end
    
    if override.OnDeactivate then
        pcall(override.OnDeactivate, override)
    end
    
    self.ActiveOverrides[name] = nil
    return true
end

function ActiveRagdollController:DeactivateAllBehaviors()
    if not self then return end
    
    self.CurrentBehavior = nil
    self.CurrentBehaviorName = ""
    self.PendingBehavior = nil
end

function ActiveRagdollController:DeactivateAllOverrides()
    if not self or not self.ActiveOverrides then return end
    
    local overridesToRemove = {}
    for name, _ in pairs(self.ActiveOverrides) do
        table.insert(overridesToRemove, name)
    end
    
    for _, name in ipairs(overridesToRemove) do
        pcall(self.DeactivateOverride, self, name)
    end
end