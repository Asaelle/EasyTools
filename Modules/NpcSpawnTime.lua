local _, EasyTools = ...
local Utils = EasyTools.Utils
local isSecret = Utils.isSecret

-- WoW API Cache for performance
local UnitGUID = UnitGUID
local GetServerTime = GetServerTime
local bit_band = bit.band
local strsplit = strsplit
local strsub = strsub
local tonumber = tonumber
local date = date

-- Time Formatter
-- "1h 30m" format
local timeFormat = "%H:%M, %d.%m"
local timeFormatter = CreateFromMixins(SecondsFormatterMixin)
timeFormatter:Init(1, SecondsFormatter.Abbreviation.Truncate)

local function AddColoredDoubleLine(tooltip, leftT, rightT)
    local leftC = NORMAL_FONT_COLOR
    local rightC = HIGHLIGHT_FONT_COLOR
    tooltip:AddDoubleLine(leftT, rightT, leftC.r, leftC.g, leftC.b, rightC.r, rightC.g, rightC.b)
end

local function ShowNPCAliveTime(tooltip)
    if not (EasyToolsDB and EasyToolsDB.Settings and EasyToolsDB.Settings.useNpcSpawnTime) then return end

    -- Get Unit and GUID
    local _, unit = tooltip:GetUnit()
    if not unit then return end

    local success, guid = pcall(UnitGUID, unit)
    if not success or not guid then return end

    -- Check Unit Type
    -- GUID Format: "Type-Zero-ServerID-InstanceID-ZoneUID-ID-SpawnTime"
    -- Only Creatures or Vehicles
    local unitType = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then return end

    -- Parse Spawn Time
    -- The spawn timer is the last 6 hex characters of the GUID
    local timeRaw = tonumber(strsub(guid, -6), 16)
    if not timeRaw then return end

    -- Calculate Timestamp
    -- The spawn ID is a 23-bit counter that rolls over every ~24 days (2^23 seconds)
    -- Mask: 0x7fffff (23 bits)
    -- Cycle: 0x800000 (2^23)
    local serverTime = GetServerTime()

    -- Find the start of the current 24-day cycle
    local epoch = serverTime - (serverTime % 0x800000)

    -- Add the mob's offset to the epoch
    local spawnOffset = bit_band(timeRaw, 0x7fffff)
    local spawnTime = epoch + spawnOffset

    -- Correction: If the calculated spawn time is in the future, it means the server
    -- cycle rolled over recently, but this mob spawned in the previous cycle.
    if spawnTime > serverTime then
        spawnTime = spawnTime - 0x800000
    end

    local uptime = serverTime - spawnTime
    if uptime >= 0 then
        AddColoredDoubleLine(tooltip, "Alive",
            timeFormatter:Format(uptime) .. " (" .. date(timeFormat, spawnTime) .. ")")
        tooltip:Show()
    end
end

-------------------------------------------------------------------------------
-- Tooltip Processor Hook
-------------------------------------------------------------------------------
if TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
        if tooltip == GameTooltip then
            ShowNPCAliveTime(tooltip)
        end
    end)
end

-- Export
if type(EasyTools.Modules) ~= "table" then EasyTools.Modules = {} end
EasyTools.Modules.NpcSpawnTime = {}
