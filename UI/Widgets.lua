-- IncahootsCoA: UI/Widgets.lua
-- Controls for the window, built only from templates that ship with the
-- 3.3.5 client (no libraries needed).
--
-- Controls take an options table:
--   label, tooltip   text on the control and in its tooltip
--   get()            returns the current value
--   set(value)       stores a new value
--   disabled()       optional; return true to grey the control out
-- Each control registers with its page, and page:Refresh() re-reads them all,
-- so the window never keeps its own copy of a setting.

local addonName, ns = ...
local UI = {}
ns.UI = UI

local counter = 0
function UI.NewName(kind)
    counter = counter + 1
    return "IncahootsCoA" .. (kind or "Widget") .. counter
end

UI.PANEL_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

UI.DIALOG_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

-- The 3.3.5 client has no SetShown / SetEnabled.
function UI.Toggle(region, show)
    if show then region:Show() else region:Hide() end
end

function UI.SetEnabled(button, enabled)
    if enabled then button:Enable() else button:Disable() end
end

-- Dark inset box.
function UI.Panel(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetBackdrop(UI.PANEL_BACKDROP)
    f:SetBackdropColor(0, 0, 0, 0.5)
    f:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    return f
end

-- ============================================================================
-- PAGES
-- ============================================================================
function UI.NewPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.controls = {}
    function page:Refresh()
        if self.BeforeRefresh then self:BeforeRefresh() end
        for _, c in ipairs(self.controls) do
            c:Refresh()
        end
    end
    return page
end

local function FindPage(frame)
    while frame do
        if frame.controls then return frame end
        frame = frame:GetParent()
    end
end

function UI.Track(parent, widget)
    local page = FindPage(parent)
    if page then
        page.controls[#page.controls + 1] = widget
        widget.page = page
    end
    return widget
end

-- Run fn every time the page refreshes.
function UI.OnRefresh(parent, fn)
    return UI.Track(parent, { Refresh = fn })
end

local function RefreshPage(widget)
    if widget.page then widget.page:Refresh() end
end

function UI.AttachTooltip(frame, title, text)
    if not text then return end
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title or "", 1, 1, 1)
        GameTooltip:AddLine(text, 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", GameTooltip_Hide)
end

-- ============================================================================
-- LAYOUT: places widgets top to bottom. Widgets may carry hints:
--   _top (space for a label above), _h (height), _x (horizontal nudge)
-- ============================================================================
function UI.Stack(parent, x, y, gap)
    local st = { x = x or 16, y = y or 16, gap = gap or 8 }
    function st:Add(widget, height, indent)
        self.y = self.y + (widget._top or 0)
        widget:ClearAllPoints()
        widget:SetPoint("TOPLEFT", parent, "TOPLEFT", self.x + (indent or 0) + (widget._x or 0), -self.y)
        self.y = self.y + (height or widget._h or widget:GetHeight()) + self.gap
        return widget
    end
    function st:Space(h)
        self.y = self.y + h
    end
    return st
end

-- ============================================================================
-- TEXT
-- ============================================================================
function UI.Header(parent, text, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width or 260, 22)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.text:SetPoint("BOTTOMLEFT", 0, 6)
    f.text:SetPoint("RIGHT", 0, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetText(text)
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetTexture(1, 0.82, 0, 0.35)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 0, 2)
    line:SetPoint("BOTTOMRIGHT", 0, 2)
    f._h = 22
    return f
end

function UI.Text(parent, text, width, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetWidth(width or 260)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetText(text or "")
    return fs
end

-- ============================================================================
-- BUTTONS
-- ============================================================================
function UI.Button(parent, text, width, onClick, tooltip)
    local b = CreateFrame("Button", UI.NewName("Button"), parent, "UIPanelButtonTemplate")
    b:SetSize(width or 100, 22)
    b:SetText(text)
    if onClick then b:SetScript("OnClick", onClick) end
    if tooltip then UI.AttachTooltip(b, text, tooltip) end
    b._h = 22
    return b
end

-- defs: { { text, width, onClick, tooltip }, ... }
function UI.ButtonRow(parent, defs)
    local f = CreateFrame("Frame", nil, parent)
    f.buttons = {}
    local x = 0
    for i, d in ipairs(defs) do
        local b = UI.Button(f, d[1], d[2], d[3], d[4])
        b:SetPoint("LEFT", f, "LEFT", x, 0)
        x = x + (d[2] or 100) + 6
        f.buttons[i] = b
    end
    f:SetSize(math.max(x - 6, 1), 22)
    f._h = 22
    return f
end

function UI.ArrowButton(parent, dir, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)
    local base = (dir == "up") and "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-"
        or "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-"
    b:SetNormalTexture(base .. "Up")
    b:SetPushedTexture(base .. "Down")
    b:SetDisabledTexture(base .. "Disabled")
    b:SetHighlightTexture(base .. "Highlight", "ADD")
    b:SetScript("OnClick", onClick)
    return b
end

-- ============================================================================
-- CHECKBOX
-- ============================================================================
function UI.Check(parent, o)
    local name = UI.NewName("Check")
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb.text = _G[name .. "Text"]
    cb.text:SetFontObject(GameFontHighlight)
    cb.text:SetText(o.label)
    cb:SetHitRectInsets(0, -math.min(cb.text:GetStringWidth() + 6, 300), 0, 0)
    cb:SetScript("OnClick", function(self)
        local v = self:GetChecked() and true or false
        PlaySound(v and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
        o.set(v)
        RefreshPage(self)
    end)
    if o.tooltip then UI.AttachTooltip(cb, o.label, o.tooltip) end
    function cb:Refresh()
        self:SetChecked(o.get() and true or false)
        local off = o.disabled and o.disabled()
        UI.SetEnabled(self, not off)
        if off then self.text:SetTextColor(0.5, 0.5, 0.5) else self.text:SetTextColor(1, 1, 1) end
    end
    cb._h = 24
    return UI.Track(parent, cb)
end

-- ============================================================================
-- SLIDER  (o.min, o.max, o.step, o.width, o.fmt(value) -> text, o.lowText, o.highText)
-- ============================================================================
function UI.Slider(parent, o)
    local name = UI.NewName("Slider")
    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    local step = o.step or 1
    local function Fmt(v)
        if o.fmt then return o.fmt(v) end
        return tostring(v)
    end
    local function Round(v)
        v = math.floor(v / step + 0.5) * step
        return tonumber(string.format("%.2f", v))
    end

    s:SetWidth(o.width or 200)
    s:SetMinMaxValues(o.min, o.max)
    s:SetValueStep(step)
    _G[name .. "Low"]:SetText(o.lowText or Fmt(o.min))
    _G[name .. "High"]:SetText(o.highText or Fmt(o.max))
    s.label = _G[name .. "Text"]

    s:SetScript("OnValueChanged", function(self, v)
        v = Round(v)
        self.label:SetText(o.label .. ": |cffffffff" .. Fmt(v) .. "|r")
        if self.updating or v == self.last then return end
        self.last = v
        o.set(v)
    end)
    if o.tooltip then UI.AttachTooltip(s, o.label, o.tooltip) end

    function s:Refresh()
        local v = o.get() or o.min
        self.updating = true
        self.last = v
        self:SetValue(v)
        self.label:SetText(o.label .. ": |cffffffff" .. Fmt(v) .. "|r")
        self.updating = false
        local off = o.disabled and o.disabled()
        self:EnableMouse(not off)
        self:SetAlpha(off and 0.5 or 1)
    end
    s._top, s._h, s._x = 16, 30, 4
    return UI.Track(parent, s)
end

-- ============================================================================
-- EDIT BOX  (o.width, o.numeric). Saves on Enter or when focus leaves; Escape cancels.
-- ============================================================================
function UI.Edit(parent, o)
    local e = CreateFrame("EditBox", UI.NewName("Edit"), parent, "InputBoxTemplate")
    e:SetSize(o.width or 160, 20)
    e:SetAutoFocus(false)
    e:SetMaxLetters(o.maxLetters or 200)
    if o.numeric then e:SetNumeric(true) end

    e.label = e:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    e.label:SetPoint("BOTTOMLEFT", e, "TOPLEFT", -4, 3)
    e.label:SetText(o.label or "")

    e:SetScript("OnEditFocusGained", function(self)
        self.focused = true
        self:HighlightText()
    end)
    e:SetScript("OnEditFocusLost", function(self)
        self.focused = false
        self:HighlightText(0, 0)
        if self.cancel then
            self.cancel = nil
            self:Refresh()
            return
        end
        local text = strtrim(self:GetText() or "")
        if text ~= (o.get() or "") then
            o.set(text)
            RefreshPage(self)
        end
    end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEscapePressed", function(self)
        self.cancel = true
        self:ClearFocus()
    end)
    if o.tooltip then UI.AttachTooltip(e, o.label, o.tooltip) end

    function e:Refresh()
        if not self.focused then
            self:SetText(o.get() or "")
            self:SetCursorPosition(0)
        end
        local off = o.disabled and o.disabled()
        self:EnableMouse(not off)
        self:SetAlpha(off and 0.5 or 1)
    end
    e._top, e._h, e._x = 14, 22, 6
    return UI.Track(parent, e)
end

-- Search box: calls onChange(text) as you type. Not tied to a setting.
function UI.Search(parent, width, placeholder, onChange)
    local e = CreateFrame("EditBox", UI.NewName("Search"), parent, "InputBoxTemplate")
    e:SetSize(width or 160, 20)
    e:SetAutoFocus(false)
    e.hint = e:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    e.hint:SetPoint("LEFT", 2, 0)
    e.hint:SetText(placeholder or "Search")
    e:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        UI.Toggle(self.hint, text == "" and not self.focused)
        onChange(text)
    end)
    e:SetScript("OnEditFocusGained", function(self)
        self.focused = true
        self.hint:Hide()
    end)
    e:SetScript("OnEditFocusLost", function(self)
        self.focused = false
        UI.Toggle(self.hint, (self:GetText() or "") == "")
    end)
    e:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    e._top, e._h, e._x = 0, 22, 6
    return e
end

-- ============================================================================
-- DROPDOWN  (o.items() -> { { value =, text = }, ... }, o.width, o.placeholder)
-- ============================================================================
function UI.Dropdown(parent, o)
    local dd = CreateFrame("Frame", UI.NewName("Dropdown"), parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dd, o.width or 150)

    dd.label = dd:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dd.label:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 18, 2)
    dd.label:SetText(o.label or "")

    UIDropDownMenu_Initialize(dd, function(self, level)
        local current = o.get()
        for _, item in ipairs(o.items()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.text
            info.value = item.value
            info.checked = (item.value == current)
            info.func = function()
                o.set(item.value)
                dd:Refresh()
                RefreshPage(dd)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    if o.tooltip then UI.AttachTooltip(dd, o.label, o.tooltip) end

    function dd:Refresh()
        local current = o.get()
        local text = o.placeholder or ""
        for _, item in ipairs(o.items()) do
            if item.value == current then
                text = item.text
                break
            end
        end
        UIDropDownMenu_SetText(self, text)
        if o.disabled and o.disabled() then
            UIDropDownMenu_DisableDropDown(self)
        else
            UIDropDownMenu_EnableDropDown(self)
        end
    end
    dd._top, dd._h, dd._x = 14, 30, -16
    return UI.Track(parent, dd)
end

-- A menu at the cursor. items: { { text, icon, func, isTitle, disabled }, ... }
local menuFrame
function UI.Menu(items)
    menuFrame = menuFrame or CreateFrame("Frame", "IncahootsCoAMenu", UIParent, "UIDropDownMenuTemplate")
    local menu = {}
    for i, item in ipairs(items) do
        menu[i] = {
            text = item.text, icon = item.icon, func = item.func,
            isTitle = item.isTitle, disabled = item.disabled, notCheckable = true,
        }
    end
    menu[#menu + 1] = { text = CANCEL, notCheckable = true, func = function() CloseDropDownMenus() end }
    EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU")
end

-- ============================================================================
-- SCROLLING LIST
--   o.width, o.rows, o.rowHeight
--   o.count()              number of items
--   o.setup(row)           build a row's children once
--   o.update(row, index)   fill a row for item `index`
--   o.selected(index)      optional; true highlights the row
-- ============================================================================
function UI.List(parent, o)
    local rows, rowH = o.rows or 10, o.rowHeight or 22
    local f = UI.Panel(parent)
    f:SetSize(o.width, rows * rowH + 8)

    local sname = UI.NewName("Scroll")
    local sf = CreateFrame("ScrollFrame", sname, f, "FauxScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 4, -4)
    sf:SetPoint("BOTTOMRIGHT", -26, 4)

    f.rows = {}
    for i = 1, rows do
        local row = CreateFrame("Button", nil, f)
        row:SetSize(o.width - 32, rowH)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -4 - (i - 1) * rowH)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.sel = row:CreateTexture(nil, "BACKGROUND")
        row.sel:SetAllPoints()
        row.sel:SetTexture(1, 0.82, 0, 0.2)
        row.sel:Hide()
        o.setup(row)
        f.rows[i] = row
    end

    function f:Refresh()
        local n = o.count()
        FauxScrollFrame_Update(sf, n, rows, rowH)
        local offset = FauxScrollFrame_GetOffset(sf)
        for i, row in ipairs(self.rows) do
            local index = offset + i
            if index <= n then
                row.index = index
                o.update(row, index)
                UI.Toggle(row.sel, o.selected and o.selected(index))
                row:Show()
            else
                row.index = nil
                row:Hide()
            end
        end
    end

    sf:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, rowH, function() f:Refresh() end)
    end)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        if sf:IsShown() then
            local bar = _G[sname .. "ScrollBar"]
            bar:SetValue(bar:GetValue() - delta * rowH * 3)
        end
    end)

    function f:ScrollTo(index)
        local offset = FauxScrollFrame_GetOffset(sf)
        local bar = _G[sname .. "ScrollBar"]
        if index <= offset then
            bar:SetValue((index - 1) * rowH)
        elseif index > offset + rows then
            bar:SetValue((index - rows) * rowH)
        end
    end

    function f:ScrollToTop()
        _G[sname .. "ScrollBar"]:SetValue(0)
        sf.offset = 0
    end

    return UI.Track(parent, f)
end

-- ============================================================================
-- POPUPS
-- ============================================================================
StaticPopupDialogs["INCAHOOTSCOA_CONFIRM"] = {
    text = "%s",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        if data then data() end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

function UI.Confirm(text, onYes)
    local dialog = StaticPopup_Show("INCAHOOTSCOA_CONFIRM", text)
    if dialog then dialog.data = onYes end
end

local function PromptAccept(dialog)
    local eb = _G[dialog:GetName() .. "EditBox"]
    if dialog.data then dialog.data(strtrim(eb:GetText() or "")) end
end

StaticPopupDialogs["INCAHOOTSCOA_PROMPT"] = {
    text = "%s",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 80,
    OnAccept = function(self)
        PromptAccept(self)
    end,
    EditBoxOnEnterPressed = function(self)
        local dialog = self:GetParent()
        PromptAccept(dialog)
        dialog:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

function UI.Prompt(text, default, onAccept)
    local dialog = StaticPopup_Show("INCAHOOTSCOA_PROMPT", text)
    if dialog then
        dialog.data = onAccept
        local eb = _G[dialog:GetName() .. "EditBox"]
        eb:SetText(default or "")
        eb:SetFocus()
        eb:HighlightText()
    end
end

-- ============================================================================
-- TEXT WINDOW (import / export)
-- UI.ShowText({ title, hint, text, buttons = { { text, onClick(text) -> true to close } } })
-- ============================================================================
local textDialog

local function BuildTextDialog()
    local f = CreateFrame("Frame", "IncahootsCoATextDialog", UIParent)
    f:SetSize(560, 420)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetBackdrop(UI.DIALOG_BACKDROP)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -20)
    f.hint = UI.Text(f, "", 510)
    f.hint:SetPoint("TOPLEFT", 24, -44)

    local box = UI.Panel(f)
    box:SetPoint("TOPLEFT", 20, -78)
    box:SetPoint("BOTTOMRIGHT", -20, 52)

    local sf = CreateFrame("ScrollFrame", "IncahootsCoATextDialogScroll", box, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 8, -8)
    sf:SetPoint("BOTTOMRIGHT", -28, 8)

    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(470)
    eb:SetHeight(260)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnTextChanged", function(self) ScrollingEdit_OnTextChanged(self, sf) end)
    eb:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged)
    eb:SetScript("OnUpdate", function(self, elapsed) ScrollingEdit_OnUpdate(self, elapsed, sf) end)
    sf:SetScrollChild(eb)
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function() eb:SetFocus() end)
    f.edit = eb

    f.close = UI.Button(f, CLOSE, 100, function() f:Hide() end)
    f.close:SetPoint("BOTTOMRIGHT", -22, 20)
    f.extra = {}

    tinsert(UISpecialFrames, "IncahootsCoATextDialog")
    f:Hide()
    return f
end

function UI.ShowText(o)
    textDialog = textDialog or BuildTextDialog()
    local f = textDialog
    f.title:SetText(o.title or "")
    f.hint:SetText(o.hint or "")
    f.edit:SetText(o.text or "")
    for _, b in ipairs(f.extra) do b:Hide() end
    local previous = f.close
    for i, def in ipairs(o.buttons or {}) do
        local b = f.extra[i]
        if not b then
            b = UI.Button(f, "", 130)
            f.extra[i] = b
        end
        b:SetText(def[1])
        b:SetScript("OnClick", function()
            if def[2](f.edit:GetText() or "") then f:Hide() end
        end)
        b:ClearAllPoints()
        b:SetPoint("RIGHT", previous, "LEFT", -8, 0)
        b:Show()
        previous = b
    end
    f:Show()
    f.edit:SetFocus()
    if o.text and o.text ~= "" then f.edit:HighlightText() end
end
