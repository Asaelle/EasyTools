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

local function Initialize()
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i]

        -- Hook only if not already hooked
        if frame and frame.AddMessage and not frame.OldAddMessage then
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
