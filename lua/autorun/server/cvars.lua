util.AddNetworkString("ar_change_setting")

-- main
CreateConVar("ar_enable", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enable the whole addon")
CreateConVar("ar_MaxHealth", "100", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "MaxHealth")
CreateConVar("ar_DrainHealth", "5.0", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Drain Rag Health")
CreateConVar("ar_BulletDamage", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enable Ragdoll Bullet Damage")

-- stumbleConfig
CreateConVar("ar_uprightForce", "480", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "UprightForce")
CreateConVar("ar_StepSpeed", "9", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "LegSpeed")
CreateConVar("ar_StepHeight", "22.5", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "StepHeight")
CreateConVar("ar_MinStepThreshold", "18", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "How much distance before stepping")
CreateConVar("ar_ReactionDelay", "0.21", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "ReactionDelay")
CreateConVar("ar_BalanceRadius", "9.35", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "BalanceRadius")
CreateConVar("ar_TimeBeforeDecay", "2", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "TimeBeforeTheBalanceDecay")
CreateConVar("ar_StepReachMultiplier", "1.17", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "StepReachMultiplier")

-- WoundGrab --
CreateConVar("ar_enableWoundGrab", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enable WoundGrab")
CreateConVar("ar_holdwound_chance", "100", FCVAR_ARCHIVE)
CreateConVar("ar_holdwound_minduration", "3", FCVAR_ARCHIVE)
CreateConVar("ar_holdwound_maxduration", "8", FCVAR_ARCHIVE)
CreateConVar("ar_holdwound_twohand_chance", "50", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Chance (0-100) active ragdoll uses both hands to grab wound.")

-- HoldEnv (Environment Grabbing) --
CreateConVar("ar_enableHoldEnv", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enable Environment Grabbing")
CreateConVar("ar_holdenv_search_radius", "15", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Radius to search for grab points")
CreateConVar("ar_holdenv_min_dist", "5", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Min distance to wall to allow grab")
CreateConVar("ar_holdenv_max_dist", "15", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Max distance to wall to allow grab")
CreateConVar("ar_holdenv_release_vel", "200", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Velocity threshold to break grab")
CreateConVar("ar_holdenv_min_hold", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Minimum time to hold")
CreateConVar("ar_holdenv_max_hold", "2", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Maximum time to hold")
CreateConVar("ar_holdenv_cooldown", "3.0", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Cooldown between grabs")
CreateConVar("ar_holdenv_max_grabs", "2", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Max concurrent grabs allowed")

-- WallStunt --
CreateConVar("ar_enableWallStunt", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enable WallStunt")

-- DeathPoses --
CreateConVar("ar_enableDeathPoses", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enable DeathPose")

-- Headshot Reaction --
CreateConVar("ar_enableHeadShotReact", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enable HeadShot Behavior")
CreateConVar("ar_enableStiffness", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enable Stiffness")

-- SFX --
CreateConVar("ar_enableSFX", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enable SFX")

-- shoot ragdoll --
CreateConVar("ar_ragdollShoot", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Allow npcs to shoot at ragdoll")

-- NpcRagdollCollideWithPlayer --
CreateConVar("ar_PlayerCollideRagdoll", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Allow the player to pass though ragdolls")

-- Headshot Sfx --
CreateConVar("ar_headshotSfx", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Play HeadshotSFX when an headshot occur")

-- Network Receiver
net.Receive("ar_change_setting", function(_, ply)
    if not ply:IsAdmin() then return end

    local cvarName = net.ReadString()
    local cvarType = net.ReadString()
    local value = net.ReadFloat()

    local cvar = GetConVar(cvarName)
    if not cvar then
        print("Invalid CVar: " .. cvarName)
        return
    end

    if cvarType == "bool" then
        cvar:SetBool(value ~= 0)
    else
        cvar:SetFloat(value)
    end

   -- print(("%s changed %s to %s"):format(ply:Nick(), cvarName, tostring(value)))
end)