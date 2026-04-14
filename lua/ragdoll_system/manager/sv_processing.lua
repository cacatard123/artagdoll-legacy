AR_Manager.LastUpdateTime = AR_Manager.LastUpdateTime or CurTime()

local function SafeUpdate(controller, dt)
    if not controller or not controller.Think then 
        return false 
    end
    return controller:Think(dt)
end

function AR_Manager:GlobalUpdate()
    if not self or not self.ActiveRagdolls then return end
    
    local currentTime = CurTime()
    local deltaTime = currentTime - (self.LastUpdateTime or currentTime)
    self.LastUpdateTime = currentTime
    
    if deltaTime > self.MaxDeltaTime or deltaTime < 0 then
        deltaTime = self.MaxDeltaTime
    end
    
    if table.Count(self.ActiveRagdolls) == 0 then return end

    local ragdollsToProcess = {}
    for ragdoll, controller in pairs(self.ActiveRagdolls) do
        if IsValid(ragdoll) and controller then
            table.insert(ragdollsToProcess, {ragdoll = ragdoll, controller = controller})
        end
    end

    for _, data in ipairs(ragdollsToProcess) do
        local ragdoll = data.ragdoll
        local controller = data.controller
        
        if not IsValid(ragdoll) then
            self:UnregisterRagdoll(ragdoll)
            goto skip_ent
        end

        if not self.ActiveRagdolls[ragdoll] then
            goto skip_ent
        end

        if controller.Think then
            local success, result = xpcall(SafeUpdate, debug.traceback, controller, deltaTime)
            
            if not success then
                AR_Manager.Log("Crash prevented in Ragdoll Think: " .. tostring(ragdoll))
                AR_Manager.Log(result or "Unknown error")
                
                pcall(self.UnregisterRagdoll, self, ragdoll)
            end
        end
        
        ::skip_ent::
    end
end

if timer.Exists("AR_Manager_GlobalUpdate") then
    timer.Remove("AR_Manager_GlobalUpdate")
end

timer.Create("AR_Manager_GlobalUpdate", AR_Manager.UpdateInterval, 0, function()
    local success, err = pcall(function()
        if AR_Manager and AR_Manager.GlobalUpdate then
            AR_Manager:GlobalUpdate()
        end
    end)
    
    if not success then
        AR_Manager.Log("Critical error in GlobalUpdate timer: " .. tostring(err))
    end
end)