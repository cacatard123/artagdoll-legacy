local BEHAVIOR = table.Copy(BehaviorBase)
BEHAVIOR.Name = "Burning"

local BurntColor = Color(38, 38, 38)
local LerpSpeed = 2

local TOGGLE_COOLDOWN = 3
local IMPULSE_STRENGTH = 50

function BEHAVIOR:OnEnter(previousStateName, enterData)
    local ragdoll = self.Ragdoll

    self.burnStartTime = CurTime()
    self.isDeadTimerTriggered = false
    
    self.nextToggleTime = CurTime() + TOGGLE_COOLDOWN
    self.isReversed = false

    self.originalColor = ragdoll:GetColor()

    if ActiveRagdoll and ActiveRagdoll.PlayAnimation then
        ActiveRagdoll:ChangeModel(ragdoll, "models/AREAnims/model_anim.mdl")

        ActiveRagdoll:PlayAnimation(ragdoll, "Burning", 0.5)
        ActiveRagdoll:SetStrength(ragdoll, 5)
    end
    
    if IsValid(ragdoll) and not ragdoll:IsOnFire() then
        ragdoll:Ignite(30, 0)
    end
end

function BEHAVIOR:OnThink()
    local ragdoll = self.Ragdoll
    if not IsValid(ragdoll) then return end

    local dt = FrameTime()
    if dt <= 0 or dt > 1 then return end

    local currentColor = ragdoll:GetColor()
    
    local r_diff = math.abs(currentColor.r - BurntColor.r)
    local g_diff = math.abs(currentColor.g - BurntColor.g)
    local b_diff = math.abs(currentColor.b - BurntColor.b)
    
    if r_diff > 2 or g_diff > 2 or b_diff > 2 then
        local lerpFactor = dt * LerpSpeed
        local newColor = Color(
            Lerp(lerpFactor, currentColor.r, BurntColor.r),
            Lerp(lerpFactor, currentColor.g, BurntColor.g),
            Lerp(lerpFactor, currentColor.b, BurntColor.b)
        )
        
        ragdoll:SetColor(newColor)
    end

    if CurTime() >= self.nextToggleTime then
        self.nextToggleTime = CurTime() + TOGGLE_COOLDOWN
        
        self.isReversed = not self.isReversed
        
        if ActiveRagdoll and ActiveRagdoll.PlayAnimation then
            local speed = self.isReversed and -0.5 or 0.5
            ActiveRagdoll:PlayAnimation(ragdoll, "Burning", speed)
        end

        for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
            local phys = ragdoll:GetPhysicsObjectNum(i)
            if IsValid(phys) then
                local randomVec = VectorRand() * IMPULSE_STRENGTH
                phys:ApplyForceCenter(randomVec)
                phys:AddAngleVelocity(VectorRand() * 10)
            end
        end
    end
end

function BEHAVIOR:OnLeave()
    local ragdoll = self.Ragdoll

    if IsValid(ragdoll) then
        if ActiveRagdoll and ActiveRagdoll.PlayAnimation then
            ActiveRagdoll:ChangeModel(ragdoll, "models/AREAnims/model_anim.mdl")
            ActiveRagdoll:StopAnimation(ragdoll)
            ActiveRagdoll:SetStrength(ragdoll, 2)
        end
    end
end

AR_Manager:RegisterBehavior(BEHAVIOR.Name, BEHAVIOR)