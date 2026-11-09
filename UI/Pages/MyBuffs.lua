-- IncahootsCoA: UI/Pages/MyBuffs.lua
-- The buffs this character tracks: add, reorder, edit and remove them.

local addonName, ns = ...
local UI = ns.UI
local Rules, Tracker, SB = ns.Rules, ns.Tracker, ns.SpellBook

local ICON_EMPTY = "Interface\\Icons\\INV_Misc_QuestionMark"

local function StatusText(st)
    if not st then return "" end
    if st.state == "active" then
        local remaining = Tracker:Remaining(st)
        if remaining and remaining ~= math.huge then
            return "|cff55ff55" .. ns.FormatTime(remaining) .. "|r"
        end
        return "|cff55ff55Active|r"
    elseif st.state == "expiring" then
        return "|cffffd200" .. ns.FormatTime(Tracker:Remaining(st) or 0) .. "|r"
    elseif st.state == "missing" then
        return "|cffff5555Missing|r"
    elseif st.state == "unknown" then
        return "|cff888888Not learned|r"
    end
    return "|cff888888Off|r"
end

local function RebuffText(v)
    if v <= 0 then return "when it's gone" end
    return "with " .. ns.FormatTime(v, true) .. " left"
end

ns.Config:RegisterPage("mybuffs", "My Buffs", function(page)
    local selected = 1
    local list, spellEdit

    local function Rule() return Rules:Get(selected) end
    local function Select(index)
        selected = index
        page:Refresh()
        list:ScrollTo(index)
    end

    -- ------------------------------------------------------------ header
    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("My Buffs")
    local summary = UI.Text(page, "", 590)
    summary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

    -- ------------------------------------------------------------ list
    list = UI.List(page, {
        width = 340,
        rows = 13,
        rowHeight = 28,
        count = function() return Rules:Count() end,
        selected = function(index) return index == selected end,
        setup = function(row)
            row.check = CreateFrame("CheckButton", UI.NewName("BuffCheck"), row, "UICheckButtonTemplate")
            row.check:SetSize(22, 22)
            row.check:SetPoint("LEFT", 0, 0)
            row.check:SetScript("OnClick", function(self)
                local rule = Rules:Get(row.index)
                if rule then
                    rule.enabled = self:GetChecked() and true or false
                    Rules:Changed()
                    page:Refresh()
                end
            end)
            UI.AttachTooltip(row.check, "On / off", "Switch this buff off without removing it.")

            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(22, 22)
            row.icon:SetPoint("LEFT", row.check, "RIGHT", 2, 0)
            row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

            row.down = UI.ArrowButton(row, "down", function() Select(Rules:Move(row.index, 1)) end)
            row.down:SetPoint("RIGHT", -2, 0)
            row.up = UI.ArrowButton(row, "up", function() Select(Rules:Move(row.index, -1)) end)
            row.up:SetPoint("RIGHT", row.down, "LEFT", 0, 0)

            row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.status:SetPoint("RIGHT", row.up, "LEFT", -6, 0)

            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.text:SetPoint("RIGHT", row.status, "LEFT", -4, 0)
            row.text:SetJustifyH("LEFT")

            row:SetScript("OnClick", function(self)
                selected = self.index
                page:Refresh()
            end)
        end,
        update = function(row, index)
            local rule = Rules:Get(index)
            local st = Tracker:StatusOf(rule)
            row.check:SetChecked(rule.enabled)
            row.icon:SetTexture((st and st.icon) or SB:GetIcon(rule.spell) or ICON_EMPTY)
            row.text:SetText(rule.spell ~= "" and rule.spell or "(choose a spell)")
            local dim = not rule.enabled or (st and st.state == "unknown")
            if dim then row.text:SetTextColor(0.55, 0.55, 0.55) else row.text:SetTextColor(1, 1, 1) end
            row.status:SetText(StatusText(st))
            UI.SetEnabled(row.up, index > 1)
            UI.SetEnabled(row.down, index < Rules:Count())
        end,
    })
    list:SetPoint("TOPLEFT", 16, -64)

    -- ------------------------------------------------------------ add buttons
    local function AddFromCurrentBuffs()
        local items = { { text = "Your buffs right now", isTitle = true } }
        local i = 1
        while true do
            local name, _, icon, _, _, _, _, caster = UnitAura("player", i, "HELPFUL")
            if not name then break end
            if not Rules:IsTracked(name) then
                local mine = caster == "player"
                items[#items + 1] = {
                    text = name .. (mine and "" or " |cff888888(from someone else)|r"),
                    icon = icon,
                    func = function() Select((Rules:AddFromBuff(name))) end,
                }
            end
            i = i + 1
        end
        if #items == 1 then
            items[2] = { text = "(nothing new to add)", disabled = true }
        end
        UI.Menu(items)
    end

    local addRow = UI.ButtonRow(page, {
        { "Add from spellbook", 132, function()
            ns.Config:Open("spellbook")
            local sp = ns.Config:GetPage("spellbook")
            if sp and sp.ShowBuffs then sp:ShowBuffs() end
        end, "Browse your spells. Spells that look like buffs are marked, and you can track them from there." },
        { "Add from my buffs", 124, AddFromCurrentBuffs, "Pick from the buffs you have right now. Quickest way to set up: cast your buffs, then add them here." },
        { "Add by name", 92, function()
            UI.Prompt("Spell to track (exact name):", "", function(name)
                if name ~= "" then Select((Rules:Add(name))) end
            end)
        end },
    })
    addRow:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -8)

    local function CopyFromCharacter()
        local others = ns.DB:OtherCharacters()
        local items = { { text = "Copy the buff list from", isTitle = true } }
        for _, c in ipairs(others) do
            items[#items + 1] = {
                text = c.key .. " |cff888888(" .. (c.className or "?") .. ", " .. c.count .. ")|r",
                func = function()
                    UI.Confirm("Replace this character's buff list with the one from " .. c.key .. "?", function()
                        Rules:CopyFrom(c.key)
                        selected = 1
                        page:Refresh()
                    end)
                end,
            }
        end
        if #others == 0 then
            items[2] = { text = "(no other characters have buffs yet)", disabled = true }
        end
        UI.Menu(items)
    end

    local ioRow = UI.ButtonRow(page, {
        { "Import", 80, function()
            UI.ShowText({
                title = "Import buffs",
                hint = "Paste a buff list exported from IncahootsCoA. One buff per line, e.g.:  Fetid Ward; also=Bone Ward; rebuff=60",
                text = "",
                buttons = {
                    { "Replace my list", function(text)
                        local n, err = Rules:Import(text, "replace")
                        if not n then ns.Print("|cffff5555Import failed:|r " .. err) return false end
                        ns.Print("Imported " .. n .. " buffs.")
                        selected = 1
                        page:Refresh()
                        return true
                    end },
                    { "Add to my list", function(text)
                        local n, err = Rules:Import(text, "add")
                        if not n then ns.Print("|cffff5555Import failed:|r " .. err) return false end
                        ns.Print("Added " .. n .. " buffs.")
                        page:Refresh()
                        return true
                    end },
                },
            })
        end, "Paste a buff list from another character or a friend." },
        { "Export", 80, function()
            UI.ShowText({
                title = "Export buffs",
                hint = "Press Ctrl+C to copy. Import it on another character, or share it.",
                text = Rules:Export(),
            })
        end, "Get your buff list as text." },
        { "Copy from character", 150, CopyFromCharacter, "Use the buff list of another of your characters." },
    })
    ioRow:SetPoint("TOPLEFT", addRow, "BOTTOMLEFT", 0, -6)

    -- ------------------------------------------------------------ editor
    local editor = CreateFrame("Frame", nil, page)
    editor:SetPoint("TOPLEFT", 372, -60)
    editor:SetSize(244, 440)

    local empty = UI.Text(page,
        "You aren't tracking any buffs yet.\n\nAdd them with the buttons below the list:\n\n"
        .. "|cffffd200Add from spellbook|r  browse your spells; likely buffs are marked\n\n"
        .. "|cffffd200Add from my buffs|r  pick from the buffs you have right now\n\n"
        .. "|cffffd200Add by name|r  type a spell name",
        236, "GameFontHighlight")
    empty:SetPoint("TOPLEFT", 376, -72)

    local est = UI.Stack(editor, 0, 0, 8)
    local header = est:Add(UI.Header(editor, "", 240))

    spellEdit = UI.Edit(editor, {
        label = "Spell to cast",
        width = 190,
        tooltip = "Exact spell name. You can also drag a spell from your spellbook onto the icon next to this box.",
        get = function()
            local r = Rule()
            return r and r.spell or ""
        end,
        set = function(v)
            local r = Rule()
            if r then
                r.spell = v
                Rules:Changed()
            end
        end,
    })
    est:Add(spellEdit)

    local function AcceptCursorSpell()
        local kind, slot, book = GetCursorInfo()
        local r = Rule()
        if kind == "spell" and slot and r then
            local name = GetSpellName(slot, book)
            if name then
                r.spell = name
                ClearCursor()
                Rules:Changed()
                page:Refresh()
            end
        end
    end
    local drop = CreateFrame("Button", nil, editor)
    drop:SetSize(28, 28)
    drop:SetPoint("LEFT", spellEdit, "RIGHT", 8, 0)
    drop.icon = drop:CreateTexture(nil, "ARTWORK")
    drop.icon:SetAllPoints()
    drop.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    drop:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    drop:SetScript("OnReceiveDrag", AcceptCursorSpell)
    drop:SetScript("OnClick", AcceptCursorSpell)
    spellEdit:SetScript("OnReceiveDrag", AcceptCursorSpell)
    UI.AttachTooltip(drop, "Drop a spell here", "Drag a spell from your spellbook onto this icon.")

    local status = UI.Text(editor, "", 240)
    est:Add(status, 40)

    est:Add(UI.Edit(editor, {
        label = "Also counts as (comma separated)",
        width = 228,
        tooltip = "Other buff names that mean you already have this one: a ward or stance that replaces it, "
            .. "or the buff's name when it isn't the same as the spell's.",
        get = function()
            local r = Rule()
            return r and table.concat(r.extras, ", ") or ""
        end,
        set = function(v)
            local r = Rule()
            if r then
                r.extras = ns.SplitList(v)
                Rules:Changed()
            end
        end,
    }))

    est:Add(UI.Slider(editor, {
        label = "Remind me",
        min = 0, max = 600, step = 5, width = 228,
        fmt = RebuffText, lowText = "gone", highText = "10m left",
        tooltip = "Show the button before the buff runs out, so you can refresh it early.",
        get = function()
            local r = Rule()
            return r and r.rebuff or 0
        end,
        set = function(v)
            local r = Rule()
            if r then
                r.rebuff = v
                Rules:Changed()
            end
        end,
    }))

    est:Add(UI.Check(editor, {
        label = "Only count it when I cast it",
        tooltip = "Ignore this buff when someone else put it on you.",
        get = function()
            local r = Rule()
            return r and r.mine
        end,
        set = function(v)
            local r = Rule()
            if r then
                r.mine = v
                Rules:Changed()
            end
        end,
    }))

    local info = UI.Text(editor, "", 240)
    est:Add(info, 52)

    est:Add(UI.Button(editor, "Remove", 100, function()
        local r = Rule()
        if not r then return end
        UI.Confirm("Stop tracking " .. (r.spell ~= "" and r.spell or "this buff") .. "?", function()
            Rules:Remove(selected)
            page:Refresh()
        end)
    end))

    -- ------------------------------------------------------------ refresh
    function page:BeforeRefresh()
        local n = Rules:Count()
        if selected > n then selected = n end
        if selected < 1 and n > 0 then selected = 1 end

        local s = Tracker:Summary()
        if n == 0 then
            summary:SetText("Track the buffs you want to keep up. Missing ones appear as buttons you can click to cast.")
        else
            local parts = { s.tracked .. " tracked", "|cff55ff55" .. s.active .. " active|r" }
            if s.need > 0 then parts[#parts + 1] = "|cffff5555" .. s.need .. " to cast|r" end
            if s.unknown > 0 then parts[#parts + 1] = "|cff888888" .. s.unknown .. " not learned|r" end
            summary:SetText(table.concat(parts, "   "))
        end

        local r = Rule()
        UI.Toggle(editor, r ~= nil)
        UI.Toggle(empty, r == nil)
        if not r then return end

        local st = Tracker:StatusOf(r)
        header.text:SetText(r.spell ~= "" and r.spell or "New buff")
        drop.icon:SetTexture(SB:GetIcon(r.spell) or ICON_EMPTY)

        if r.spell == "" then
            status:SetText("Type a spell name, or drag a spell from your spellbook onto the icon.")
        elseif not SB:IsKnown(r.spell) then
            status:SetText("|cffff6666" .. r.spell .. " isn't in this character's spellbook,|r so it won't get a button. Check the spelling.")
        else
            local text = "|cff55ff55In your spellbook.|r"
            if st and st.state == "active" then
                local remaining = Tracker:Remaining(st)
                text = text .. "\nActive" .. ((remaining and remaining ~= math.huge) and (", " .. ns.FormatTime(remaining, true) .. " left") or "")
            elseif st and Tracker.NeedsCast(st.state) then
                text = text .. "\n|cffff5555You need to cast it.|r"
            end
            status:SetText(text)
        end

        local lines = {}
        local link = ns.global.learned.links[r.spell]
        if link then lines[#lines + 1] = "Learned: casting it gives the buff |cffffffff" .. link .. "|r." end
        local duration = ns.global.learned.durations[link or r.spell]
        if duration then lines[#lines + 1] = "Lasts " .. ns.FormatTime(duration, true) .. "." end
        if st and st.buff and st.buff ~= r.spell and st.buff ~= link then
            lines[#lines + 1] = "Counting your buff |cffffffff" .. st.buff .. "|r."
        end
        info:SetText(table.concat(lines, "\n"))
    end

    -- live timers while the page is open
    local elapsedTotal = 0
    page:SetScript("OnUpdate", function(self, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal < 1 then return end
        elapsedTotal = 0
        list:Refresh()
    end)
    ns.On("STATUS_UPDATED", function()
        if page:IsVisible() then list:Refresh() end
    end)
end)
