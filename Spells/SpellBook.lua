-- IncahootsCoA: Spells/SpellBook.lua
-- Reads every spell in your spellbook (and your pet's) and keeps a record of
-- each one. Rescans automatically when you learn or change spells.
--
-- A record:
--   name, rank        "Fetid Ward", "Rank 3" (rank may be nil)
--   ranks             how many ranks of it are in the book
--   id                spell ID of the highest rank
--   slot, book        spellbook slot and "spell" / "pet"
--   tab, tabIndex     spellbook tab name and number ("Pet" for pet spells)
--   general           true for the General tab (racials, professions, mounts, utility)
--   icon, passive
--   cost, castTime, range, cooldown   text as shown in the tooltip
--   description       the tooltip's description
--   duration          seconds, read from the description (nil if none)
--   selfCast          true when the spell has no range (self-only)
--   buffScore         how much the description reads like a buff
--   likelyBuff        buffScore is high enough to suggest it
--
-- Public API (also usable from other addons as IncahootsCoA.SpellBook):
--   :Scan()                  rescan now
--   :GetAll()                every record, in spellbook order
--   :Get(name)               player spell record by name (any case)
--   :IsKnown(name)           is it in your (player) spellbook?
--   :GetIcon(name)
--   :BuffStatus(record)      "confirmed", "likely" or nil
--   :GetCount()
--   :Export()                plain-text table of every spell

local addonName, ns = ...
local SB = ns.NewModule("SpellBook")

local BOOK_SPELL = BOOKTYPE_SPELL or "spell"
local BOOK_PET = BOOKTYPE_PET or "pet"

local records = {}
local byName = {}       -- [lower name] = player record
local detailCache = {}  -- [id or name..rank] = parsed tooltip details
local scanned = false

-- ============================================================================
-- TOOLTIP READING
-- ============================================================================
local TIP = "IncahootsCoASpellScanTip"
local scanTip = CreateFrame("GameTooltip", TIP, nil, "GameTooltipTemplate")

local function TipText(side, i)
    local fs = _G[TIP .. "Text" .. side .. i]
    local text = fs and fs:GetText()
    if text and text ~= "" then return text end
end

local UNIT_SECONDS = { sec = 1, second = 1, seconds = 1, min = 60, minute = 60, minutes = 60, hour = 3600, hours = 3600, hr = 3600, hrs = 3600 }

local DURATION_PATTERNS = {
    "for (%d+%.?%d*) (%a+)",
    "lasts (%d+%.?%d*) (%a+)",
    "(%d+%.?%d*) (%a+) duration",
    "over (%d+%.?%d*) (%a+)",
}

-- Longest duration mentioned in a description, in seconds.
local function DurationFromText(text)
    if not text then return nil end
    text = text:lower()
    local best
    for _, pattern in ipairs(DURATION_PATTERNS) do
        for num, unit in text:gmatch(pattern) do
            local mult = UNIT_SECONDS[unit] or UNIT_SECONDS[unit:gsub("%.$", "")]
            local seconds = mult and tonumber(num) and tonumber(num) * mult
            if seconds and (not best or seconds > best) then best = seconds end
        end
    end
    return best
end
SB.DurationFromText = DurationFromText

local function ReadTooltip(slot, book)
    local d = {}
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTip:ClearLines()
    scanTip:SetSpell(slot, book)
    local n = scanTip:NumLines() or 0
    for i = 2, n do
        local left, right = TipText("Left", i), TipText("Right", i)
        if right then
            local r = right:lower()
            if r:find("cooldown") then
                d.cooldown = right
            elseif r:find("range") then
                d.range = right
            end
        end
        if left then
            local l = left:lower()
            if l:find("^instant") or l:find("cast$") or l:find("^channeled") or l:find("sec cast") then
                d.castTime = left
            elseif l:find("cooldown") and #l < 30 then
                d.cooldown = d.cooldown or left
            elseif l:find("range") and #l < 30 then
                d.range = d.range or left
            elseif i == 2 and l:find("%d") and #l < 40 then
                d.cost = left
            elseif l:find("^requires") or l:find("^reagents") or l:find("^tools") then
                -- requirement lines aren't the description
            elseif #left > 20 and left:find(" ") then
                d.description = left -- keep the last long line: the description
            end
        end
    end
    scanTip:Hide()
    return d
end

-- ============================================================================
-- "IS THIS A BUFF?" HEURISTIC
-- Confirmed buffs come from watching what actually happens when you cast
-- (Spells/BuffLearner.lua). Before that, the description gives a good hint.
-- ============================================================================
local BUFF_WORDS = {
    "increas", "grant", "surround", "shield", "absorb", "protect", "empower", "imbu", "infus",
    "ward", "aura", "blessing", "enhanc", "boost", "improv", "regenerat", "reflect", "armor",
    "resist", "haste", "speed", "transform", "stance", "presence", "fortif", "barrier", "reduces damage taken",
}
local HARM_WORDS = {
    "enem", "deals", "damage to", "inflict", "stun", "interrupt", "silence", "taunt", "summon", "knock",
}

local function ScoreBuff(rec)
    if rec.passive then return 0 end
    local text = (rec.description or ""):lower()
    local score = 0
    local d = rec.duration
    if d and d >= 30 then score = score + 2 elseif d and d >= 10 then score = score + 1 end
    local hits = 0
    for _, w in ipairs(BUFF_WORDS) do
        if text:find(w, 1, true) then hits = hits + 1 end
    end
    score = score + math.min(hits, 3)
    for _, w in ipairs(HARM_WORDS) do
        if text:find(w, 1, true) then score = score - 2 end
    end
    if rec.selfCast then score = score + 1 end
    return score
end

-- ============================================================================
-- SCANNING
-- ============================================================================
local function SpellIdFromLink(link)
    return link and tonumber(link:match("spell:(%d+)"))
end

local function FillDetails(rec)
    local key = rec.id or (rec.name .. (rec.rank or ""))
    local d = detailCache[key]
    if not d then
        d = ReadTooltip(rec.slot, rec.book)
        detailCache[key] = d
    end
    rec.cost, rec.castTime, rec.range, rec.cooldown, rec.description = d.cost, d.castTime, d.range, d.cooldown, d.description
    rec.duration = DurationFromText(rec.description)
    if rec.id then
        local _, _, _, _, _, _, _, minRange, maxRange = GetSpellInfo(rec.id)
        rec.selfCast = (maxRange or 0) == 0 and (minRange or 0) == 0
    end
    rec.buffScore = ScoreBuff(rec)
    -- General-tab spells (professions, mounts, utility) are never suggested;
    -- they still count once actually seen putting a buff on you.
    rec.likelyBuff = not rec.general and rec.buffScore >= 3
end

-- Adds one record per spell name; later (higher) ranks replace earlier ones.
local function ScanRange(book, tabName, tabIndex, first, last, seen)
    for slot = first, last do
        local name, rank = GetSpellName(slot, book)
        if name then
            local rec = seen[name]
            if rec then
                rec.ranks = rec.ranks + 1
            else
                rec = {
                    name = name, ranks = 1, book = book, tab = tabName, tabIndex = tabIndex,
                    general = (book == BOOK_SPELL and tabIndex == 1),
                }
                seen[name] = rec
                records[#records + 1] = rec
            end
            rec.slot = slot
            rec.rank = (rank and rank ~= "") and rank or nil
            rec.icon = GetSpellTexture(slot, book)
            rec.id = SpellIdFromLink(GetSpellLink(slot, book))
            rec.passive = IsPassiveSpell(slot, book) and true or false
        end
    end
end

function SB:Scan()
    wipe(records)
    wipe(byName)

    local seen = {}
    for tab = 1, GetNumSpellTabs() do
        local tabName, _, offset, count = GetSpellTabInfo(tab)
        if tabName and count and count > 0 then
            ScanRange(BOOK_SPELL, tabName, tab, offset + 1, offset + count, seen)
        end
    end

    local petCount = HasPetSpells()
    if petCount and petCount > 0 then
        ScanRange(BOOK_PET, "Pet", 0, 1, petCount, {})
    end

    for _, rec in ipairs(records) do
        FillDetails(rec)
        if rec.book == BOOK_SPELL then
            byName[rec.name:lower()] = rec
        end
    end

    scanned = true
    ns.Debug("spellbook scanned: " .. #records .. " spells")
    ns.Fire("SPELLBOOK_UPDATED")
end

-- ============================================================================
-- QUERIES
-- ============================================================================
function SB:GetAll()
    return records
end

function SB:GetCount()
    return #records
end

-- Player spellbook tab names in order, e.g. { "General", "Necromancy", ... }.
function SB:GetTabs()
    local tabs = {}
    for tab = 1, GetNumSpellTabs() do
        local tabName = GetSpellTabInfo(tab)
        if tabName then tabs[#tabs + 1] = tabName end
    end
    return tabs
end

function SB:Get(name)
    return name and byName[name:lower()]
end

function SB:IsKnown(name)
    if not name or name == "" then return false end
    if scanned then return byName[name:lower()] ~= nil end
    return GetSpellInfo(name) ~= nil -- before the first scan
end

function SB:GetIcon(name)
    local rec = self:Get(name)
    if rec then return rec.icon end
    local _, _, icon = GetSpellInfo(name or "")
    return icon
end

function SB:BuffStatus(rec)
    if rec.passive then return nil end
    local learned = ns.global.learned
    if learned.confirmed[rec.name] or learned.links[rec.name] then return "confirmed" end
    if rec.likelyBuff then return "likely" end
    return nil
end

-- Plain text, one spell per line, for sharing or building class presets.
-- The General tab is left out unless includeGeneral is true.
function SB:Export(includeGeneral)
    local body = {}
    for _, r in ipairs(records) do
        if includeGeneral or not r.general then
            local buff = self:BuffStatus(r) or ""
            local link = ns.global.learned.links[r.name]
            if link then buff = buff .. " (gives " .. link .. ")" end
            body[#body + 1] = table.concat({
                r.name, r.rank or "", r.id or "", r.tab, r.passive and "passive" or "active",
                r.cost or "", r.castTime or "", r.range or "", r.cooldown or "",
                r.duration and ns.FormatTime(r.duration, true) or "", buff, r.description or "",
            }, " ; ")
        end
    end
    local header = {
        "# IncahootsCoA spellbook export - " .. (ns.char.className or "?") .. " - " .. #body .. " spells"
            .. (includeGeneral and "" or " (General tab left out)"),
        "# name ; rank ; id ; tab ; type ; cost ; cast ; range ; cooldown ; duration ; buff ; description",
    }
    return table.concat(header, "\n") .. "\n" .. table.concat(body, "\n")
end

-- ============================================================================
-- LIFECYCLE
-- ============================================================================
local RequestScan = ns.Throttle(1, function() SB:Scan() end)

function SB:OnEnable()
    self:Scan()
    ns.RegisterEvent("SPELLS_CHANGED", RequestScan)
    ns.RegisterEvent("LEARNED_SPELL_IN_TAB", RequestScan)
    ns.RegisterEvent("PET_BAR_UPDATE", RequestScan)
    ns.RegisterEvent("UNIT_PET", function(_, unit)
        if unit == "player" then RequestScan() end
    end)
end
