local addonName, EasyTools = ...
local Defines = EasyTools.Defines

local function SendMessage(...)
    print("|cFF33FF99" .. addonName .. "|r:", ...)
end

local function SendError(...)
    print("|cFFFF3333[Error] " .. addonName .. "|r:", ...)
end

local function GetTimestampString()
    local setting = Settings.GetSetting("ET_ChatTimestamp")
    local index = setting:GetValue()

    if index > #Defines.BlizzardTimeFormat then
        return ""
    end

    if Defines.BlizzardTimeFormat[index] == "None" then
        return ""
    end

    return date(Defines.BlizzardTimeFormat[index]):gsub("%s+$", "")
end

local function hook(table, fn, cb)
    if table and table[fn] then
        hooksecurefunc(table, fn, cb)
    end
end

local function hookScript(table, fn, cb)
    if table and table:HasScript(fn) then
        table:HookScript(fn, cb)
    end
end

local function isSecret(value)
    if not issecretvalue or not issecrettable then return false end
    return issecretvalue(value) or issecrettable(value)
end

local function getTooltipName(tooltip)
    return tooltip:GetName() or nil
end

local function contains(tbl, element)
    for _, value in pairs(tbl) do
        if value == element then return true end
    end
    return false
end

local function isStringOrNumber(val)
    local t = type(val)
    return (t == "string") or (t == "number")
end

local function CreateMinimapClock()
    local originalClock = TimeManagerClockTicker
    if originalClock and originalClock:IsVisible() then
        originalClock:Hide()
    end

    local clockFrame = CreateFrame("Frame", "EasyToolsClock", TimeManagerClockButton)
    clockFrame:SetSize(80, 20)
    clockFrame:SetPoint("CENTER", -5, 1)

    clockFrame.text = clockFrame:CreateFontString(nil, "ARTWORK", "WhiteNormalNumberFont")
    clockFrame.text:SetAllPoints()
    clockFrame.text:SetJustifyH("CENTER")
    clockFrame:Show()

    return clockFrame
end

GMinimapClock = nil
local function UpdateMinimapClock()
    if not GMinimapClock then
        GMinimapClock = CreateMinimapClock()
    end

    local localCheck = TimeManagerLocalTimeCheck
    local militaryCheck = TimeManagerMilitaryTimeCheck
    if not (GMinimapClock and localCheck and militaryCheck) then return end

    local useLocalTime = localCheck:GetChecked()
    local useMilitaryTime = militaryCheck:GetChecked()

    local h, m, s
    local ampm = ""

    if useLocalTime then
        local t = date("*t")
        h, m, s = t.hour, t.min, t.sec
    else
        h, m = GetGameTime()
        s = nil -- Server time doesn't have seconds
    end

    if not useMilitaryTime then
        if h == 0 then
            h = 12
            ampm = " AM"
        elseif h < 12 then
            ampm = " AM"
        elseif h == 12 then
            ampm = " PM"
        else
            h = h - 12
            ampm = " PM"
        end
    end

    if useLocalTime and s then
        GMinimapClock.text:SetFormattedText("%02d:%02d:%02d%s", h, m, s, ampm)
    else
        GMinimapClock.text:SetFormattedText("%02d:%02d%s", h, m, ampm)
    end
end

local function GetQuestTitle(questID)
    -- Try C_TaskQuest first (for world quests)
    if C_TaskQuest and C_TaskQuest.GetQuestInfoByQuestID then
        local name = C_TaskQuest.GetQuestInfoByQuestID(questID)
        if name and name ~= "" then return name end
    end
    -- Then try C_QuestLog
    local name = C_QuestLog.GetTitleForQuestID(questID)
    if name and name ~= "" and name ~= RETRIEVING_DATA then return name end
    return nil
end

local function GetCurrentMapInfo()
    local mapdata, x, y
    local mapID = C_Map.GetBestMapForUnit('player')
    if mapID then
        mapdata = C_Map.GetMapInfo(mapID)
        local position = C_Map.GetPlayerMapPosition(mapdata.mapID, 'player')
        if position then
            x, y = position:GetXY()
        end
    end
    return mapdata, x, y
end

local function NotifyQuestUpdate(statusType, questID, questName, mapName, x, y)
    local msgFormat = "@ %s (%.1f, %.1f)"
    local locString = string.format(msgFormat, mapName or "Unknown", x or 0, y or 0)
    questName = questName or "Unknown"

    if statusType == "complete" then
        print("|cff00ff00Quest complete:|r", questID, questName, locString)
    elseif statusType == "accepted" then
        print("|cff00aaffQuest accepted:|r", questID, questName, locString)
    elseif statusType == "removed" then
        print("|cffff6666Quest removed:|r", questID, questName, locString)
    elseif statusType == "unflagged" then
        print("|cffffaa00Quest unflagged:|r", questID, questName, locString)
    end
end

-- Returns (id, kind) for any Map Pin (Vignette or AreaPOI)
local function GetIDFromPin(pin)
    if not pin then return nil end
    local id = nil

    -- Vignette check
    if pin.vignetteID then id = pin.vignetteID end
    if (not id or id == 0) and pin.vignetteInfo then id = pin.vignetteInfo.vignetteID end
    if (not id or id == 0) and pin.GetVignetteID then id = pin:GetVignetteID() end
    if id and id ~= 0 then return id, "vignette" end

    -- AreaPOI check
    if pin.poiInfo then id = pin.poiInfo.areaPoiID or pin.poiInfo.poiID end
    if (not id or id == 0) and pin.tooltipWidgetSet then id = pin.tooltipWidgetSet end
    if (not id or id == 0) and pin.GetAreaPoiID then id = pin:GetAreaPoiID() end
    if (not id or id == 0) then id = pin.areaPoiID end
    if (not id or id == 0) then id = pin.poiID end

    if (not id or id == 0) and pin.GetElementData then
        local data = pin:GetElementData()
        if data then
            id = data.areaPoiID or data.poiID or data.questID
        end
    end

    if id and id ~= 0 then return id, "areapoi" end
    return nil
end

-- Export
if type(EasyTools.Utils) ~= "table" then EasyTools.Utils = {} end
EasyTools.Utils = {
    hook = hook,
    hookScript = hookScript,
    isSecret = isSecret,
    contains = contains,
    isStringOrNumber = isStringOrNumber,
    getTooltipName = getTooltipName,
    GetTimestampString = GetTimestampString,
    SendMessage = SendMessage,
    SendError = SendError,
    UpdateMinimapClock = UpdateMinimapClock,
    GetQuestTitle = GetQuestTitle,
    GetCurrentMapInfo = GetCurrentMapInfo,
    NotifyQuestUpdate = NotifyQuestUpdate,
    GetIDFromPin = GetIDFromPin,
}
