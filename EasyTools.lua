local addonName, EasyTools = ...
local Utils = EasyTools.Utils
local Modules = EasyTools.Modules

local TooltipID = Modules.TooltipID
local QuestTracker = Modules.QuestTracker
local Chat = Modules.Chat

local hook = Utils.hook
local hookScript = Utils.hookScript

local quests = QuestTracker.quests
local new_quests = QuestTracker.new_quests

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
            C_Timer.NewTicker(1, Utils.UpdateMinimapClock)
            EasyTools.Settings.Initialize()
            Chat.Initialize()
            Utils.SendMessage("Loaded - IDs in tooltips, NPC alive time, quest tracking enabled")
        elseif arg1 == "Blizzard_AchievementUI" then
            if AchievementTemplateMixin then
                hook(AchievementTemplateMixin, "OnEnter", TooltipID.achievementOnEnter)
                hook(AchievementTemplateMixin, "OnLeave", GameTooltip_Hide)

                local hooked = {}
                local getter = function(pool)
                    return function(self, index)
                        if not self or not self[pool] then return end
                        local frame = self[pool][index]
                        frame.___index = index
                        if frame and not hooked[frame] then
                            hookScript(frame, "OnEnter", TooltipID.criteriaOnEnter(index))
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
                    hookScript(button, "OnEnter", TooltipID.achievementOnEnter)
                    hookScript(button, "OnLeave", GameTooltip_Hide)

                    local hooked = {}
                    hook(_G, "AchievementButton_GetCriteria", function(index, renderOffScreen)
                        local frame = _G["AchievementFrameCriteria" .. (renderOffScreen and "OffScreen" or "") .. index]
                        if frame and not hooked[frame] then
                            hookScript(frame, "OnEnter", TooltipID.criteriaOnEnter(index))
                            hookScript(frame, "OnLeave", GameTooltip_Hide)
                            hooked[frame] = true
                        end
                    end)
                end
            end
        elseif arg1 == "Blizzard_Collections" then
            hook(CollectionWardrobeUtil, "SetAppearanceTooltip", function(_frame, sources)
                local visualIDs, sourceIDs, itemIDs = {}, {}, {}

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

                if #visualIDs > 0 then TooltipID.add(GameTooltip, visualIDs, "visual") end
                if #sourceIDs > 0 then TooltipID.add(GameTooltip, sourceIDs, "source") end
                if #itemIDs > 0 then TooltipID.add(GameTooltip, itemIDs, "item") end
            end)

            hookScript(PetJournalPetCardPetInfo, "OnEnter", function()
                if not C_PetJournal or not C_PetBattles.GetPetInfoBySpeciesID then return end
                if PetJournalPetCard.speciesID then
                    local npcId = select(4, C_PetJournal.GetPetInfoBySpeciesID(PetJournalPetCard.speciesID))
                    TooltipID.add(GameTooltip, PetJournalPetCard.speciesID, "species")
                    TooltipID.add(GameTooltip, npcId, "unit")
                end
            end)
        elseif arg1 == "Blizzard_GarrisonUI" then
            hook(_G, "AddAutoCombatSpellToTooltip", function(tooltip, info)
                if info and info.autoCombatSpellID then
                    TooltipID.add(tooltip, info.autoCombatSpellID, "ability")
                end
            end)
        end
    elseif event == "PLAYER_LOGIN" then
        new_quests = C_QuestLog.GetAllCompletedQuestIDs(new_quests)
        for _, questid in pairs(new_quests) do
            quests[questid] = true
        end
    elseif event == "QUEST_LOG_UPDATE" or event == "ENCOUNTER_LOOT_RECEIVED" then
        questCheckFrame:Show()
    elseif event == "QUEST_DATA_LOAD_RESULT" then
        -- Clean one-liner call to module
        QuestTracker.OnQuestDataLoaded(arg1, arg2)
    end
end)
