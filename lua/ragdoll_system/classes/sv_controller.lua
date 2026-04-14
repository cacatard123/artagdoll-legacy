ActiveRagdollController = {}
ActiveRagdollController.__index = ActiveRagdollController

local function SafeGetConVar(name, default)
    local cvar = GetConVar(name)
    if not cvar then return default end
    
    local success, value = pcall(function() return cvar:GetFloat() end)
    return success and value or default
end

ActiveRagdollController.CONST = {
    HEALTH_MAX = SafeGetConVar("ar_MaxHealth", 100),
    HEALTH_DRAIN_RATE = SafeGetConVar("ar_DrainHealth", 1),
    HEALTH_DRAIN_ONFIRE = 10.0,
    FALLING_MIN_SPEED = 150,
    FALLING_MIN_VERTICAL = -100,
    FALLING_VERTICAL_FAST = -150,
    AIRBORNE_MIN_SPEED = 100,
    GROUND_FAST_SPEED = 300,
    GROUND_STAGGER_SPEED = 150,
    GROUND_SLIDE_THRESHOLD = 350,
    UPRIGHTNESS_THRESHOLD = 0.3,
    UPRIGHTNESS_GOOD = 0.5
}

local folder = "ragdoll_system/classes/controller/"

local function LoadModule(filename)
    if not filename or filename == "" then
        ErrorNoHalt("[Controller] Invalid module filename\n")
        return false
    end
    
    local filePath = folder .. filename
    if not file.Exists(filePath, "LUA") then
        ErrorNoHalt("[Controller] Module not found: " .. filePath .. "\n")
        return false
    end
    
    local success, err = pcall(include, filePath)
    if not success then
        ErrorNoHalt("[Controller] Failed to load " .. filename .. ": " .. tostring(err) .. "\n")
        return false
    end
    
    return true
end

local modulesLoaded = true
modulesLoaded = LoadModule("sv_init.lua") and modulesLoaded
modulesLoaded = LoadModule("sv_health.lua") and modulesLoaded
modulesLoaded = LoadModule("sv_physics.lua") and modulesLoaded
modulesLoaded = LoadModule("sv_behavior.lua") and modulesLoaded

if modulesLoaded then
    print("[Ragdoll System] Controller Modules Loaded.")
else
    ErrorNoHalt("[Ragdoll System] WARNING: Some controller modules failed to load!\n")
end