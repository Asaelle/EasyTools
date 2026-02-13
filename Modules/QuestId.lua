local _, EasyTools = ...
local Utils = EasyTools.Utils
local hook = Utils.hook

-------------------------------------------------------------------------------
-- 1. Objective Tracker (Watch Frame)
-------------------------------------------------------------------------------
local function AddQuestIdToObjectiveTracker(_, block)
    if not (EasyToolsDB and EasyToolsDB.Settings and EasyToolsDB.Settings.showQuestIDLog) then return end
    if not block or not block.id then return end

    -- Different tracker types store text in different places, usually HeaderText
    local textLine = block.HeaderText
    if not textLine then return end

    local text = textLine:GetText()
    -- Check if ID is already there (starts with [123])
    if text and not text:match("^%[%d+%]") then
        -- Store original height before modification
        local originalHeight = textLine:GetHeight()

        -- Configure the text to handle multiple lines properly
        textLine:SetMaxLines(0) -- Allow unlimited lines
        textLine:SetText(("[%d] %s"):format(block.id, text))

        -- Calculate new text height after adding ID
        local newHeight = textLine:GetStringHeight()

        -- If text height increased, adjust the block height
        if newHeight > originalHeight then
            local heightDiff = newHeight - originalHeight
            if block.height then
                block.height = block.height + heightDiff
            end
            -- Adjust the block's actual frame height
            if block.SetHeight then
                local currentBlockHeight = block:GetHeight()
                block:SetHeight(currentBlockHeight + heightDiff)
            end
        end
    end
end

-- Hook all tracker modules present in 11.0
local trackers = {
    QuestObjectiveTracker,
    CampaignQuestObjectiveTracker,
    WorldQuestObjectiveTracker,
    BonusObjectiveTracker,
    --  ScenarioObjectiveTracker,
    --  AchievementObjectiveTracker,
    --  ProfessionsRecipeTracker,
    --  MonthlyActivitiesObjectiveTracker,
}

for _, tracker in pairs(trackers) do
    if tracker then
        hook(tracker, "AddBlock", AddQuestIdToObjectiveTracker)
    end
end

-------------------------------------------------------------------------------
-- 2. Quest Dialogs (Accept / Turn-in / Log Details)
-------------------------------------------------------------------------------
if QuestUtils_DecorateQuestText then
    local originalDecorateQuestText = QuestUtils_DecorateQuestText

    QuestUtils_DecorateQuestText = function(questID, title, useLargeIcon, ...)
        local result = originalDecorateQuestText(questID, title, useLargeIcon, ...)

        if not (EasyToolsDB and EasyToolsDB.Settings and EasyToolsDB.Settings.showQuestIDFrame) then
            return result
        end

        if questID and questID > 0 and result and not result:match("%[%d+%]") then
            -- Determine if the title starts with an icon (Texture, Atlas, or Hyperlink)
            -- We want: [Icon] [ID] Title

            local prefix, rest

            -- Hyperlink (rare in titles, but possible)
            prefix, rest = result:match("^(|H.-|h|A.-|a|h)(.*)$")

            -- Atlas (|A...|a)
            if not prefix then
                prefix, rest = result:match("^(|A.-|a)(.*)$")
            end

            -- Texture (|T...|t)
            if not prefix then
                prefix, rest = result:match("^(|T.-|t)(.*)$")
            end

            if prefix then
                -- Insert ID after the icon
                return prefix .. " [" .. questID .. "]" .. rest
            else
                -- No icon, just prepend ID
                return "[" .. questID .. "] " .. result
            end
        end

        return result
    end
end

-- Export
if type(EasyTools.Modules) ~= "table" then EasyTools.Modules = {} end
EasyTools.Modules.QuestId = {}
