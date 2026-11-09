-- IncahootsCoA: Spells/BuffLearner.lua
-- Learns which of your spells are buffs by watching what happens:
--   * a buff you cast on yourself that has the same name as a spell in your
--     spellbook confirms that spell as a buff
--   * a buff that appears on you right after you cast a spell with a different
--     name links the two ("casting Raise Bone Armor gives the buff Bone Armor")
--   * the full duration of each buff is remembered
-- Everything learned lives in ns.global.learned and is shared by all characters.

local addonName, ns = ...
local Learner = ns.NewModule("BuffLearner")
local SB = ns.SpellBook

local LINK_WINDOW = 1.0 -- seconds between a cast and the buff it caused

local lastCastName, lastCastTime = nil, 0

local function Learned()
    return ns.global.learned
end

local function Confirm(spellName)
    local learned = Learned()
    if learned.confirmed[spellName] then return false end
    learned.confirmed[spellName] = true
    ns.Debug("learned: " .. spellName .. " is a buff")
    return true
end

-- Only self-targeted or buff-looking spells can be linked, so a damage spell
-- that happens to trigger a proc isn't mistaken for a buff.
local function CanLink(castName)
    local rec = SB:Get(castName)
    if not rec or rec.passive then return false end
    return rec.selfCast or rec.likelyBuff
end

local function OnBuffApplied(buffName)
    local changed = false
    if SB:IsKnown(buffName) then
        changed = Confirm(buffName)
    elseif lastCastName and GetTime() - lastCastTime <= LINK_WINDOW and lastCastName ~= buffName
        and CanLink(lastCastName) then
        local learned = Learned()
        if learned.links[lastCastName] ~= buffName then
            learned.links[lastCastName] = buffName
            learned.confirmed[lastCastName] = true
            changed = true
            ns.Debug("learned: casting " .. lastCastName .. " gives the buff " .. buffName)
        end
    end
    if changed then ns.Fire("LEARNED_UPDATED") end
end

-- Remember durations and confirm buffs you already have (e.g. after a reload).
local function ScanOwnBuffs()
    local learned = Learned()
    local changed = false
    local i = 1
    while true do
        local name, _, _, _, _, duration, _, caster = UnitAura("player", i, "HELPFUL")
        if not name then break end
        if caster == "player" then
            if duration and duration > 0 then learned.durations[name] = duration end
            if SB:IsKnown(name) and not learned.confirmed[name] then
                learned.confirmed[name] = true
                changed = true
            end
        end
        i = i + 1
    end
    if changed then ns.Fire("LEARNED_UPDATED") end
end

-- 3.3.5 combat log: timestamp, event, srcGUID, srcName, srcFlags,
-- dstGUID, dstName, dstFlags, spellId, spellName, spellSchool, auraType
local function OnCombatLog(_, _, subEvent, srcGUID, _, _, dstGUID, _, _, _, spellName, _, auraType)
    if (subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH")
        and auraType == "BUFF" and srcGUID == ns.playerGUID and dstGUID == ns.playerGUID and spellName then
        OnBuffApplied(spellName)
    end
end

function Learner:Forget()
    local learned = Learned()
    wipe(learned.confirmed)
    wipe(learned.links)
    wipe(learned.durations)
    ns.Fire("LEARNED_UPDATED")
end

function Learner:ForgetLink(spellName)
    Learned().links[spellName] = nil
    ns.Fire("LEARNED_UPDATED")
end

function Learner:OnEnable()
    ns.RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, spellName)
        if unit == "player" then
            lastCastName, lastCastTime = spellName, GetTime()
        end
    end)
    ns.RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", OnCombatLog)
    local RequestScan = ns.Throttle(0.5, ScanOwnBuffs)
    ns.RegisterEvent("UNIT_AURA", function(_, unit)
        if unit == "player" then RequestScan() end
    end)
    ns.On("SPELLBOOK_UPDATED", RequestScan)
end
