-- !ToTTracker
ToTTargetsByToken = {}
ToTTargetLevelByToken = {}
ToTTargetClassByToken = {}
ToTTargetIsLocalPlayerByToken = {}
ToTTargetHPBarByToken = {}
ToTThreat = {}

local frame = CreateFrame("Frame")
frame:RegisterEvent("UNIT_TARGET")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

local function safeNum(v)
    if v == nil then return 0 end
    local n = tonumber(tostring(v))
    return n or 0
end

local function isOpenWorld()
    local _, instanceType = IsInInstance()
    return instanceType == "none"
end

local barPool = {}

local function getBar()
    if #barPool > 0 then
        local b = table.remove(barPool)
        b:Show()
        return b
    end
    local b = CreateFrame("StatusBar", nil, UIParent)
    b:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    b:SetMinMaxValues(0, 1)
    b:SetValue(1)
    return b
end

local function releaseBar(unit)
    local b = ToTTargetHPBarByToken[unit]
    if b then
        b:Hide()
        b:ClearAllPoints()
        b:SetParent(UIParent)
        table.insert(barPool, b)
        ToTTargetHPBarByToken[unit] = nil
    end
end

local function updateBarHP(unit)
    local b = ToTTargetHPBarByToken[unit]
    if not b then return end
    local targetUnit = unit .. "target"
    b:SetMinMaxValues(0, UnitHealthMax(targetUnit) or 1)
    b:SetValue(UnitHealth(targetUnit) or 0)
end

local function updateTargetInfo(unit)
    local targetUnit = unit .. "target"
    local destName = UnitName(targetUnit)
    if destName ~= nil then
        ToTTargetsByToken[unit] = destName
        ToTTargetLevelByToken[unit] = safeNum(UnitLevel(targetUnit))

        if isOpenWorld() then
            local isPlayer = UnitIsPlayer(targetUnit)
            if isPlayer then
                local _, class = UnitClass(targetUnit)
                ToTTargetClassByToken[unit] = class or ""
            else
                ToTTargetClassByToken[unit] = ""
            end
            local isLocalPlayer = UnitIsUnit(targetUnit, "player")
            ToTTargetIsLocalPlayerByToken[unit] = isLocalPlayer and 1 or 0
        else
            ToTTargetClassByToken[unit] = ""
            ToTTargetIsLocalPlayerByToken[unit] = 0
        end

        local b = ToTTargetHPBarByToken[unit]
        if not b then
            b = getBar()
            ToTTargetHPBarByToken[unit] = b
        end
        b:SetStatusBarColor(0.8, 0.1, 0.1)
        updateBarHP(unit)
    else
        ToTTargetsByToken[unit] = nil
        ToTTargetLevelByToken[unit] = nil
        ToTTargetClassByToken[unit] = nil
        ToTTargetIsLocalPlayerByToken[unit] = nil
        releaseBar(unit)
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_TARGET" then
        local unit = ...
        if not unit then return end
        if not (unit:find("nameplate") or unit == "pet") then return end
        updateTargetInfo(unit)
        local status = UnitThreatSituation("player", unit)
        ToTThreat[unit] = safeNum(status)

    elseif event == "UNIT_HEALTH" then
        for unit, _ in pairs(ToTTargetHPBarByToken) do
            updateBarHP(unit)
        end

    elseif event == "UNIT_THREAT_LIST_UPDATE" then
        local unit = ...
        if not unit then return end
        if not (unit:find("nameplate") or unit == "pet") then return end
        local status = UnitThreatSituation("player", unit)
        ToTThreat[unit] = safeNum(status)

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- only wipe on leaving combat
        for unit, _ in pairs(ToTTargetHPBarByToken) do
            releaseBar(unit)
        end
        ToTTargetsByToken = {}
        ToTTargetLevelByToken = {}
        ToTTargetClassByToken = {}
        ToTTargetIsLocalPlayerByToken = {}
        ToTTargetHPBarByToken = {}
        ToTThreat = {}
    end
end)

-- Called by Plater NAMEPLATE ADDED to proactively populate data
function ToTTrackerRefresh(unit)
    if not unit then return end
    if not (unit:find("nameplate") or unit == "pet") then return end
    updateTargetInfo(unit)
end
