BehaviorBase = {}
BehaviorBase.__index = BehaviorBase
BehaviorBase.Name = "Base"

function BehaviorBase:New(controller)
    local behavior = setmetatable({}, self)
    behavior.Controller = controller
    behavior.Ragdoll = controller.Ragdoll
    behavior.Data = controller.Data
    return behavior
end

function BehaviorBase:OnEnter(previousStateName, ...) 
end

function BehaviorBase:OnThink() 
end

function BehaviorBase:OnLeave() 
end

function BehaviorBase:OnDamage(dmgInfo) 
end

function BehaviorBase:OnPhysicsCollide(data, phys) 
end