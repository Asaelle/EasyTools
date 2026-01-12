local _, EasyTools = ...
local Utils = EasyTools.Utils

-------------------------------------------------------------------------------
-- Chat Frame Timestamp
-------------------------------------------------------------------------------
local function OnAddMessage(frame, text, ...)
    if text and type(text) == "string" and text ~= "" then
        local ts = Utils.GetTimestampString()
        if ts and ts ~= "" then
            local TIMESTAMP_COLOR_CODE = "|cff808080"
            -- Prevent double-stamping if another addon (or this one) already added a gray timestamp
            -- We look for the specific gray color code at the start
            if not text:find("^" .. TIMESTAMP_COLOR_CODE) then
                text = string.format("%s[%s]|r %s", TIMESTAMP_COLOR_CODE, ts, text)
            end
        end
    end

    return frame.OldAddMessage(frame, text, ...)
end

-------------------------------------------------------------------------------
-- Chat Copy
-------------------------------------------------------------------------------

local frame = CreateFrame("Frame", "EasyToolsCopyFrame", UIParent, "DialogBoxFrame")
frame:SetPoint("CENTER")
frame:SetSize(700, 500)
frame:SetFrameStrata("DIALOG")
frame:Hide()
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

local header = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
header:SetPoint("TOP", 0, -16)
header:SetText("Easy Tools: Press Ctrl+C to copy the text.")
header:SetTextColor(1, 0.82, 0)

local scrollArea = CreateFrame("ScrollFrame", "EasyToolsCopyScroll", frame, "UIPanelScrollFrameTemplate")
scrollArea:SetPoint("TOPLEFT", 20, -45)
scrollArea:SetPoint("BOTTOMRIGHT", -30, 50)

local editBox = CreateFrame("EditBox", nil, scrollArea)
editBox:SetMultiLine(true)
editBox:SetMaxLetters(99999)
editBox:EnableMouse(true)
editBox:SetAutoFocus(false)
editBox:SetFontObject(ChatFontNormal)
editBox:SetWidth(650)
editBox:SetHeight(450)
editBox:SetScript("OnEscapePressed", function() frame:Hide() end)

scrollArea:SetScrollChild(editBox)

local function GetChatLines(chatFrame)
    if not chatFrame then return "" end
    local lines = {}
    local num = chatFrame:GetNumMessages()
    local amount = 200
    local start = math.max(1, num - amount)
    for i = start, num do
        local text = chatFrame:GetMessageInfo(i)
        if text then table.insert(lines, text) end
    end
    return table.concat(lines, "\n")
end

local function OpenCopyWindow(chatFrame)
    local fullText = GetChatLines(chatFrame)
    editBox:SetText(fullText)
    frame:Show()
    editBox:HighlightText()
    editBox:SetFocus()
end

local function CreateCopyButton(chatFrame)
    if _G[chatFrame:GetName() .. "CopyButton"] then return end

    local btn = CreateFrame("Button", chatFrame:GetName() .. "CopyButton", chatFrame)
    btn:SetSize(20, 20)
    btn:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", -5, -5)
    btn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    btn:SetPushedTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Down")
    btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    btn:SetAlpha(0.4)
    btn:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Copy Chat")
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetAlpha(0.4)
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function() OpenCopyWindow(chatFrame) end)
end

local function Initialize()
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i]
        if frame then
            if frame.AddMessage and not frame.OldAddMessage then
                frame.OldAddMessage = frame.AddMessage
                frame.AddMessage = OnAddMessage
            end

            CreateCopyButton(frame)
        end
    end
end

-- Export
if type(EasyTools.Modules) ~= "table" then EasyTools.Modules = {} end
EasyTools.Modules.Chat = {
    Initialize = Initialize,
}
