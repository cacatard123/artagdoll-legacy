AR_Manager = AR_Manager or {}
AR_Manager.Behaviors = AR_Manager.Behaviors or {}
AR_Manager.OverrideBehaviors = AR_Manager.OverrideBehaviors or {}
AR_Manager.ActiveRagdolls = AR_Manager.ActiveRagdolls or {}

AR_Manager.UpdateInterval = 0
AR_Manager.MaxDeltaTime = 0.1
AR_Manager.Initialized = false
AR_Manager.ControllerClass = nil

local function SafeError(msg)
    ErrorNoHaltWithStack("[AR_Manager] " .. msg .. "\n")
end
AR_Manager.Log = SafeError