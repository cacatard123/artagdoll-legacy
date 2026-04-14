RagdollSys = RagdollSys or {}
AR_Manager = AR_Manager or {}

print("Loading modules...")

local root = "ragdoll_system/"
local mgr  = "ragdoll_system/manager/"

if file.Exists(mgr .. "sh_const.lua", "LUA") then
    include(mgr .. "sh_const.lua")
    include(mgr .. "sv_loader.lua")
    include(mgr .. "sv_registry.lua")
    include(mgr .. "sv_processing.lua")
    print("Manager loaded.")
else
    ErrorNoHalt("CRITICAL: Manager files missing in " .. mgr .. "\n")
end

if file.Exists(root .. "sh_config.lua", "LUA") then
    include(root .. "sh_config.lua")
    include(root .. "sv_utils.lua")
    include(root .. "sv_core.lua")
    include(root .. "sv_hooks.lua")
    print("Core logic loaded.")
else
    ErrorNoHalt("CRITICAL: Core files missing in " .. root .. "\n")
end

print("Load complete.")