local _, EasyTools = ...
local Utils = EasyTools.Utils

-------------------------------------------------------------------------------
-- Chat Frame
-------------------------------------------------------------------------------
local function OnAddMessage(frame, text, ...)
    local TIMESTAMP_COLOR_CODE = "|cff808080"

    if text and type(text) == "string" and text ~= "" then
        if not text:find("^" .. TIMESTAMP_COLOR_CODE .. ".-" .. "|r") then
            local ts = Utils.GetTimestampString()
            if ts ~= "" then
                text = TIMESTAMP_COLOR_CODE .. "[" .. ts .. "]|r " .. text
            end
        end
    end

    return frame.OldAddMessage(frame, text, ...)
end

local function Initialize()
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i]

        if frame and not frame.OldAddMessage then
            frame.OldAddMessage = frame.AddMessage
            frame.AddMessage = OnAddMessage
        end
    end
end

-- Export
if type(EasyTools.Modules) ~= "table" then EasyTools.Modules = {} end
EasyTools.Modules.Chat = {
    Initialize = Initialize,
}
