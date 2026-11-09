-- IncahootsCoA: Buffs/Display.lua
-- The on-screen buff buttons. Each one casts its spell on you when clicked.
--
-- "missing" mode shows a button for each buff you need.
-- "all" mode shows every tracked buff; the ones you have are faded with their
-- time left, so the buttons never move and can be clicked in combat to
-- refresh a buff.
--
-- WoW only lets addons change click-to-cast buttons out of combat. In combat
-- the buttons keep their spells; their look (fade, border, timer) still
-- updates, and the layout catches up when combat ends.
--
-- A hidden button, IncahootsCoANextBuff, always holds the first buff you need.
-- Key Bindings > IncahootsCoA > "Cast next missing buff" clicks it.

local addonName, ns = ...
local Display = ns.NewModule("Display")
local Tracker = ns.Tracker

local MAX_BUTTONS = 24
local ICON_TEST = "Interface\\Icons\\Spell_Holy_WordFortitude"

local cfg
local testMode = false
local buttons = {}
local assigned = {} -- [buttonIndex] = rule
local shownCount = 0

local CORNER = { RIGHT = "TOPLEFT", DOWN = "TOPLEFT", LEFT = "TOPRIGHT", UP = "BOTTOMLEFT" }

-- ============================================================================
-- ANCHOR AND MOVER
-- ============================================================================
local anchor = CreateFrame("Frame", "IncahootsCoABuffAnchor", UIParent)
anchor:SetSize(36, 36)
anchor:SetPoint("CENTER", 0, -140)

local mover = CreateFrame("Frame", nil, anchor)
mover:SetPoint("TOPLEFT", -4, 4)
mover:SetPoint("BOTTOMRIGHT", 4, -4)
mover:SetFrameStrata("DIALOG")
mover:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
mover:SetBackdropColor(0.1, 0.6, 0.3, 0.45)
mover:SetBackdropBorderColor(0.2, 1, 0.5, 0.9)
mover:EnableMouse(true)
mover.text = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
mover.text:SetPoint("CENTER")
mover.text:SetText("Buffs")
mover:Hide()
mover:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("IncahootsCoA buff buttons")
    GameTooltip:AddLine("Drag to move. Lock the buttons in the window (/ich) to hide this box.", 1, 1, 1, true)
    GameTooltip:Show()
end)
mover:SetScript("OnLeave", GameTooltip_Hide)

-- ============================================================================
-- BUTTONS
-- ============================================================================
local STATE_TEXT = {
    missing = "|cffff5555Missing|r",
    expiring = "|cffffd200Running out|r",
    active = "|cff55ff55Active|r",
}

local function ButtonOnEnter(self)
    if not cfg.showTooltips then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if testMode then
        GameTooltip:SetText("Test button")
        GameTooltip:AddLine("Drag the green box to move the buttons.", 1, 1, 1, true)
    else
        local rule = assigned[self.index]
        local st = rule and Tracker:StatusOf(rule)
        if not st then return end
        GameTooltip:SetText(rule.spell)
        local remaining = Tracker:Remaining(st)
        local line = STATE_TEXT[st.state] or st.state
        if remaining and remaining ~= math.huge then
            line = line .. "  " .. ns.FormatTime(remaining, true) .. " left"
        end
        GameTooltip:AddLine(line, 1, 1, 1)
        if st.buff and st.buff ~= rule.spell then
            GameTooltip:AddLine("Buff: " .. st.buff, 0.8, 0.8, 0.8)
        end
        GameTooltip:AddLine("Click to cast on yourself", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function CreateButton(i)
    local b = CreateFrame("Button", "IncahootsCoABuffButton" .. i, anchor, "SecureActionButtonTemplate")
    b.index = i
    b:SetSize(36, 36)
    b:RegisterForClicks("LeftButtonUp")
    b:SetAttribute("type", "spell")
    b:SetAttribute("unit", "player")
    b:Hide()

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", -1, 1)
    bg:SetPoint("BOTTOMRIGHT", 1, -1)
    bg:SetTexture(0, 0, 0, 1)

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    b.glow = b:CreateTexture(nil, "OVERLAY")
    b.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    b.glow:SetBlendMode("ADD")
    b.glow:SetPoint("CENTER")
    b.glow:Hide()

    b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints(b.icon)

    b.timer = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.timer:SetPoint("BOTTOM", 0, 2)

    b:SetScript("OnEnter", ButtonOnEnter)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

for i = 1, MAX_BUTTONS do
    buttons[i] = CreateButton(i)
end

local nextBuff = CreateFrame("Button", "IncahootsCoANextBuff", UIParent, "SecureActionButtonTemplate")
nextBuff:SetAttribute("type", "spell")
nextBuff:SetAttribute("unit", "player")
nextBuff:Hide()

-- ============================================================================
-- LOOK (safe in combat)
-- ============================================================================
local function UpdateCooldown(b)
    local rule = assigned[b.index]
    if rule and not testMode then
        local start, duration, enable = GetSpellCooldown(rule.spell)
        if start then
            CooldownFrame_SetTimer(b.cooldown, start, duration, enable)
            return
        end
    end
    b.cooldown:Hide()
end

local function UpdateLook(b)
    if testMode then
        b:SetAlpha(1)
        b.glow:Hide()
        b.timer:SetText("")
        return
    end
    local rule = assigned[b.index]
    local st = rule and Tracker:StatusOf(rule)
    if not st then return end

    local need = Tracker.NeedsCast(st.state)
    b:SetAlpha(need and 1 or cfg.activeAlpha)

    if cfg.showBorders and need then
        if st.state == "expiring" then
            b.glow:SetVertexColor(1, 0.82, 0)
        else
            b.glow:SetVertexColor(1, 0.15, 0.15)
        end
        b.glow:Show()
    else
        b.glow:Hide()
    end

    local remaining = Tracker:Remaining(st)
    if cfg.showTimers and remaining and remaining ~= math.huge then
        b.timer:SetText(ns.FormatTime(remaining))
        if st.state == "expiring" then b.timer:SetTextColor(1, 0.82, 0) else b.timer:SetTextColor(1, 1, 1) end
    else
        b.timer:SetText("")
    end

    -- not enough mana / can't be used right now
    local usable, noMana = IsUsableSpell(rule.spell)
    if noMana then
        b.icon:SetVertexColor(0.5, 0.5, 1)
    elseif not usable then
        b.icon:SetVertexColor(0.4, 0.4, 0.4)
    else
        b.icon:SetVertexColor(1, 1, 1)
    end
end

local function UpdateAllLooks()
    for i = 1, shownCount do
        UpdateLook(buttons[i])
    end
end

-- ============================================================================
-- LAYOUT (out of combat only)
-- ============================================================================
local function PlaceButtons()
    local size, gap, perRow = cfg.size, cfg.spacing, math.max(1, cfg.perRow)
    for i, b in ipairs(buttons) do
        local col = (i - 1) % perRow
        local row = math.floor((i - 1) / perRow)
        local along, across = col * (size + gap), row * (size + gap)
        b:SetSize(size, size)
        b.glow:SetSize(size * 1.8, size * 1.8)
        b:ClearAllPoints()
        if cfg.grow == "LEFT" then
            b:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -along, -across)
        elseif cfg.grow == "DOWN" then
            b:SetPoint("TOPLEFT", anchor, "TOPLEFT", across, -along)
        elseif cfg.grow == "UP" then
            b:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", across, along)
        else
            b:SetPoint("TOPLEFT", anchor, "TOPLEFT", along, -across)
        end
    end
end

local function SizeAnchor(n)
    n = math.max(n, 1)
    local size, gap, perRow = cfg.size, cfg.spacing, math.max(1, cfg.perRow)
    local alongCount = math.min(n, perRow)
    local acrossCount = math.ceil(n / perRow)
    local along = alongCount * size + (alongCount - 1) * gap
    local across = acrossCount * size + (acrossCount - 1) * gap
    if cfg.grow == "DOWN" or cfg.grow == "UP" then
        anchor:SetSize(across, along)
    else
        anchor:SetSize(along, across)
    end
end

local function Suppressed()
    if UnitIsDeadOrGhost("player") then return true end
    if cfg.hideVehicle and (UnitOnTaxi("player") or UnitInVehicle("player") or UnitHasVehicleUI("player")) then return true end
    if cfg.hideMounted and IsMounted() then return true end
    if cfg.hideResting and IsResting() then return true end
    return false
end

-- Decide which buffs get a button and load them. Out of combat only.
local function Rebuild()
    if InCombatLockdown() then
        UpdateAllLooks()
        ns.RunAfterCombat(Rebuild)
        return
    end

    local list = {}
    if testMode then
        for i = 1, math.min(cfg.maxButtons, 4) do list[i] = false end
    elseif cfg.enabled and not Suppressed() then
        for _, st in ipairs(Tracker:GetStatuses()) do
            if Tracker.NeedsCast(st.state) or (cfg.mode == "all" and st.state == "active") then
                list[#list + 1] = st.rule
            end
        end
    end

    local n = math.min(#list, cfg.maxButtons, MAX_BUTTONS)
    for i, b in ipairs(buttons) do
        local rule = (i <= n) and list[i] or nil
        assigned[i] = rule or nil
        if i <= n then
            if rule then
                local st = Tracker:StatusOf(rule)
                b.icon:SetTexture(st and st.icon)
                if b:GetAttribute("spell") ~= rule.spell then b:SetAttribute("spell", rule.spell) end
            else
                b.icon:SetTexture(ICON_TEST)
                b:SetAttribute("spell", nil)
            end
            b:Show()
            UpdateLook(b)
            UpdateCooldown(b)
        else
            b:SetAttribute("spell", nil)
            b:Hide()
        end
    end
    shownCount = n
    SizeAnchor(n)

    -- the keybind button gets the first buff you need
    local first
    if not testMode and cfg.enabled then
        for _, st in ipairs(Tracker:GetStatuses()) do
            if Tracker.NeedsCast(st.state) then
                first = st.rule.spell
                break
            end
        end
    end
    nextBuff:SetAttribute("spell", first)
end

-- ============================================================================
-- PUBLIC
-- ============================================================================
function Display:UpdateMover()
    if cfg.enabled and not ns.IsLocked() and not InCombatLockdown() then
        mover:Show()
    else
        mover:Hide()
    end
end

-- Re-read every setting.
function Display:Apply()
    cfg = ns.char.display
    ns.RunAfterCombat(function()
        anchor:SetScale(cfg.scale)
        ns.RestorePoint(anchor, cfg.point)
        PlaceButtons()
        Rebuild()
        ns.AnchorToCorner(anchor, cfg.point, CORNER[cfg.grow] or "TOPLEFT")
        if cfg.hideInCombat then
            RegisterStateDriver(anchor, "visibility", "[combat] hide; show")
        else
            UnregisterStateDriver(anchor, "visibility")
            anchor:Show()
        end
        Display:UpdateMover()
    end)
end

function Display:IsTesting()
    return testMode
end

function Display:SetTest(on)
    if InCombatLockdown() then
        ns.Print("Test buttons can't be changed in combat.")
        return
    end
    testMode = on and true or false
    Rebuild()
end

function Display:ToggleTest()
    self:SetTest(not testMode)
end

function Display:ResetPosition()
    cfg.point = ns.CopyTable(ns.DB.defaults.char.display.point)
    self:Apply()
end

-- ============================================================================
-- LIFECYCLE
-- ============================================================================
function Display:OnEnable()
    self:Apply()

    local RequestRebuild = ns.Throttle(0.1, Rebuild)
    ns.On("STATUS_UPDATED", function()
        if InCombatLockdown() then UpdateAllLooks() else RequestRebuild() end
    end)
    ns.On("DISPLAY_CHANGED", function() Display:Apply() end)
    ns.On("LOCK_CHANGED", function() Display:UpdateMover() end)

    for _, event in ipairs({
        "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_UPDATE_RESTING",
        "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", -- taxis
        "COMPANION_UPDATE",                             -- mounting
    }) do
        ns.RegisterEvent(event, RequestRebuild)
    end
    ns.RegisterEvent("UNIT_ENTERED_VEHICLE", function(_, unit) if unit == "player" then RequestRebuild() end end)
    ns.RegisterEvent("UNIT_EXITED_VEHICLE", function(_, unit) if unit == "player" then RequestRebuild() end end)
    ns.RegisterEvent("SPELL_UPDATE_COOLDOWN", function()
        for i = 1, shownCount do UpdateCooldown(buttons[i]) end
    end)
    ns.RegisterEvent("PLAYER_REGEN_DISABLED", function() mover:Hide() end)
    ns.RegisterEvent("PLAYER_REGEN_ENABLED", function()
        Display:UpdateMover()
        RequestRebuild()
    end)

    -- timers and mana tint
    local ticker = CreateFrame("Frame")
    local elapsedTotal = 0
    ticker:SetScript("OnUpdate", function(_, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal < 0.25 then return end
        elapsedTotal = 0
        UpdateAllLooks()
    end)
end
