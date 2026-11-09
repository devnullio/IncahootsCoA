-- IncahootsCoA: UI/Pages/Spellbook.lua
-- Every spell you (and your pet) know, with everything the game tells us
-- about it. Search, filter, see which ones are buffs, and track them.

local addonName, ns = ...
local UI = ns.UI
local SB, Rules = ns.SpellBook, ns.Rules

local FILTERS = {
    { value = "all", text = "All spells" },
    { value = "buffs", text = "Buffs (seen & likely)" },
    { value = "active", text = "Castable" },
    { value = "passive", text = "Passive" },
    { value = "tracked", text = "Tracked" },
    { value = "pet", text = "Pet spells" },
}

local function Tag(rec)
    if rec.book ~= "spell" then return "|cffaaaaaaPet|r" end
    if Rules:IsTracked(rec.name) then return "|cff66bbffTracked|r" end
    local status = SB:BuffStatus(rec)
    if status == "confirmed" then return "|cff55ff55Buff|r" end
    if status == "likely" then return "|cffffd200Likely buff|r" end
    if rec.passive then return "|cff888888Passive|r" end
    return ""
end

local function MatchesTab(rec, tab)
    if tab == "nogeneral" then return not rec.general end
    if tab == "all" then return true end
    return rec.tab == tab
end

local function Matches(rec, filter, search, tab)
    if not MatchesTab(rec, tab) then return false end
    if filter == "buffs" and (rec.book ~= "spell" or not SB:BuffStatus(rec)) then return false end
    if filter == "active" and rec.passive then return false end
    if filter == "passive" and not rec.passive then return false end
    if filter == "tracked" and (rec.book ~= "spell" or not Rules:IsTracked(rec.name)) then return false end
    if filter == "pet" and rec.book == "spell" then return false end
    if search ~= "" then
        local hay = (rec.name .. " " .. (rec.description or "") .. " " .. (rec.tab or "")):lower()
        if not hay:find(search, 1, true) then return false end
    end
    return true
end

ns.Config:RegisterPage("spellbook", "Spellbook", function(page)
    local filter, search = "all", ""
    local visible = {}
    local selectedKey
    local list, searchBox

    local function KeyOf(rec) return rec.book .. ":" .. rec.name end
    local function Selected()
        for _, rec in ipairs(SB:GetAll()) do
            if KeyOf(rec) == selectedKey then return rec end
        end
    end

    -- ------------------------------------------------------------ top bar
    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("Spellbook")
    local count = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("LEFT", title, "RIGHT", 10, -1)

    local tools = UI.ButtonRow(page, {
        { "Rescan", 70, function()
            SB:Scan()
            ns.Print("Spellbook scanned: " .. SB:GetCount() .. " spells.")
        end, "Read the spellbook again. This also happens automatically when you learn spells." },
        { "Export list", 90, function()
            UI.ShowText({
                title = "Spellbook export",
                hint = "Every spell with its details, one per line. Press Ctrl+C to copy.",
                text = SB:Export(ns.char.spellbookTab ~= "nogeneral"),
            })
        end, "Get every spell and its details as text, e.g. to share your class's spells." },
    })
    tools:SetPoint("TOPRIGHT", page, "TOPRIGHT", -16, -12)

    searchBox = UI.Search(page, 170, "Search name or description", function(text)
        search = strtrim(text):lower()
        if list then
            list:ScrollToTop()
            page:Refresh()
        end
    end)
    searchBox:SetPoint("TOPLEFT", 24, -44)

    local filterDrop = UI.Dropdown(page, {
        width = 150,
        items = function() return FILTERS end,
        get = function() return filter end,
        set = function(v)
            filter = v
            list:ScrollToTop()
        end,
    })
    filterDrop:SetPoint("LEFT", searchBox, "RIGHT", -8, -2)

    local tabDrop = UI.Dropdown(page, {
        width = 130,
        tooltip = "The General tab holds racials, professions, mounts and other utility spells, so it's hidden by default.",
        items = function()
            local items = {
                { value = "nogeneral", text = "All but General" },
                { value = "all", text = "All tabs" },
            }
            for _, name in ipairs(SB:GetTabs()) do
                items[#items + 1] = { value = name, text = name }
            end
            if HasPetSpells() then
                items[#items + 1] = { value = "Pet", text = "Pet" }
            end
            return items
        end,
        get = function() return ns.char.spellbookTab end,
        set = function(v)
            ns.char.spellbookTab = v
            list:ScrollToTop()
        end,
    })
    tabDrop:SetPoint("LEFT", filterDrop, "RIGHT", -24, 0)

    -- ------------------------------------------------------------ list
    list = UI.List(page, {
        width = 330,
        rows = 16,
        rowHeight = 26,
        count = function() return #visible end,
        selected = function(index) return visible[index] and KeyOf(visible[index]) == selectedKey end,
        setup = function(row)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(22, 22)
            row.icon:SetPoint("LEFT", 2, 0)
            row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            row.tag = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.tag:SetPoint("RIGHT", -4, 0)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.text:SetPoint("RIGHT", row.tag, "LEFT", -4, 0)
            row.text:SetJustifyH("LEFT")
            row:SetScript("OnClick", function(self)
                selectedKey = KeyOf(visible[self.index])
                page:Refresh()
            end)
        end,
        update = function(row, index)
            local rec = visible[index]
            row.icon:SetTexture(rec.icon)
            local rank = rec.rank and (" |cff888888" .. rec.rank .. "|r") or ""
            row.text:SetText(rec.name .. rank)
            if rec.passive then row.text:SetTextColor(0.6, 0.6, 0.6) else row.text:SetTextColor(1, 1, 1) end
            row.tag:SetText(Tag(rec))
        end,
    })
    list:SetPoint("TOPLEFT", 16, -74)

    local legend = UI.Text(page,
        "|cff55ff55Buff|r seen putting a buff on you   |cffffd200Likely buff|r its description reads like one   |cff66bbffTracked|r on My Buffs",
        600)
    legend:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 2, -8)

    -- ------------------------------------------------------------ details
    local details = CreateFrame("Frame", nil, page)
    details:SetPoint("TOPLEFT", 360, -74)
    details:SetSize(254, 424)

    local noneText = UI.Text(page, "Click a spell to see its details.", 240, "GameFontHighlight")
    noneText:SetPoint("TOPLEFT", 364, -80)

    local iconButton = CreateFrame("Button", nil, details)
    iconButton:SetSize(40, 40)
    iconButton:SetPoint("TOPLEFT", 0, 0)
    iconButton.icon = iconButton:CreateTexture(nil, "ARTWORK")
    iconButton.icon:SetAllPoints()
    iconButton.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    iconButton:SetScript("OnEnter", function(self)
        local rec = Selected()
        if not rec then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpell(rec.slot, rec.book)
        GameTooltip:Show()
    end)
    iconButton:SetScript("OnLeave", GameTooltip_Hide)

    local nameText = details:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameText:SetPoint("TOPLEFT", iconButton, "TOPRIGHT", 8, -2)
    nameText:SetPoint("RIGHT", details, "RIGHT", 0, 0)
    nameText:SetJustifyH("LEFT")
    local rankText = details:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rankText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -4)

    local infoText = UI.Text(details, "", 254)
    infoText:SetPoint("TOPLEFT", iconButton, "BOTTOMLEFT", 0, -10)
    local buffText = UI.Text(details, "", 254)
    buffText:SetPoint("TOPLEFT", infoText, "BOTTOMLEFT", 0, -8)
    local descText = UI.Text(details, "", 254, "GameFontNormal")
    descText:SetPoint("TOPLEFT", buffText, "BOTTOMLEFT", 0, -10)

    local trackButton = UI.Button(details, "Track this buff", 130, function()
        local rec = Selected()
        if not rec then return end
        local index = Rules:Add(rec.name)
        ns.Print("Now tracking " .. rec.name .. ". Fine-tune it on the My Buffs page.")
        page:Refresh()
        return index
    end)
    trackButton:SetPoint("BOTTOMLEFT", details, "BOTTOMLEFT", 0, 0)
    local linkButton = UI.Button(details, "Link in chat", 100, function()
        local rec = Selected()
        local link = rec and GetSpellLink(rec.slot, rec.book)
        if link and not ChatEdit_InsertLink(link) then
            ChatFrame_OpenChat(link)
        end
    end)
    linkButton:SetPoint("LEFT", trackButton, "RIGHT", 8, 0)

    local function Line(label, value)
        if not value or value == "" then return nil end
        return "|cffffd200" .. label .. ":|r " .. value
    end

    -- ------------------------------------------------------------ refresh
    function page:BeforeRefresh()
        -- a saved tab that no longer exists falls back to the default
        local tab = ns.char.spellbookTab
        if tab ~= "nogeneral" and tab ~= "all" and tab ~= "Pet" then
            local found = false
            for _, name in ipairs(SB:GetTabs()) do
                if name == tab then found = true end
            end
            if not found then ns.char.spellbookTab = "nogeneral" end
        end

        wipe(visible)
        for _, rec in ipairs(SB:GetAll()) do
            if Matches(rec, filter, search, ns.char.spellbookTab) then visible[#visible + 1] = rec end
        end
        count:SetText(#visible .. " of " .. SB:GetCount() .. " spells")

        local rec = Selected()
        UI.Toggle(details, rec ~= nil)
        UI.Toggle(noneText, rec == nil)
        if not rec then return end

        iconButton.icon:SetTexture(rec.icon)
        nameText:SetText(rec.name)
        rankText:SetText((rec.rank or "") .. (rec.ranks > 1 and ("  (" .. rec.ranks .. " ranks)") or ""))

        local lines = {}
        local function add(l) if l then lines[#lines + 1] = l end end
        add(Line("Spell ID", rec.id and tostring(rec.id)))
        add(Line("Tab", rec.tab))
        add(Line("Type", rec.passive and "Passive" or "Active"))
        add(Line("Cost", rec.cost))
        add(Line("Cast", rec.castTime))
        add(Line("Range", rec.range or (rec.selfCast and not rec.passive and "Self" or nil)))
        add(Line("Cooldown", rec.cooldown))
        local learnedDuration = ns.global.learned.durations[ns.global.learned.links[rec.name] or rec.name]
        if learnedDuration then
            add(Line("Duration", ns.FormatTime(learnedDuration, true) .. " (seen)"))
        elseif rec.duration then
            add(Line("Duration", ns.FormatTime(rec.duration, true) .. " (from description)"))
        end
        infoText:SetText(table.concat(lines, "\n"))

        local status = SB:BuffStatus(rec)
        local link = ns.global.learned.links[rec.name]
        local buffLine
        if rec.book ~= "spell" then
            buffLine = "|cffaaaaaaPet spell.|r"
        elseif status == "confirmed" then
            buffLine = "|cff55ff55Buff:|r seen putting a buff on you" .. (link and (" (|cffffffff" .. link .. "|r)") or "") .. "."
        elseif status == "likely" then
            buffLine = "|cffffd200Likely a buff|r, judging by its description. Cast it once to confirm."
        elseif rec.passive then
            buffLine = "|cff888888Passive: always on, nothing to cast.|r"
        else
            buffLine = "|cff888888Doesn't look like a buff.|r"
        end
        buffText:SetText(buffLine)
        descText:SetText(rec.description or "|cff888888No description.|r")

        if rec.book ~= "spell" or rec.passive then
            trackButton:SetText("Can't track")
            trackButton:Disable()
        elseif Rules:IsTracked(rec.name) then
            trackButton:SetText("Tracked")
            trackButton:Disable()
        else
            trackButton:SetText("Track this buff")
            trackButton:Enable()
        end
    end

    -- Used by "Add from spellbook" on the My Buffs page.
    function page:ShowBuffs()
        filter = "buffs"
        searchBox:SetText("")
        list:ScrollToTop()
        self:Refresh()
    end

    ns.On("SPELLBOOK_UPDATED", function()
        if page:IsVisible() then page:Refresh() end
    end)
    ns.On("LEARNED_UPDATED", function()
        if page:IsVisible() then page:Refresh() end
    end)
end)
