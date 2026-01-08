local _, EasyTools = ...
local Utils = EasyTools.Utils
local isSecret = Utils.isSecret

local timeFormat = "%H:%M, %d.%m"
local timeFormatter = CreateFromMixins(SecondsFormatterMixin)
timeFormatter:Init(1, SecondsFormatter.Abbreviation.Truncate)

local function AddColoredDoubleLine(tooltip, leftT, rightT, leftC, rightC)
    leftC = leftC or NORMAL_FONT_COLOR
    rightC = rightC or HIGHLIGHT_FONT_COLOR
    tooltip:AddDoubleLine(leftT, rightT, leftC.r, leftC.g, leftC.b, rightC.r, rightC.g, rightC.b, true)
end

local function ShowNPCAliveTime(tooltip)
    if not (EasyToolsDB and EasyToolsDB.Settings and EasyToolsDB.Settings.useNpcSpawnTime) then return end

    local _, unit = tooltip:GetUnit()
    local guid = UnitGUID(unit or "none")
    if isSecret(guid) then return end
    if not guid then return end

    local unitType = strsplit("-", guid)
    local timeRaw = tonumber(strsub(guid, -6), 16)

    if timeRaw and (unitType == "Creature" or unitType == "Vehicle") then
        local serverTime = GetServerTime()
        local spawnTime = (serverTime - (serverTime % 2 ^ 23)) + bit.band(timeRaw, 0x7fffff)

        if spawnTime > serverTime then
            spawnTime = spawnTime - ((2 ^ 23) - 1)
        end

        AddColoredDoubleLine(tooltip, "Alive",
            timeFormatter:Format((serverTime - spawnTime), false) .. " (" .. date(timeFormat, spawnTime) .. ")")
        tooltip:Show()
    end
end

-------------------------------------------------------------------------------
-- NPC Alive Time Hook
-------------------------------------------------------------------------------

if C_TooltipInfo and TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, tooltipData)
        if tooltip ~= GameTooltip then return end
        if GetRestrictedActionStatus then
            if not GetRestrictedActionStatus(1) then
                ShowNPCAliveTime(tooltip)
            end
        else
            ShowNPCAliveTime(tooltip)
        end
    end)
else
    GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
        ShowNPCAliveTime(tooltip)
    end)
end

-- Export
if type(EasyTools.Modules) ~= "table" then EasyTools.Modules = {} end
EasyTools.Modules.QuestId = {}
