-- ToTBars.lua
-- Standalone target-of-target nameplate bars. No Plater required.
-- Replaces the Plater "hook mod" lifecycle (Nameplate Added / Nameplate Updated /
-- Destructor / Mod Option Changed / Initialization) with native nameplate events
-- and a SavedVariables config, driven by ToTTracker.lua's data tables.

local ADDON_NAME = ...

------------------------------------------------------------
-- Config (was modTable.config / the Plater options panel)
------------------------------------------------------------
local DEFAULTS = {
    WIDTH        = 120,
    HEIGHT       = 16,
    X_OFFSET     = 0,
    Y_OFFSET     = 12,
    TEXT_SIZE    = 12,
    TEXT_CLIP    = 100,
    TEXT_GAP     = 0,
    T_HEIGHT     = 1,
    PET_Y_OFFSET = -100,
    PET_SCALE    = 0.9,
    TEST         = false,
}

ToTBarsDB = ToTBarsDB or {}

local function InitDB()
    for k, v in pairs(DEFAULTS) do
        if ToTBarsDB[k] == nil then
            ToTBarsDB[k] = v
        end
    end
end

------------------------------------------------------------
-- State (was Plater's ToTBars / ToTAllContainers globals)
------------------------------------------------------------
local ToTBars = {}          -- unitId -> bar table
local ToTAllContainers = {} -- flat list, just for a hard cleanup on init

------------------------------------------------------------
-- Helpers
------------------------------------------------------------

-- Plater passed its own plate frame in as "self". Without Plater we get the
-- unit token from NAME_PLATE_UNIT_ADDED and look the plate up ourselves, then
-- anchor to the healthbar if the default Blizzard nameplate layout exposes
-- one, otherwise fall back to the UnitFrame, otherwise the plate itself.
local function GetAnchorFrame(plate)
    if plate.UnitFrame then
        if plate.UnitFrame.healthBar then
            return plate.UnitFrame.healthBar
        end
        return plate.UnitFrame
    end
    return plate
end

local function ApplyPosition(t)
    local cfg = ToTBarsDB
    local ox  = cfg.X_OFFSET
    local oy  = cfg.Y_OFFSET
    local oy2 = t.isPet and (oy + cfg.PET_Y_OFFSET) or oy
    t.container:ClearAllPoints()
    t.container:SetPoint("TOP", t.anchor, "BOTTOM", ox, oy2)
end

local function ApplySize(t)
    local cfg = ToTBarsDB
    local scale = t.isPet and cfg.PET_SCALE or 1.0

    local bw2 = math.floor(cfg.WIDTH * scale)
    local bh2 = math.floor(cfg.HEIGHT * scale)
    local ts2 = math.floor(cfg.TEXT_SIZE * scale)
    local th2 = math.floor(cfg.T_HEIGHT * scale)

    t.container:SetSize(bw2, ts2 + 4 + bh2 + th2 + 4)
    t.hpBarAnchor:SetSize(bw2, bh2)
    t.threatBar:SetSize(bw2, th2)
    t.nameText:SetWidth(math.min(bw2 - 20, cfg.TEXT_CLIP))
    t.nameText:SetFont(STANDARD_TEXT_FONT, ts2, "OUTLINE")
    t.hpBarAnchor:ClearAllPoints()
    t.hpBarAnchor:SetPoint("TOPLEFT", t.container, "TOPLEFT", 0, 0)
    t.nameText:ClearAllPoints()
    t.nameText:SetPoint("BOTTOMLEFT", t.hpBarAnchor, "TOPLEFT", 0, cfg.TEXT_GAP)
    t.threatBar:ClearAllPoints()
    t.threatBar:SetPoint("TOPLEFT", t.hpBarAnchor, "BOTTOMLEFT", 0, -2)

    t._bw2, t._bh2 = bw2, bh2
end

local function SetBorder(t, r, g, b, a)
    t.bTop:SetColorTexture(r, g, b, a)
    t.bBot:SetColorTexture(r, g, b, a)
    t.bLeft:SetColorTexture(r, g, b, a)
    t.bRight:SetColorTexture(r, g, b, a)
end

------------------------------------------------------------
-- Bar creation (was the "Nameplate Added" hook body)
------------------------------------------------------------
local function CreateBar(unitId, plate)
    if ToTBars[unitId] then return end

    if ToTTrackerRefresh then ToTTrackerRefresh(unitId) end

    local isPet = UnitIsUnit(unitId, "pet")
    local frameLevel    = isPet and 190 or 200
    local frameLevelBar = isPet and 191 or 201

    local container = CreateFrame("Frame", nil, WorldFrame)
    container:SetFrameStrata("TOOLTIP")
    container:SetFrameLevel(frameLevel)
    container:Show()
    ToTAllContainers[#ToTAllContainers + 1] = container

    local hpBarAnchor = CreateFrame("Frame", nil, container)
    hpBarAnchor:SetFrameLevel(frameLevelBar)
    local hpBg = hpBarAnchor:CreateTexture(nil, "BACKGROUND")
    hpBg:SetAllPoints()
    hpBg:SetColorTexture(0, 0, 0, 0.7)
    hpBarAnchor:Hide()

    local bTop   = hpBarAnchor:CreateTexture(nil, "OVERLAY")
    local bBot   = hpBarAnchor:CreateTexture(nil, "OVERLAY")
    local bLeft  = hpBarAnchor:CreateTexture(nil, "OVERLAY")
    local bRight = hpBarAnchor:CreateTexture(nil, "OVERLAY")
    for _, l in ipairs({ bTop, bBot, bLeft, bRight }) do
        l:SetTexture("Interface\\Buttons\\WHITE8X8")
        l:SetColorTexture(0.3, 0.3, 0.3, 1)
    end
    bTop:SetPoint("TOPLEFT", hpBarAnchor, "TOPLEFT", -1, 1)
    bTop:SetPoint("TOPRIGHT", hpBarAnchor, "TOPRIGHT", 1, 1)
    bTop:SetHeight(1)
    bBot:SetPoint("BOTTOMLEFT", hpBarAnchor, "BOTTOMLEFT", -1, -1)
    bBot:SetPoint("BOTTOMRIGHT", hpBarAnchor, "BOTTOMRIGHT", 1, -1)
    bBot:SetHeight(1)
    bLeft:SetPoint("TOPLEFT", hpBarAnchor, "TOPLEFT", -1, 1)
    bLeft:SetPoint("BOTTOMLEFT", hpBarAnchor, "BOTTOMLEFT", -1, -1)
    bLeft:SetWidth(1)
    bRight:SetPoint("TOPRIGHT", hpBarAnchor, "TOPRIGHT", 1, 1)
    bRight:SetPoint("BOTTOMRIGHT", hpBarAnchor, "BOTTOMRIGHT", 1, -1)
    bRight:SetWidth(1)

    local nameText = container:CreateFontString(nil, "OVERLAY")
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetText("")
    nameText:SetAlpha(0)
    nameText:SetTextColor(1, 1, 1)

    local threatBar = CreateFrame("StatusBar", nil, container)
    threatBar:SetFrameLevel(frameLevelBar)
    local threatTex = threatBar:CreateTexture(nil, "ARTWORK")
    threatTex:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    threatTex:SetAllPoints()
    threatBar:SetStatusBarTexture(threatTex)
    threatBar:SetMinMaxValues(0, 100)
    threatBar:SetValue(0)
    threatBar:SetStatusBarColor(0.9, 0.1, 0.1)
    local threatBg = threatBar:CreateTexture(nil, "BACKGROUND")
    threatBg:SetAllPoints()
    threatBg:SetColorTexture(0, 0, 0, 0.5)
    threatBar:Hide()

    local t = {
        container   = container,
        hpBarAnchor = hpBarAnchor,
        nameText    = nameText,
        threatBar   = threatBar,
        bTop = bTop, bBot = bBot, bLeft = bLeft, bRight = bRight,
        isPet       = isPet,
        anchor      = GetAnchorFrame(plate),
        active      = true,
        lastHpBar   = nil,
    }
    ToTBars[unitId] = t

    ApplySize(t)
    ApplyPosition(t)

    C_Timer.After(0, function()
        if not t.active then return end
        local elapsed = 0
        container:SetScript("OnUpdate", function(c, dt)
            if not t.active then
                c:SetScript("OnUpdate", nil)
                c:Hide()
                return
            end

            if not UnitExists(unitId) then
                t.active = false
                c:SetScript("OnUpdate", nil)
                c:Hide()
                ToTBars[unitId] = nil
                return
            end

            elapsed = elapsed + dt
            if elapsed < 0.1 then return end
            elapsed = 0

            local cfg = ToTBarsDB
            local totName = nil

            if cfg.TEST then
                totName = "Test Target"
            elseif InCombatLockdown() then
                totName = ToTTargetsByToken and ToTTargetsByToken[unitId]
            end

            if totName then
                nameText:SetAlpha(1)
                hpBarAnchor:Show()

                local hpBar = ToTTargetHPBarByToken and ToTTargetHPBarByToken[unitId]
                if hpBar ~= t.lastHpBar then
                    if t.lastHpBar then
                        t.lastHpBar:ClearAllPoints()
                        t.lastHpBar:SetParent(UIParent)
                        t.lastHpBar:Hide()
                    end
                    t.lastHpBar = hpBar
                end
                if hpBar then
                    hpBar:SetParent(container)
                    hpBar:SetFrameStrata("TOOLTIP")
                    hpBar:SetFrameLevel(frameLevelBar)
                    hpBar:SetSize(t._bw2, t._bh2)
                    hpBar:ClearAllPoints()
                    hpBar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
                    hpBar:Show()
                end

                if cfg.TEST then
                    nameText:SetText("80 Test Target")
                    nameText:SetTextColor(1, 1, 1)
                    if hpBar then
                        hpBar:SetMinMaxValues(0, 100)
                        hpBar:SetValue(60)
                        hpBar:SetStatusBarColor(0.8, 0.1, 0.1)
                    end
                    SetBorder(t, 0.5, 0.8, 1, 1)
                    threatBar:Show()
                    threatBar:SetValue(75)
                else
                    local lvl           = ToTTargetLevelByToken and ToTTargetLevelByToken[unitId] or 0
                    local class         = ToTTargetClassByToken and ToTTargetClassByToken[unitId]
                    local isLocalPlayer = ToTTargetIsLocalPlayerByToken and ToTTargetIsLocalPlayerByToken[unitId] == 1
                    local threatVal     = ToTThreat and ToTThreat[unitId] or 0

                    local lvlStr = (lvl > 0) and tostring(lvl) or "??"
                    nameText:SetText(lvlStr .. " " .. totName)

                    if class and class ~= "" then
                        local color = RAID_CLASS_COLORS[class]
                        if color then
                            nameText:SetTextColor(color.r, color.g, color.b)
                        else
                            nameText:SetTextColor(1, 1, 1)
                        end
                    elseif isLocalPlayer or threatVal == 3 then
                        nameText:SetTextColor(0.5, 0.8, 1)
                    else
                        nameText:SetTextColor(1, 1, 1)
                    end

                    if hpBar then
                        if class and class ~= "" then
                            local color = RAID_CLASS_COLORS[class]
                            if color then
                                hpBar:SetStatusBarColor(color.r, color.g, color.b)
                            else
                                hpBar:SetStatusBarColor(0.8, 0.1, 0.1)
                            end
                        else
                            hpBar:SetStatusBarColor(0.8, 0.1, 0.1)
                        end
                    end

                    if isLocalPlayer or threatVal == 3 then
                        SetBorder(t, 0.5, 0.8, 1, 1)
                    else
                        SetBorder(t, 0.3, 0.3, 0.3, 1)
                    end

                    if threatVal > 0 then
                        threatBar:Show()
                        threatBar:SetValue(threatVal * 33)
                    else
                        threatBar:Hide()
                    end
                end
            else
                nameText:SetAlpha(0)
                nameText:SetText("")
                nameText:SetTextColor(1, 1, 1)
                hpBarAnchor:Hide()
                if t.lastHpBar then
                    t.lastHpBar:ClearAllPoints()
                    t.lastHpBar:SetParent(UIParent)
                    t.lastHpBar:Hide()
                    t.lastHpBar = nil
                end
                threatBar:Hide()
            end
        end)
    end)
end

------------------------------------------------------------
-- Bar teardown (was the "Destructor" hook body)
------------------------------------------------------------
local function DestroyBar(unitId)
    local t = ToTBars[unitId]
    if not t then return end
    t.active = false
    t.container:SetScript("OnUpdate", nil)
    t.container:Hide()
    ToTBars[unitId] = nil
end

------------------------------------------------------------
-- Reapply config to every live bar (was "Mod Option Changed")
------------------------------------------------------------
local function ApplyConfigToAll()
    for _, t in pairs(ToTBars) do
        ApplySize(t)
        ApplyPosition(t)
    end
end

------------------------------------------------------------
-- Events (replaces Plater's Nameplate Added/Updated + Initialization)
------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            InitDB()
            for _, c in ipairs(ToTAllContainers) do
                c:SetScript("OnUpdate", nil)
                c:Hide()
            end
            ToTAllContainers = {}
            ToTBars = {}
        end

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unitId = arg1
        local plate = C_NamePlate.GetNamePlateForUnit(unitId)
        if plate then
            CreateBar(unitId, plate)
        end

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        DestroyBar(arg1)
    end
end)

------------------------------------------------------------
-- Slash commands (was the Plater options panel)
------------------------------------------------------------
SLASH_TOTBARS1 = "/totbars"
SlashCmdList["TOTBARS"] = function(msg)
    local key, value = msg:match("^(%S+)%s*(.-)$")
    if not key or key == "" then
        print("|cff33ff99ToTBars|r commands:")
        print("  /totbars test            - toggle test bar display")
        print("  /totbars <KEY> <value>   - set a config value, e.g. /totbars WIDTH 140")
        print("  /totbars list            - show current config")
        return
    end

    key = key:upper()

    if key == "TEST" then
        ToTBarsDB.TEST = not ToTBarsDB.TEST
        print("|cff33ff99ToTBars|r TEST mode: " .. tostring(ToTBarsDB.TEST))
        return
    end

    if key == "LIST" then
        for k, v in pairs(ToTBarsDB) do
            print("  " .. k .. " = " .. tostring(v))
        end
        return
    end

    if DEFAULTS[key] == nil then
        print("|cff33ff99ToTBars|r unknown option: " .. key)
        return
    end

    local num = tonumber(value)
    if not num then
        print("|cff33ff99ToTBars|r expected a number for " .. key)
        return
    end

    ToTBarsDB[key] = num
    ApplyConfigToAll()
    print("|cff33ff99ToTBars|r " .. key .. " = " .. tostring(num))
end
