local _, EasyTools = ...
local Utils = EasyTools.Utils
local hook = Utils.hook

local isPending = false

-------------------------------------------------------------------------------
-- Gossip Frame Modification
-------------------------------------------------------------------------------
local function UpdateGossipButtons()
    isPending = false -- Reset the timer lock

    if not (EasyToolsDB and EasyToolsDB.Settings) then return end
    local showQuest = EasyToolsDB.Settings.showQuestIDFrame
    local showGossip = EasyToolsDB.Settings.showGossipDetails

    -- If both settings are off, do nothing
    if not showQuest and not showGossip then return end
    if not GossipFrame:IsShown() then return end

    local scrollBox = GossipFrame.GreetingPanel and GossipFrame.GreetingPanel.ScrollBox
    if not scrollBox then return end

    local requiresResizeLayout = false

    -- Iterate Buttons
    scrollBox:ForEachFrame(function(button)
        local elementData = button:GetElementData()
        if not elementData or not elementData.info then return end

        local info = elementData.info
        local currentText = button:GetText()

        -- Avoid double-tagging if it already starts with [ID]
        if currentText and not currentText:find("^%[") then
            local newText = nil
            if info.questID and showQuest then
                newText = string.format("[%d] %s", info.questID, currentText)
            elseif info.gossipOptionID and showGossip then
                -- Fallback to "?" if orderIndex is nil
                local idx = info.orderIndex or "?"
                newText = string.format("[%s:%d] %s", idx, info.gossipOptionID, currentText)
            end

            if newText then
                button:SetText(newText)
                if button.Resize then
                    button:Resize()
                end
                requiresResizeLayout = true
            end
        end
    end)

    -- Fix Layout (Prevent overlapping)
    if requiresResizeLayout then
        scrollBox:Layout()
    end
end

-- Hook the Update event (Handles page turns and initial show)
hook(GossipFrame, "Update", function()
    if not isPending then
        isPending = true
        C_Timer.After(0, UpdateGossipButtons)
    end
end)

-- Export
if type(EasyTools.Modules) ~= "table" then EasyTools.Modules = {} end
EasyTools.Modules.Gossip = {}
