if SERVER then AddCSLuaFile() end

-- Polyfills
if not SafeRemoveEntity then
    function SafeRemoveEntity(ent)
        if IsValid(ent) then ent:Remove() end
    end
end
 
local ENTITY = FindMetaTable("Entity")
if ENTITY and not ENTITY.DeleteOnRemove then
    function ENTITY:DeleteOnRemove(child)
        if not IsValid(self) or not IsValid(child) then return end
        self:CallOnRemove("delete_" .. child:EntIndex(), function(_, e)
            if IsValid(e) then e:Remove() end
        end, child)
    end
end

local PHYS = FindMetaTable("PhysObj")
if PHYS and not PHYS.GetID then
    function PHYS:GetID()
        local ent = self:GetEntity()
        if not IsValid(ent) then return -1 end
        for i = 0, ent:GetPhysicsObjectCount() - 1 do
            local p = ent:GetPhysicsObjectNum(i)
            if IsValid(p) and p == self then return i end
        end
        return -1
    end
end

local IsValid = IsValid
local CurTime = CurTime
local Vector = Vector
local math_max = math.max
local math_min = math.min
local math_Clamp = math.Clamp
local math_asin = math.asin
local math_pi = math.pi
local math_sqrt = math.sqrt
local pairs = pairs
local istable = istable
local pcall = pcall
local NULL = NULL
local TRANSMIT_NEVER = TRANSMIT_NEVER
local SERVER = SERVER
local CLIENT = CLIENT

local vecZero = Vector(0, 0, 0)

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.AutomaticFrameAdvance = true
ENT.Enabled = true

function ENT:SetupDataTables()
    if self.NetworkVar then
        self:NetworkVar("Entity", 0, "Target")
        self:NetworkVar("Entity", 1, "Parent")
        self:NetworkVar("Bool", 0, "ControllerEnabled")
    else
        self.GetTarget = self.GetTarget or function() return NULL end
        self.SetTarget = self.SetTarget or function() end
        self.GetParent = self.GetParent or function() return NULL end
        self.SetParent = self.SetParent or function() end
        self.GetControllerEnabled = self.GetControllerEnabled or function() return false end
        self.SetControllerEnabled = self.SetControllerEnabled or function() end
    end
end

function ENT:SetMaxAngVel(val) 
    self.max_ang_vel = val or 600 
end

function ENT:SetReactionStrength(val) 
    self.reaction_strength = math_max(val or 1, 0.1) 
end

function ENT:GetReactionStrength() 
    return self.reaction_strength or 1 
end

function ENT:SetSmoothingFactor(factor) 
    self.smoothing_factor = math.Clamp(factor or 0.7, 0.1, 1.0) 
end

function ENT:SetResponseSpeed(speed) 
    self.response_speed = math.Clamp(speed or 1.0, 0.1, 3.0) 
end

local function ProcessUniversalBone(self, target, physID, addToController)
    local phys = target:GetPhysicsObjectNum(physID)
    if not IsValid(phys) then return false end

    local boneID = target:TranslatePhysBoneToBone(physID)
    local boneName = target:GetBoneName(boneID)
    
    if not boneName then return false end

    if addToController then
        self:AddToMotionController(phys)
        if phys.Wake then phys:Wake() end
    else
        self:RemoveFromMotionController(phys)
    end
    
    return true, phys, boneName
end

function ENT:EnableController()
    self:SetControllerEnabled(true)
    self.Enabled = true
    local target = self:GetTarget()
    if not IsValid(target) then return end
    
    local count = target:GetPhysicsObjectCount()
    for i = 0, count - 1 do
        ProcessUniversalBone(self, target, i, true)
    end
end

function ENT:DisableController()
    self:SetControllerEnabled(false)
    self.Enabled = false
    local target = self:GetTarget()
    if not IsValid(target) then return end
    
    local count = target:GetPhysicsObjectCount()
    for i = 0, count - 1 do
        ProcessUniversalBone(self, target, i, false)
    end
end

function ENT:ToggleController()
    if self.Enabled then self:DisableController() else self:EnableController() end
    return self.Enabled
end

function ENT:ChangeModel(model)
    if self.SetModel then self:SetModel(model) end
end

function ENT:SetBoneList(list)
    local target = self:GetTarget()
    if not IsValid(target) then return end

    local allowedBones = {}
    if list and istable(list) then
        for _, name in pairs(list) do
            allowedBones[name] = true
        end
    end

    self._physCache = {}
    self._boneNameCache = {}
    
    local hasValidBone = false

    local count = target:GetPhysicsObjectCount()

    for i = 0, count - 1 do
        local boneID = target:TranslatePhysBoneToBone(i)
        local name = target:GetBoneName(boneID)
        
        local shouldEnable = false
        if name and allowedBones[name] then
            shouldEnable = true
        end

        local success, phys, boneName = ProcessUniversalBone(self, target, i, shouldEnable)
        
        if shouldEnable and success and IsValid(phys) then
            hasValidBone = true

            local pid = phys:GetID()
            if pid and pid >= 0 then
                self._physCache[pid] = {
                    name = boneName,
                    physobj = phys
                }
                
                local selfBoneID = self:LookupBone(boneName)
                if selfBoneID then
                    self._boneNameCache[boneName] = selfBoneID
                end
            end
        end
    end

    if not hasValidBone then 
        self:SetControllerEnabled(false)
    else
        self:SetControllerEnabled(true)
        self.Enabled = true
    end
end

function ENT:Initialize()
    if CLIENT then return end
    
    if self.SetModel and self.Model then self:SetModel(self.Model) end
    if self.StartMotionController then self:StartMotionController() end

    self:SetControllerEnabled(true)
    self.Enabled = true
    self:SetSmoothingFactor(0)
    self:SetResponseSpeed(1)
    self:SetReactionStrength(2)

    local target = self:GetTarget()
    if not IsValid(target) then 
        if SERVER then SafeRemoveEntity(self) end
        return 
    end

    self._physCache = {}
    self._boneNameCache = {}
    
    local hasValidBone = false
    local count = target:GetPhysicsObjectCount()

    for i = 0, count - 1 do
        local success, phys, name = ProcessUniversalBone(self, target, i, true)
        
        if success and IsValid(phys) then
            hasValidBone = true

            local pid = phys:GetID()
            if pid and pid >= 0 then
                self._physCache[pid] = {
                    name = name,
                    physobj = phys
                }
                
                local selfBoneID = self:LookupBone(name)
                if selfBoneID then
                    self._boneNameCache[name] = selfBoneID
                end
            end
        end
    end

    if not hasValidBone then 
        if SERVER then SafeRemoveEntity(self) end
        return 
    end
    
    if target.DeleteOnRemove then target:DeleteOnRemove(self) end
    self.Created = CurTime()
end

function ENT:Think()
    if SERVER then
        local target = self:GetTarget()
        local angleparent = self:GetParent()
        
        if IsValid(target) and IsValid(angleparent) then
            local root = target:TranslatePhysBoneToBone(0)
            if root then
                local _, physparent = target:GetBonePosition(root)
                
                if physparent then 
                    angleparent:SetAngles(physparent)
                end
            end
        end
    end
    
    self:NextThink(CurTime())
    return true
end

function ENT:OnRemove()
    if CLIENT then return end
    
    local target = self:GetTarget()
    if IsValid(target) and self.PCCB and target.RemoveCallback then
        target:RemoveCallback("PhysicsCollide", self.PCCB)
    end
    
    local physCache = self._physCache
    if physCache then
        for _, cache in pairs(physCache) do
            if IsValid(cache.physobj) then
                self:RemoveFromMotionController(cache.physobj)
            end
        end
    end
    
    self._physCache = nil
    self._boneNameCache = nil
end

function ENT:UpdateTransmitState()
    return TRANSMIT_NEVER
end

function ENT:VectorsFromAngles(phys, anim)
    
    local physang = phys
    local animang = anim
    
    local phyforward = physang:Forward()
    local phyright = physang:Right()
    local phyup = physang:Up()
    
    local animforward = animang:Forward()
    local animright = animang:Right()
    local animup = animang:Up()
    
    animforward:Normalize()
    phyforward:Normalize()

    local dot_yaw = math_Clamp(phyforward:Dot(animright), -1, 1)
    local dot_pitch = math_Clamp(phyforward:Dot(animup), -1, 1)
    local dot_roll = math_Clamp(phyright:Dot(animup), -1, 1)

    local yaw = math_asin(dot_yaw)*180/math_pi
    local pitch = math_asin(dot_pitch)*180/math_pi
    local roll = math_asin(dot_roll) * 180/math_pi
    
    angvel = Vector(roll,pitch,yaw)
    
    return angvel
end

function ENT:PhysicsSimulate(phys, dt)
    if CLIENT then return end
    if not self.Enabled or not self:GetControllerEnabled() then return end

    local target = self:GetTarget()
    if not IsValid(target) then return end

    local pid = phys:GetID()
    local boneInfo = self._physCache[pid]
    
    if not boneInfo then 
        timer.Simple(0, function()
            if IsValid(self) and IsValid(phys) then
                self:RemoveFromMotionController(phys)
            end
        end)
        return 
    end

    local boneName = boneInfo.name
    local bone_id = self._boneNameCache[boneName]
    
    if not bone_id then return end

    local _, animAng = self:GetBonePosition(bone_id)
    if not animAng then return end

    local physAng = phys:GetAngles()

    local angVel = self:VectorsFromAngles(physAng, animAng)

    local multiplier = self.response_speed or 1.0
    local strength = self.reaction_strength or 1.0
    
    angVel = angVel * (multiplier * strength)

    local currentAngVel = phys:GetAngleVelocity()
    angVel.x = angVel.x - (currentAngVel.x * 0.2)
    angVel.y = angVel.y - (currentAngVel.y * 0.2)
    angVel.z = angVel.z - (currentAngVel.z * 0.2)

    local limit = 315
    local limitSq = limit * limit
    local angVelLengthSq = angVel.x * angVel.x + angVel.y * angVel.y + angVel.z * angVel.z
    
    if angVelLengthSq >= limitSq then
        local len = math_sqrt(angVelLengthSq)
        if len > 0 then
            local scale = (limit * 0.5) / len
            angVel.x = angVel.x * scale
            angVel.y = angVel.y * scale
            angVel.z = angVel.z * scale
        end
    end

    phys:AddAngleVelocity(angVel)
end

function ENT:DeactivateBone(bone)
    if CLIENT then return end
    local ragdoll = self:GetTarget()
    if not IsValid(ragdoll) then return end
    local phys = ragdoll:GetPhysicsObjectNum(bone)
    if not IsValid(phys) then return end
    self:RemoveFromMotionController(phys)
end