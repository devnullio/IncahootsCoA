-- IncahootsCoA: Core/Database.lua
-- Saved variables.
--
-- IncahootsCoADB = {
--   schema = 3,
--   global = {                                   shared by all characters
--     minimap = { hide, angle },
--     learned = {
--       confirmed = { [spellName] = true },      spells seen putting a buff on you
--       links     = { [spellName] = buffName },  spell whose buff has a different name
--       durations = { [buffName] = seconds },    last seen full duration
--     },
--   },
--   chars = {
--     ["Name - Realm"] = { class, className, buffs = { rule, ... }, display = { ... }, locked, debug },
--   },
-- }
--
-- At runtime ns.global and ns.char point into this table.

local addonName, ns = ...
local DB = {}
ns.DB = DB

local SCHEMA = 3

DB.defaults = {
    global = {
        minimap = { hide = false, angle = 215 },
        learned = { confirmed = {}, links = {}, durations = {} },
    },
    char = {
        buffs = {},
        locked = true,
        spellbookTab = "nogeneral", -- Spellbook page tab filter: "nogeneral", "all" or a tab name
        debug = false,
        display = {
            enabled = true,
            mode = "missing",      -- "missing": only buffs you need; "all": every tracked buff
            point = { "CENTER", "CENTER", 0, -140 },
            size = 36,
            spacing = 4,
            perRow = 8,
            maxButtons = 12,
            grow = "RIGHT",        -- RIGHT, LEFT, DOWN, UP
            scale = 1,
            showTimers = true,
            showTooltips = true,
            showBorders = true,
            activeAlpha = 0.4,     -- "all" mode: how visible buffs you already have are
            hideMounted = true,
            hideVehicle = true,    -- also on taxis
            hideResting = false,
            hideInCombat = false,
            sound = false,         -- play a sound when a tracked buff runs out
        },
    },
}

function DB:CharKey()
    return (UnitName("player") or "Unknown") .. " - " .. (GetRealmName() or "Unknown")
end

function DB:Init()
    local sv = IncahootsCoADB
    if type(sv) ~= "table" or sv.schema ~= SCHEMA then
        -- Data from older versions isn't compatible; start clean.
        self.wasReset = type(sv) == "table" and next(sv) ~= nil
        sv = { schema = SCHEMA }
    end
    if type(sv.global) ~= "table" then sv.global = {} end
    if type(sv.chars) ~= "table" then sv.chars = {} end
    ns.ApplyDefaults(sv.global, self.defaults.global)
    IncahootsCoADB = sv
    self.sv = sv

    self.key = self:CharKey()
    local char = sv.chars[self.key]
    if type(char) ~= "table" then
        char = {}
        sv.chars[self.key] = char
        self.isNewCharacter = true
    end
    ns.ApplyDefaults(char, self.defaults.char)
    local className, classToken = UnitClass("player")
    char.className = className or char.className
    char.class = classToken or className or char.class

    ns.global = sv.global
    ns.char = char
end

-- Other characters that have tracked buffs, for "Copy from character".
function DB:OtherCharacters()
    local list = {}
    for key, data in pairs(self.sv.chars) do
        if key ~= self.key and type(data.buffs) == "table" and #data.buffs > 0 then
            list[#list + 1] = { key = key, className = data.className, count = #data.buffs }
        end
    end
    table.sort(list, function(a, b) return a.key < b.key end)
    return list
end

function DB:GetCharacter(key)
    return self.sv.chars[key]
end

function DB:ResetDisplay()
    ns.char.display = ns.CopyTable(self.defaults.char.display)
    ns.Fire("DISPLAY_CHANGED")
end
