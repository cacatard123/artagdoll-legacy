DeathFaces = DeathFaces or {}
DeathFaces.ActiveRagdolls = {}

DeathFaces.Config = {
    enabled = true,
    animSpeed = 1.0,
    noiseIntensity = 2.5,

    faceModifier = 1.8,
    debugMode = false
}

DeathFaces.FlexDatabase = {
    jaw = { "jaw_drop", "right_mouth_drop", "left_mouth_drop", "lower_lip" },
    tension = { "wrinkler", "bite", "right_cheek_raiser", "left_cheek_raiser" },
    suffering = { "right_inner_raiser", "left_inner_raiser", "right_outer_raiser", "left_outer_raiser" },
    eyes = { "right_lid_closer", "left_lid_closer", "right_lid_droop", "left_lid_droop", "blink" }
}

DeathFaces.ExpressionPresets = {
    {
        name = "screaming_agony",
        weight = 30,
        params = { 
            lowerLip = 0.0,      
            jawDrop = 0.9,
            bite = 0.1,          
            innerRaiser = 1.0,   
            outerRaiser = 0.3,
            cheekRaiser = 0.0    
        }
    },
    {
        name = "terror_clench",
        weight = 25,
        params = { 
            lowerLip = 0.0,
            jawDrop = 0.3,
            bite = 0.9,
            innerRaiser = 0.9,
            outerRaiser = 0.8,
            cheekRaiser = 0.0    
        }
    },
    {
        name = "gasping",
        weight = 25,
        params = { 
            lowerLip = 0.0,
            jawDrop = 1.0,
            bite = 0.0,
            innerRaiser = 1.0,
            outerRaiser = 0.6,
            cheekRaiser = 0.0    
        }
    },
    {
        name = "grimace",
        weight = 20,
        params = {
            lowerLip = 0.0,
            jawDrop = 0.4,
            bite = 0.6,
            innerRaiser = 0.8,
            outerRaiser = 0.4,
            cheekRaiser = 0.0    
        }
    }
}

function DeathFaces:GetFlexID(ent, name)
    if not IsValid(ent) then return nil end
    
    ent.DF_FlexCache = ent.DF_FlexCache or {}
    
    if ent.DF_FlexCache[name] ~= nil then 
        return ent.DF_FlexCache[name] 
    end
    
    local id = ent:GetFlexIDByName(name)
    if id and id >= 0 then
        ent.DF_FlexCache[name] = id
        return id
    end
    
    ent.DF_FlexCache[name] = -1
    return nil
end

function DeathFaces:SetFlex(ent, flexName, value)
    if not IsValid(ent) then return false end
    
    local id = self:GetFlexID(ent, flexName)
    if not id or id < 0 then return false end
    
    local safeVal = math.Clamp(value or 0, 0, 1)
    ent:SetFlexWeight(id, safeVal)
    return true
end

function DeathFaces:GetFlex(ent, flexName)
    if not IsValid(ent) then return 0 end
    
    local id = self:GetFlexID(ent, flexName)
    if not id or id < 0 then return 0 end
    
    return ent:GetFlexWeight(id) or 0
end

function DeathFaces:GetRandomPreset()
    local total = 0
    for _, p in ipairs(self.ExpressionPresets) do total = total + p.weight end
    
    local rand = math.random() * total
    local current = 0
    
    for _, p in ipairs(self.ExpressionPresets) do
        current = current + p.weight
        if rand <= current then return p end
    end
    
    return self.ExpressionPresets[1]
end

function DeathFaces:SyncFace(ent)
    local function Copy(src, dst)
        local val = self:GetFlex(ent, src)
        self:SetFlex(ent, dst, val)
    end
    
    Copy("right_inner_raiser", "left_inner_raiser")
    Copy("right_outer_raiser", "left_outer_raiser")
    Copy("right_mouth_drop", "left_mouth_drop")
end

function DeathFaces:Initialize(ent, modifier)
    if not IsValid(ent) then return false end
    
    local flexNum = ent:GetFlexNum()
    if not flexNum or flexNum <= 0 then return false end

    ent.DF_FlexCache = {}
    
    for i = #self.ActiveRagdolls, 1, -1 do
        if self.ActiveRagdolls[i] == ent then
            table.remove(self.ActiveRagdolls, i)
        end
    end
    
    table.insert(self.ActiveRagdolls, ent)

    local preset = self:GetRandomPreset()
    local p = preset.params
    
    local ct = CurTime()
    ent.DeathFaceData = {
        startTime = ct,
        lastUpdate = ct,
        modifier = modifier or self.Config.faceModifier,
        isAlive = true, 
        
        baseLip = p.lowerLip,
        baseBite = p.bite,
        baseInner = p.innerRaiser,
        baseOuter = p.outerRaiser,
        baseJaw = p.jawDrop,
        baseCheek = p.cheekRaiser,
    }
    
    ent.DF_TremorFreq = math.Rand(18, 35)
    ent.DF_ShiverFreq = math.Rand(8, 15)
    
    ent.DF_NextBlink = ct + math.Rand(0.2, 0.8)
    ent.DF_IsBlinking = false
    ent.DF_BlinkEnd = 0
    ent.DF_BlinkStrength = 0

    for i = 0, flexNum - 1 do
        ent:SetFlexWeight(i, 0)
    end
    
    self:SetFlex(ent, "right_lid_droop", 0)
    self:SetFlex(ent, "left_lid_droop", 0)
    self:SetFlex(ent, "blink", 0)
    
    self:SetFlex(ent, "right_cheek_raiser", 0)
    self:SetFlex(ent, "left_cheek_raiser", 0)
    self:SetFlex(ent, "left_part", 0)     
    self:SetFlex(ent, "right_part", 0)    
    self:SetFlex(ent, "left_stretcher", 0) 
    self:SetFlex(ent, "right_stretcher", 0)
    
    return true
end

function DeathFaces:AnimateFace(ent)
    if not IsValid(ent) or not ent.DeathFaceData then return false end
    if not ent.DeathFaceData.isAlive then return false end 
    
    local data = ent.DeathFaceData
    local ct = CurTime()
    
    local mod = data.modifier * self.Config.noiseIntensity
    
    local tremor = math.sin(ct * ent.DF_TremorFreq) * 0.2
    local shiver = math.sin(ct * ent.DF_ShiverFreq) * 0.1
    
    local jawVal = data.baseJaw 
    local lipVal = data.baseLip
    local biteVal = data.baseBite

    local innerVal = math.Clamp(data.baseInner + (tremor * 0.3), 0, 1) 
    local outerVal = math.Clamp(data.baseOuter + (shiver * 0.3), 0, 1)
    
    self:SetFlex(ent, "jaw_drop", jawVal)
    self:SetFlex(ent, "lower_lip", lipVal)
    self:SetFlex(ent, "bite", biteVal)
    
    self:SetFlex(ent, "right_inner_raiser", innerVal)
    self:SetFlex(ent, "right_outer_raiser", outerVal)
    
    self:SetFlex(ent, "right_mouth_drop", jawVal * 0.6)
    self:SetFlex(ent, "left_mouth_drop", jawVal * 0.6)
    
    self:SetFlex(ent, "right_cheek_raiser", 0)
    self:SetFlex(ent, "left_cheek_raiser", 0)
    self:SetFlex(ent, "left_part", 0)
    self:SetFlex(ent, "right_part", 0)
    self:SetFlex(ent, "left_stretcher", 0)
    self:SetFlex(ent, "right_stretcher", 0)
    
    self:SyncFace(ent)
    self:UpdateBlinking(ent)
    
    return true
end

function DeathFaces:UpdateBlinking(ent)
    local ct = CurTime()
    
    if not ent.DF_IsBlinking then
        if ct >= ent.DF_NextBlink then
            ent.DF_IsBlinking = true
            ent.DF_BlinkStart = ct
            ent.DF_BlinkDuration = math.Rand(0.1, 0.2)
            ent.DF_BlinkEnd = ct + ent.DF_BlinkDuration
            
            local nextDelay = math.Rand(0.3, 2.0)
            ent.DF_NextBlink = ct + ent.DF_BlinkDuration + nextDelay
        end
    else
        local blinkElapsed = ct - ent.DF_BlinkStart
        local blinkProgress = math.Clamp(blinkElapsed / ent.DF_BlinkDuration, 0, 1)
        
        if blinkProgress >= 1 then
            ent.DF_IsBlinking = false
            ent.DF_BlinkStrength = 0
            self:SetFlex(ent, "blink", 0)
        else
            local curve = math.sin(blinkProgress * math.pi)
            ent.DF_BlinkStrength = curve * 0.9
            self:SetFlex(ent, "blink", ent.DF_BlinkStrength)
        end
    end
end

function DeathFaces:RelaxToDeadPose(ragdoll, time)
    if not IsValid(ragdoll) then return end
    if not ragdoll.DeathFaceData then return end
    
    local duration = time or 0.5
    
    ragdoll.DeathFaceData.isAlive = false
    ragdoll.DeathFaceRelaxing = true
    ragdoll.DeathFaceRelaxStart = CurTime()
    ragdoll.DeathFaceRelaxDuration = duration
    ragdoll.DeathFaceLastUpdate = CurTime()
    
    ragdoll.DF_RelaxStartValues = {}
    for i = 0, ragdoll:GetFlexNum() - 1 do
        local name = ragdoll:GetFlexName(i)
        ragdoll.DF_RelaxStartValues[name] = ragdoll:GetFlexWeight(i)
    end
    
    local jawDead = math.Rand(0.5, 0.8)
    local eyeDead = math.Rand(0.4, 0.7)
    
    ragdoll.DF_RelaxTargets = {
        ["jaw_drop"] = jawDead,
        ["lower_lip"] = 0,                  
        ["right_mouth_drop"] = jawDead * 0.5,
        ["left_mouth_drop"] = jawDead * 0.5,
        ["right_lid_droop"] = eyeDead,
        ["left_lid_droop"] = eyeDead,
        ["blink"] = 0,
        ["bite"] = 0,
        ["wrinkler"] = 0,
        ["right_inner_raiser"] = 0,
        ["left_inner_raiser"] = 0,
        ["right_outer_raiser"] = 0,
        ["left_outer_raiser"] = 0,
        ["right_cheek_raiser"] = 0,    
        ["left_cheek_raiser"] = 0,      
    }
end

function DeathFaces:UpdateRelaxation(ent)
    if not IsValid(ent) or not ent.DeathFaceRelaxing then return false end
    
    local ct = CurTime()
    local elapsed = ct - ent.DeathFaceRelaxStart
    local progress = math.Clamp(elapsed / ent.DeathFaceRelaxDuration, 0, 1)
    
    if progress >= 1 then
        for name, target in pairs(ent.DF_RelaxTargets) do
            self:SetFlex(ent, name, target)
        end
        return false 
    end
    
    local eased = 1 - math.pow(1 - progress, 3)
    
    for name, target in pairs(ent.DF_RelaxTargets) do
        local start = ent.DF_RelaxStartValues[name] or 0
        local val = Lerp(eased, start, target)
        self:SetFlex(ent, name, val)
    end
    
    return true
end

function DeathFaces:Think()
    if not self.Config.enabled then return end
    
    for i = #self.ActiveRagdolls, 1, -1 do
        local ent = self.ActiveRagdolls[i]
        
        if not IsValid(ent) then
            table.remove(self.ActiveRagdolls, i)
            continue
        end

        local keepAlive = false
        
        if ent.DeathFaceRelaxing then
            keepAlive = self:UpdateRelaxation(ent)
        elseif ent.DeathFaceData and ent.DeathFaceData.isAlive then
            keepAlive = self:AnimateFace(ent)
        end
        
        if not keepAlive then
            table.remove(self.ActiveRagdolls, i)
        end
    end
end

function DeathFaces:Activate(ragdoll, modifier)
    return self:Initialize(ragdoll, modifier)
end

function DeathFaces:Clear(ragdoll)
    if not IsValid(ragdoll) then return end
    for i = #self.ActiveRagdolls, 1, -1 do
        if self.ActiveRagdolls[i] == ragdoll then
            table.remove(self.ActiveRagdolls, i)
        end
    end
    ragdoll.DeathFaceData = nil
    ragdoll.DeathFaceRelaxing = nil
end

hook.Add("Think", "DeathFaces_MainLoop", function() 
    DeathFaces:Think() 
end)

_G.DeathFaces = DeathFaces

return DeathFaces