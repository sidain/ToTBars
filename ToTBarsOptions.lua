-- ToTBarsOptions.lua
-- Adds a settings panel under Interface (Game Menu) > AddOns > ToTBars,
-- using the same Settings API Blizzard's built-in addon options use.
-- Reads/writes the same ToTBarsDB config that the /totbars slash command
-- uses, so both stay in sync.

local ADDON_NAME, ns = ...

local FIELDS = {
    { key = "WIDTH",        label = "Bar Width" },
    { key = "HEIGHT",       label = "Bar Height" },
    { key = "X_OFFSET",     label = "X Offset" },
    { key = "Y_OFFSET",     label = "Y Offset" },
    { key = "TEXT_SIZE",    label = "Text Size" },
    { key = "TEXT_CLIP",    label = "Text Clip Width" },
    { key = "TEXT_GAP",     label = "Text Gap" },
    { key = "T_HEIGHT",     label = "Threat Bar Height" },
    { key = "PET_Y_OFFSET", label = "Pet Y Offset" },
    { key = "PET_SCALE",    label = "Pet Scale" },
    { key = "TARGET_X_OFFSET", label = "Target/Soft-Target X Offset" },
    { key = "TARGET_Y_OFFSET", label = "Target/Soft-Target Y Offset" },
}

local LIGHTEN_OPTIONS = {
    { text = "0%",  value = 0 },
    { text = "25%", value = 0.25 },
    { text = "50%", value = 0.5 },
    { text = "75%", value = 0.75 },
}

-- There's no Blizzard API exposing a general font-family picker to addons.
-- These are font files that ship with every client and are always safe to
-- reference by path.
local FONT_OPTIONS = {
    { text = "Friz Quadrata (Default)", value = "Fonts\\FRIZQT__.TTF" },
    { text = "Arial Narrow",            value = "Fonts\\ARIALN.TTF" },
    { text = "Skurri",                  value = "Fonts\\SKURRI.TTF" },
    { text = "Morpheus",                value = "Fonts\\MORPHEUS.TTF" },
}

local function FindLabel(options, value)
    for _, opt in ipairs(options) do
        if opt.value == value then
            return opt.text
        end
    end
    return options[1].text
end

local function InitDropdown(dd, options, getCurrent, onSelect)
    UIDropDownMenu_Initialize(dd, function(self, level)
        for _, opt in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.text
            info.value = opt.value
            info.checked = (getCurrent() == opt.value)
            info.func = function()
                onSelect(opt.value)
                UIDropDownMenu_SetSelectedValue(dd, opt.value)
                UIDropDownMenu_SetText(dd, opt.text)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end

local panel = CreateFrame("Frame")
panel.name = "ToTBars"

local registeredCategory

local editBoxes = {}
local testCheck
local lightenDropdown

local function ApplyAll()
    if ns.ApplyConfigToAll then
        ns.ApplyConfigToAll()
    end
end

local function BuildPanel()
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("ToTBars")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Target-of-target nameplate bar settings. Press Enter in a field to apply it.")

    testCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    testCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -16)
    testCheck.Text:SetText("Show test bar (preview)")
    testCheck:SetChecked(ToTBarsDB.TEST)
    testCheck:SetScript("OnClick", function(self)
        ToTBarsDB.TEST = self:GetChecked() and true or false
    end)

    local anchor = testCheck
    local firstRow = true
    for _, field in ipairs(FIELDS) do
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        -- Only the first row nudges +2 to line up under the checkbox text;
        -- every row after that anchors with a ZERO x offset to the row
        -- above so the left edge stays fixed instead of drifting further
        -- right each iteration (that +2-every-time was the recursive
        -- indent bug).
        local xOffset = firstRow and 2 or 0
        label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOffset, -18)
        label:SetText(field.label)
        firstRow = false

        local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        edit:SetSize(80, 20)
        edit:SetPoint("LEFT", label, "RIGHT", 16, 0)
        edit:SetAutoFocus(false)
        edit:SetText(tostring(ToTBarsDB[field.key]))

        edit:SetScript("OnEnterPressed", function(self)
            local num = tonumber(self:GetText())
            if num then
                ToTBarsDB[field.key] = num
                ApplyAll()
            else
                self:SetText(tostring(ToTBarsDB[field.key]))
            end
            self:ClearFocus()
        end)
        edit:SetScript("OnEscapePressed", function(self)
            self:SetText(tostring(ToTBarsDB[field.key]))
            self:ClearFocus()
        end)

        editBoxes[field.key] = edit
        anchor = label
    end

    do
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -18)
        label:SetText("Name Color Lighten")

        lightenDropdown = CreateFrame("Frame", "ToTBarsLightenDropdown", panel, "UIDropDownMenuTemplate")
        UIDropDownMenu_SetWidth(lightenDropdown, 90)
        -- UIDropDownMenuTemplate frames carry built-in left padding for
        -- their button art, so anchor from LEFT rather than TOPLEFT like
        -- the plain fontstring labels.
        lightenDropdown:SetPoint("LEFT", label, "RIGHT", 0, -2)
        InitDropdown(lightenDropdown, LIGHTEN_OPTIONS,
            function() return ToTBarsDB.CLASS_COLOR_LIGHTEN end,
            function(value)
                ToTBarsDB.CLASS_COLOR_LIGHTEN = value
                ApplyAll()
            end)
        UIDropDownMenu_SetText(lightenDropdown, FindLabel(LIGHTEN_OPTIONS, ToTBarsDB.CLASS_COLOR_LIGHTEN))

        -- Keep resetBtn anchored to the label (not the wider dropdown
        -- frame) so the left margin stays consistent with the rows above.
        anchor = label
    end

    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(140, 22)
    resetBtn:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -2, -34)
    resetBtn:SetText("Reset to Defaults")
    resetBtn:SetScript("OnClick", function()
        for k, v in pairs(ns.DEFAULTS) do
            ToTBarsDB[k] = v
        end
        testCheck:SetChecked(ToTBarsDB.TEST)
        for _, field in ipairs(FIELDS) do
            editBoxes[field.key]:SetText(tostring(ToTBarsDB[field.key]))
        end
        UIDropDownMenu_SetText(lightenDropdown, FindLabel(LIGHTEN_OPTIONS, ToTBarsDB.CLASS_COLOR_LIGHTEN))
        ApplyAll()
    end)
end

panel:SetScript("OnShow", function(self)
    if not self.built then
        BuildPanel()
        self.built = true
        return
    end
    -- Refresh displayed values in case /totbars changed something since
    -- the panel was last open.
    if testCheck then
        testCheck:SetChecked(ToTBarsDB.TEST)
    end
    if lightenDropdown then
        UIDropDownMenu_SetText(lightenDropdown, FindLabel(LIGHTEN_OPTIONS, ToTBarsDB.CLASS_COLOR_LIGHTEN))
    end
    for _, field in ipairs(FIELDS) do
        local edit = editBoxes[field.key]
        if edit and not edit:HasFocus() then
            edit:SetText(tostring(ToTBarsDB[field.key]))
        end
    end
end)

local function RegisterPanel()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        -- Do NOT overwrite category.ID - Blizzard assigns a real numeric ID
        -- here, and OpenToCategory() requires that number (or the category
        -- object itself), not the panel name. Overwriting it with a string
        -- is what caused the "outside of expected range" error.
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        registeredCategory = category
    elseif InterfaceOptions_AddCategory then
        -- Fallback for older clients without the modern Settings API.
        InterfaceOptions_AddCategory(panel)
    end
end

local function OpenPanel()
    if Settings and Settings.OpenToCategory and registeredCategory then
        -- This build's OpenToCategory wants the raw numeric category ID,
        -- not the category object itself (passing the object throws
        -- "outside of expected range" from OpenSettingsPanel).
        local id = registeredCategory.ID or (registeredCategory.GetID and registeredCategory:GetID())
        -- Blizzard quirk: the first call after login sometimes opens the
        -- options window without actually focusing the category, so call
        -- it twice.
        Settings.OpenToCategory(id)
        Settings.OpenToCategory(id)
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel.name)
        InterfaceOptionsFrame_OpenToCategory(panel.name)
    end
end

SLASH_TOTBARSCONFIG1 = "/tot"
SlashCmdList["TOTBARSCONFIG"] = OpenPanel

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == ADDON_NAME then
        RegisterPanel()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
