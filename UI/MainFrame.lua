-- IncahootsCoA: UI/MainFrame.lua
-- The main window: page list on the left, the page on the right.
-- Pages register with Config:RegisterPage and are built the first time
-- they're opened. Also adds an Interface > AddOns entry.

local addonName, ns = ...
local UI = ns.UI
local Config = {}
ns.Config = Config

local WIDTH, HEIGHT = 820, 580
local SIDEBAR_WIDTH = 150

local pageDefs, pageByKey = {}, {}
local frame, content, subtitle
local navButtons = {}
local current

function Config:RegisterPage(key, title, build)
    local def = { key = key, title = title, build = build }
    pageDefs[#pageDefs + 1] = def
    pageByKey[key] = def
end

local function MakeNavButton(parent, def)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(SIDEBAR_WIDTH - 16, 24)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetPoint("LEFT", 10, 0)
    b.text:SetText(def.title)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints()
    b.sel:SetTexture(1, 0.82, 0, 0.25)
    b.sel:Hide()
    b:SetScript("OnClick", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        Config:Select(def.key)
    end)
    return b
end

local function Build()
    frame = CreateFrame("Frame", "IncahootsCoAWindow", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetBackdrop(UI.DIALOG_BACKDROP)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnShow", function() PlaySound("igMainMenuOpen") end)
    frame:SetScript("OnHide", function()
        PlaySound("igMainMenuClose")
        CloseDropDownMenus()
    end)
    tinsert(UISpecialFrames, "IncahootsCoAWindow") -- Escape closes it

    local header = frame:CreateTexture(nil, "ARTWORK")
    header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    header:SetSize(320, 64)
    header:SetPoint("TOP", 0, 12)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", header, "TOP", 0, -14)
    title:SetText("IncahootsCoA")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    local sidebar = UI.Panel(frame)
    sidebar:SetPoint("TOPLEFT", 16, -32)
    sidebar:SetPoint("BOTTOMLEFT", 16, 16)
    sidebar:SetWidth(SIDEBAR_WIDTH)

    content = UI.Panel(frame)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, 0)
    content:SetPoint("BOTTOMRIGHT", -16, 16)
    content:SetBackdropColor(0, 0, 0, 0.35)

    subtitle = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOPLEFT", 10, -10)
    subtitle:SetPoint("RIGHT", -8, 0)
    subtitle:SetJustifyH("LEFT")

    local y = -36
    for _, def in ipairs(pageDefs) do
        local b = MakeNavButton(sidebar, def)
        b:SetPoint("TOPLEFT", 8, y)
        navButtons[def.key] = b
        y = y - 26
    end

    local version = sidebar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    version:SetPoint("BOTTOM", 0, 10)
    version:SetText("v" .. ns.version .. "  -  /ich")
end

function Config:Select(key)
    local def = pageByKey[key] or pageDefs[1]
    for k, d in pairs(pageByKey) do
        if d.page then d.page:Hide() end
        UI.Toggle(navButtons[k].sel, k == def.key)
    end
    if not def.page then
        def.page = UI.NewPage(content)
        def.build(def.page)
    end
    current = def
    subtitle:SetText((UnitName("player") or "") .. "\n|cffffffff" .. (ns.char.className or "") .. "|r")
    def.page:Show()
    def.page:Refresh()
    return def.page
end

function Config:Open(key)
    if not frame then Build() end
    frame:Show()
    return self:Select(key or (current and current.key) or pageDefs[1].key)
end

function Config:Toggle(key)
    if frame and frame:IsShown() and (not key or (current and current.key == key)) then
        frame:Hide()
    else
        self:Open(key)
    end
end

function Config:IsOpen()
    return frame ~= nil and frame:IsShown()
end

function Config:CurrentKey()
    return self:IsOpen() and current and current.key or nil
end

function Config:Refresh()
    if self:IsOpen() and current and current.page then
        current.page:Refresh()
    end
end

function Config:GetPage(key)
    local def = pageByKey[key]
    return def and def.page
end

ns.On("LOCK_CHANGED", function() Config:Refresh() end)
ns.On("DISPLAY_CHANGED", function() Config:Refresh() end)

-- ============================================================================
-- Interface > AddOns entry
-- ============================================================================
local panel = CreateFrame("Frame")
panel.name = "IncahootsCoA"
panel:Hide()

local panelTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
panelTitle:SetPoint("TOPLEFT", 16, -16)
panelTitle:SetText("IncahootsCoA")

local panelText = UI.Text(panel, "Track your own buffs and cast them with one click. Everything is set up in the IncahootsCoA window.", 380, "GameFontHighlight")
panelText:SetPoint("TOPLEFT", panelTitle, "BOTTOMLEFT", 0, -8)

local panelButton = UI.Button(panel, "Open IncahootsCoA", 170, function()
    if InterfaceOptionsFrame then HideUIPanel(InterfaceOptionsFrame) end
    if GameMenuFrame then HideUIPanel(GameMenuFrame) end
    Config:Open()
end)
panelButton:SetPoint("TOPLEFT", panelText, "BOTTOMLEFT", 0, -12)

InterfaceOptions_AddCategory(panel)
