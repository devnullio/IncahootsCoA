-- IncahootsCoA: UI/Pages/Display.lua
-- How the buff buttons look and when they show.

local addonName, ns = ...
local UI = ns.UI

local MODE_ITEMS = {
    { value = "missing", text = "Only buffs I need" },
    { value = "all", text = "All tracked buffs" },
}
local GROW_ITEMS = {
    { value = "RIGHT", text = "Right" },
    { value = "LEFT", text = "Left" },
    { value = "DOWN", text = "Down" },
    { value = "UP", text = "Up" },
}

ns.Config:RegisterPage("display", "Buttons", function(page)
    local function C() return ns.char.display end
    local function Changed() ns.Fire("DISPLAY_CHANGED") end
    local function Off() return not C().enabled end

    local function Setting(key)
        return function() return C()[key] end, function(v)
            C()[key] = v
            Changed()
        end
    end
    local function Check(key, label, tooltip, disabled)
        local get, set = Setting(key)
        return UI.Check(page, { label = label, tooltip = tooltip, get = get, set = set, disabled = disabled or Off })
    end
    local function Slider(key, label, min, max, step, fmt, tooltip, disabled)
        local get, set = Setting(key)
        return UI.Slider(page, {
            label = label, min = min, max = max, step = step, width = 250, fmt = fmt, tooltip = tooltip,
            get = get, set = set, disabled = disabled or Off,
        })
    end
    local function Percent(v) return string.format("%d%%", v * 100 + 0.5) end

    -- left column
    local left = UI.Stack(page, 16, 12)
    left:Add(UI.Header(page, "Buttons", 270))
    left:Add(UI.Check(page, {
        label = "Show buff buttons",
        get = function() return C().enabled end,
        set = function(v)
            C().enabled = v
            Changed()
        end,
    }))
    local modeGet, modeSet = Setting("mode")
    left:Add(UI.Dropdown(page, {
        label = "Show", width = 170, items = function() return MODE_ITEMS end,
        get = modeGet, set = modeSet, disabled = Off,
        tooltip = "Only buffs I need: a button appears when a buff is missing or running out.\n"
            .. "All tracked buffs: every buff has a button; the ones you have are faded and show their time left.",
    }))
    left:Add(Slider("activeAlpha", "Buffs I have", 0.1, 1, 0.05, Percent,
        "How visible the buttons of buffs you already have are.",
        function() return Off() or C().mode ~= "all" end))
    left:Add(Slider("maxButtons", "Most buttons", 1, 24, 1))
    left:Add(Slider("perRow", "Buttons per row", 1, 24, 1))
    local growGet, growSet = Setting("grow")
    left:Add(UI.Dropdown(page, {
        label = "Grow", width = 110, items = function() return GROW_ITEMS end,
        get = growGet, set = growSet, disabled = Off,
    }))
    left:Add(Slider("size", "Button size", 20, 64, 1))
    left:Add(Slider("spacing", "Spacing", 0, 20, 1))

    -- right column
    local right = UI.Stack(page, 320, 12)
    right:Add(UI.Header(page, "Look", 290))
    right:Add(Slider("scale", "Scale", 0.5, 2, 0.05, Percent))
    right:Add(Check("showTimers", "Show time left on buttons"))
    right:Add(Check("showBorders", "Glow: red when missing, yellow when running out"))
    right:Add(Check("showTooltips", "Show tooltips"))
    right:Add(Check("sound", "Play a sound when a buff runs out"))

    right:Space(4)
    right:Add(UI.Header(page, "Hide the buttons when", 290))
    right:Add(Check("hideMounted", "Mounted"))
    right:Add(Check("hideVehicle", "In a vehicle or on a taxi"))
    right:Add(Check("hideResting", "Resting (city or inn)"))
    right:Add(Check("hideInCombat", "In combat",
        "Hides the buttons during combat. The keybind for the next missing buff still works."))

    -- bottom
    local tools = UI.ButtonRow(page, {
        { "Test buttons", 110, function()
            ns.Display:ToggleTest()
            page:Refresh()
        end, "Show placeholder buttons so you can see and move the layout." },
        { "Reset position", 110, function() ns.Display:ResetPosition() end },
        { "Reset all", 90, function()
            UI.Confirm("Reset every button setting to its default?", function() ns.DB:ResetDisplay() end)
        end },
    })
    tools:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 16, 14)
    local lock = UI.Check(page, {
        label = "Lock buttons",
        tooltip = "Unlock to drag the buttons by the green box.",
        get = function() return ns.IsLocked() end,
        set = function(v) ns.SetLocked(v) end,
    })
    lock:SetPoint("LEFT", tools, "RIGHT", 16, 0)
    UI.OnRefresh(page, function()
        tools.buttons[1]:SetText(ns.Display:IsTesting() and "Stop test" or "Test buttons")
    end)
end)
