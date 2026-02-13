local addonName, EasyTools = ...
local Defines = EasyTools.Defines
local Utils = EasyTools.Utils

-------------------------------------------------
-- Utility
-------------------------------------------------
local function SafeRegister(cat, id, var, tbl, vtype, label, def)
    local setting = Settings.RegisterAddOnSetting(cat, id, var, tbl, vtype, label, def)
    if not setting then
        Utils.SendError("Failed to register setting: " .. id)
    end
    return setting
end

local function SafeCreateDropdown(cat, setting, list, description)
    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        for i, v in ipairs(list) do
            container:Add(i, v)
        end
        return container:GetData()
    end

    local dropdown = Settings.CreateDropdown(cat, setting, GetOptions, description)
    if not dropdown then
        Utils.SendError("Failed to create dropdown: " .. setting.variableKey)
    end
    return dropdown
end

local function SafeAddDescription(layout, text)
    local initializer = CreateSettingsListSectionHeaderInitializer(text)

    local originalInit = initializer.InitFrame
    initializer.InitFrame = function(self, frame)
        originalInit(self, frame) -- Run the standard setup

        -- Override the font to look like normal text
        if frame.Title then
            frame.Title:SetFontObject("GameFontHighlight") -- White text
            frame.Title:SetJustifyH("LEFT")
        end
    end

    layout:AddInitializer(initializer)
end

-------------------------------------------------
-- Options Settings
-------------------------------------------------
local function Initialize()
    if type(EasyToolsDB) ~= "table" then EasyToolsDB = {} end
    if type(EasyToolsDB.Settings) ~= "table" then EasyToolsDB.Settings = {} end

    local category, layout = Settings.RegisterVerticalLayoutCategory(addonName)

    ---------------------------------------------------------------------------
    -- Addon Description
    ---------------------------------------------------------------------------
    SafeAddDescription(layout,
        "EasyTools provides quality of life improvements for questing, chatting, and NPC interactions.")

    ---------------------------------------------------------------------------
    -- Section: Quests
    ---------------------------------------------------------------------------
    do
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Quests"))

        local settingQL = SafeRegister(category, "ET_QuestLogID", "showQuestIDLog", EasyToolsDB.Settings,
            Settings.VarType.Boolean, "Show Quest ID in Quest Log", true)
        local settingQF = SafeRegister(category, "ET_QuestFrameID", "showQuestIDFrame", EasyToolsDB.Settings,
            Settings.VarType.Boolean, "Show Quest ID in Quest Frame", true)

        if settingQL then
            Settings.CreateCheckbox(category, settingQL, "Display the ID next to quest titles in the log.")
        end

        if settingQF then
            Settings.CreateCheckbox(category, settingQF, "Display the ID when talking to NPCs.")
        end
    end

    ---------------------------------------------------------------------------
    -- Section: Gossip
    ---------------------------------------------------------------------------
    do
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Gossip"))

        local settingG = SafeRegister(category, "ET_GossipDetails", "showGossipDetails", EasyToolsDB.Settings,
            Settings.VarType.Boolean, "Show Gossip Details", true)

        if settingG then
            Settings.CreateCheckbox(category, settingG, "Display indices and option IDs in gossip frames.")
        end
    end

    ---------------------------------------------------------------------------
    -- Section: Modules
    ---------------------------------------------------------------------------
    do
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Modules"))

        local settingTooltipID = SafeRegister(category, "ET_TooldtipID", "useTooltipID", EasyToolsDB.Settings,
            Settings.VarType.Boolean, "Tooltip ID", true)
        local settingNpcSpawnTime = SafeRegister(category, "ET_NpcSpawnTime", "useNpcSpawnTime",
            EasyToolsDB.Settings,
            Settings.VarType.Boolean, "NPC Spawn Time", true)
        local settingQuestTracker = SafeRegister(category, "ET_QuestTracker", "useQuestTracker",
            EasyToolsDB.Settings,
            Settings.VarType.Boolean, "Quest Tracker", true)

        if settingTooltipID then
            Settings.CreateCheckbox(category, settingTooltipID,
                "Show the IDs of spells/creatures/items in their tooltip frame.")
        end

        if settingNpcSpawnTime then
            Settings.CreateCheckbox(category, settingNpcSpawnTime, "Show the NPC creation time in their tooltip frame.")
        end

        if settingQuestTracker then
            Settings.CreateCheckbox(category, settingQuestTracker, "Keep track of quest status change.")
        end
    end

    ---------------------------------------------------------------------------
    -- Section: Chat
    ---------------------------------------------------------------------------
    do
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Chat"))

        local settingChatT = SafeRegister(category, "ET_ChatTimestamp", "timestampFormat", EasyToolsDB.Settings,
            Settings.VarType.Number, "Chat Timestamp", 1)

        if settingChatT then
            SafeCreateDropdown(category, settingChatT, Defines.BlizzardTimeFormatExample,
                "Select the format to be displayed.")
        end
    end

    ---------------------------------------------------------------------------
    -- Section: Minimap
    ---------------------------------------------------------------------------
    do
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Minimap"))

        local settingShowSeconds = SafeRegister(category, "ET_MinimapShowSeconds", "minimapShowSeconds",
            EasyToolsDB.Settings, Settings.VarType.Boolean, "Show Seconds on Clock", true)

        if settingShowSeconds then
            Settings.CreateCheckbox(category, settingShowSeconds,
                "Display seconds on the minimap clock (requires local time).")
        end
    end

    Settings.RegisterAddOnCategory(category)
end

-- Export
EasyTools.Settings = {
    Initialize = Initialize,
}
