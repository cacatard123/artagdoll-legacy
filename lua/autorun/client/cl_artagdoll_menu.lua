Artagdoll = Artagdoll or {}
Artagdoll.Menu = {}

local colors = Artagdoll.Config.Colors

local function CreateHelpSection(parent, title, icon, content)
    local section = vgui.Create("DPanel", parent)
    section:Dock(TOP)
    section:DockMargin(0, 0, 0, 10)
    section:SetTall(50)
    section.expanded = false
    section.targetHeight = 50
    
    section.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, colors.bg)
        if s.expanded then
            draw.RoundedBox(6, 0, 0, 3, h, colors.accent)
        end
    end
    
    local header = vgui.Create("DButton", section)
    header:Dock(TOP)
    header:SetTall(50)
    header:SetText("")
    header.hoverProgress = 0
    
    header.Paint = function(s, w, h)
        local target = s:IsHovered() and 1 or 0
        s.hoverProgress = Artagdoll.LerpNumber(s.hoverProgress, target, FrameTime() * 10)
        if s.hoverProgress > 0.01 then
            local col = ColorAlpha(colors.hover, s.hoverProgress * 100)
            draw.RoundedBox(6, 0, 0, w, h, col)
        end
        surface.SetDrawColor(colors.accent.r, colors.accent.g, colors.accent.b, 255)
        surface.SetMaterial(Material(icon))
        surface.DrawTexturedRect(15, h/2 - 8, 16, 16)
        draw.SimpleText(title, "DermaDefaultBold", 40, h/2, colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local arrow = section.expanded and "▼" or "▶"
        draw.SimpleText(arrow, "DermaDefault", w - 25, h/2, colors.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    header.DoClick = function()
        section.expanded = not section.expanded
        section.targetHeight = section.expanded and (50 + #content * 25 + 20) or 50
        surface.PlaySound("ui/buttonclick.wav")
    end
    
    local contentPanel = vgui.Create("DPanel", section)
    contentPanel:Dock(FILL)
    contentPanel:DockMargin(15, 5, 15, 10)
    contentPanel.Paint = function() end
    contentPanel:SetVisible(false)
    
    for _, line in ipairs(content) do
        local label = vgui.Create("DLabel", contentPanel)
        label:Dock(TOP)
        label:DockMargin(5, 2, 5, 2)
        label:SetFont("DermaDefault")
        label:SetTextColor(colors.description)
        label:SetText("• " .. line)
        label:SetWrap(true)
        label:SetAutoStretchVertical(true)
    end
    
    section.Think = function(s)
        local currentHeight = s:GetTall()
        s:SetTall(Artagdoll.LerpNumber(currentHeight, s.targetHeight, FrameTime() * 12))
        contentPanel:SetVisible(s.expanded)
    end
    
    return section
end

local function CreateHelpPanel()
    local panel = vgui.Create("DPanel")
    panel.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, colors.panel)
    end
    local title = vgui.Create("DLabel", panel)
    title:Dock(TOP)
    title:DockMargin(15, 15, 15, 5)
    title:SetFont("DermaLarge")
    title:SetTextColor(colors.text)
    title:SetText("Help & Setup Guide")
    title:SizeToContents()
    
    local scroll = vgui.Create("DScrollPanel", panel)
    scroll:Dock(FILL)
    scroll:DockMargin(15, 5, 15, 15)
    
    CreateHelpSection(scroll, "Quick Start Guide", "icon16/flag_green.png", {
        "1. Go to the 'Presets' tab and load the 'Normal' preset",
        "2. Spawn NPCs or ragdolls to see Artagdoll in action",
        "3. Experiment with different presets to find your style"
    })
    
    return panel
end

-- 2. PRESET PANEL
local function CreatePresetPanel()
    local panel = vgui.Create("DPanel")
    panel.Paint = function(_, w, h) draw.RoundedBox(8, 0, 0, w, h, colors.panel) end
    
    local title = vgui.Create("DLabel", panel)
    title:Dock(TOP)
    title:DockMargin(15, 15, 15, 5)
    title:SetFont("DermaLarge")
    title:SetTextColor(colors.text)
    title:SetText("Preset Manager")
    title:SizeToContents()
    
    local saveSection = vgui.Create("DPanel", panel)
    saveSection:Dock(TOP)
    saveSection:DockMargin(15, 5, 15, 10)
    saveSection:SetTall(80)
    saveSection.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, colors.bg)
        draw.RoundedBox(6, 0, 0, 3, h, colors.accent)
    end
    
    local saveLabel = vgui.Create("DLabel", saveSection)
    saveLabel:Dock(TOP)
    saveLabel:DockMargin(15, 10, 10, 5)
    saveLabel:SetFont("DermaDefaultBold")
    saveLabel:SetTextColor(colors.text)
    saveLabel:SetText("Save Current Settings as New Preset")
    saveLabel:SizeToContents()
    
    local saveContainer = vgui.Create("DPanel", saveSection)
    saveContainer:Dock(FILL)
    saveContainer:DockMargin(15, 5, 15, 10)
    saveContainer.Paint = function() end
    
    local presetNameEntry = vgui.Create("DTextEntry", saveContainer)
    presetNameEntry:Dock(LEFT)
    presetNameEntry:SetWide(220)
    presetNameEntry:SetPlaceholderText("Enter a name...")
    presetNameEntry:SetFont("DermaDefault")
    presetNameEntry:SetTextColor(colors.text)
    presetNameEntry.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, colors.unchecked)
        s:DrawTextEntryText(colors.text, colors.accent, colors.text)
    end
    
    local saveBtn = vgui.Create("DButton", saveContainer)
    saveBtn:Dock(FILL)
    saveBtn:DockMargin(10, 0, 0, 0)
    saveBtn:SetText("")
    saveBtn.hoverProgress = 0
    saveBtn.Paint = function(s, w, h)
        local target = s:IsHovered() and 1 or 0
        s.hoverProgress = Artagdoll.LerpNumber(s.hoverProgress, target, FrameTime() * 10)
        local bgCol = s.hoverProgress > 0.01 and Artagdoll.LerpColor(colors.preset, colors.presetHover, s.hoverProgress) or colors.preset
        draw.RoundedBox(6, 0, 0, w, h, bgCol)
        draw.SimpleText("Save Preset", "DermaDefaultBold", w/2, h/2, colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    saveBtn.DoClick = function()
        local name = presetNameEntry:GetValue()
        if name ~= "" then
            Artagdoll.Presets[name] = Artagdoll.System:GetCurrentSettings()
            Artagdoll.System:SavePresets()
            presetNameEntry:SetValue("")
            if IsValid(panel.presetList) then panel:RefreshPresetList() end
        end
    end
    
    local scroll = vgui.Create("DScrollPanel", panel)
    scroll:Dock(FILL)
    scroll:DockMargin(15, 0, 15, 15)
    panel.presetList = scroll
    
    function panel:RefreshPresetList()
        scroll:Clear()
        Artagdoll.System:LoadPresets()
        
        for presetName, _ in SortedPairs(Artagdoll.Presets) do
            local isDefault = Artagdoll.Config.DefaultPresets[presetName] ~= nil
            local presetItem = vgui.Create("DPanel", scroll)
            presetItem:Dock(TOP)
            presetItem:DockMargin(0, 0, 0, 6)
            presetItem:SetTall(45)
            presetItem.hoverProgress = 0
            
            presetItem.Paint = function(s, w, h)
                local target = s:IsHovered() and 1 or 0
                s.hoverProgress = Artagdoll.LerpNumber(s.hoverProgress, target, FrameTime() * 10)
                local bgCol = s.hoverProgress > 0.01 and Artagdoll.LerpColor(colors.bg, colors.hover, s.hoverProgress) or colors.bg
                draw.RoundedBox(6, 0, 0, w, h, bgCol)
                local iconText = isDefault and "⭐ " or " "
                draw.SimpleText(iconText .. presetName .. (isDefault and " (Built-in)" or ""), "DermaDefaultBold", 15, h/2, colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            
            local loadBtn = vgui.Create("DButton", presetItem)
            loadBtn:SetSize(100, 45)
            loadBtn:SetText("")
            loadBtn:Dock(RIGHT)
            loadBtn.Paint = function(s, w, h)
                local target = s:IsHovered() and 1 or 0
                local bgCol = target > 0 and colors.accentHover or colors.accent
                draw.RoundedBox(6, 5, 5, w-10, h-10, bgCol)
                draw.SimpleText("Load", "DermaDefaultBold", w/2, h/2, colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            loadBtn.DoClick = function() Artagdoll.System:ApplyPreset(presetName) end
            
            if not isDefault then
                local deleteBtn = vgui.Create("DButton", presetItem)
                deleteBtn:SetSize(100, 45)
                deleteBtn:SetText("")
                deleteBtn:Dock(RIGHT)
                deleteBtn.Paint = function(s, w, h)
                    local target = s:IsHovered() and 1 or 0
                    local bgCol = target > 0 and colors.presetDeleteHover or colors.presetDelete
                    draw.RoundedBox(6, 5, 5, w-10, h-10, bgCol)
                    draw.SimpleText("Delete", "DermaDefaultBold", w/2, h/2, colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                deleteBtn.DoClick = function()
                    Artagdoll.Presets[presetName] = nil
                    Artagdoll.System:SavePresets()
                    panel:RefreshPresetList()
                end
            end
        end
    end
    
    panel:RefreshPresetList()
    return panel
end

-- 3. SETTINGS COMPONENTS
local function CreateCategoryPanel(category)
    local panel = vgui.Create("DPanel")
    panel.Paint = function(_, w, h) draw.RoundedBox(8, 0, 0, w, h, colors.panel) end

    if category.description then
        local headerPanel = vgui.Create("DPanel", panel)
        headerPanel:Dock(TOP)
        headerPanel:DockMargin(10, 10, 10, 5)
        headerPanel:SetTall(30)
        headerPanel.Paint = function(_, w, h)
            draw.RoundedBox(6, 0, 0, w, h, colors.bg)
            draw.RoundedBox(6, 0, 0, 3, h, colors.accent)
        end
        local headerLabel = vgui.Create("DLabel", headerPanel)
        headerLabel:Dock(FILL)
        headerLabel:DockMargin(15, 5, 15, 5)
        headerLabel:SetFont("DermaDefault")
        headerLabel:SetTextColor(colors.description)
        headerLabel:SetText(category.description)
    end

    local scroll = vgui.Create("DScrollPanel", panel)
    scroll:Dock(FILL)
    scroll:DockMargin(10, 5, 10, 10)

    for _, setting in ipairs(category.settings) do
        local currentVal = Artagdoll.SafeGetConVar(setting.cvar, setting.default or 0)

        if setting.type == "space" then
            local spacer = vgui.Create("DPanel", scroll)
            spacer:Dock(TOP)
            spacer:SetTall(setting.size or 10)
            spacer.Paint = function() end

        elseif setting.type == "separator" then
            local hasDescription = setting.description and setting.description ~= ""
            local totalHeight = hasDescription and 50 or 25
            local separator = vgui.Create("DPanel", scroll)
            separator:Dock(TOP)
            separator:DockMargin(20, 8, 20, 5)
            separator:SetTall(totalHeight)
            separator.Paint = function(_, w, h)
                local lineY = hasDescription and 12 or h/2-1
                draw.RoundedBox(1, 0, lineY, w, 2, colors.separator)
                if setting.label then
                    surface.SetFont("DermaDefaultBold")
                    local tw, _ = surface.GetTextSize(setting.label)
                    local labelY = hasDescription and 2 or h/2 - 10
                    draw.RoundedBox(4, w/2 - tw/2 - 10, labelY, tw + 20, 20, colors.panel)
                    draw.SimpleText(setting.label, "DermaDefaultBold", w/2, labelY + 10, colors.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                if hasDescription then
                    draw.SimpleText(setting.description, "DermaDefault", w/2, 32, colors.description, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end

        elseif setting.type == "toggle" then
            local container = vgui.Create("DPanel", scroll)
            container:Dock(TOP)
            container:DockMargin(15, 0, 15, 6)
            container:SetTall(40)
            container.hoverProgress = 0
            container:SetTooltip(setting.help or "")

            container.Paint = function(s, w, h)
                local target = s:IsHovered() and 1 or 0
                s.hoverProgress = Artagdoll.LerpNumber(s.hoverProgress, target, FrameTime() * 10)
                if s.hoverProgress > 0.01 then
                    draw.RoundedBox(6, 0, 0, w, h, ColorAlpha(colors.hover, s.hoverProgress * 100))
                end
            end

            local checkbox = vgui.Create("DCheckBoxLabel", container)
            checkbox:Dock(FILL)
            checkbox:DockMargin(12, 0, 12, 0)
            checkbox:SetText(setting.label)
            checkbox:SetValue(tobool(currentVal))
            checkbox.Label:SetTextColor(colors.text)
            checkbox.Label:SetFont("DermaDefault")
            setting._checkbox = checkbox

            local button = checkbox.Button
            button.animProgress = checkbox:GetChecked() and 1 or 0
            button.hoverProgress = 0
            button.Paint = function(s, w, h)
                local target = checkbox:GetChecked() and 1 or 0
                s.animProgress = Artagdoll.LerpNumber(s.animProgress, target, FrameTime() * 12)
                local baseCol = colors.unchecked
                draw.RoundedBox(4, 0, 0, w, h, baseCol)
                if s.animProgress > 0.01 then
                    local innerSize = Artagdoll.LerpNumber(0, w - 4, s.animProgress)
                    local offset = (w - innerSize) / 2
                    draw.RoundedBox(4, offset, offset, innerSize, innerSize, colors.accent)
                end
            end
            
            button.DoClick = function()
                -- STOP ECHO if loading preset
                if Artagdoll.IsLoadingPreset then return end
                
                surface.PlaySound("ui/buttonclick.wav")
                local newVal = not checkbox:GetChecked()
                checkbox:SetValue(newVal)
                if net then
                    net.Start("ar_change_setting")
                    net.WriteString(setting.cvar)
                    net.WriteString("bool")
                    net.WriteFloat(newVal and 1 or 0)
                    net.SendToServer()
                end
                Artagdoll.System:SaveState()
            end

        elseif setting.type == "slider" then
            local container = vgui.Create("DPanel", scroll)
            container:Dock(TOP)
            container:DockMargin(15, 0, 15, 6)
            container:SetTall(50)
            container.hoverProgress = 0
            container:SetTooltip(setting.help or "")

            container.Paint = function(s, w, h)
                local target = s:IsHovered() and 1 or 0
                s.hoverProgress = Artagdoll.LerpNumber(s.hoverProgress, target, FrameTime() * 10)
                if s.hoverProgress > 0.01 then
                    draw.RoundedBox(6, 0, 0, w, h, ColorAlpha(colors.hover, s.hoverProgress * 80))
                end
            end

            local slider = vgui.Create("DNumSlider", container)
            slider:Dock(FILL)
            slider:DockMargin(12, 0, 12, 0)
            slider:SetText(setting.label)
            slider:SetMin(setting.min)
            slider:SetMax(setting.max)
            slider:SetDecimals(1)
            slider:SetValue(currentVal)
            slider.Label:SetTextColor(colors.text)
            slider.Label:SetFont("DermaDefault")
            slider.TextArea:SetTextColor(colors.text)
            setting._slider = slider

            if IsValid(slider.Slider) then
                slider.Slider.Paint = function(s, w, h)
                    draw.RoundedBox(4, 0, h / 2 - 3, w, 6, colors.unchecked)
                    local frac = (slider:GetValue() - setting.min) / (setting.max - setting.min)
                    draw.RoundedBox(4, 0, h / 2 - 3, w * frac, 6, colors.accent)
                end
            end
            
            slider.OnValueChanged = function(_, val)
                -- STOP ECHO if loading preset
                if Artagdoll.IsLoadingPreset then return end

                if net then
                    net.Start("ar_change_setting")
                    net.WriteString(setting.cvar)
                    net.WriteString("float")
                    net.WriteFloat(val)
                    net.SendToServer()
                end
            end
        end
    end
    
    local resetContainer = vgui.Create("DPanel", scroll)
    resetContainer:Dock(TOP)
    resetContainer:DockMargin(15, 15, 15, 10)
    resetContainer:SetTall(45)
    resetContainer.Paint = function() end
    
    local resetButton = vgui.Create("DButton", resetContainer)
    resetButton:Dock(FILL)
    resetButton:SetText("")
    resetButton.hoverProgress = 0
    resetButton.Paint = function(s, w, h)
        local target = s:IsHovered() and 1 or 0
        s.hoverProgress = Artagdoll.LerpNumber(s.hoverProgress, target, FrameTime() * 10)
        local bgCol = s.hoverProgress > 0.01 and Artagdoll.LerpColor(colors.reset, colors.resetHover, s.hoverProgress) or colors.reset
        draw.RoundedBox(6, 0, 0, w, h, bgCol)
        draw.SimpleText("Reset to Defaults", "DermaDefaultBold", w/2, h/2, colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    resetButton.DoClick = function()
        surface.PlaySound("ui/buttonclick.wav")
        -- We can just rely on the existing ApplyTable Logic for resetting!
        -- It's cleaner.
        local defaultTable = {}
        for _, setting in ipairs(category.settings) do
            if setting.cvar and setting.default then
                defaultTable[setting.cvar] = setting.default
            end
        end
        -- Use the system function to apply defaults instantly
        Artagdoll.System:ApplyTable(defaultTable)
        Artagdoll.System:SaveState()
    end
    
    return panel
end

-- 4. MAIN MENU
function Artagdoll.Menu:Open()
    if IsValid(self.Frame) then self.Frame:Remove() end
    
    Artagdoll.System:LoadPresets()
    
    local frame = vgui.Create("DFrame")
    frame:SetSize(600, 650)
    frame:Center()
    frame:SetTitle("Artagdoll Settings  |  Early-Access")
    frame:MakePopup()
    self.Frame = frame
    
    frame.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, colors.bg)
        draw.RoundedBox(0, 0, 0, w, 24, colors.panel)
        surface.SetDrawColor(colors.accent.r, colors.accent.g, colors.accent.b, 80)
        surface.DrawRect(0, 24, w, 2)
    end
    
    timer.Simple(0, function()
        if IsValid(frame) and IsValid(frame.CloseButton) then
            frame.CloseButton.hoverProgress = 0
            frame.CloseButton.Paint = function(s, w, h)
                local target = s:IsHovered() and 1 or 0
                s.hoverProgress = Artagdoll.LerpNumber(s.hoverProgress, target, FrameTime() * 10)
                if s.hoverProgress > 0.01 then
                    local col = ColorAlpha(Color(200, 60, 60), s.hoverProgress * 200)
                    draw.RoundedBox(4, 2, 2, w-4, h-4, col)
                end
                draw.SimpleText("✕", "DermaLarge", w/2, h/2 - 1, colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end)
    
    frame.OnClose = function()
        Artagdoll.System:SaveState()
    end

    local sheet = vgui.Create("DPropertySheet", frame)
    sheet:Dock(FILL)
    sheet:SetPadding(8)
    sheet.Paint = function() end

    local function PaintTab(tab)
        tab.hoverProgress = 0
        tab.Paint = function(s, w, h)
            local target = s:IsHovered() and 1 or 0
            s.hoverProgress = Artagdoll.LerpNumber(s.hoverProgress, target, FrameTime() * 10)
            
            if s:GetPropertySheet():GetActiveTab() == s then
                draw.RoundedBox(4, 0, 0, w, h, colors.accent)
            elseif s.hoverProgress > 0.01 then
                local col = Artagdoll.LerpColor(colors.panel, colors.hover, s.hoverProgress)
                draw.RoundedBox(4, 0, 0, w, h, col)
            else
                draw.RoundedBox(4, 0, 0, w, h, colors.panel)
            end
        end
    end

    for _, cat in ipairs(Artagdoll.Config.Categories) do
        local catPanel = CreateCategoryPanel(cat)
        local tab = sheet:AddSheet(cat.name, catPanel, cat.icon)
        if IsValid(tab.Tab) then PaintTab(tab.Tab) end
    end

    local presetPanel = CreatePresetPanel()
    local pTab = sheet:AddSheet("Presets", presetPanel, "icon16/disk.png")
    if IsValid(pTab.Tab) then PaintTab(pTab.Tab) end

    local helpPanel = CreateHelpPanel()
    local hTab = sheet:AddSheet("Help", helpPanel, "icon16/help.png")
    if IsValid(hTab.Tab) then PaintTab(hTab.Tab) end
end

hook.Add("PopulateToolMenu", "ArtagdollSettingsMenu", function()
    if spawnmenu then
        spawnmenu.AddToolMenuOption("Artagdoll", "Settings", "ArtagdollSettings", "Settings", "", "", function(panel)
            panel:ClearControls()
            panel:Help("Configure your Artagdoll addon settings")
            local btn = panel:Button("Open Settings Menu")
            btn.DoClick = function() Artagdoll.Menu:Open() end
        end)
    end
end)