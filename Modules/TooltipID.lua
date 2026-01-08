local _, EasyTools = ...

local Defines = EasyTools.Defines
local Utils = EasyTools.Utils

local hook = Utils.hook
local hookScript = Utils.hookScript
local isSecret = Utils.isSecret
local isStringOrNumber = Utils.isStringOrNumber
local getTooltipName = Utils.getTooltipName

local ItemContextNames = Defines.ItemContextNames
local kinds = Defines.kinds
local disabledKinds = Defines.disabledKinds
local kindsByID = Defines.kindsByID

local GetSpellTexture = (C_Spell and C_Spell.GetSpellTexture) and C_Spell.GetSpellTexture or GetSpellTexture
local GetItemIconByID = (C_Item and C_Item.GetItemIconByID) and C_Item.GetItemIconByID or GetItemIconByID
local GetItemInfo = (C_Item and C_Item.GetItemInfo) and C_Item.GetItemInfo or GetItemInfo
local GetItemGem = (C_Item and C_Item.GetItemGem) and C_Item.GetItemGem or GetItemGem
local GetItemSpell = (C_Item and C_Item.GetItemSpell) and C_Item.GetItemSpell or GetItemSpell
local GetItemLinkByGUID = (C_Item and C_Item.GetItemLinkByGUID) and C_Item.GetItemLinkByGUID

local function addLine(tooltip, id, kind)
    if not (EasyToolsDB and EasyToolsDB.Settings and EasyToolsDB.Settings.useTooltipID) then return end
    if not id or id == "" or not tooltip or not tooltip.GetName then return end
    if disabledKinds[kind] then return end

    local ok, name = pcall(getTooltipName, tooltip)
    if not ok or not name then return end

    local frame, text
    for i = tooltip:NumLines(), 1, -1 do
        frame = _G[name .. "TextLeft" .. i]
        if frame then text = frame:GetText() end
        if not isSecret(text) and text and string.find(text, kinds[kind]) then return end
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

-- Items
local function onSetItem(tooltip)
    attachItemTooltip(tooltip, nil)
end

-- Hyperlinks
local function onSetHyperlink(tooltip, link)
    local kind, id = string.match(link, "^(%a+):(%d+)")
    addByKind(tooltip, id, kind)
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

-------------------------------------------------------------------------------
-- Tooltip hooks - ID Display
-------------------------------------------------------------------------------

if TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
        if not data or not data.type then return end

        -- Blizz removed access while in combat for spells/auras
        if isSecret(data.type) then
            add(tooltip, data.id, "spell")
            return
        end

        local kind = kindsByID[tonumber(data.type)]

        if isSecret(data.guid) then
            Utils.SendError("Data guid is secret for " .. kind .. " with id " .. data.id)
            return
        end

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

hookScript(GameTooltip, "OnTooltipSetItem", onSetItem)
hookScript(ItemRefTooltip, "OnTooltipSetItem", onSetItem)
hookScript(ItemRefShoppingTooltip1, "OnTooltipSetItem", onSetItem)
hookScript(ItemRefShoppingTooltip2, "OnTooltipSetItem", onSetItem)
hookScript(ShoppingTooltip1, "OnTooltipSetItem", onSetItem)
hookScript(ShoppingTooltip2, "OnTooltipSetItem", onSetItem)

-- Pet Battles
if C_PetBattles and C_PetBattles.GetActivePet and C_PetBattles.GetAbilityInfo then
    hook(_G, "PetBattleAbilityButton_OnEnter", function(btn)
        local petIndex = C_PetBattles.GetActivePet(LE_BATTLE_PET_ALLY)
        if btn:GetEffectiveAlpha() > 0 then
            local id = select(1, C_PetBattles.GetAbilityInfo(LE_BATTLE_PET_ALLY, petIndex, btn:GetID()))
            if id then
                local oldText = PetBattlePrimaryAbilityTooltip.Description:GetText(id)
                PetBattlePrimaryAbilityTooltip.Description:SetText(oldText ..
                    "\r\r" .. kinds.ability .. "|cffffffff " .. id .. "|r")
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
            PetBattlePrimaryAbilityTooltip.Description:SetText(oldText ..
                "\r\r" .. kinds.ability .. "|cffffffff " .. id .. "|r")
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

-- Export
if type(EasyTools.Modules) ~= "table" then EasyTools.Modules = {} end
EasyTools.Modules.TooltipID = {
    add = add,
    achievementOnEnter = achievementOnEnter,
    criteriaOnEnter = criteriaOnEnter,
}
