-- IncahootsCoA: UI/Minimap.lua
-- Minimap icon. Left-click: open the window. Right-click: lock/unlock the
-- buff buttons. Drag: move it around the minimap. Hover: buff summary.

local addonName, ns = ...
local MinimapIcon = ns.NewModule("Minimap")

local RADIUS = 80
local ICON = "Interface\\Icons\\Spell_Holy_WordFortitude"
local button

local function Position()
    local angle = math.rad(ns.global.minimap.angle or 215)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * RADIUS, math.sin(angle) * RADIUS)
end

local function DragUpdate()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    ns.global.minimap.angle = math.deg(math.atan2(py - my, px - mx))
    Position()
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("IncahootsCoA")
    local s = ns.Tracker:Summary()
    if s.tracked == 0 then
        GameTooltip:AddLine("No buffs tracked yet.", 0.8, 0.8, 0.8)
    else
        GameTooltip:AddLine(s.active .. " of " .. s.tracked .. " buffs active", 1, 1, 1)
        for _, name in ipairs(s.needNames) do
            GameTooltip:AddLine("   " .. name, 1, 0.35, 0.35)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: open window", 0.6, 0.6, 0.6)
    GameTooltip:AddLine("Right-click: " .. (ns.IsLocked() and "unlock" or "lock") .. " buttons", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function Build()
    button = CreateFrame("Button", "IncahootsCoAMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetPoint("TOPLEFT", 7, -6)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            ns.SetLocked(not ns.IsLocked())
            ns.Print(ns.IsLocked() and "Buttons locked." or "Buttons unlocked. Drag the green box to move them.")
        else
            ns.Config:Toggle()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", DragUpdate)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", GameTooltip_Hide)
end

function MinimapIcon:Update()
    if not button then Build() end
    Position()
    if ns.global.minimap.hide then button:Hide() else button:Show() end
end

function MinimapIcon:OnEnable()
    self:Update()
end
