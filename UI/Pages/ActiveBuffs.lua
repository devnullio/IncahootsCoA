-- IncahootsCoA: UI/Pages/ActiveBuffs.lua
-- Live view of every buff on you right now, with one-click tracking.

local addonName, ns = ...
local UI = ns.UI
local Rules = ns.Rules

ns.Config:RegisterPage("activebuffs", "Active Buffs", function(page)
    local onlyMine = false
    local buffs = {} -- { index, name, icon, count, duration, expires, caster, id }
    local list

    local function Collect()
        wipe(buffs)
        local i = 1
        while true do
            local name, _, icon, count, _, duration, expires, caster, _, _, id = UnitAura("player", i, "HELPFUL")
            if not name then break end
            if not onlyMine or caster == "player" then
                buffs[#buffs + 1] = {
                    index = i, name = name, icon = icon, count = count, duration = duration,
                    expires = expires, caster = caster, id = id,
                }
            end
            i = i + 1
        end
    end

    local function Source(b)
        if b.caster == "player" then return "|cff55ff55you|r" end
        if b.caster == "pet" then return "your pet" end
        if b.caster then return UnitName(b.caster) or b.caster end
        return "|cff888888unknown|r"
    end

    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("Active Buffs")
    local count = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("LEFT", title, "RIGHT", 10, -1)

    local intro = UI.Text(page, "Every buff on you right now. Hover a row for its tooltip, click Track to add it to My Buffs.", 590)
    intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

    local mineCheck = UI.Check(page, {
        label = "Only buffs I cast",
        get = function() return onlyMine end,
        set = function(v) onlyMine = v end,
    })
    mineCheck:SetPoint("TOPRIGHT", page, "TOPRIGHT", -140, -10)

    list = UI.List(page, {
        width = 598,
        rows = 16,
        rowHeight = 26,
        count = function() return #buffs end,
        setup = function(row)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(22, 22)
            row.icon:SetPoint("LEFT", 2, 0)
            row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

            row.track = UI.Button(row, "Track", 70, function()
                local b = buffs[row.index]
                if b then
                    local index, isNew = Rules:AddFromBuff(b.name)
                    local rule = Rules:Get(index)
                    if isNew and rule and not ns.SpellBook:IsKnown(rule.spell) then
                        ns.Print("Tracking " .. b.name .. ". Its spell isn't known yet: set the spell on My Buffs.")
                    else
                        ns.Print("Now tracking " .. (rule and rule.spell or b.name) .. ".")
                    end
                    page:Refresh()
                end
            end)
            row.track:SetPoint("RIGHT", -2, 0)
            row.tracked = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.tracked:SetPoint("CENTER", row.track, "CENTER")
            row.tracked:SetText("|cff66bbffTracked|r")

            row.source = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.source:SetPoint("RIGHT", row.track, "LEFT", -10, 0)
            row.source:SetWidth(100)
            row.source:SetJustifyH("LEFT")
            row.time = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.time:SetPoint("RIGHT", row.source, "LEFT", -10, 0)
            row.time:SetWidth(90)
            row.time:SetJustifyH("RIGHT")

            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.text:SetPoint("RIGHT", row.time, "LEFT", -6, 0)
            row.text:SetJustifyH("LEFT")

            row:SetScript("OnEnter", function(self)
                local b = buffs[self.index]
                if not b then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetUnitAura("player", b.index, "HELPFUL")
                if b.id then GameTooltip:AddLine("Spell ID " .. b.id, 0.6, 0.6, 0.6) end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", GameTooltip_Hide)
        end,
        update = function(row, index)
            local b = buffs[index]
            row.icon:SetTexture(b.icon)
            row.text:SetText(b.name .. ((b.count and b.count > 1) and (" |cffffd200x" .. b.count .. "|r") or ""))
            if b.expires and b.expires > 0 then
                row.time:SetText(ns.FormatTime(b.expires - GetTime(), true))
            else
                row.time:SetText("|cff888888no time limit|r")
            end
            row.source:SetText(Source(b))
            local tracked = Rules:IsTracked(b.name)
            UI.Toggle(row.track, not tracked)
            UI.Toggle(row.tracked, tracked)
        end,
    })
    list:SetPoint("TOPLEFT", 16, -64)

    local empty = UI.Text(page, "No buffs on you right now.", 300, "GameFontHighlight")
    empty:SetPoint("TOPLEFT", list, "TOPLEFT", 12, -12)

    function page:BeforeRefresh()
        Collect()
        count:SetText(#buffs .. (#buffs == 1 and " buff" or " buffs"))
        UI.Toggle(empty, #buffs == 0)
    end

    local elapsedTotal = 0
    page:SetScript("OnUpdate", function(self, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal < 0.5 then return end
        elapsedTotal = 0
        self:Refresh()
    end)
end)
