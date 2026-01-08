local addonName, EasyTools = ...
local Utils = EasyTools.Utils
local Modules = EasyTools.Modules

local TooltipId = Modules.TooltipId
local QuestTracker = Modules.QuestTracker
local Chat = Modules.Chat

local hook = Utils.hook
local hookScript = Utils.hookScript
local GetQuestTitle = Utils.GetQuestTitle

local quests = QuestTracker.quests
local new_quests = QuestTracker.new_quests
local questsRequested = QuestTracker.questsRequested
local questsPendingAnnounce = QuestTracker.questsPendingAnnounce
local quest_names = QuestTracker.quest_names
local logQuest = QuestTracker.logQuest

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
    QuestTracker.CheckQuests()
    time_since = 0
    self:Hide()
end)

EventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            -- Start minimap clock ticker (every 1 second)
            C_Timer.NewTicker(1, Utils.UpdateMinimapClock)
            EasyTools.Settings.Initialize()
            Chat.Initialize()

            Utils.SendMessage("Loaded - IDs in tooltips, NPC alive time, quest tracking enabled")
        elseif arg1 == "Blizzard_AchievementUI" then
            -- Achievement UI hooks
            if AchievementTemplateMixin then
                hook(AchievementTemplateMixin, "OnEnter", TooltipId.achievementOnEnter)
                hook(AchievementTemplateMixin, "OnLeave", GameTooltip_Hide)

                local hooked = {}
                local getter = function(pool)
                    return function(self, index)
                        if not self or not self[pool] then return end
                        local frame = self[pool][index]
                        frame.___index = index
                        if frame and not hooked[frame] then
                            hookScript(frame, "OnEnter", TooltipId.criteriaOnEnter(index))
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
                    hookScript(button, "OnEnter", TooltipId.achievementOnEnter)
                    hookScript(button, "OnLeave", GameTooltip_Hide)

                    local hooked = {}
                    hook(_G, "AchievementButton_GetCriteria", function(index, renderOffScreen)
                        local frame = _G["AchievementFrameCriteria" .. (renderOffScreen and "OffScreen" or "") .. index]
                        if frame and not hooked[frame] then
                            hookScript(frame, "OnEnter", TooltipId.criteriaOnEnter(index))
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
                    if sources[i].visualID and not Utils.contains(visualIDs, sources[i].visualID) then
                        table.insert(visualIDs, sources[i].visualID)
                    end
                    if sources[i].sourceID and not Utils.contains(sourceIDs, sources[i].sourceID) then
                        table.insert(sourceIDs, sources[i].sourceID)
                    end
                    if sources[i].itemID and not Utils.contains(itemIDs, sources[i].itemID) then
                        table.insert(itemIDs, sources[i].itemID)
                    end
                end

                if #visualIDs == 1 then TooltipId.add(GameTooltip, visualIDs[1], "visual") end
                if #sourceIDs == 1 then TooltipId.add(GameTooltip, sourceIDs[1], "source") end
                if #itemIDs == 1 then TooltipId.add(GameTooltip, itemIDs[1], "item") end

                if #visualIDs > 1 then TooltipId.add(GameTooltip, visualIDs, "visual") end
                if #sourceIDs > 1 then TooltipId.add(GameTooltip, sourceIDs, "source") end
                if #itemIDs > 1 then TooltipId.add(GameTooltip, itemIDs, "item") end
            end)

            -- Pet Journal
            hookScript(PetJournalPetCardPetInfo, "OnEnter", function()
                if not C_PetJournal or not C_PetBattles.GetPetInfoBySpeciesID then return end
                if PetJournalPetCard.speciesID then
                    local npcId = select(4, C_PetJournal.GetPetInfoBySpeciesID(PetJournalPetCard.speciesID))
                    TooltipId.add(GameTooltip, PetJournalPetCard.speciesID, "species")
                    TooltipId.add(GameTooltip, npcId, "unit")
                end
            end)
        elseif arg1 == "Blizzard_GarrisonUI" then
            hook(_G, "AddAutoCombatSpellToTooltip", function(tooltip, info)
                if info and info.autoCombatSpellID then
                    TooltipId.add(tooltip, info.autoCombatSpellID, "ability")
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
                logQuest(pending.type, questID, questName, pending.map, pending.x, pending.y)

                if pending.type == "complete" then
                    print("|cff00ff00Quest complete:|r", questID, questName,
                        string.format("@ %s (%.1f, %.1f)", pending.map, pending.x, pending.y))
                elseif pending.type == "accepted" then
                    print("|cff00aaffQuest accepted:|r", questID, questName,
                        string.format("@ %s (%.1f, %.1f)", pending.map, pending.x, pending.y))
                elseif pending.type == "removed" then
                    print("|cffff6666Quest removed:|r", questID, questName,
                        string.format("@ %s (%.1f, %.1f)", pending.map, pending.x, pending.y))
                elseif pending.type == "unflagged" then
                    print("|cffffaa00Quest unflagged:|r", questID, questName,
                        string.format("@ %s (%.1f, %.1f)", pending.map, pending.x, pending.y))
                end
            end
            questsPendingAnnounce[questID] = nil
        end
    end
end)
