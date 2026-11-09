-- IncahootsCoA: Core/Commands.lua
-- Chat commands and key binding labels. Everything is also in the window.

local addonName, ns = ...

-- Key Bindings > IncahootsCoA
BINDING_HEADER_INCAHOOTSCOA = "IncahootsCoA"
BINDING_NAME_INCAHOOTSCOA_TOGGLE = "Open / close the IncahootsCoA window"
_G["BINDING_NAME_CLICK IncahootsCoANextBuff:LeftButton"] = "Cast next missing buff"

function IncahootsCoA_ToggleWindow()
    ns.Config:Toggle()
end

local function Help()
    ns.Print("v" .. ns.version .. " - |cffffd200/ich|r opens the window. Shortcuts:")
    for _, line in ipairs({
        "spells - open the spellbook browser",
        "buffs - open your tracked buffs",
        "lock | unlock - lock or unlock the buff buttons",
        "test - show test buttons to position them",
        "scan - rescan your spellbook",
        "reset - move the buttons back to the default position",
    }) do
        DEFAULT_CHAT_FRAME:AddMessage("   |cffffd200/ich|r " .. line)
    end
end

SLASH_INCAHOOTSCOA1 = "/ich"
SLASH_INCAHOOTSCOA2 = "/incahoots"
SlashCmdList["INCAHOOTSCOA"] = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "" then
        ns.Config:Toggle()
    elseif cmd == "spells" or cmd == "spellbook" then
        ns.Config:Open("spellbook")
    elseif cmd == "buffs" then
        ns.Config:Open("mybuffs")
    elseif cmd == "lock" or cmd == "unlock" then
        ns.SetLocked(cmd == "lock")
        ns.Print(cmd == "lock" and "Buttons locked." or "Buttons unlocked. Drag the green box to move them.")
    elseif cmd == "test" then
        ns.Display:ToggleTest()
    elseif cmd == "scan" then
        ns.SpellBook:Scan()
        ns.Print("Spellbook scanned: " .. ns.SpellBook:GetCount() .. " spells.")
    elseif cmd == "reset" then
        ns.Display:ResetPosition()
        ns.Print("Buttons moved back to the default position.")
    else
        Help()
    end
end

ns.On("READY", function()
    if ns.DB.wasReset then
        ns.Print("Welcome to version " .. ns.version .. ". Settings from older versions were cleared. Type |cffffd200/ich|r to set up your buffs.")
    elseif ns.DB.isNewCharacter then
        ns.Print("Type |cffffd200/ich|r or click the minimap icon to set up your buffs.")
    end
end)
