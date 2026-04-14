local function LoadFilesFromDir(directory, typeName)
    if not directory or directory == "" then
        AR_Manager.Log("Invalid directory path for " .. (typeName or "unknown"))
        return
    end
    
    local files, _ = file.Find(directory .. "*.lua", "LUA")
    
    if files and #files > 0 then
        for _, fileName in ipairs(files) do
            if not fileName or fileName == "" then
                continue
            end
            
            local filePath = directory .. fileName
            
            if not file.Exists(filePath, "LUA") then
                AR_Manager.Log("File not found: " .. filePath)
                continue
            end
            
            local success, err = pcall(include, filePath)
            if not success then
                AR_Manager.Log("Failed to load " .. (typeName or "file") .. ": " .. fileName .. " - " .. tostring(err))
            else
                -- print("[Ragdoll System] Loaded " .. typeName .. ": " .. fileName) -- for debug
            end
        end
    else
        AR_Manager.Log("Warning: No files found in " .. directory)
    end
end

function AR_Manager:LoadAllBehaviors()
    self.Behaviors = self.Behaviors or {}
    self.OverrideBehaviors = self.OverrideBehaviors or {}
    
    LoadFilesFromDir("ragdoll_system/behaviors/", "Behavior")
    LoadFilesFromDir("ragdoll_system/overrides/", "Override")
end

function AR_Manager:RegisterBehavior(name, tbl)
    if not name or name == "" then
        AR_Manager.Log("Cannot register behavior with empty name")
        return
    end
    
    if not tbl then
        AR_Manager.Log("Cannot register behavior '" .. name .. "' with nil table")
        return
    end
    
    if not self.Behaviors then
        self.Behaviors = {}
    end
    
    if self.Behaviors[name] then 
        AR_Manager.Log("Warning: Behavior '" .. name .. "' already registered, skipping")
        return 
    end
    
    self.Behaviors[name] = tbl
end

function AR_Manager:RegisterOverrideBehavior(name, tbl)
    if not name or name == "" then
        AR_Manager.Log("Cannot register override with empty name")
        return
    end
    
    if not tbl then
        AR_Manager.Log("Cannot register override '" .. name .. "' with nil table")
        return
    end
    
    if not self.OverrideBehaviors then
        self.OverrideBehaviors = {}
    end
    
    if self.OverrideBehaviors[name] then 
        AR_Manager.Log("Warning: Override '" .. name .. "' already registered, skipping")
        return 
    end
    
    self.OverrideBehaviors[name] = tbl
end

function AR_Manager:Initialize()
    if self.Initialized then 
        AR_Manager.Log("Manager already initialized")
        return 
    end

    print("[Ragdoll System] Initializing Core...")

    if not self.ActiveRagdolls then
        self.ActiveRagdolls = {}
    end
    
    if not self.Behaviors then
        self.Behaviors = {}
    end
    
    if not self.OverrideBehaviors then
        self.OverrideBehaviors = {}
    end

    local coreFiles = {
        "ragdoll_system/classes/sh_behavior.lua",
        "ragdoll_system/classes/sh_override.lua",
        "ragdoll_system/classes/sv_controller.lua"
    }

    for _, filePath in ipairs(coreFiles) do
        if not filePath or filePath == "" then
            AR_Manager.Log("Invalid core file path")
            continue
        end
        
        if file.Exists(filePath, "LUA") then
            local success, err = pcall(include, filePath)
            if not success then
                AR_Manager.Log("CRITICAL: Failed to load core file: " .. filePath .. " - " .. tostring(err))
                return
            end
        else
            AR_Manager.Log("CRITICAL: Missing core file: " .. filePath)
            return
        end
    end

    if _G.ActiveRagdollController then
        if type(_G.ActiveRagdollController) == "table" and _G.ActiveRagdollController.New then
            self.ControllerClass = _G.ActiveRagdollController
            print("[Ragdoll System] Controller class loaded successfully")
        else
            AR_Manager.Log("Warning: ActiveRagdollController exists but is invalid")
        end
    else
        AR_Manager.Log("Warning: ActiveRagdollController not found. Will retry on first ragdoll registration.")
    end

    local success, err = pcall(self.LoadAllBehaviors, self)
    if not success then
        AR_Manager.Log("Error loading behaviors: " .. tostring(err))
    end
    
    self.Initialized = true
    print("[Ragdoll System] Manager Initialized Successfully.")
end

if SERVER then
    hook.Remove("Initialize", "AR_Manager_Boot")
    
    hook.Add("Initialize", "AR_Manager_Boot", function()
        timer.Simple(0.1, function() 
            local success, err = pcall(function()
                if AR_Manager and AR_Manager.Initialize then
                    AR_Manager:Initialize()
                end
            end)
            
            if not success then
                print("[Ragdoll System] CRITICAL: Failed to initialize - " .. tostring(err))
            end
        end)
    end)
    
    hook.Add("ShutDown", "AR_Manager_Shutdown", function()
        if AR_Manager and AR_Manager.Shutdown then
            pcall(AR_Manager.Shutdown, AR_Manager)
        end
    end)
end