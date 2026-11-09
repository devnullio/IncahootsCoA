local addonName = ...

-- Saved variables are loaded before PLAYER_LOGIN fires.
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        MyAddonDB = MyAddonDB or {}
    elseif event == "PLAYER_LOGIN" then
        print("|cff33ff99" .. addonName .. "|r loaded. Type /myaddon for help.")
    end
end)

SLASH_MYADDON1 = "/myaddon"
SlashCmdList["MYADDON"] = function(msg)
    print(addonName .. ": hello! Replace this handler with your own commands.")
end
