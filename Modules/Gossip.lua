local _, EasyTools = ...
local Utils = EasyTools.Utils

local hook = Utils.hook
local isPending = false

function UpdateGossipButtons()
    isPending = false -- Reset the timer lock
    if not GossipFrame:IsShown() then return end

    local scrollBox = GossipFrame.GreetingPanel and GossipFrame.GreetingPanel.ScrollBox
    if not scrollBox then return end

    local requiresResizeLayout = false
    scrollBox:ForEachFrame(function(button)
        local elementData = button:GetElementData()
        if not elementData or not elementData.info then return end

        local info = elementData.info
        local currentText = button:GetText()

        if currentText and not currentText:find("^%[") then
            local newText = nil

            if info.questID then
                if not (EasyToolsDB and EasyToolsDB.Settings and EasyToolsDB.Settings.showQuestIDFrame) then return end
                newText = string.format("[%d] %s", info.questID, currentText)
            end

            if info.gossipOptionID then
                if not (EasyToolsDB and EasyToolsDB.Settings and EasyToolsDB.Settings.showGossipDetails) then return end
                local idx = info.orderIndex or "?"
                newText = string.format("[%s:%d] %s", idx, info.gossipOptionID, currentText)
            end

            if newText then
                button:SetText(newText)
                if button.Resize then
                    button:Resize()
                end

                requiresResizeLayout = true;
            end
        end
    end)

    if requiresResizeLayout then
        scrollBox:Layout()
    end
end

hook(GossipFrame, "Update", function()
    if not isPending then
        isPending = true
        C_Timer.After(0, UpdateGossipButtons)
    end
end)

-- Export
if type(EasyTools.Modules) ~= "table" then EasyTools.Modules = {} end
EasyTools.Modules.Gossip = {}
