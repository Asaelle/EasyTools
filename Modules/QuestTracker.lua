local _, EasyTools = ...
local Utils = EasyTools.Utils
local GetQuestTitle = Utils.GetQuestTitle
local GetCurrentMapInfo = Utils.GetCurrentMapInfo

local quests = {}
local new_quests = {}
local session_quests = {}
local active_quests = {}
local quests_completed = {}
local quests_removed = {}

local SPAM_QUESTS = {
    [32468] = true,
    [32469] = true,
}

-------------------------------------------------------------------------------
-- Quest Log Storage
-------------------------------------------------------------------------------

local function InitQuestLog()
    if type(EasyToolsDB) ~= "table" then EasyToolsDB = {} end
    if type(EasyToolsDB.QuestLog) ~= "table" then EasyToolsDB.QuestLog = {} end
end

local function LogQuest(questType, questID, questName, mapName, x, y)
    InitQuestLog()
    -- Format: "time;questID;name;type;map;x;y"
    local entry = string.format("%s;%d;%s;%s;%s;%.1f;%.1f",
        date("%Y-%m-%d %H:%M:%S"),
        questID,
        questName or UNKNOWN,
        questType,
        mapName or UNKNOWN,
        x or 0,
        y or 0
    )
    table.insert(EasyToolsDB.QuestLog, entry)
end

-- Quest name retrieval with server request fallback (like AllTheThings)
local questsRequested = {}
local questsPendingAnnounce = {}

local quest_names = {}
setmetatable(quest_names, {
    __index = function(self, key)
        local name = GetQuestTitle(key)
        if name then
            self[key] = name
            return name
        end
        -- Request from server if not cached
        if C_QuestLog.RequestLoadQuestByID and not questsRequested[key] then
            questsRequested[key] = true
            C_QuestLog.RequestLoadQuestByID(key)
        end
        return nil
    end,
})

local function AnnounceQuest(questid, questType, mapdata, x, y)
    if not (EasyToolsDB and EasyToolsDB.Settings and EasyToolsDB.Settings.useQuestTracker) then return end

    local questName = quest_names[questid]
    local mapName = mapdata and mapdata.name or UNKNOWN
    local posX, posY = (x or 0) * 100, (y or 0) * 100

    if questName then
        -- Log to SavedVariables
        LogQuest(questType, questid, questName, mapName, posX, posY)

        if questType == "complete" then
            print("|cff00ff00Quest complete:|r", questid, questName,
                string.format("@ %s (%.1f, %.1f)", mapName, posX, posY))
        elseif questType == "accepted" then
            print("|cff00aaffQuest accepted:|r", questid, questName,
                string.format("@ %s (%.1f, %.1f)", mapName, posX, posY))
        elseif questType == "removed" then
            print("|cffff6666Quest removed:|r", questid, questName,
                string.format("@ %s (%.1f, %.1f)", mapName, posX, posY))
        elseif questType == "unflagged" then
            print("|cffffaa00Quest unflagged:|r", questid, questName,
                string.format("@ %s (%.1f, %.1f)", mapName, posX, posY))
        end
    else
        -- Store for later announcement when name is loaded from server
        questsPendingAnnounce[questid] = {
            type = questType,
            map = mapName,
            x = posX,
            y = posY,
            timeout = GetTime() + 1
        }
    end
end

-- Timeout check for pending quests
local pendingCheckFrame = CreateFrame("Frame")
pendingCheckFrame:SetScript("OnUpdate", function(self, elapsed)
    local now = GetTime()
    for questid, pending in pairs(questsPendingAnnounce) do
        if pending.timeout and now >= pending.timeout then
            -- Timeout reached, announce with Unknown
            local questName = quest_names[questid] or UNKNOWN
            LogQuest(pending.type, questid, questName, pending.map, pending.x, pending.y)

            if pending.type == "complete" then
                print("|cff00ff00Quest complete:|r", questid, questName,
                    string.format("@ %s (%.1f, %.1f)", pending.map, pending.x, pending.y))
            elseif pending.type == "accepted" then
                print("|cff00aaffQuest accepted:|r", questid, questName,
                    string.format("@ %s (%.1f, %.1f)", pending.map, pending.x, pending.y))
            elseif pending.type == "removed" then
                print("|cffff6666Quest removed:|r", questid, questName,
                    string.format("@ %s (%.1f, %.1f)", pending.map, pending.x, pending.y))
            elseif pending.type == "unflagged" then
                print("|cffffaa00Quest unflagged:|r", questid, questName,
                    string.format("@ %s (%.1f, %.1f)", pending.map, pending.x, pending.y))
            end
            questsPendingAnnounce[questid] = nil
        end
    end
end)

-- Dual-step tracking like AllTheThings for detecting completed and unflagged quests
local completedQuestSequence = {}
local MAX_QUEST_ID = 999999

local function CheckQuests()
    local mapdata, x, y

    -- Get fresh completed quests (sorted by Blizzard)
    local freshCompletes = C_QuestLog.GetAllCompletedQuestIDs()
    if not freshCompletes or #freshCompletes == 0 then
        return
    end

    -- First check = initialization (don't announce completed, but announce unflagged)
    local isFirstCheck = #completedQuestSequence == 0

    -- Dual-step comparison (like AllTheThings)
    local Ci, Ni = 1, 1
    local c, n = completedQuestSequence[Ci] or MAX_QUEST_ID, freshCompletes[Ni] or MAX_QUEST_ID

    while c ~= MAX_QUEST_ID or n ~= MAX_QUEST_ID do
        if c == n then
            -- Same questID, no change
            Ci = Ci + 1
            Ni = Ni + 1
            c, n = completedQuestSequence[Ci] or MAX_QUEST_ID, freshCompletes[Ni] or MAX_QUEST_ID
        elseif c < n then
            -- Quest was in old list but not in new = unflagged
            if not SPAM_QUESTS[c] then
                if not mapdata then mapdata, x, y = GetCurrentMapInfo() end
                AnnounceQuest(c, "unflagged", mapdata, x, y)
            end
            quests[c] = nil
            Ci = Ci + 1
            c = completedQuestSequence[Ci] or MAX_QUEST_ID
        else
            -- Quest in new list but not in old = newly completed
            if not isFirstCheck and not session_quests[n] and not SPAM_QUESTS[n] then
                if not mapdata then mapdata, x, y = GetCurrentMapInfo() end
                AnnounceQuest(n, "complete", mapdata, x, y)
                session_quests[n] = true
                table.insert(quests_completed, { id = n, time = time() })
            end
            quests[n] = true
            Ni = Ni + 1
            n = freshCompletes[Ni] or MAX_QUEST_ID
        end
    end

    -- Update the sequence for next comparison
    completedQuestSequence = freshCompletes

    -- Check for removed/abandoned quests (from quest log, not completed)
    local current_active_quests = {}
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isHidden then
            current_active_quests[info.questID] = true
        end
    end

    -- Detect quests that were active but are no longer (and not completed)
    for questid, _ in pairs(active_quests) do
        if not current_active_quests[questid] and not quests[questid] then
            if not mapdata then mapdata, x, y = GetCurrentMapInfo() end
            AnnounceQuest(questid, "removed", mapdata, x, y)
            table.insert(quests_removed, { id = questid, time = time(), abandoned = true })
        end
    end

    -- Detect newly accepted quests
    if not isFirstCheck then
        for questid, _ in pairs(current_active_quests) do
            if not active_quests[questid] then
                if not mapdata then mapdata, x, y = GetCurrentMapInfo() end
                AnnounceQuest(questid, "accepted", mapdata, x, y)
            end
        end
    end

    active_quests = current_active_quests
end

-- Export
if type(EasyTools.Modules) ~= "table" then EasyTools.Modules = {} end
EasyTools.Modules.QuestTracker = {
    quests = quests,
    new_quests = new_quests,
    session_quests = session_quests,
    active_quests = active_quests,
    quests_completed = quests_completed,
    quests_removed = quests_removed,
    questsRequested = questsRequested,
    questsPendingAnnounce = questsPendingAnnounce,
    quest_names = quest_names,
    LogQuest = LogQuest,
    CheckQuests = CheckQuests,
}
