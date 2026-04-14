function ActiveRagdollController:GetHealth()
    if not IsValid(self.Ragdoll) then return 0 end
    return self.Ragdoll.AR_Health or 0
end

function ActiveRagdollController:SetHealth(amount)
    if not IsValid(self.Ragdoll) then return end
    
    self.Ragdoll.AR_Health = math.max(0, math.min(self.CONST.HEALTH_MAX, amount))
    
    if self.Ragdoll.AR_Health <= 0 and not self.isDead then
        self:SetDead()
    end
end

function ActiveRagdollController:TakeDamage(amount)
    self:SetHealth(self:GetHealth() - amount)
end

function ActiveRagdollController:InitializeProceduralDrain()

    -- procedural "die time" for ragdolls. (more variable deaths)

    if not IsValid(self.Ragdoll) then return end
    if self.Ragdoll.AR_DrainInitialized then return end

    local entIndex = self.Ragdoll:EntIndex()
    local spawnTime = CurTime() * 10000
    local position = self.Ragdoll:GetPos()
    local posSeed = (position.x + position.y * 13 + position.z * 37) * 100
    
    local uniqueSeed = entIndex * 7919 + spawnTime + posSeed
    math.randomseed(uniqueSeed)

    self.Ragdoll.AR_BaseDrainMultiplier = math.Rand(0.4, 1.8)

    self.Ragdoll.AR_Wave1_Offset = math.Rand(0, 10000)
    self.Ragdoll.AR_Wave1_Freq = math.Rand(0.2, 1.5)
    self.Ragdoll.AR_Wave1_Amp = math.Rand(0.15, 0.35)
    
    self.Ragdoll.AR_Wave2_Offset = math.Rand(0, 10000)
    self.Ragdoll.AR_Wave2_Freq = math.Rand(0.5, 2.5)
    self.Ragdoll.AR_Wave2_Amp = math.Rand(0.1, 0.25)
    
    self.Ragdoll.AR_Wave3_Offset = math.Rand(0, 10000)
    self.Ragdoll.AR_Wave3_Freq = math.Rand(0.1, 0.8)
    self.Ragdoll.AR_Wave3_Amp = math.Rand(0.08, 0.2)
    
    self.Ragdoll.AR_Wave4_Offset = math.Rand(0, 10000)
    self.Ragdoll.AR_Wave4_Freq = math.Rand(1.0, 3.5)
    self.Ragdoll.AR_Wave4_Amp = math.Rand(0.05, 0.15)

    self.Ragdoll.AR_PulseEnabled = math.random() > 0.5
    self.Ragdoll.AR_PulseFreq = math.Rand(0.3, 1.2)
    self.Ragdoll.AR_PulseAmp = math.Rand(0.2, 0.5)
    self.Ragdoll.AR_PulseOffset = math.Rand(0, 10000)

    self.Ragdoll.AR_HealthResilienceFactor = math.Rand(-0.3, 0.3)
    
    self.Ragdoll.AR_NextChaosTime = CurTime() + math.Rand(2, 8)
    self.Ragdoll.AR_ChaosMultiplier = 1.0
    self.Ragdoll.AR_ChaosDecay = 0
    
    self.Ragdoll.AR_DrainInitialized = true
end

function ActiveRagdollController:GetComplexDrainMultiplier()
    if not IsValid(self.Ragdoll) then return 1 end
    
    self:InitializeProceduralDrain()
    
    local time = CurTime()
    
    local wave1 = math.sin((time * self.Ragdoll.AR_Wave1_Freq + self.Ragdoll.AR_Wave1_Offset) * math.pi)
    local wave2 = math.sin((time * self.Ragdoll.AR_Wave2_Freq + self.Ragdoll.AR_Wave2_Offset) * math.pi)
    local wave3 = math.sin((time * self.Ragdoll.AR_Wave3_Freq + self.Ragdoll.AR_Wave3_Offset) * math.pi)
    local wave4 = math.sin((time * self.Ragdoll.AR_Wave4_Freq + self.Ragdoll.AR_Wave4_Offset) * math.pi)
    
    local waveVariation = 1.0 +
        (wave1 * self.Ragdoll.AR_Wave1_Amp) +
        (wave2 * self.Ragdoll.AR_Wave2_Amp) +
        (wave3 * self.Ragdoll.AR_Wave3_Amp) +
        (wave4 * self.Ragdoll.AR_Wave4_Amp)
    
    local pulseEffect = 1.0
    if self.Ragdoll.AR_PulseEnabled then
        local pulseWave = math.sin((time * self.Ragdoll.AR_PulseFreq + self.Ragdoll.AR_PulseOffset) * math.pi)
        pulseEffect = 1.0 + (math.max(0, pulseWave) * self.Ragdoll.AR_PulseAmp)
    end

    local healthPercent = self:GetHealth() / self.CONST.HEALTH_MAX
    local healthFactor = 1.0 + (self.Ragdoll.AR_HealthResilienceFactor * (1.0 - healthPercent))
    
    if time >= self.Ragdoll.AR_NextChaosTime then
        self.Ragdoll.AR_ChaosMultiplier = math.Rand(1.3, 2.5)
        self.Ragdoll.AR_ChaosDecay = math.Rand(0.5, 2.0)
        self.Ragdoll.AR_NextChaosTime = time + math.Rand(3, 12)
    end
    
    if self.Ragdoll.AR_ChaosMultiplier > 1.0 then
        self.Ragdoll.AR_ChaosMultiplier = math.max(1.0, 
            self.Ragdoll.AR_ChaosMultiplier - (self.Ragdoll.AR_ChaosDecay * FrameTime()))
    end
    
    local totalMultiplier = self.Ragdoll.AR_BaseDrainMultiplier * 
                           waveVariation * 
                           pulseEffect * 
                           healthFactor * 
                           self.Ragdoll.AR_ChaosMultiplier
    
    return math.max(0.1, totalMultiplier)
end

function ActiveRagdollController:UpdateHealth()
    if self.isDead or not IsValid(self.Ragdoll) then return end
    
    local now = CurTime()
    local deltaTime = now - (self.Ragdoll.AR_LastHealthDrain or now)
    self.Ragdoll.AR_LastHealthDrain = now
    
    local drainRate = self.CONST.HEALTH_DRAIN_RATE
    
    if self.Ragdoll:IsOnFire() then
        drainRate = self.CONST.HEALTH_DRAIN_ONFIRE
        self.wasOnFire = true
    else
        self.wasOnFire = false
    end
    
    local complexMultiplier = self:GetComplexDrainMultiplier()
    drainRate = drainRate * complexMultiplier
 
    local drainAmount = drainRate * deltaTime
    self:TakeDamage(drainAmount)
end

function ActiveRagdollController:SetDead()
    if self.isDead then return end
    self.isDead = true

    self.IsTransitioning = false
    self.PendingBehavior = nil
    
    if self.CurrentBehavior then
        pcall(self.CurrentBehavior.OnLeave, self.CurrentBehavior)
    end
    
    self:DeactivateAllBehaviors()
    self:DeactivateAllOverrides()

    if self.isHeadshot and not GetConVar("ar_enableHeadShotReact"):GetBool() then
        self:Cleanup()
        return
    end
    
    if self.SoundManager then
        self.SoundManager:Cleanup()
        self.SoundManager = nil
    end

    if DeathFaces then
        DeathFaces:RelaxToDeadPose(self.Ragdoll, 1)
    end

    if not self.isHeadshot and AnimatedHands then
        AnimatedHands:RemoveEntity(self.Ragdoll)
    end

    if IsValid(self.TargetForNpc) then
        self.TargetForNpc:Remove()
    end
end

function ActiveRagdollController:OnTakeDamage(dmgInfo)
    if self.isDead or not IsValid(self.Ragdoll) then return end

    for _, override in pairs(self.ActiveOverrides) do
        pcall(override.OnDamage, override, dmgInfo)
    end

    if self.CurrentBehavior then
        pcall(self.CurrentBehavior.OnDamage, self.CurrentBehavior, dmgInfo)
    end
end