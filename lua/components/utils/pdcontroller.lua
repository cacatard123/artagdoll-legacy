local PDController = {}
PDController.__index = PDController

function PDController:new(kp, kd)
    local self = setmetatable({}, PDController)
    self.Kp = kp or 1000
    self.Kd = kd or 100

    self.lastError = Vector(0, 0, 0)
    self.lastOutput = Vector(0, 0, 0)

    return self
end

function PDController:Reset()
    self.lastError = Vector(0, 0, 0)
    self.lastOutput = Vector(0, 0, 0)
end

local function ClampVector(vec, maxLen)
    if vec:Length() > maxLen then
        return vec:GetNormalized() * maxLen
    end
    return vec
end

function PDController:UpdateForce(dt, physObj, targetPos)
    if not IsValid(physObj) or dt <= 0 or dt > 0.1 then return self.lastOutput end

    local currentPos = physObj:GetPos()
    local currentVel = physObj:GetVelocity()

    local error = targetPos - currentPos
    local dError = (error - self.lastError) / dt
    self.lastError = error

    local pTerm = error * self.Kp
    local dTerm = dError * self.Kd

    local force = pTerm + dTerm
    local mass = physObj:GetMass()
    local totalForce = force * mass

    totalForce = LerpVector(math.Clamp(dt * 15, 0, 1), self.lastOutput, totalForce)
    self.lastOutput = totalForce

    totalForce = ClampVector(totalForce, 800)
    return totalForce
end

return PDController
