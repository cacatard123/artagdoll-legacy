function AR_Manager:RegisterRagdoll(ragdoll, initialBehavior, ...)
    if not IsValid(ragdoll) or self.ActiveRagdolls[ragdoll] then return nil end
    
    if not self.Initialized then 
        self:Initialize() 
    end

    if not self.ControllerClass or not self.ControllerClass.New then
        if _G.ActiveRagdollController and _G.ActiveRagdollController.New then
            self.ControllerClass = _G.ActiveRagdollController
        else
            AR_Manager.Log("CRITICAL: Cannot register ragdoll. ControllerClass is missing!")
            return nil
        end
    end

    local success, controller = pcall(self.ControllerClass.New, self.ControllerClass, ragdoll)
    if not success then
        AR_Manager.Log("Constructor Failed: " .. tostring(controller))
        return nil
    end

    self.ActiveRagdolls[ragdoll] = controller

    local initSuccess, initErr = pcall(controller.Initialize, controller, initialBehavior, ...)
    if not initSuccess then
        AR_Manager.Log("Init Failed: " .. tostring(initErr))
        self.ActiveRagdolls[ragdoll] = nil
        return nil
    end

    return controller
end

function AR_Manager:UnregisterRagdoll(ragdoll)
    local controller = self.ActiveRagdolls[ragdoll]
    if not controller then return end

    self.ActiveRagdolls[ragdoll] = nil

    if controller.Cleanup then
        local success, err = pcall(controller.Cleanup, controller)
        if not success then
            AR_Manager.Log("Cleanup Error for " .. tostring(ragdoll) .. ": " .. err)
        end
    end
end

hook.Add("EntityRemoved", "AR_Manager_AutoCleanup", function(ent)
    if AR_Manager.ActiveRagdolls[ent] then
        AR_Manager:UnregisterRagdoll(ent)
    end
end)