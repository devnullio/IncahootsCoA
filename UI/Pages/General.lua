-- IncahootsCoA: UI/Pages/General.lua

local addonName, ns = ...
local UI = ns.UI

ns.Config:RegisterPage("general", "General", function(page)
    local st = UI.Stack(page, 16, 12)
    st:Add(UI.Header(page, "General", 590))
    st:Add(UI.Check(page, {
        label = "Show minimap icon",
        tooltip = "Left-click the icon to open this window, right-click to lock or unlock the buttons.",
        get = function() return not ns.global.minimap.hide end,
        set = function(v)
            ns.global.minimap.hide = not v
            ns.Minimap:Update()
        end,
    }))
    st:Add(UI.Check(page, {
        label = "Lock buff buttons",
        get = function() return ns.IsLocked() end,
        set = function(v) ns.SetLocked(v) end,
    }))
    st:Add(UI.Check(page, {
        label = "Debug messages",
        tooltip = "Print what the addon learns and does to chat.",
        get = function() return ns.char.debug end,
        set = function(v) ns.char.debug = v end,
    }))

    st:Space(6)
    st:Add(UI.Header(page, "What the addon has learned", 590))
    local learnedText = UI.Text(page, "", 590)
    st:Add(learnedText, 30)
    UI.OnRefresh(page, function()
        local l = ns.global.learned
        local confirmed, links = 0, 0
        for _ in pairs(l.confirmed) do confirmed = confirmed + 1 end
        for _ in pairs(l.links) do links = links + 1 end
        learnedText:SetText(confirmed .. " spells confirmed as buffs, " .. links
            .. " spells whose buff has a different name. It learns this by watching your casts, "
            .. "and it's shared by all your characters.")
    end)
    st:Add(UI.ButtonRow(page, {
        { "Show learned", 120, function()
            local l = ns.global.learned
            local lines = { "# Spells confirmed as buffs" }
            local names = {}
            for name in pairs(l.confirmed) do names[#names + 1] = name end
            table.sort(names)
            for _, name in ipairs(names) do
                local d = l.durations[l.links[name] or name]
                lines[#lines + 1] = name .. (l.links[name] and (" -> " .. l.links[name]) or "")
                    .. (d and (" (" .. ns.FormatTime(d, true) .. ")") or "")
            end
            UI.ShowText({ title = "Learned buffs", text = table.concat(lines, "\n") })
        end },
        { "Forget learned", 120, function()
            UI.Confirm("Forget every learned buff? The addon will learn them again as you cast.", function()
                ns.BuffLearner:Forget()
                page:Refresh()
            end)
        end },
    }))

    st:Space(6)
    st:Add(UI.Header(page, "Key bindings", 590))
    st:Add(UI.Text(page,
        "In the game menu, Key Bindings > |cffffd200IncahootsCoA|r has two bindings:\n"
        .. "|cffffd200Cast next missing buff|r casts the first buff you need, top of My Buffs first. Works in combat.\n"
        .. "|cffffd200Open / close the IncahootsCoA window|r",
        590), 46)

    st:Space(6)
    st:Add(UI.Header(page, "Chat commands", 590))
    st:Add(UI.Text(page,
        "|cffffd200/ich|r open or close this window     |cffffd200/ich spells|r spellbook     |cffffd200/ich buffs|r My Buffs\n"
        .. "|cffffd200/ich lock|r, |cffffd200/ich unlock|r     |cffffd200/ich test|r test buttons     "
        .. "|cffffd200/ich scan|r rescan spells     |cffffd200/ich reset|r reset button position\n"
        .. "For other addons and macros: |cffffd200IncahootsCoA.SpellBook:GetAll()|r returns every spell with its details.",
        590), 46)
end)
