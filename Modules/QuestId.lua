local _, EasyTools = ...
local Utils = EasyTools.Utils

local hook = Utils.hook

-------------------------------------------------------------------------------
-- Quest ID in Objective Tracker
-------------------------------------------------------------------------------

local function AddQuestIdToObjectiveTracker(_, block)
    if not (EasyToolsDB and EasyToolsDB.Settings and EasyToolsDB.Settings.showQuestIDLog) then return end
    if not block or not block.id or not block.HeaderText then return end

    local text = block.HeaderText:GetText()
    if text and not text:match("^%[%d+%]") then
        block.HeaderText:SetText(("[%d] %s"):format(block.id, text))
    end
end

hook(QuestObjectiveTracker, "AddBlock", AddQuestIdToObjectiveTracker)
hook(CampaignQuestObjectiveTracker, "AddBlock", AddQuestIdToObjectiveTracker)
hook(WorldQuestObjectiveTracker, "AddBlock", AddQuestIdToObjectiveTracker)
hook(BonusObjectiveTracker, "AddBlock", AddQuestIdToObjectiveTracker)

-------------------------------------------------------------------------------
-- Quest ID in Quest Dialog (Accept/Turn-in) - Prepend to title
-------------------------------------------------------------------------------

if QuestUtils_DecorateQuestText then
    local originalDecorateQuestText = QuestUtils_DecorateQuestText
    QuestUtils_DecorateQuestText = function(questID, title, useLargeIcon, ...)
        local result = originalDecorateQuestText(questID, title, useLargeIcon, ...)
        if not (EasyToolsDB and EasyToolsDB.Settings and EasyToolsDB.Settings.showQuestIDFrame) then return result end

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

-- Export
if type(EasyTools.Modules) ~= "table" then EasyTools.Modules = {} end
EasyTools.Modules.QuestId = {}
