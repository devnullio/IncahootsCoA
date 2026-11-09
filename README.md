# IncahootsCoA 3.0

Track your own buffs and cast them with one click, with a full spellbook browser.
For Conquest of Azeroth (WotLK 3.3.5 client). Open with the minimap icon or `/ich`.

## Folder layout

| Path | What it does |
|---|---|
| `Core/Init.lua` | Shared helpers: events, internal messages, modules, timer, combat-safe queue |
| `Core/Database.lua` | Saved variables: account-wide data plus one entry per character |
| `Core/Commands.lua` | `/ich` commands and key binding labels |
| `Bindings.xml` | Key bindings: cast next missing buff, open the window |
| `Spells/SpellBook.lua` | Reads every spell in your spellbook (and your pet's) with its details |
| `Spells/BuffLearner.lua` | Watches your casts to learn which spells are buffs and what their buffs are called |
| `Buffs/Rules.lua` | Your tracked buff list, import/export, copy from another character |
| `Buffs/Tracker.lua` | Works out which tracked buffs are active, running out or missing |
| `Buffs/Display.lua` | The click-to-cast buttons and the hidden "next buff" keybind button |
| `UI/Widgets.lua` | Window controls (no libraries needed) |
| `UI/MainFrame.lua` | The window and the Interface > AddOns entry |
| `UI/Pages/*.lua` | One file per page |
| `UI/Minimap.lua` | Minimap icon |

## Spellbook API

Other addons and macros can use the scanner:

```lua
local SB = IncahootsCoA.SpellBook
for _, spell in ipairs(SB:GetAll()) do
    print(spell.name, spell.rank, spell.id, spell.tab, spell.passive, spell.cost,
          spell.castTime, spell.range, spell.cooldown, spell.duration, spell.description)
end
SB:Get("Spell Name")      -- one spell (any case)
SB:IsKnown("Spell Name")  -- in your spellbook?
SB:BuffStatus(spell)      -- "confirmed", "likely" or nil
SB:Export()               -- every spell as text
```

## Saved data

- `IncahootsCoADB.chars["Name - Realm"]`: that character's tracked buffs and button settings.
- `IncahootsCoADB.global.learned`: which spells are buffs, what their buffs are called and how long they last. Shared by all characters.
