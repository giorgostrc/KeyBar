# KeyBar

An on-screen keyboard for WoW: Forever (interface 16001) that shows what each key does, with one layer per modifier.

## Install

Copy this folder into your Forever client's `Interface\AddOns` folder, as `Interface\AddOns\KeyBar`. The folder name has to match `KeyBar.toc`.

## Use

- Hold Shift, Ctrl or Alt, alone or together, and the keyboard switches to that layer. A dimmed, grey icon means the key isn't bound on this layer, so it shows the base layer's bind instead.
- Click a key to cast or use what's bound to it. Hold Shift/Ctrl/Alt while clicking for that layer; this works in combat too. Game controls (map, autorun, ...) aren't clickable.
- Icons tint like Blizzard's action bars: red when your target is out of range (the key label turns red too), blue when you lack mana/energy, grey when unusable.
- A key that casts a lower rank than you know (a downranked macro, or an old rank on a bar) shows a small grey "R1" in the corner; the tooltip adds your highest known rank. Highest-rank keys show nothing.
- Consumables (potions, food, bandages, ...) show how many you carry in that corner instead, and grey out when you have none.
- Spells bound straight to a key no longer get the spellbook's "not on your action bars" highlight.
- Move the frame by its title bar or border; dragging a key no longer moves it. The keyboard can't be moved, resized or hidden in combat.
- Skins: Classic, Minimal (flat, borderless) and Gilded (Blizzard dialog frame, gold edges). The title bar can be hidden; with it hidden, drag the frame's edge to move it.
- Hover the keyboard to reveal move, scale, lock and settings icons in its top-right corner. Drag the move icon to reposition; drag the scale grip left or right to resize (50%–200%, top-left corner stays put). The lock disables both. Settings: layout (QWERTY/QWERTZ/AZERTY/UK), size (Full/TKL/75/65/60), rows, scale, lock, setup mode.
- `/keybar` toggles the frame. `/keybar help` lists every command.

### Setup mode (`/keybar setup`)

- Pick a layer from the buttons above the frame, or click the Shift/Ctrl/Alt keys on the board.
- Drop a spell, item, macro or mount on a key to bind it (`SetBindingSpell` / `SetBindingItem` / `SetBindingMacro`). These binds don't use action bars, so you can hide the bars once every key is bound directly.
- Drag a game control (Toggle Map, Autorun, Target Nearest Enemy, ...) from the grouped list on the right onto a key. `/keybar controls` shows the list outside setup mode too.
- Right-click a key to clear it. Drag one key onto another to swap their binds.
- Editing is blocked in combat.

### Binds per character

Every character uses its own WoW binding set (Blizzard's "Character Specific Keybindings"). On a character's first login with KeyBar, a dialog asks where its binds start:

- **Keep current binds**: the character's own binds if it has them; otherwise the account's binds with only the controls kept (no other characters' spells, items or macros).
- **KeyBar defaults**: Blizzard's defaults with `1`–`=`, `Q`, `E`, `R`, `T`, `F`, `G`, `Z`, `X`, `C` and `V` cleared on the base and Shift layers; Character on `,`, friendly nameplates on `[`, enemy nameplates on `]`, Autorun on `\`, Strafe Left/Right on `A`/`D`.

After that, each character's binds are its own and KeyBar never changes them on its own.

## If a key shows the wrong bind

WoW names keys by the character your OS layout produces. Run `/keybar keytest`, press the key, and compare the printed token with the matching entry in `LOCALES` in `Layouts.lua`.

## Files

| File | Role |
|---|---|
| `Layouts.lua` | Key geometry per layout and size, in key units |
| `Bindings.lua` | Turns a key into an icon or label, plus its cooldown and tooltip |
| `Keycap.lua` | One key: Blizzard `ActionButtonTemplate` art on a dark keycap |
| `Keyboard.lua` | Main frame: layout, layer switching, press highlights |
| `ControlsList.lua` | Searchable game controls list, grouped like the Key Bindings menu |
| `Setup.lua` | Drag-and-drop binding, clear, swap, layer picker |
| `Skins.lua` | Classic, Minimal and Gilded looks |
| `Spellbook.lua` | Marks key-bound spells as placed in the spellbook |
| `CharacterBinds.lua` | First-login choice of starting binds |
| `Core.lua` | Saved settings, options menu, slash commands, events |
