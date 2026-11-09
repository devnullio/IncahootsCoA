-- IncahootsCoA: Buffs/Tracker.lua
-- Works out the state of every tracked buff:
--   "active"    you have it
--   "expiring"  you have it but less than the rule's rebuff time is left
--   "missing"   you don't have it
--   "unknown"   the spell isn't in this character's spellbook
--   "disabled"  the rule is switched off
--
-- A status: { rule, index, state, expires (GetTime() value or math.huge),
--             buff (name found), duration, icon }

local addonName, ns = ...
local Tracker = ns.NewModule("Tracker")
local SB = ns.SpellBook
local Rules = ns.Rules

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local PERMANENT = math.huge

local statuses = {}  -- in rule order
local byRule = {}    -- [rule] = status
local initialized = false
local hasRebuffRules = false

local anyExp, mineExp, buffIcon, buffDuration = {}, {}, {}, {}

local function ScanPlayerBuffs()
    wipe(anyExp)
    wipe(mineExp)
    wipe(buffIcon)
    wipe(buffDuration)
    local i = 1
    while true do
        local name, _, icon, _, _, duration, expires, caster = UnitAura("player", i, "HELPFUL")
        if not name then break end
        local exp = (expires and expires > 0) and expires or PERMANENT
        if not anyExp[name] or exp > anyExp[name] then
            anyExp[name] = exp
            buffIcon[name] = icon
            buffDuration[name] = duration
        end
        if caster == "player" and (not mineExp[name] or exp > mineExp[name]) then
            mineExp[name] = exp
        end
        i = i + 1
    end
end

local function NeedsCast(state)
    return state == "missing" or state == "expiring"
end
Tracker.NeedsCast = NeedsCast

local function Evaluate()
    ScanPlayerBuffs()
    local now = GetTime()
    local newStatuses, alive = {}, {}
    local somethingRanOut = false
    hasRebuffRules = false

    for i, rule in ipairs(Rules:All()) do
        local st = byRule[rule]
        if not st then
            st = { rule = rule }
            byRule[rule] = st
        end
        alive[rule] = true
        local previous = st.state
        st.index = i
        st.icon = SB:GetIcon(rule.spell)
        st.expires, st.buff, st.duration = nil, nil, nil

        if not rule.enabled then
            st.state = "disabled"
        elseif not SB:IsKnown(rule.spell) then
            st.state = "unknown"
        else
            local source = rule.mine and mineExp or anyExp
            for _, name in ipairs(Rules:BuffNames(rule)) do
                local e = source[name]
                if e and (not st.expires or e > st.expires) then
                    st.expires, st.buff = e, name
                end
            end
            if st.buff then
                st.icon = st.icon or buffIcon[st.buff]
                st.duration = buffDuration[st.buff]
            end
            if rule.rebuff > 0 then hasRebuffRules = true end

            if not st.expires then
                st.state = "missing"
            elseif rule.rebuff > 0 and st.expires ~= PERMANENT and st.expires - now <= rule.rebuff then
                st.state = "expiring"
            else
                st.state = "active"
            end
        end
        st.icon = st.icon or FALLBACK_ICON

        if initialized and previous == "active" and NeedsCast(st.state) then
            somethingRanOut = true
        end
        newStatuses[i] = st
    end

    for rule in pairs(byRule) do
        if not alive[rule] then byRule[rule] = nil end
    end
    statuses = newStatuses
    initialized = true

    if somethingRanOut and ns.char.display.sound and not UnitIsDeadOrGhost("player") then
        PlaySound("RaidWarning")
    end
    ns.Fire("STATUS_UPDATED")
end

local RequestEvaluate = ns.Throttle(0.1, Evaluate)

-- ============================================================================
-- PUBLIC
-- ============================================================================
function Tracker:GetStatuses()
    return statuses
end

function Tracker:StatusOf(rule)
    return byRule[rule]
end

-- Seconds left on a status's buff (math.huge for no time limit, nil if none).
function Tracker:Remaining(st)
    if not st or not st.expires then return nil end
    if st.expires == PERMANENT then return PERMANENT end
    return math.max(0, st.expires - GetTime())
end

-- Counts for summaries: tracked, active, need (missing + expiring), unknown.
function Tracker:Summary()
    local s = { tracked = 0, active = 0, need = 0, unknown = 0, needNames = {} }
    for _, st in ipairs(statuses) do
        if st.state ~= "disabled" then s.tracked = s.tracked + 1 end
        if st.state == "active" then s.active = s.active + 1 end
        if st.state == "unknown" then s.unknown = s.unknown + 1 end
        if NeedsCast(st.state) then
            s.need = s.need + 1
            s.needNames[#s.needNames + 1] = st.rule.spell
        end
    end
    return s
end

function Tracker:Refresh()
    Evaluate()
end

-- ============================================================================
-- LIFECYCLE
-- ============================================================================
function Tracker:OnEnable()
    ns.RegisterEvent("UNIT_AURA", function(_, unit)
        if unit == "player" then RequestEvaluate() end
    end)
    ns.RegisterEvent("PLAYER_ENTERING_WORLD", RequestEvaluate)
    ns.On("SPELLBOOK_UPDATED", RequestEvaluate)
    ns.On("LEARNED_UPDATED", RequestEvaluate)
    ns.On("RULES_CHANGED", RequestEvaluate)

    -- "Rebuff when under X sec" needs a clock, not just aura events.
    local ticker = CreateFrame("Frame")
    local elapsedTotal = 0
    ticker:SetScript("OnUpdate", function(_, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal < 0.5 then return end
        elapsedTotal = 0
        if hasRebuffRules then Evaluate() end
    end)

    Evaluate()
end
