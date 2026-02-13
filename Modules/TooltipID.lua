local _, EasyTools = ...

local Defines = EasyTools.Defines
local Utils = EasyTools.Utils

local hook = Utils.hook
local isSecret = Utils.isSecret
local getTooltipName = Utils.getTooltipName
local isStringOrNumber = Utils.isStringOrNumber
local GetIDFromPin = Utils.GetIDFromPin

local kinds = Defines.kinds
local disabledKinds = Defines.disabledKinds
local kindsByID = Defines.kindsByID

-- Cache WoW API
local GetSpellTexture = C_Spell.GetSpellTexture
local GetItemIconByID = C_Item.GetItemIconByID
local GetItemSpell = C_Item.GetItemSpell

-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

local function addLine(tooltip, id, kind)
    if not (EasyToolsDB and EasyToolsDB.Settings and EasyToolsDB.Settings.useTooltipID) then return end
    if not id or id == "" or not tooltip or not tooltip.GetName then return end
    if disabledKinds[kind] then return end

    local labelKey = kind and kinds[kind] or "ID"

    -- Check for Duplicates
    local name = getTooltipName(tooltip)
    if name then
        for i = tooltip:NumLines(), 1, -1 do
            local frame = _G[name .. "TextLeft" .. i]
            if frame then
                local success, text = pcall(frame.GetText, frame);
                if success and text and not isSecret(text) and string.find(text, labelKey) then return end
            end
        end
    end

    -- Format Output
    local multiple = type(id) == "table"
    if multiple and #id == 1 then
        id = id[1]
        multiple = false
    end

    local left = labelKey .. (multiple and "s" or "")
    local right = multiple and table.concat(id, ",") or id
    tooltip:AddDoubleLine(left, right, nil, nil, nil, WHITE_FONT_COLOR.r, WHITE_FONT_COLOR.g, WHITE_FONT_COLOR.b)

    local s, err = pcall(function() tooltip:Show() end)
    if not s then
        Utils.SendError("[addLine:Show()] " .. err)
    end
end

local function add(tooltip, id, kind)
    addLine(tooltip, id, kind)

    if kind == "spell" and GetSpellTexture and isStringOrNumber(id) then
        local iconId = GetSpellTexture(id)
        if iconId then add(tooltip, iconId, "icon") end
    end

    if kind == "item" and type(id) == "number" then
        if GetItemIconByID then
            local iconId = GetItemIconByID(id)
            if iconId then add(tooltip, iconId, "icon") end
        end
        if GetItemSpell then
            local spellId = select(2, GetItemSpell(id))
            if spellId then add(tooltip, spellId, "spell") end
        end

        -- Add Context and Bonus IDs from itemLink
        if tooltip.GetItem then
            local success, _, itemLink = pcall(tooltip.GetItem, tooltip)
            if success and itemLink then
                -- Extract context (instanceDifficulty) from itemLink
                -- Format: itemID:enchant:gem1:gem2:gem3:gem4:suffix:unique:level:spec:upgrade:instanceDifficulty:numBonusIDs:bonusID1...
                local linkData = { strsplit(":", itemLink:match("item:([%-?%d:]+)")) }

                -- Context is at position 12 (instanceDifficulty)
                local context = tonumber(linkData[12])
                if context and context > 0 then
                    local contextName = Defines.ItemContextNames[context] or "UNKNOWN"
                    addLine(tooltip, string.format("%d (%s)", context, contextName), "context")
                end

                -- Bonus IDs start at position 14
                local numBonusIDs = tonumber(linkData[13])
                if numBonusIDs and numBonusIDs > 0 then
                    local bonusIDs = {}
                    for i = 1, numBonusIDs do
                        local bonusID = tonumber(linkData[13 + i])
                        if bonusID then
                            table.insert(bonusIDs, bonusID)
                        end
                    end
                    -- Don't display if only bonus is 3407 (client preview)
                    -- But display it if there are other bonuses alongside it
                    if #bonusIDs > 0 and not (#bonusIDs == 1 and bonusIDs[1] == 3407) then
                        addLine(tooltip, bonusIDs, "bonus")
                    end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Modern Tooltip Processor (11.0+)
-------------------------------------------------------------------------------
if TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
        -- Wrap in pcall to catch "Secret" value errors without crashing the game
        local success, err = pcall(function()
            if not data or not tooltip then return end

            -- PROTECTED TYPE CHECK (Combat Safety)
            -- In combat, data.type for auras/spells becomes restricted/secret.
            if isSecret(data.type) then
                add(tooltip, data.id, "spell")
                return
            end

            local kind = kindsByID[tonumber(data.type)]
            if not kind then return end

            -- AreaPOI and Vignette are handled in Map Pin Ticker System
            if kind == "areapoi" or kind == "vignette" then return end

            -- Ignore Embedded tooltips
            local name = tooltip:GetName()
            if not name or string.find(name, "Embedded") then return end

            -- Unit Handling with Secret GUID Check
            if kind == "unit" and data.guid then
                -- Check if GUID is secret (Hostile NPCs in instances)
                if isSecret(data.guid) then
                    add(tooltip, data.id, "unit")
                else
                    local unitId = tonumber(data.guid:match("-(%d+)-%x+$"), 10)
                    if unitId and data.guid:match("%a+") ~= "Player" then
                        add(tooltip, unitId, "unit")
                    elseif data.id then
                        add(tooltip, data.id, "unit")
                    end
                end
                return
            end

            if data.id then
                add(tooltip, data.id, kind)
            end
        end)

        if not success then
            Utils.SendError("[TooltipDataProcessor] " .. err)
        end
    end)
end

-------------------------------------------------------------------------------
-- Specific UI Hooks
-------------------------------------------------------------------------------

-- Talents
if TalentDisplayMixin then
    hook(TalentDisplayMixin, "SetTooltipInternal", function(btn)
        if not btn then return end
        if btn.entryID then add(GameTooltip, btn.entryID, "traitentry") end
        if btn.definitionID then add(GameTooltip, btn.definitionID, "traitdef") end
        if btn.GetNodeInfo then
            local nodeInfo = btn:GetNodeInfo()
            if nodeInfo and nodeInfo.ID then
                add(GameTooltip, nodeInfo.ID, "traitnode")
            end
        end
    end)
end

-- Quest Log
hook(_G, "QuestMapLogTitleButton_OnEnter", function(tooltip)
    if C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
        local id = C_QuestLog.GetQuestIDForLogIndex(tooltip.questLogIndex)
        add(GameTooltip, id, "quest")
    end
end)

-- Quest icons on map (WQ, normal quests)
hook(_G, "TaskPOI_OnEnter", function(tooltip)
    if tooltip and tooltip.questID then add(GameTooltip, tooltip.questID, "quest") end
end)

-------------------------------------------------------------------------------
-- Map Pin Ticker System
-------------------------------------------------------------------------------

local function OnPinMouseEnter(self)
    local id, kind = GetIDFromPin(self)
    if id and kind and GameTooltip:IsVisible() then
        add(GameTooltip, id, kind)
    end
end

if VignettePinMixin then
    hook(VignettePinMixin, "OnMouseEnter", OnPinMouseEnter)
end

if AreaPOIPinMixin then
    hook(AreaPOIPinMixin, "OnMouseEnter", OnPinMouseEnter)
end

if DungeonEntrancePinMixin then
    hook(DungeonEntrancePinMixin, "OnMouseEnter", OnPinMouseEnter)
end

if DelveEntrancePinMixin then
    hook(DelveEntrancePinMixin, "OnMouseEnter", OnPinMouseEnter)
end

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

        local numCriteria = GetAchievementNumCriteria(achievementId)
        if not numCriteria or index > numCriteria then return end

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

-- Artifact Power
if C_ArtifactUI and C_ArtifactUI.GetPowerInfo then
    hook(GameTooltip, "SetArtifactPowerByID", function(tooltip, powerID)
        local powerInfo = C_ArtifactUI.GetPowerInfo(powerID)
        add(tooltip, powerID, "artifactpower")
        if powerInfo then add(tooltip, powerInfo.spellID, "spell") end
    end)
end

-------------------------------------------------------------------------------
-- Export
-------------------------------------------------------------------------------
if type(EasyTools.Modules) ~= "table" then EasyTools.Modules = {} end
EasyTools.Modules.TooltipID = {
    add = add,
    achievementOnEnter = achievementOnEnter,
    criteriaOnEnter = criteriaOnEnter,
}
