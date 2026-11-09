-- IncahootsCoA: Core/Init.lua
-- Foundation used by every other file:
--   * printing and small helpers
--   * frame position helpers
--   * an internal message bus (ns.On / ns.Fire)
--   * one shared game-event frame (ns.RegisterEvent)
--   * modules with OnInitialize / OnEnable
--   * a timer and a throttle (the 3.3.5 client has no C_Timer)
--   * a queue for work that must wait until combat ends

local addonName, ns = ...
IncahootsCoA = ns -- global handle, handy for /run and other addons

ns.name = addonName
ns.version = GetAddOnMetadata(addonName, "Version") or "dev"

local floor, ceil = math.floor, math.ceil

-- ============================================================================
-- OUTPUT
-- ============================================================================
function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99IncahootsCoA|r: " .. tostring(msg))
end

-- Only prints when debug messages are switched on (General page).
function ns.Debug(msg)
    if ns.char and ns.char.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff999999[IncahootsCoA]|r " .. tostring(msg))
    end
end

-- ============================================================================
-- HELPERS
-- ============================================================================
function ns.CopyTable(src)
    local t = {}
    for k, v in pairs(src) do
        t[k] = (type(v) == "table") and ns.CopyTable(v) or v
    end
    return t
end

-- Fill in anything missing from dst using src, recursively. Never overwrites.
function ns.ApplyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = ns.CopyTable(v)
            else
                ns.ApplyDefaults(dst[k], v)
            end
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function ns.Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- "a, b ,c" -> { "a", "b", "c" }
function ns.SplitList(text)
    local out = {}
    for part in tostring(text or ""):gmatch("[^,]+") do
        part = strtrim(part)
        if part ~= "" then out[#out + 1] = part end
    end
    return out
end

-- Short form for buttons ("12m"), long form for the window ("12m 5s").
function ns.FormatTime(seconds, long)
    if not seconds or seconds == math.huge then
        return long and "no time limit" or ""
    end
    if seconds < 0 then seconds = 0 end
    if long then
        if seconds >= 3600 then
            return string.format("%dh %dm", floor(seconds / 3600), floor(seconds % 3600 / 60))
        elseif seconds >= 60 then
            return string.format("%dm %ds", floor(seconds / 60), floor(seconds % 60))
        end
        return string.format("%ds", ceil(seconds))
    end
    if seconds >= 3600 then return ceil(seconds / 3600) .. "h" end
    if seconds >= 60 then return ceil(seconds / 60) .. "m" end
    return ceil(seconds) .. "s"
end

-- ============================================================================
-- FRAME POSITIONS
-- Saved as { point, relativePoint, x, y } relative to UIParent.
-- ============================================================================
function ns.SavePoint(frame, t)
    local point, _, relPoint, x, y = frame:GetPoint(1)
    t[1], t[2], t[3], t[4] = point, relPoint, floor(x + 0.5), floor(y + 0.5)
end

function ns.RestorePoint(frame, t)
    frame:ClearAllPoints()
    frame:SetPoint(t[1] or "CENTER", UIParent, t[2] or "CENTER", t[3] or 0, t[4] or 0)
end

-- Re-anchor a frame by one of its corners without moving it on screen, so it
-- grows away from that corner when its size changes.
function ns.AnchorToCorner(frame, t, corner)
    local x = corner:find("RIGHT") and frame:GetRight() or frame:GetLeft()
    local y = corner:find("TOP") and frame:GetTop() or frame:GetBottom()
    if not x or not y then return end
    t[1], t[2], t[3], t[4] = corner, "BOTTOMLEFT", floor(x + 0.5), floor(y + 0.5)
    ns.RestorePoint(frame, t)
end

-- handle: what the mouse grabs. target: what moves. getPoint(): table to save into.
function ns.MakeDraggable(handle, target, getPoint, canDrag, onStop)
    target:SetMovable(true)
    target:SetClampedToScreen(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        if canDrag and not canDrag() then return end
        target.ichMoving = true
        target:StartMoving()
    end)
    handle:SetScript("OnDragStop", function()
        if not target.ichMoving then return end
        target.ichMoving = nil
        target:StopMovingOrSizing()
        target:SetUserPlaced(false) -- we save the position ourselves
        ns.SavePoint(target, getPoint())
        if onStop then onStop() end
    end)
end

-- ============================================================================
-- MESSAGE BUS
--   SPELLBOOK_UPDATED  the spellbook was (re)scanned
--   LEARNED_UPDATED    a spell was confirmed as a buff, or a cast->buff link learned
--   RULES_CHANGED      the tracked buff list was edited
--   STATUS_UPDATED     tracked buff states were re-evaluated
--   DISPLAY_CHANGED    button display settings changed
--   LOCK_CHANGED       frames were locked or unlocked
-- ============================================================================
local listeners = {}

function ns.On(msg, fn)
    local list = listeners[msg]
    if not list then
        list = {}
        listeners[msg] = list
    end
    list[#list + 1] = fn
end

function ns.Fire(msg, ...)
    local list = listeners[msg]
    if not list then return end
    for i = 1, #list do
        list[i](...)
    end
end

-- ============================================================================
-- GAME EVENTS. Handlers receive (event, ...).
-- ============================================================================
local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = eventHandlers[event]
    if not list then return end
    for i = 1, #list do
        list[i](event, ...)
    end
end)

function ns.RegisterEvent(event, fn)
    local list = eventHandlers[event]
    if not list then
        list = {}
        eventHandlers[event] = list
        eventFrame:RegisterEvent(event)
    end
    list[#list + 1] = fn
end

-- ============================================================================
-- MODULES: ns.NewModule("Tracker") is reachable as ns.Tracker.
-- OnInitialize runs once saved variables are loaded, OnEnable at login.
-- ============================================================================
ns.modules = {}

function ns.NewModule(name)
    local m = { name = name }
    ns.modules[#ns.modules + 1] = m
    ns[name] = m
    return m
end

local function CallModules(method)
    for _, m in ipairs(ns.modules) do
        if m[method] then m[method](m) end
    end
end

-- ============================================================================
-- TIMER AND THROTTLE
-- ============================================================================
local timers = {}
local timerFrame = CreateFrame("Frame")
timerFrame:Hide()
timerFrame:SetScript("OnUpdate", function(self)
    local now = GetTime()
    for i = #timers, 1, -1 do
        local t = timers[i]
        if now >= t.at then
            table.remove(timers, i)
            t.fn()
        end
    end
    if #timers == 0 then self:Hide() end
end)

function ns.After(delay, fn)
    timers[#timers + 1] = { at = GetTime() + delay, fn = fn }
    timerFrame:Show()
end

-- Returns a function that runs fn at most once per `delay` seconds, no matter
-- how often it's called (events like UNIT_AURA fire in bursts).
function ns.Throttle(delay, fn)
    local pending = false
    local function run()
        pending = false
        fn()
    end
    return function()
        if pending then return end
        pending = true
        ns.After(delay, run)
    end
end

-- ============================================================================
-- COMBAT QUEUE
-- Secure (click-to-cast) buttons can't be changed in combat. Work that
-- touches them goes through here and runs as soon as combat ends.
-- ============================================================================
local combatQueue, combatQueued = {}, {}

function ns.RunAfterCombat(fn)
    if not InCombatLockdown() then
        fn()
        return
    end
    if not combatQueued[fn] then
        combatQueued[fn] = true
        combatQueue[#combatQueue + 1] = fn
    end
end

-- ============================================================================
-- LOCKING
-- ============================================================================
function ns.IsLocked()
    return ns.char.locked
end

function ns.SetLocked(locked)
    ns.char.locked = locked and true or false
    ns.Fire("LOCK_CHANGED")
end

-- ============================================================================
-- STARTUP
-- ============================================================================
ns.RegisterEvent("ADDON_LOADED", function(_, name)
    if name ~= addonName or ns.char then return end
    ns.DB:Init()
    CallModules("OnInitialize")
end)

ns.RegisterEvent("PLAYER_LOGIN", function()
    ns.playerGUID = UnitGUID("player")
    CallModules("OnEnable")
    ns.Fire("READY")
end)

ns.RegisterEvent("PLAYER_REGEN_ENABLED", function()
    local queue = combatQueue
    combatQueue = {}
    wipe(combatQueued)
    for _, fn in ipairs(queue) do
        fn()
    end
end)
