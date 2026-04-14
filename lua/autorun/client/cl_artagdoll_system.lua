Artagdoll = Artagdoll or {}
Artagdoll.System = {}
Artagdoll.Presets = {}
Artagdoll.IsLoadingPreset = false

local PRESET_FILE = "artagdoll_presets.json"
local STATE_FILE = "artagdoll_last_state.json"

function Artagdoll.LerpNumber(a, b, t) return a + (b - a) * t end
function Artagdoll.LerpColor(a, b, t)
    return Color(
        Artagdoll.LerpNumber(a.r, b.r, t),
        Artagdoll.LerpNumber(a.g, b.g, t),
        Artagdoll.LerpNumber(a.b, b.b, t),
        Artagdoll.LerpNumber(a.a or 255, b.a or 255, t)
    )
end

function Artagdoll.SafeGetConVar(cvar, default)
    if not cvar then return default end
    local cv = GetConVar(cvar)
    if not cv then return default end
    return cv:GetFloat() or default
end

function Artagdoll.System:LoadPresets()
    if file.Exists(PRESET_FILE, "DATA") then
        local saved = file.Read(PRESET_FILE, "DATA")
        local success, result = pcall(util.JSONToTable, saved)
        Artagdoll.Presets = success and result or {}
    else
        Artagdoll.Presets = {}
        for name, preset in pairs(Artagdoll.Config.DefaultPresets) do
            Artagdoll.Presets[name] = table.Copy(preset)
        end
        self:SavePresets()
    end
end

function Artagdoll.System:SavePresets()
    local success, json = pcall(util.TableToJSON, Artagdoll.Presets, true)
    if success and json then
        file.Write(PRESET_FILE, json)
    end
end

function Artagdoll.System:GetCurrentSettings()
    local current = {}
    for _, cat in ipairs(Artagdoll.Config.Categories) do
        for _, setting in ipairs(cat.settings) do
            if setting.cvar then
                current[setting.cvar] = Artagdoll.SafeGetConVar(setting.cvar, setting.default)
            end
        end
    end
    return current
end

function Artagdoll.System:SaveState()
    if Artagdoll.IsLoadingPreset then return end
    local state = self:GetCurrentSettings()
    file.Write(STATE_FILE, util.TableToJSON(state))
end

function Artagdoll.System:LoadState()
    if not file.Exists(STATE_FILE, "DATA") then 
        self:ApplyPreset("Normal")
        return 
    end

    local json = file.Read(STATE_FILE, "DATA")
    local state = util.JSONToTable(json)
    
    if state then
        self:ApplyTable(state)
        print("[Artagdoll] Settings restored.")
    end
end

function Artagdoll.System:ApplyTable(tbl)
    Artagdoll.IsLoadingPreset = true
    
    for cvarName, value in pairs(tbl) do
        if net then
            net.Start("ar_change_setting")
            net.WriteString(cvarName)
            net.WriteString("float")
            net.WriteFloat(value)
            net.SendToServer()
        end
        
        RunConsoleCommand(cvarName, tostring(value))
        for _, cat in ipairs(Artagdoll.Config.Categories) do
            for _, setting in ipairs(cat.settings) do
                if setting.cvar == cvarName then
                    if setting.type == "toggle" and IsValid(setting._checkbox) then
                        setting._checkbox:SetValue(tobool(value))
                        if IsValid(setting._checkbox.Button) then
                            setting._checkbox.Button.animProgress = tobool(value) and 1 or 0
                        end
                    elseif setting.type == "slider" and IsValid(setting._slider) then
                        setting._slider:SetValue(value)
                    end
                end
            end
        end
    end
    
    Artagdoll.IsLoadingPreset = false
end

function Artagdoll.System:ApplyPreset(presetName)
    local preset = Artagdoll.Presets[presetName]
    if not preset then preset = Artagdoll.Config.DefaultPresets[presetName] end
    if not preset then return end
    
    self:ApplyTable(preset)
    self:SaveState()
    
    if surface then surface.PlaySound("ui/buttonclickrelease.wav") end
    if chat then chat.AddText(Color(100, 200, 140), "[Artagdoll] ", color_white, "Applied preset: " .. presetName) end
end

hook.Add("InitPostEntity", "Artagdoll_LoadState", function()
    Artagdoll.System:LoadPresets()
    timer.Simple(2, function() Artagdoll.System:LoadState() end)
end)

hook.Add("ShutDown", "Artagdoll_SaveState", function()
    Artagdoll.System:SaveState()
end)