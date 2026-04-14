Artagdoll = Artagdoll or {}
Artagdoll.Config = {}

Artagdoll.Config.Colors = {
    bg = Color(25, 25, 30),
    panel = Color(35, 35, 40),
    accent = Color(60, 120, 200),
    accentHover = Color(70, 140, 220),
    text = Color(240, 240, 245),
    textDim = Color(160, 160, 165),
    hover = Color(45, 45, 50),
    unchecked = Color(55, 55, 60),
    separator = Color(50, 50, 55),
    reset = Color(200, 80, 60),
    resetHover = Color(220, 100, 80),
    description = Color(140, 140, 150),
    preset = Color(80, 180, 120),
    presetHover = Color(100, 200, 140),
    presetDelete = Color(180, 60, 60),
    presetDeleteHover = Color(200, 80, 80),
    warning = Color(255, 180, 0),
    warningBg = Color(255, 180, 0, 30),
    success = Color(46, 204, 113)
}

Artagdoll.Config.DefaultPresets = {
    ["Normal"] = {
        ar_enable = 1, ar_enableSFX = 1, ar_BulletDamage = 1, ar_MaxHealth = 100,
        ar_DrainHealth = 5, ar_TimeBeforeDecay = 2, ar_uprightForce = 480,
        ar_StepSpeed = 9, ar_StepHeight = 18.5, ar_MinStepThreshold = 18,
        ar_ReactionDelay = 0.21, ar_BalanceRadius = 9.35, ar_StepReachMultiplier = 1.6,
        ar_enableDeathPoses = 1, ar_enableHeadShotReact = 1, ar_enableStiffness = 1,
        ar_enableWoundGrab = 1, ar_WoundGrabTime = 5, ar_enableWallStunt = 1
    },
    ["Realistic"] = {
        ar_enable = 1, ar_enableSFX = 1, ar_BulletDamage = 1, ar_MaxHealth = 75,
        ar_TimeBeforeDecay = 1.25, ar_DrainHealth = 8, ar_uprightForce = 425,
        ar_StepSpeed = 7.75, ar_StepHeight = 17.5, ar_MinStepThreshold = 10,
        ar_ReactionDelay = 0.32, ar_BalanceRadius = 7.5, ar_StepReachMultiplier = 1.3,
        ar_enableDeathPoses = 0, ar_enableHeadShotReact = 1, ar_enableStiffness = 1,
        ar_enableWoundGrab = 1, ar_WoundGrabTime = 8, ar_enableWallStunt = 0
    },
    ["Dev preset / Very good tho"] = {
        ar_enable = 1, ar_enableSFX = 1, ar_BulletDamage = 1, ar_MaxHealth = 135.33,
        ar_DrainHealth = 7.16, ar_TimeBeforeDecay = 3.2, ar_uprightForce = 480,
        ar_StepSpeed = 8.32, ar_StepHeight = 20.64, ar_MinStepThreshold = 12.81,
        ar_ReactionDelay = 0.1, ar_BalanceRadius = 8.08, ar_StepReachMultiplier = 1.5,
        ar_enableDeathPoses = 0, ar_enableHeadShotReact = 1, ar_enableStiffness = 1,
        ar_enableWoundGrab = 1, ar_WoundGrabTime = 5, ar_enableWallStunt = 1
    }
}

Artagdoll.Config.Categories = {
    {
        name = "Main",
        icon = "icon16/application.png",
        description = "Core settings of the ragdoll.",
        settings = {
            {type = "space", size = 5},
            {type = "separator", label = "Core Controls", description = "Enable or disable main addon features"},
            {type = "space", size = 3},
            {type = "toggle", label = "Enable Artagdoll", cvar = "ar_enable", default = 1, help = "turns the entire addon on/off"},
            {type = "toggle", label = "Enable Ragdolls Collide with Player", cvar = "ar_PlayerCollideRagdoll", default = 1, help = "Allow the Player to have collisions with other ragdolls"},
            {type = "separator", label = "Sfx", description = "Tweak sfx of Artagdoll"},
            {type = "space", size = 5},
            {type = "toggle", label = "Enable Sound Effects", cvar = "ar_enableSFX", default = 1, help = "Toggle ragdoll sound effects"},
            {type = "toggle", label = "Enable HeadshotSFX to be played", cvar = "ar_headshotSfx", default = 1, help = "Toggle ragdoll headshot sfx"},
            {type = "space", size = 8},
            {type = "separator", label = "Health & Damage", description = "Configure ragdoll health and damage behavior"},
            {type = "space", size = 3},
            {type = "toggle", label = "Can Take Damage", cvar = "ar_BulletDamage", default = 1, help = "Allow ragdolls to receive damage"},
            {type = "slider", label = "Max Health", cvar = "ar_MaxHealth", min = 5, max = 300, default = 100, help = "Starting health for ragdolls (5-300)"},
            {type = "slider", label = "Health Drain Rate", cvar = "ar_DrainHealth", min = 0, max = 25, default = 5, help = "How fast health depletes while wounded (0-25)"},
        }
    },
    {
        name = "Behaviours",
        icon = "icon16/cog.png",
        description = "Fine-tune ragdoll behaviors and how they react.",
        settings = {
            {type = "separator", label = "Balance & Movement", description = "How ragdolls recover and maintain balance"},
            {type = "space", size = 5},
            {type = "slider", label = "Upright Force", cvar = "ar_uprightForce", min = 200, max = 700, default = 480, help = "urightforce help to balance the whole body"}, 
            {type = "slider", label = "Time before the balance Decay", cvar = "ar_TimeBeforeDecay", min = 2, max = 20, default = 2, help = "time before loosing balance"},
            {type = "slider", label = "Step Speed", cvar = "ar_StepSpeed", min = 2, max = 15, default = 9, help = "Speed of recovery steps (2-15)"},
            {type = "slider", label = "Step Height", cvar = "ar_StepHeight", min = 5, max = 40, default = 22.5, help = "Maximum step-over height (5-40)"},
            {type = "slider", label = "Min Step Threshold", cvar = "ar_MinStepThreshold", min = 3, max = 30, default = 18, help = "Minimum distance before taking step (3-30)"},
            {type = "slider", label = "Reaction Delay", cvar = "ar_ReactionDelay", min = 0.1, max = 1, default = 0.21, help = "Delay before reacting to hits (0.1-1 sec)"},
            {type = "slider", label = "Balance Radius", cvar = "ar_BalanceRadius", min = 3, max = 13, default = 9.35, help = "Size of balance detection zone (3-13)"},
            {type = "slider", label = "Step Reach", cvar = "ar_StepReachMultiplier", min = 1, max = 2.5, default = 1.5, help = "How far ragdoll can reach when stepping (1-3)"},
            {type = "space", size = 8},
            {type = "separator", label = "Death Poses", description = "Ragdoll animation when health reaches zero"},
            {type = "space", size = 3},
            {type = "toggle", label = "Enable Death Poses", cvar = "ar_enableDeathPoses", default = 1, help = "Play death reaction instead of instant ragdoll"},
            {type = "space", size = 8},
            {type = "separator", label = "Headshot Reactions", description = "Special behavior for headshots"},
            {type = "space", size = 3},
            {type = "toggle", label = "Enable Headshot Reaction", cvar = "ar_enableHeadShotReact", default = 1, help = "Ragdolls react differently to headshots"},
            {type = "toggle", label = "Enable Stiffness", cvar = "ar_enableStiffness", default = 1, help = "Body stiffening effect after headshot"},
            {type = "space", size = 8},
            {type = "separator", label = "Wound Grabbing", description = "Ragdolls hold injured body parts"},
            {type = "space", size = 3},
            {type = "toggle", label = "Enable Wound Grabbing", cvar = "ar_enableWoundGrab", default = 1, help = "Ragdolls grab wounded areas"},
            {type = "slider", label = "GrabWoundChance", cvar = "ar_holdwound_chance", min = 0, max = 100, default = 100, help = "Chance to hold wound"},
            {type = "slider", label = "MinDuration", cvar = "ar_holdwound_minduration", min = 0, max = 10, default = 3, help = "How long to hold wound min"},
            {type = "slider", label = "MaxDuration", cvar = "ar_holdwound_maxduration", min = 0, max = 10, default = 8, help = "How long to hold wound max"},
            {type = "slider", label = "2 hand Grab Chance", cvar = "ar_holdwound_twohand_chance", min = 0, max = 100, default = 50, help = "Chance (0-100) uses both hands to grab wound."},
            {type = "space", size = 8},
            {type = "separator", label = "Environment Grabbing", description = "Ragdolls grabbing walls"},
            {type = "space", size = 3},
            {type = "toggle", label = "Enable Environment Grabbing", cvar = "ar_enableHoldEnv", default = 1, help = "Ragdolls try to grab on smth when falling."},
            {type = "slider", label = "Search Radius", cvar = "ar_holdenv_search_radius", min = 5, max = 50, default = 15, help = "How far hands search for something to grab"},
            {type = "slider", label = "Max Grab Duration", cvar = "ar_holdenv_max_hold", min = 0.5, max = 5.0, default = 2.0, help = "Max time a ragdoll holds onto an surface"},
            {type = "slider", label = "Grab Cooldown", cvar = "ar_holdenv_cooldown", min = 0.5, max = 5.0, default = 3.0, help = "Time before they can grab again"},
            {type = "slider", label = "Release Force", cvar = "ar_holdenv_release_vel", min = 50, max = 500, default = 200, help = "Velocity required to break the grip"},
            {type = "slider", label = "Max Grabs", cvar = "ar_holdenv_max_grabs", min = 1, max = 4, default = 2, help = "how many times they can grab surfaces"},
        }
    },
    {
        name = "Experimental",
        icon = "icon16/lightbulb.png",
        description = "experimental features - may be unstable or cause errors",
        settings = {
            {type = "separator", label = "Wall Stunts", description = "GTA-style wall vaulting and flipping"},
            {type = "space", size = 5},
            {type = "toggle", label = "Enable Wall Stunts", cvar = "ar_enableWallStunt", default = 1, help = "Ragdolls can vault over low obstacles (GTA IV/RDR style)"},
            {type = "space", size = 8},
            {type = "toggle", label = "Enable npcs can shoot ragdolls", cvar = "ar_ragdollShoot", default = 1, help = "Npcs can shoot alive ragdolls"},
        }
    },
}