OverrideBase = {}
OverrideBase.__index = OverrideBase
OverrideBase.Name = "BaseOverride"

function OverrideBase:New(controller)
    local override = setmetatable({}, self)
    override.Controller = controller
    override.Ragdoll = controller.Ragdoll
    override.Data = controller.Data
    override.IsActive = false

    return override
end

function OverrideBase:GetDmgPos()
    return self.Controller.dmgpos
end

function OverrideBase:OnActivate(duration, ...)
    self.IsActive = true
end

function OverrideBase:OnThink() 
end

function OverrideBase:OnDeactivate()
    self.IsActive = false
end

function OverrideBase:OnDamage(dmgInfo) 
end

function OverrideBase:OnPhysicsCollide(data, phys) 
end