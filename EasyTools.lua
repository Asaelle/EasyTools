local addonName, EasyTools = ...

-------------------------------------------------------------------------------
-- API Compatibility
-------------------------------------------------------------------------------

local GetSpellTexture = (C_Spell and C_Spell.GetSpellTexture) and C_Spell.GetSpellTexture or GetSpellTexture
local GetItemIconByID = (C_Item and C_Item.GetItemIconByID) and C_Item.GetItemIconByID or GetItemIconByID
local GetItemInfo = (C_Item and C_Item.GetItemInfo) and C_Item.GetItemInfo or GetItemInfo
local GetItemGem = (C_Item and C_Item.GetItemGem) and C_Item.GetItemGem or GetItemGem
local GetItemSpell = (C_Item and C_Item.GetItemSpell) and C_Item.GetItemSpell or GetItemSpell
local GetRecipeReagentItemLink = (C_TradeSkillUI and C_TradeSkillUI.GetRecipeReagentItemLink) and C_TradeSkillUI.GetRecipeReagentItemLink or GetTradeSkillReagentItemLink
local GetItemLinkByGUID = (C_Item and C_Item.GetItemLinkByGUID) and C_Item.GetItemLinkByGUID

-------------------------------------------------------------------------------
-- Utility Functions
-------------------------------------------------------------------------------

local function Print(...) 
    print("|cFF33FF99EasyTools|r:", ...) 
end

local function PrintQuest(...)
    print(...)
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

-------------------------------------------------------------------------------
-- Minimap Clock with Seconds
-------------------------------------------------------------------------------

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

local minimapClock
local function UpdateMinimapClock()
    if not minimapClock then
        minimapClock = CreateMinimapClock()
    end
    
    local localCheck = TimeManagerLocalTimeCheck
    local militaryCheck = TimeManagerMilitaryTimeCheck
    if not (minimapClock and localCheck and militaryCheck) then return end
    
    local useLocalTime = localCheck:GetChecked()
    local useMilitaryTime = militaryCheck:GetChecked()
    
    local h, m, s
    local ampm = ""
    
    if useLocalTime then
        local t = date("*t")
        h, m, s = t.hour, t.min, t.sec
    else
        h, m = GetGameTime()
        s = nil  -- Server time doesn't have seconds
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
        minimapClock.text:SetFormattedText("%02d:%02d:%02d%s", h, m, s, ampm)
    else
        minimapClock.text:SetFormattedText("%02d:%02d%s", h, m, ampm)
    end
end

-------------------------------------------------------------------------------
-- ID Tooltip Module (based on idTip)
-------------------------------------------------------------------------------

local ItemContextNames = EasyTools.ItemContextNames
local kinds = EasyTools.kinds
local disabledKinds = EasyTools.disabledKinds
local kindsByID = EasyTools.kindsByID

local function addLine(tooltip, id, kind)
    if isSecret(id) then return end
    if not id or id == "" or not tooltip or not tooltip.GetName then return end
    if disabledKinds[kind] then return end

    local ok, name = pcall(getTooltipName, tooltip)
    if not ok or not name then return end

    local frame, text
    for i = tooltip:NumLines(), 1, -1 do
        frame = _G[name .. "TextLeft" .. i]
        if frame then text = frame:GetText() end
        if isSecret(text) then return end
        if text and string.find(text, kinds[kind]) then return end
    end

    local multiple = type(id) == "table"
    if multiple and #id == 1 then
        id = id[1]
        multiple = false
    end

    local left = kinds[kind] .. (multiple and "s" or "")
    local right = multiple and table.concat(id, ",") or id
    tooltip:AddDoubleLine(left, right, nil, nil, nil, WHITE_FONT_COLOR.r, WHITE_FONT_COLOR.g, WHITE_FONT_COLOR.b)
    tooltip:Show()
end

local function isStringOrNumber(val)
    local t = type(val)
    return (t == "string") or (t == "number")
end

local function add(tooltip, id, kind)
    addLine(tooltip, id, kind)

    if kind == "spell" and GetSpellTexture and isStringOrNumber(id) then
        local iconId = GetSpellTexture(id)
        if iconId then add(tooltip, iconId, "icon") end
    end

    if kind == "item" and GetItemIconByID and isStringOrNumber(id) then
        local iconId = GetItemIconByID(id)
        if iconId then add(tooltip, iconId, "icon") end
    end

    if kind == "item" and GetItemSpell and isStringOrNumber(id) then
        local spellId = select(2, GetItemSpell(id))
        if spellId then add(tooltip, spellId, "spell") end
    end

    if kind == "macro" and tooltip.GetPrimaryTooltipData then
        local data = tooltip:GetPrimaryTooltipData()
        if data and data.lines and data.lines[1] and data.lines[1].tooltipID then
            add(tooltip, data.lines[1].tooltipID, "spell")
        end
    end
end

local function addByKind(tooltip, id, kind)
    if not kind or not id then return end
    if kind == "spell" or kind == "enchant" or kind == "trade" then
        add(tooltip, id, "spell")
    elseif kinds[kind] then
        add(tooltip, id, kind)
    end
end

local function addItemInfo(tooltip, link)
    if not link then return end
    local itemString = string.match(link, "item:([%-?%d:]+)")
    if not itemString then return end

    local bonuses = {}
    local itemSplit = {}

    for v in string.gmatch(itemString, "(%d*:?)") do
        if v == ":" then
            itemSplit[#itemSplit + 1] = 0
        else
            itemSplit[#itemSplit + 1] = string.gsub(v, ":", "")
        end
    end

    for index = 1, tonumber(itemSplit[13]) or 0 do
        bonuses[#bonuses + 1] = itemSplit[13 + index]
    end

    local gems = {}
    if GetItemGem then
        for i = 1, 4 do
            local gemLink = select(2, GetItemGem(link, i))
            if gemLink then
                local gemDetail = string.match(gemLink, "item[%-?%d:]+")
                gems[#gems + 1] = string.match(gemDetail, "item:(%d+):")
            end
        end
    end

    local itemId = string.match(link, "item:(%d*)")
    if itemId then
        add(tooltip, itemId, "item")

        if itemSplit[2] and itemSplit[2] ~= 0 then add(tooltip, itemSplit[2], "enchant") end
        if #bonuses ~= 0 then add(tooltip, bonuses, "bonus") end
        if #gems ~= 0 then add(tooltip, gems, "gem") end
        
        -- Context (position 12 in itemString = difficultyID/instanceDifficultyId)
        local context = tonumber(itemSplit[12])
        if context and context ~= 0 then
            local contextName = ItemContextNames[context]
            if contextName then
                add(tooltip, context .. " (" .. contextName .. ")", "context")
            else
                add(tooltip, context, "context")
            end
        end

        local expansionId = select(15, GetItemInfo(itemId))
        if expansionId and expansionId ~= 254 then
            add(tooltip, expansionId, "expansion")
        end

        local setId = select(16, GetItemInfo(itemId))
        if setId then
            add(tooltip, setId, "set")
        end
    end
end

local function attachItemTooltip(tooltip, id)
    if (tooltip == ShoppingTooltip1 or tooltip == ShoppingTooltip2) and tooltip.info and tooltip.info.tooltipData and tooltip.info.tooltipData.guid and GetItemLinkByGUID then
        local link = GetItemLinkByGUID(tooltip.info.tooltipData.guid)
        if link then
            addItemInfo(tooltip, link)
        else
            add(tooltip, id, "item")
        end
    elseif tooltip.GetItem then
        local link = select(2, tooltip:GetItem())
        if link then
            addItemInfo(tooltip, link)
        else
            add(tooltip, id, "item")
        end
    else
        add(tooltip, id, "item")
    end
end

-------------------------------------------------------------------------------
-- NPC Alive Time Module (based on NPCTime)
-------------------------------------------------------------------------------

local timeFormat = "%H:%M, %d.%m"
local timeFormatter = CreateFromMixins(SecondsFormatterMixin)
timeFormatter:Init(1, SecondsFormatter.Abbreviation.Truncate)

local function AddColoredDoubleLine(tooltip, leftT, rightT, leftC, rightC)
    leftC = leftC or NORMAL_FONT_COLOR
    rightC = rightC or HIGHLIGHT_FONT_COLOR
    tooltip:AddDoubleLine(leftT, rightT, leftC.r, leftC.g, leftC.b, rightC.r, rightC.g, rightC.b, true)
end

local function ShowNPCAliveTime(tooltip)
    local _, unit = tooltip:GetUnit()
    local guid = UnitGUID(unit or "none")
    if issecretvalue and issecretvalue(guid) then return end
    if not guid then return end

    local unitType = strsplit("-", guid)
    local timeRaw = tonumber(strsub(guid, -6), 16)
    
    if timeRaw and (unitType == "Creature" or unitType == "Vehicle") then
        local serverTime = GetServerTime()
        local spawnTime = (serverTime - (serverTime % 2^23)) + bit.band(timeRaw, 0x7fffff)

        if spawnTime > serverTime then
            spawnTime = spawnTime - ((2^23) - 1)
        end

        AddColoredDoubleLine(tooltip, "Alive", timeFormatter:Format((serverTime - spawnTime), false) .. " (" .. date(timeFormat, spawnTime) .. ")")
        tooltip:Show()
    end
end

-------------------------------------------------------------------------------
-- Quest ID in Objective Tracker
-------------------------------------------------------------------------------

if QuestObjectiveTracker and QuestObjectiveTracker.AddBlock then
    hooksecurefunc(QuestObjectiveTracker, "AddBlock", function(self, block)
        if block and block.id and block.HeaderText then
            local questID = block.id
            local currentText = block.HeaderText:GetText()
            if currentText and not currentText:match("^%[%d+%]") then
                block.HeaderText:SetText("[" .. questID .. "] " .. currentText)
            end
        end
    end)
end

-------------------------------------------------------------------------------
-- Quest ID in Quest Dialog (Accept/Turn-in) - Prepend to title
-------------------------------------------------------------------------------

if QuestUtils_DecorateQuestText then
    local originalDecorateQuestText = QuestUtils_DecorateQuestText
    QuestUtils_DecorateQuestText = function(questID, title, useLargeIcon, ...)
        local result = originalDecorateQuestText(questID, title, useLargeIcon, ...)
        if questID and questID > 0 and result and not result:match("%[%d+%]") then
            -- Check if there's an icon with hyperlink (|H...|h|A:...|a|h) or atlas (|A:...|a) or texture (|T...|t)
            local prefix, rest = result:match("^(|H.-|h|A.-|a|h)(.*)$")
            if not prefix then
                prefix, rest = result:match("^(|A.-|a)(.*)$")
            end
            if not prefix then
                prefix, rest = result:match("^(|T.-|t)(.*)$")
            end
            if prefix then
                -- Insert ID after the icon/hyperlink
                return prefix .. "[" .. questID .. "]" .. rest
            else
                -- No icon, just prepend
                return "[" .. questID .. "] " .. result
            end
        end
        return result
    end
end

-------------------------------------------------------------------------------
-- Quest Tracking Module (based on QuestsChanged)
-------------------------------------------------------------------------------

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

local function AnnounceQuest(questid, questType, mapdata, x, y)
    local questName = quest_names[questid]
    local mapName = mapdata and mapdata.name or UNKNOWN
    local posX, posY = (x or 0) * 100, (y or 0) * 100
    
    if questName then
        -- Log to SavedVariables
        LogQuest(questType, questid, questName, mapName, posX, posY)
        
        if questType == "complete" then
            PrintQuest("|cff00ff00Quest complete:|r", questid, questName, 
                string.format("@ %s (%.1f, %.1f)", mapName, posX, posY))
        elseif questType == "accepted" then
            PrintQuest("|cff00aaffQuest accepted:|r", questid, questName, 
                string.format("@ %s (%.1f, %.1f)", mapName, posX, posY))
        elseif questType == "removed" then
            PrintQuest("|cffff6666Quest removed:|r", questid, questName,
                string.format("@ %s (%.1f, %.1f)", mapName, posX, posY))
        elseif questType == "unflagged" then
            PrintQuest("|cffffaa00Quest unflagged:|r", questid, questName,
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
                PrintQuest("|cff00ff00Quest complete:|r", questid, questName, 
                    string.format("@ %s (%.1f, %.1f)", pending.map, pending.x, pending.y))
            elseif pending.type == "accepted" then
                PrintQuest("|cff00aaffQuest accepted:|r", questid, questName, 
                    string.format("@ %s (%.1f, %.1f)", pending.map, pending.x, pending.y))
            elseif pending.type == "removed" then
                PrintQuest("|cffff6666Quest removed:|r", questid, questName,
                    string.format("@ %s (%.1f, %.1f)", pending.map, pending.x, pending.y))
            elseif pending.type == "unflagged" then
                PrintQuest("|cffffaa00Quest unflagged:|r", questid, questName,
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
                table.insert(quests_completed, {id = n, time = time()})
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
            table.insert(quests_removed, {id = questid, time = time(), abandoned = true})
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

-------------------------------------------------------------------------------
-- Tooltip Hooks - ID Display
-------------------------------------------------------------------------------

if TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
        if not data or not data.type then return end
        local kind = kindsByID[tonumber(data.type)]

        if kind == "unit" and data and data.guid then
            local unitId = tonumber(data.guid:match("-(%d+)-%x+$"), 10)
            if unitId and data.guid:match("%a+") ~= "Player" then
                add(tooltip, unitId, "unit")
            else
                add(tooltip, data.id, "unit")
            end
        elseif kind == "item" and data and data.guid and GetItemLinkByGUID then
            local link = GetItemLinkByGUID(data.guid)
            if link then
                addItemInfo(tooltip, link)
            else
                add(tooltip, data.id, kind)
            end
        elseif kind then
            add(tooltip, data.id, kind)
        end
        
    end)
end

-- Action bar
if GetActionInfo then
    hook(GameTooltip, "SetAction", function(tooltip, slot)
        local kind, id = GetActionInfo(slot)
        addByKind(tooltip, id, kind)
    end)
end

-- Talents (Dragonflight+)
if TalentDisplayMixin then
    hook(TalentDisplayMixin, "SetTooltipInternal", function(btn)
        if not btn then return end
        add(GameTooltip, btn.entryID, "traitentry")
        add(GameTooltip, btn.definitionID, "traitdef")
        if btn.GetNodeInfo then
            add(GameTooltip, btn:GetNodeInfo().ID, "traitnode")
        end
    end)
end

-- Hyperlinks
local function onSetHyperlink(tooltip, link)
    local kind, id = string.match(link, "^(%a+):(%d+)")
    addByKind(tooltip, id, kind)
end
hook(ItemRefTooltip, "SetHyperlink", onSetHyperlink)
hook(GameTooltip, "SetHyperlink", onSetHyperlink)

-- Buffs/Debuffs
if UnitBuff then
    hook(GameTooltip, "SetUnitBuff", function(tooltip, ...)
        local id = select(10, UnitBuff(...))
        add(tooltip, id, "spell")
    end)
end

if UnitDebuff then
    hook(GameTooltip, "SetUnitDebuff", function(tooltip, ...)
        local id = select(10, UnitDebuff(...))
        add(tooltip, id, "spell")
    end)
end

if UnitAura then
    hook(GameTooltip, "SetUnitAura", function(tooltip, ...)
        local id = select(10, UnitAura(...))
        add(tooltip, id, "spell")
    end)
end

hook(GameTooltip, "SetSpellByID", function(tooltip, id)
    addByKind(tooltip, id, "spell")
end)

hook(_G, "SetItemRef", function(link)
    local id = tonumber(link:match("spell:(%d+)"))
    add(ItemRefTooltip, id, "spell")
end)

hookScript(GameTooltip, "OnTooltipSetSpell", function(tooltip)
    local id = select(2, tooltip:GetSpell())
    add(tooltip, id, "spell")
end)

-- Spellbook
if SpellBook_GetSpellBookSlot then
    hook(_G, "SpellButton_OnEnter", function(btn)
        local slot = SpellBook_GetSpellBookSlot(btn)
        local spellID = select(2, GetSpellBookItemInfo(slot, SpellBookFrame.bookType))
        add(GameTooltip, spellID, "spell")
    end)
end

-- Recipes
hook(GameTooltip, "SetRecipeResultItem", function(tooltip, id)
    add(tooltip, id, "spell")
end)

hook(GameTooltip, "SetRecipeRankInfo", function(tooltip, id)
    add(tooltip, id, "spell")
end)

-- Artifact
if C_ArtifactUI and C_ArtifactUI.GetPowerInfo then
    hook(GameTooltip, "SetArtifactPowerByID", function(tooltip, powerID)
        local powerInfo = C_ArtifactUI.GetPowerInfo(powerID)
        add(tooltip, powerID, "artifactpower")
        add(tooltip, powerInfo.spellID, "spell")
    end)
end

-- Talents (pre-DF)
if GetTalentInfoByID then
    hook(GameTooltip, "SetTalent", function(tooltip, id)
        local ok, result = pcall(GetTalentInfoByID, id)
        if not ok then return end
        local spellID = select(6, result)
        add(tooltip, id, "talent")
        add(tooltip, spellID, "spell")
    end)
end

if GetPvpTalentInfoByID then
    hook(GameTooltip, "SetPvpTalent", function(tooltip, id)
        local spellID = select(6, GetPvpTalentInfoByID(id))
        add(tooltip, id, "talent")
        add(tooltip, spellID, "spell")
    end)
end

-- Pet Journal
if C_PetJournal and C_PetJournal.GetPetInfoByPetID then
    hook(GameTooltip, "SetCompanionPet", function(_tooltip, petId)
        local speciesId = select(1, C_PetJournal.GetPetInfoByPetID(petId))
        if speciesId then
            local npcId = select(4, C_PetJournal.GetPetInfoBySpeciesID(speciesId))
            add(GameTooltip, speciesId, "species")
            add(GameTooltip, npcId, "unit")
        end
    end)
end

-- Unit tooltip
hookScript(GameTooltip, "OnTooltipSetUnit", function(tooltip)
    if C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle() then return end
    local unit = select(2, tooltip:GetUnit())
    if unit and UnitGUID then
        local guid = UnitGUID(unit) or ""
        local id = tonumber(guid:match("-(%d+)-%x+$"), 10)
        if id and guid:match("%a+") ~= "Player" then 
            add(GameTooltip, id, "unit") 
        end
    end
end)

-- Toys
hook(GameTooltip, "SetToyByItemID", function(tooltip, id)
    add(tooltip, id, "item")
end)

hook(GameTooltip, "SetRecipeReagentItem", function(tooltip, id)
    add(tooltip, id, "item")
end)

-- Items
local function onSetItem(tooltip)
    attachItemTooltip(tooltip, nil)
end
hookScript(GameTooltip, "OnTooltipSetItem", onSetItem)
hookScript(ItemRefTooltip, "OnTooltipSetItem", onSetItem)
hookScript(ItemRefShoppingTooltip1, "OnTooltipSetItem", onSetItem)
hookScript(ItemRefShoppingTooltip2, "OnTooltipSetItem", onSetItem)
hookScript(ShoppingTooltip1, "OnTooltipSetItem", onSetItem)
hookScript(ShoppingTooltip2, "OnTooltipSetItem", onSetItem)

-- Achievements
local function achievementOnEnter(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_NONE")
    GameTooltip:SetPoint("TOPLEFT", btn, "TOPRIGHT", 0, 0)
    add(GameTooltip, btn.id, "achievement")
    GameTooltip:Show()
end

local function criteriaOnEnter(enterIndex)
    return function(frame)
        if not GetAchievementCriteriaInfo then return end
        local btn = frame:GetParent() and frame:GetParent():GetParent()
        if not btn or not btn.id then return end
        local achievementId = btn.id
        local index = frame.___index or enterIndex
        if index > GetAchievementNumCriteria(achievementId) then return end
        local criteriaId = select(10, GetAchievementCriteriaInfo(achievementId, index))
        if criteriaId then
            if not GameTooltip:IsVisible() then
                GameTooltip:SetOwner(btn:GetParent(), "ANCHOR_NONE")
            end
            GameTooltip:SetPoint("TOPLEFT", btn, "TOPRIGHT", 0, 0)
            add(GameTooltip, achievementId, "achievement")
            add(GameTooltip, criteriaId, "criteria")
            GameTooltip:Show()
        end
    end
end

-- Pet Battles
if C_PetBattles and C_PetBattles.GetActivePet and C_PetBattles.GetAbilityInfo then
    hook(_G, "PetBattleAbilityButton_OnEnter", function(btn)
        local petIndex = C_PetBattles.GetActivePet(LE_BATTLE_PET_ALLY)
        if btn:GetEffectiveAlpha() > 0 then
            local id = select(1, C_PetBattles.GetAbilityInfo(LE_BATTLE_PET_ALLY, petIndex, btn:GetID()))
            if id then
                local oldText = PetBattlePrimaryAbilityTooltip.Description:GetText(id)
                PetBattlePrimaryAbilityTooltip.Description:SetText(oldText .. "\r\r" .. kinds.ability .. "|cffffffff " .. id .. "|r")
            end
        end
    end)
end

if C_PetBattles and C_PetBattles.GetAuraInfo then
    hook(_G, "PetBattleAura_OnEnter", function(frame)
        local parent = frame:GetParent()
        local id = select(1, C_PetBattles.GetAuraInfo(parent.petOwner, parent.petIndex, frame.auraIndex))
        if id then
            local oldText = PetBattlePrimaryAbilityTooltip.Description:GetText(id)
            PetBattlePrimaryAbilityTooltip.Description:SetText(oldText .. "\r\r" .. kinds.ability .. "|cffffffff " .. id .. "|r")
        end
    end)
end

-- Currency
if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListLink then
    hook(GameTooltip, "SetCurrencyToken", function(tooltip, index)
        local id = tonumber(string.match(C_CurrencyInfo.GetCurrencyListLink(index), "currency:(%d+)"))
        add(tooltip, id, "currency")
    end)
end

hook(GameTooltip, "SetCurrencyByID", function(tooltip, id)
    add(tooltip, id, "currency")
end)

hook(GameTooltip, "SetCurrencyTokenByID", function(tooltip, id)
    add(tooltip, id, "currency")
end)

-- Quest log
if C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
    hook(_G, "QuestMapLogTitleButton_OnEnter", function(tooltip)
        local id = C_QuestLog.GetQuestIDForLogIndex(tooltip.questLogIndex)
        add(GameTooltip, id, "quest")
    end)
end

hook(_G, "TaskPOI_OnEnter", function(tooltip)
    if tooltip and tooltip.questID then add(GameTooltip, tooltip.questID, "quest") end
end)

-- AreaPois (world map)
hook(AreaPOIPinMixin, "TryShowTooltip", function(tooltip)
    if tooltip and tooltip.areaPoiID then add(GameTooltip, tooltip.areaPoiID, "areapoi") end
end)

-- Vignettes (world map)
hook(VignettePinMixin, "OnMouseEnter", function(tooltip)
    if tooltip and tooltip.vignetteInfo and tooltip.vignetteInfo.vignetteID then 
        add(GameTooltip, tooltip.vignetteInfo.vignetteID, "vignette") 
    end
end)

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

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("QUEST_LOG_UPDATE")
EventFrame:RegisterEvent("ENCOUNTER_LOOT_RECEIVED")
EventFrame:RegisterEvent("QUEST_DATA_LOAD_RESULT")

local questCheckFrame = CreateFrame("Frame")
questCheckFrame:Hide()

local time_since = 0
questCheckFrame:SetScript("OnUpdate", function(self, elapsed)
    time_since = time_since + elapsed
    if time_since < 0.3 then return end
    CheckQuests()
    time_since = 0
    self:Hide()
end)

EventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            -- Start minimap clock ticker (every 1 second)
            C_Timer.NewTicker(1, UpdateMinimapClock)
            Print("Loaded - IDs in tooltips, NPC alive time, quest tracking enabled")
        elseif arg1 == "Blizzard_AchievementUI" then
            -- Achievement UI hooks
            if AchievementTemplateMixin then
                hook(AchievementTemplateMixin, "OnEnter", achievementOnEnter)
                hook(AchievementTemplateMixin, "OnLeave", GameTooltip_Hide)

                local hooked = {}
                local getter = function(pool)
                    return function(self, index)
                        if not self or not self[pool] then return end
                        local frame = self[pool][index]
                        frame.___index = index
                        if frame and not hooked[frame] then
                            hookScript(frame, "OnEnter", criteriaOnEnter(index))
                            hookScript(frame, "OnLeave", GameTooltip_Hide)
                            hooked[frame] = true
                        end
                    end
                end
                hook(AchievementTemplateMixin:GetObjectiveFrame(), "GetCriteria", getter("criterias"))
                hook(AchievementTemplateMixin:GetObjectiveFrame(), "GetMiniAchievement", getter("miniAchivements"))
                hook(AchievementTemplateMixin:GetObjectiveFrame(), "GetMeta", getter("metas"))
                hook(AchievementTemplateMixin:GetObjectiveFrame(), "GetProgressBar", getter("progressBars"))
            elseif AchievementFrameAchievementsContainer then
                for _, button in ipairs(AchievementFrameAchievementsContainer.buttons) do
                    hookScript(button, "OnEnter", achievementOnEnter)
                    hookScript(button, "OnLeave", GameTooltip_Hide)

                    local hooked = {}
                    hook(_G, "AchievementButton_GetCriteria", function(index, renderOffScreen)
                        local frame = _G["AchievementFrameCriteria" .. (renderOffScreen and "OffScreen" or "") .. index]
                        if frame and not hooked[frame] then
                            hookScript(frame, "OnEnter", criteriaOnEnter(index))
                            hookScript(frame, "OnLeave", GameTooltip_Hide)
                            hooked[frame] = true
                        end
                    end)
                end
            end
        elseif arg1 == "Blizzard_Collections" then
            -- Collections hooks
            hook(CollectionWardrobeUtil, "SetAppearanceTooltip", function(_frame, sources)
                local visualIDs = {}
                local sourceIDs = {}
                local itemIDs = {}

                for i = 1, #sources do
                    if sources[i].visualID and not contains(visualIDs, sources[i].visualID) then 
                        table.insert(visualIDs, sources[i].visualID) 
                    end
                    if sources[i].sourceID and not contains(sourceIDs, sources[i].sourceID) then 
                        table.insert(sourceIDs, sources[i].sourceID) 
                    end
                    if sources[i].itemID and not contains(itemIDs, sources[i].itemID) then 
                        table.insert(itemIDs, sources[i].itemID) 
                    end
                end

                if #visualIDs == 1 then add(GameTooltip, visualIDs[1], "visual") end
                if #sourceIDs == 1 then add(GameTooltip, sourceIDs[1], "source") end
                if #itemIDs == 1 then add(GameTooltip, itemIDs[1], "item") end

                if #visualIDs > 1 then add(GameTooltip, visualIDs, "visual") end
                if #sourceIDs > 1 then add(GameTooltip, sourceIDs, "source") end
                if #itemIDs > 1 then add(GameTooltip, itemIDs, "item") end
            end)

            -- Pet Journal
            hookScript(PetJournalPetCardPetInfo, "OnEnter", function()
                if not C_PetJournal or not C_PetBattles.GetPetInfoBySpeciesID then return end
                if PetJournalPetCard.speciesID then
                    local npcId = select(4, C_PetJournal.GetPetInfoBySpeciesID(PetJournalPetCard.speciesID))
                    add(GameTooltip, PetJournalPetCard.speciesID, "species")
                    add(GameTooltip, npcId, "unit")
                end
            end)
        elseif arg1 == "Blizzard_GarrisonUI" then
            hook(_G, "AddAutoCombatSpellToTooltip", function(tooltip, info)
                if info and info.autoCombatSpellID then
                    add(tooltip, info.autoCombatSpellID, "ability")
                end
            end)
        end
    elseif event == "PLAYER_LOGIN" then
        -- Initialize quest tracking
        new_quests = C_QuestLog.GetAllCompletedQuestIDs(new_quests)
        for _, questid in pairs(new_quests) do
            quests[questid] = true
        end
    elseif event == "QUEST_LOG_UPDATE" or event == "ENCOUNTER_LOOT_RECEIVED" then
        questCheckFrame:Show()
    elseif event == "QUEST_DATA_LOAD_RESULT" then
        local questID, success = arg1, arg2
        if not questID then return end
        questsRequested[questID] = nil
        
        -- Check if we have a pending announcement for this quest
        local pending = questsPendingAnnounce[questID]
        if pending and success then
            local questName = GetQuestTitle(questID)
            if questName then
                quest_names[questID] = questName
                -- Log to SavedVariables
                LogQuest(pending.type, questID, questName, pending.map, pending.x, pending.y)
                
                if pending.type == "complete" then
                    PrintQuest("|cff00ff00Quest complete:|r", questID, questName, 
                        string.format("@ %s (%.1f, %.1f)", pending.map, pending.x, pending.y))
                elseif pending.type == "accepted" then
                    PrintQuest("|cff00aaffQuest accepted:|r", questID, questName, 
                        string.format("@ %s (%.1f, %.1f)", pending.map, pending.x, pending.y))
                elseif pending.type == "removed" then
                    PrintQuest("|cffff6666Quest removed:|r", questID, questName,
                        string.format("@ %s (%.1f, %.1f)", pending.map, pending.x, pending.y))
                elseif pending.type == "unflagged" then
                    PrintQuest("|cffffaa00Quest unflagged:|r", questID, questName,
                        string.format("@ %s (%.1f, %.1f)", pending.map, pending.x, pending.y))
                end
            end
            questsPendingAnnounce[questID] = nil
        end
    end
end)
