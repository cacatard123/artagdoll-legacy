local AnimatedHands = {}

AnimatedHands.Poses = {

    ["Lflat"] = {
        ["ValveBiped.Bip01_L_Finger4"]  = Angle(-20, 27, 0),
        ["ValveBiped.Bip01_L_Finger41"] = Angle(0, 8, 0),
        ["ValveBiped.Bip01_L_Finger42"] = Angle(0, 29, 0),

        ["ValveBiped.Bip01_L_Finger3"]  = Angle(-8, 12.5, 0),
        ["ValveBiped.Bip01_L_Finger31"] = Angle(0, 39, 0),
        ["ValveBiped.Bip01_L_Finger32"] = Angle(0, 25, 0),

        ["ValveBiped.Bip01_L_Finger2"]  = Angle(0, 22, 0),
        ["ValveBiped.Bip01_L_Finger21"] = Angle(0, -22, 0),
        ["ValveBiped.Bip01_L_Finger22"] = Angle(0, 12, 0),

        ["ValveBiped.Bip01_L_Finger1"]  = Angle(2, 24, 0),
        ["ValveBiped.Bip01_L_Finger11"] = Angle(0, -16, 0),
        ["ValveBiped.Bip01_L_Finger12"] = Angle(0, -12, 0),

        ["ValveBiped.Bip01_L_Finger0"]  = Angle(-8, -12, 0),
        ["ValveBiped.Bip01_L_Finger01"] = Angle(12, 14, 0),
        ["ValveBiped.Bip01_L_Finger02"] = Angle(-24, -8, 0)
    },

    ["Rflat"] = {
        ["ValveBiped.Bip01_R_Finger4"]  = Angle(-20, 27, 0),
        ["ValveBiped.Bip01_R_Finger41"] = Angle(0, 8, 0),
        ["ValveBiped.Bip01_R_Finger42"] = Angle(0, 29, 0),

        ["ValveBiped.Bip01_R_Finger3"]  = Angle(-8, 12.5, 0),
        ["ValveBiped.Bip01_R_Finger31"] = Angle(0, 39, 0),
        ["ValveBiped.Bip01_R_Finger32"] = Angle(0, 25, 0),

        ["ValveBiped.Bip01_R_Finger2"]  = Angle(0, 22, 0),
        ["ValveBiped.Bip01_R_Finger21"] = Angle(0, -22, 0),
        ["ValveBiped.Bip01_R_Finger22"] = Angle(0, 12, 0),

        ["ValveBiped.Bip01_R_Finger1"]  = Angle(2, 24, 0),
        ["ValveBiped.Bip01_R_Finger11"] = Angle(0, -16, 0),
        ["ValveBiped.Bip01_R_Finger12"] = Angle(0, -12, 0),

        ["ValveBiped.Bip01_R_Finger0"]  = Angle(-8, -12, 0),
        ["ValveBiped.Bip01_R_Finger01"] = Angle(12, 14, 0),
        ["ValveBiped.Bip01_R_Finger02"] = Angle(-24, -8, 0)
    },

    ["Lrelaxed"] = {
        ["ValveBiped.Bip01_L_Finger4"]  = Angle(-6, 12, 0),
        ["ValveBiped.Bip01_L_Finger41"] = Angle(0, 18, 0),
        ["ValveBiped.Bip01_L_Finger42"] = Angle(0, 10, 0),

        ["ValveBiped.Bip01_L_Finger3"]  = Angle(-4, 10, 0),
        ["ValveBiped.Bip01_L_Finger31"] = Angle(0, 20, 0),
        ["ValveBiped.Bip01_L_Finger32"] = Angle(0, 12, 0),

        ["ValveBiped.Bip01_L_Finger2"]  = Angle(-2, 14, 0),
        ["ValveBiped.Bip01_L_Finger21"] = Angle(0, 22, 0),
        ["ValveBiped.Bip01_L_Finger22"] = Angle(0, 10, 0),

        ["ValveBiped.Bip01_L_Finger1"]  = Angle(-1, 10, 0),
        ["ValveBiped.Bip01_L_Finger11"] = Angle(0, 16, 0),
        ["ValveBiped.Bip01_L_Finger12"] = Angle(0, 12, 0),

        ["ValveBiped.Bip01_L_Finger0"]  = Angle(4, 12, 0),
        ["ValveBiped.Bip01_L_Finger01"] = Angle(-6, 18, 0),
        ["ValveBiped.Bip01_L_Finger02"] = Angle(2, 10, 0)
    },

    ["Rrelaxed"] = {
        ["ValveBiped.Bip01_R_Finger4"]  = Angle(-6, -12, 0),
        ["ValveBiped.Bip01_R_Finger41"] = Angle(0, -18, 0),
        ["ValveBiped.Bip01_R_Finger42"] = Angle(0, -10, 0),

        ["ValveBiped.Bip01_R_Finger3"]  = Angle(-4, -10, 0),
        ["ValveBiped.Bip01_R_Finger31"] = Angle(0, -20, 0),
        ["ValveBiped.Bip01_R_Finger32"] = Angle(0, -12, 0),

        ["ValveBiped.Bip01_R_Finger2"]  = Angle(-2, -14, 0),
        ["ValveBiped.Bip01_R_Finger21"] = Angle(0, -22, 0),
        ["ValveBiped.Bip01_R_Finger22"] = Angle(0, -10, 0),

        ["ValveBiped.Bip01_R_Finger1"]  = Angle(-1, -10, 0),
        ["ValveBiped.Bip01_R_Finger11"] = Angle(0, -16, 0),
        ["ValveBiped.Bip01_R_Finger12"] = Angle(0, -12, 0),

        ["ValveBiped.Bip01_R_Finger0"]  = Angle(4, -12, 0),
        ["ValveBiped.Bip01_R_Finger01"] = Angle(-6, -18, 0),
        ["ValveBiped.Bip01_R_Finger02"] = Angle(2, -10, 0)
    },

    ["Ltense"] = {
        ["ValveBiped.Bip01_L_Finger4"]  = Angle(-20, 27, 0),
        ["ValveBiped.Bip01_L_Finger41"] = Angle(0, 8, 0),
        ["ValveBiped.Bip01_L_Finger42"] = Angle(0, 29, 0),

        ["ValveBiped.Bip01_L_Finger3"]  = Angle(-8, 12.5, 0),
        ["ValveBiped.Bip01_L_Finger31"] = Angle(0, 39, 0),
        ["ValveBiped.Bip01_L_Finger32"] = Angle(0, 25, 0),

        ["ValveBiped.Bip01_L_Finger2"]  = Angle(-6, 14, 0),
        ["ValveBiped.Bip01_L_Finger21"] = Angle(0, -36, 0),
        ["ValveBiped.Bip01_L_Finger22"] = Angle(0, -50, 0),

        ["ValveBiped.Bip01_L_Finger1"]  = Angle(6, -6, 0),
        ["ValveBiped.Bip01_L_Finger11"] = Angle(0, 2, 0),
        ["ValveBiped.Bip01_L_Finger12"] = Angle(0, -50, 0),

        ["ValveBiped.Bip01_L_Finger0"]  = Angle(-24, 10, 0),
        ["ValveBiped.Bip01_L_Finger01"] = Angle(-10, -8, 0),
        ["ValveBiped.Bip01_L_Finger02"] = Angle(28, 50, 0)
    },

    ["Rtense"] = {
        ["ValveBiped.Bip01_R_Finger4"]  = Angle(-20, 27, 0),
        ["ValveBiped.Bip01_R_Finger41"] = Angle(0, 8, 0),
        ["ValveBiped.Bip01_R_Finger42"] = Angle(0, 29, 0),

        ["ValveBiped.Bip01_R_Finger3"]  = Angle(-8, 12.5, 0),
        ["ValveBiped.Bip01_R_Finger31"] = Angle(0, 39, 0),
        ["ValveBiped.Bip01_R_Finger32"] = Angle(0, 25, 0),

        ["ValveBiped.Bip01_R_Finger2"]  = Angle(-6, 14, 0),
        ["ValveBiped.Bip01_R_Finger21"] = Angle(0, -36, 0),
        ["ValveBiped.Bip01_R_Finger22"] = Angle(0, -50, 0),

        ["ValveBiped.Bip01_R_Finger1"]  = Angle(6, -6, 0),
        ["ValveBiped.Bip01_R_Finger11"] = Angle(0, 2, 0),
        ["ValveBiped.Bip01_R_Finger12"] = Angle(0, -50, 0),

        ["ValveBiped.Bip01_R_Finger0"]  = Angle(-24, 10, 0),
        ["ValveBiped.Bip01_R_Finger01"] = Angle(-10, -8, 0),
        ["ValveBiped.Bip01_R_Finger02"] = Angle(28, 50, 0)
    },

    ["Lfist"] = {
        ["ValveBiped.Bip01_L_Finger2"]  = Angle(12, -46, 0),
        ["ValveBiped.Bip01_L_Finger21"] = Angle(0, -18, 0),
        ["ValveBiped.Bip01_L_Finger22"] = Angle(0, -50, 0),

        ["ValveBiped.Bip01_L_Finger1"]  = Angle(2, -50, 0),
        ["ValveBiped.Bip01_L_Finger11"] = Angle(0, -32, 0),
        ["ValveBiped.Bip01_L_Finger12"] = Angle(0, -50, 0),

        ["ValveBiped.Bip01_L_Finger0"]  = Angle(12, 22, 0),
        ["ValveBiped.Bip01_L_Finger01"] = Angle(-28, 42, 0),
        ["ValveBiped.Bip01_L_Finger02"] = Angle(6, 26, 0)
    },

    ["Rfist"] = {
        ["ValveBiped.Bip01_R_Finger2"]  = Angle(12, -46, 0),
        ["ValveBiped.Bip01_R_Finger21"] = Angle(0, -18, 0),
        ["ValveBiped.Bip01_R_Finger22"] = Angle(0, -50, 0),

        ["ValveBiped.Bip01_R_Finger1"]  = Angle(2, -50, 0),
        ["ValveBiped.Bip01_R_Finger11"] = Angle(0, -32, 0),
        ["ValveBiped.Bip01_R_Finger12"] = Angle(0, -50, 0),

        ["ValveBiped.Bip01_R_Finger0"]  = Angle(12, 22, 0),
        ["ValveBiped.Bip01_R_Finger01"] = Angle(-28, 42, 0),
        ["ValveBiped.Bip01_R_Finger02"] = Angle(6, 26, 0)
    }
}

AnimatedHands.CurlStages = {
    "flat",
    "relaxed",
    "tense",
    "fist",
    "tense",
    "relaxed",
}

AnimatedHands.Active = {}

function AnimatedHands:AddEntity(ent)
    if not IsValid(ent) then return end

    AnimatedHands.Active[ent] = {
        Stage = 1,
        Progress = 0,
        Speed = 0.65,
        NoiseFreq = math.Rand(1.7, 2),
        NoiseAmp = 2.3,

        WaitTime = math.Rand(0.2, 0.25),

        L_old = AnimatedHands.Poses["Lflat"],
        R_old = AnimatedHands.Poses["Rflat"],

        L_new = AnimatedHands.Poses["Lrelaxed"],
        R_new = AnimatedHands.Poses["Rrelaxed"],
    }
end

function AnimatedHands:RemoveEntity(ent)
    if AnimatedHands.Active[ent] then
        AnimatedHands.Active[ent] = nil
    end
end

local function Ease(t)
    return math.ease.InOutSine(math.Clamp(t, 0, 1))
end

hook.Add("Think", "AnimatedHands_CurlSystem", function()
    local dt = FrameTime()
    local ct = CurTime()

    for ent, data in pairs(AnimatedHands.Active) do
        if not IsValid(ent) then AnimatedHands.Active[ent] = nil continue end

        data.Progress = data.Progress + dt * data.Speed

        if data.Progress >= (1 + data.WaitTime) then
            
            data.Stage = data.Stage + 1
            if data.Stage > #AnimatedHands.CurlStages then
                data.Stage = 1
            end

            local stag = AnimatedHands.CurlStages[data.Stage]

            data.L_old = data.L_new
            data.R_old = data.R_new

            data.L_new = AnimatedHands.Poses["L" .. stag]
            data.R_new = AnimatedHands.Poses["R" .. stag]

            data.Progress = 0
            data.WaitTime = math.Rand(0.2, 0.4)
        end

        local t = Ease(data.Progress)
        
        for boneName, newAng in pairs(data.L_new) do
            local id = ent:LookupBone(boneName)
            if not id then continue end

            local oldAng = data.L_old[boneName] or Angle(0, 0, 0)
            local blended = LerpAngle(t, oldAng, newAng)

            local noise = math.sin(ct * data.NoiseFreq + (id * 0.3)) * data.NoiseAmp

            blended.p = blended.p + noise * 1
            blended.y = blended.y + noise * 0.5

            ent:ManipulateBoneAngles(id, blended)
        end

        for boneName, newAng in pairs(data.R_new) do
            local id = ent:LookupBone(boneName)
            if not id then continue end

            local oldAng = data.R_old[boneName] or Angle(0, 0, 0)
            local blended = LerpAngle(t, oldAng, newAng)

            local noise = math.sin(ct * data.NoiseFreq + (id * 0.3)) * data.NoiseAmp

            blended.p = blended.p + noise * 1
            blended.y = blended.y - noise * 0.5

            ent:ManipulateBoneAngles(id, blended)
        end
    end
end)

return AnimatedHands