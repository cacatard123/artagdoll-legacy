-- will redo later.

AddCSLuaFile()

ENT.Base = "base_ai"
ENT.Type = "ai"
ENT.AutomaticFrameAdvance = true

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "Ragdoll")
end

function ENT:Initialize()

end

function ENT:Think()
end

function ENT:OnRemove()
end