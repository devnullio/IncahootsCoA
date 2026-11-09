-- IncahootsCoA: Buffs/Rules.lua
-- The list of buffs this character tracks (ns.char.buffs), in priority order.
--
-- A rule:
--   spell    spell the button casts on you
--   extras   other buff names that also count as having it (e.g. a ward that
--            replaces another ward, or the buff's name when it differs)
--   rebuff   show the button when less than this many seconds remain (0 = only when gone)
--   mine     only count the buff when you cast it yourself
--   enabled  switch a rule off without deleting it

local addonName, ns = ...
local Rules = ns.NewModule("Rules")
local SB = ns.SpellBook

local function Changed()
    ns.Fire("RULES_CHANGED")
end

function Rules:All()
    return ns.char.buffs
end

function Rules:Get(index)
    return ns.char.buffs[index]
end

function Rules:Count()
    return #ns.char.buffs
end

-- Every buff name that satisfies a rule.
function Rules:BuffNames(rule)
    local names = { rule.spell }
    local link = ns.global.learned.links[rule.spell]
    if link then names[#names + 1] = link end
    for _, extra in ipairs(rule.extras) do
        names[#names + 1] = extra
    end
    return names
end

-- Index of the rule that casts `spell` or is satisfied by the buff `name`.
function Rules:Find(name)
    if not name then return nil end
    for i, rule in ipairs(ns.char.buffs) do
        for _, n in ipairs(self:BuffNames(rule)) do
            if n == name then return i end
        end
    end
end

function Rules:IsTracked(name)
    return self:Find(name) ~= nil
end

-- Adds a rule (or returns the existing one's index). Returns index, isNew.
function Rules:Add(spell, extras)
    spell = strtrim(spell or "")
    if spell ~= "" then
        local existing = self:Find(spell)
        if existing then return existing, false end
    end
    local list = ns.char.buffs
    list[#list + 1] = {
        spell = spell,
        extras = extras or {},
        rebuff = 0,
        mine = false,
        enabled = true,
    }
    Changed()
    return #list, true
end

-- Track a buff you currently have. Works out which spell casts it.
function Rules:AddFromBuff(buffName)
    if SB:IsKnown(buffName) then
        return self:Add(buffName)
    end
    for spell, buff in pairs(ns.global.learned.links) do
        if buff == buffName and SB:IsKnown(spell) then
            return self:Add(spell)
        end
    end
    -- We don't know the spell yet: keep the buff's name so it's recognised,
    -- and the player only has to fill in the spell.
    return self:Add(buffName, { buffName })
end

function Rules:Remove(index)
    if ns.char.buffs[index] then
        table.remove(ns.char.buffs, index)
        Changed()
    end
end

-- Returns the rule's new index.
function Rules:Move(index, delta)
    local list = ns.char.buffs
    local target = index + delta
    if not list[index] or target < 1 or target > #list then return index end
    list[index], list[target] = list[target], list[index]
    Changed()
    return target
end

-- Call after editing a rule's fields directly.
function Rules:Changed()
    Changed()
end

function Rules:CopyFrom(charKey)
    local other = ns.DB:GetCharacter(charKey)
    if not other or type(other.buffs) ~= "table" then return false end
    ns.char.buffs = ns.CopyTable(other.buffs)
    Changed()
    return true
end

-- ============================================================================
-- IMPORT / EXPORT
--   # IncahootsCoA buffs
--   Fetid Ward; also=Bone Ward, Blood Ward
--   Foul Mandate; rebuff=60; mine
--   Razorice; off
-- Semicolons, not pipes: WoW edit boxes treat "|" as an escape character.
-- ============================================================================
function Rules:Export()
    local lines = { "# IncahootsCoA buffs (" .. (ns.char.className or "?") .. ")" }
    for _, r in ipairs(ns.char.buffs) do
        local parts = { r.spell }
        if #r.extras > 0 then parts[#parts + 1] = "also=" .. table.concat(r.extras, ", ") end
        if r.rebuff > 0 then parts[#parts + 1] = "rebuff=" .. r.rebuff end
        if r.mine then parts[#parts + 1] = "mine" end
        if not r.enabled then parts[#parts + 1] = "off" end
        lines[#lines + 1] = table.concat(parts, "; ")
    end
    return table.concat(lines, "\n")
end

-- Parses exported text. Returns a list of rules, or nil and an error message.
function Rules:Parse(text)
    local rules = {}
    local lineNo = 0
    for line in (tostring(text or "") .. "\n"):gmatch("(.-)\r?\n") do
        lineNo = lineNo + 1
        line = strtrim(line)
        if line ~= "" and line:sub(1, 1) ~= "#" then
            local fields = {}
            for f in (line .. ";"):gmatch("([^;]*);") do
                fields[#fields + 1] = strtrim(f)
            end
            if fields[1] == "" then
                return nil, "line " .. lineNo .. " has no spell name"
            end
            local rule = { spell = fields[1], extras = {}, rebuff = 0, mine = false, enabled = true }
            for j = 2, #fields do
                local k, v = fields[j]:match("^(%a+)%s*=%s*(.*)$")
                k = (k or fields[j]):lower()
                if k == "also" then
                    rule.extras = ns.SplitList(v)
                elseif k == "rebuff" then
                    rule.rebuff = ns.Clamp(tonumber(v) or 0, 0, 3600)
                elseif k == "mine" then
                    rule.mine = true
                elseif k == "off" then
                    rule.enabled = false
                elseif k ~= "" then
                    return nil, "line " .. lineNo .. ": unknown option \"" .. fields[j] .. "\""
                end
            end
            rules[#rules + 1] = rule
        end
    end
    if #rules == 0 then return nil, "no buffs found" end
    return rules
end

-- mode: "replace" or "add" (skips buffs already tracked). Returns count added.
function Rules:Import(text, mode)
    local rules, err = self:Parse(text)
    if not rules then return nil, err end
    if mode == "replace" then
        ns.char.buffs = rules
        Changed()
        return #rules
    end
    local added = 0
    for _, rule in ipairs(rules) do
        if not self:Find(rule.spell) then
            ns.char.buffs[#ns.char.buffs + 1] = rule
            added = added + 1
        end
    end
    Changed()
    return added
end
