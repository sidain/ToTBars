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

local panel = CreateFrame("Frame")
panel.name = "ToTBars"

local registeredCategory

local editBoxes = {}
local testCheck

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

    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(140, 22)
    resetBtn:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -2, -22)
    resetBtn:SetText("Reset to Defaults")
    resetBtn:SetScript("OnClick", function()
        for k, v in pairs(ns.DEFAULTS) do
            ToTBarsDB[k] = v
        end
        testCheck:SetChecked(ToTBarsDB.TEST)
        for _, field in ipairs(FIELDS) do
            editBoxes[field.key]:SetText(tostring(ToTBarsDB[field.key]))
        end
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

SLASH_TOTBARSCONFIG1 = "/totb"
SlashCmdList["TOTBARSCONFIG"] = OpenPanel

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == ADDON_NAME then
        RegisterPanel()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
