local _, ns = ...

local function Key(token, label, w, h)
    return { token = token, label = label or token, w = w or 1, h = h or 1 }
end

local function Modifier(token, modifier, w)
    local key = Key(token, modifier:sub(1, 1) .. modifier:sub(2):lower(), w)
    key.modifier = modifier
    return key
end

local function Cosmetic(label, w)
    return { label = label, w = w, h = 1 }
end

local function Gap(w)
    return { gap = w }
end

local function Keys(spec)
    local keys = {}
    for token in spec:gmatch("%S+") do
        keys[#keys + 1] = Key(token)
    end
    return keys
end

local function Concat(...)
    local out = {}
    for i = 1, select("#", ...) do
        for _, key in ipairs((select(i, ...))) do
            out[#out + 1] = key
        end
    end
    return out
end

-- Key tokens are what WoW reports for the key, which follows the OS keyboard layout.
-- Use /keybar keytest to check a token if a key shows the wrong bind.
local LOCALES = {
    qwerty = {
        num = "` 1 2 3 4 5 6 7 8 9 0 - =",
        top = "Q W E R T Y U I O P [ ] \\",
        home = "A S D F G H J K L ; '",
        bottom = "Z X C V B N M , . /",
    },
    qwerty_uk = {
        iso = true,
        num = "` 1 2 3 4 5 6 7 8 9 0 - =",
        top = "Q W E R T Y U I O P [ ]",
        home = "A S D F G H J K L ; ' #",
        bottom = "\\ Z X C V B N M , . /",
    },
    qwertz = {
        iso = true,
        num = "^ 1 2 3 4 5 6 7 8 9 0 ß ´",
        top = "Q W E R T Z U I O P Ü +",
        home = "A S D F G H J K L Ö Ä #",
        bottom = "< Y X C V B N M , . -",
    },
    azerty = {
        iso = true,
        num = "² 1 2 3 4 5 6 7 8 9 0 ) =",
        top = "A Z E R T Y U I O P ^ $",
        home = "Q S D F G H J K L M Ù *",
        bottom = "< W X C V B N , ; : !",
    },
}

local FN_SPREAD = Concat(
    { Key("ESCAPE", "Esc"), Gap(1) }, Keys("F1 F2 F3 F4"),
    { Gap(0.5) }, Keys("F5 F6 F7 F8"),
    { Gap(0.5) }, Keys("F9 F10 F11 F12")
)

local FN_COMPACT = Concat(
    { Key("ESCAPE", "Esc"), Gap(0.25) }, Keys("F1 F2 F3 F4"),
    { Gap(0.25) }, Keys("F5 F6 F7 F8"),
    { Gap(0.25) }, Keys("F9 F10 F11 F12"),
    { Gap(0.25), Key("DELETE", "Del") }
)

local SPACE_FULL = {
    Modifier("LCTRL", "CTRL", 1.25), Cosmetic("Win", 1.25), Modifier("LALT", "ALT", 1.25),
    Key("SPACE", "Space", 6.25),
    Modifier("RALT", "ALT", 1.25), Cosmetic("Win", 1.25), Cosmetic("Menu", 1.25), Modifier("RCTRL", "CTRL", 1.25),
}

local SPACE_COMPACT = {
    Modifier("LCTRL", "CTRL", 1.25), Cosmetic("Win", 1.25), Modifier("LALT", "ALT", 1.25),
    Key("SPACE", "Space", 6.25),
    Modifier("RALT", "ALT", 1), Cosmetic("Fn", 1), Modifier("RCTRL", "CTRL", 1),
}

local MOUSE = {
    Key("BUTTON1", "M1"), Key("BUTTON2", "M2"), Key("BUTTON3", "M3"), Key("BUTTON4", "M4"), Key("BUTTON5", "M5"),
    Gap(0.25), Key("MOUSEWHEELUP", "WhUp"), Key("MOUSEWHEELDOWN", "WhDn"),
}

local NAV_CLUSTER = {
    fn = { Key("PRINTSCREEN", "PrtSc"), Key("SCROLLLOCK", "ScrLk"), Key("PAUSE", "Pause") },
    num = { Key("INSERT", "Ins"), Key("HOME", "Home"), Key("PAGEUP", "PgUp") },
    top = { Key("DELETE", "Del"), Key("END", "End"), Key("PAGEDOWN", "PgDn") },
    bottom = { Gap(1), Key("UP", "Up") },
    space = { Key("LEFT", "Left"), Key("DOWN", "Down"), Key("RIGHT", "Right") },
}

local NUMPAD = {
    num = { Key("NUMLOCK", "Num"), Key("NUMPADDIVIDE", "/"), Key("NUMPADMULTIPLY", "*"), Key("NUMPADMINUS", "-") },
    top = { Key("NUMPAD7", "7"), Key("NUMPAD8", "8"), Key("NUMPAD9", "9"), Key("NUMPADPLUS", "+", 1, 2) },
    home = { Key("NUMPAD4", "4"), Key("NUMPAD5", "5"), Key("NUMPAD6", "6") },
    bottom = { Key("NUMPAD1", "1"), Key("NUMPAD2", "2"), Key("NUMPAD3", "3"), Key("ENTER", "Ent", 1, 2) },
    space = { Key("NUMPAD0", "0", 2), Key("NUMPADDECIMAL", ".") },
}

local function CompactRightColumn(numRowKey)
    return {
        num = { Gap(2), numRowKey },
        top = { Gap(2), Key("PAGEUP", "PgUp") },
        home = { Gap(2), Key("PAGEDOWN", "PgDn") },
        bottom = { Gap(1), Key("UP", "Up"), Key("END", "End") },
        space = { Key("LEFT", "Left"), Key("DOWN", "Down"), Key("RIGHT", "Right") },
    }
end

local FORM_FACTORS = {
    full = { fn = FN_SPREAD, space = SPACE_FULL, rshift = 2.75, extras = {
        { rows = NAV_CLUSTER, x = 15.25 },
        { rows = NUMPAD, x = 18.5, group = "numpad" },
    } },
    tkl = { fn = FN_SPREAD, space = SPACE_FULL, rshift = 2.75, extras = {
        { rows = NAV_CLUSTER, x = 15.25 },
    } },
    ["75"] = { fn = FN_COMPACT, space = SPACE_COMPACT, rshift = 1.75, extras = {
        { rows = CompactRightColumn(Key("HOME", "Home")), x = 13 },
    } },
    ["65"] = { space = SPACE_COMPACT, rshift = 1.75, extras = {
        { rows = CompactRightColumn(Key("DELETE", "Del")), x = 13 },
    } },
    ["60"] = { space = SPACE_FULL, rshift = 2.75, extras = {} },
}

local function MainBlock(locale, rshiftWidth)
    local top = Keys(locale.top)
    local rshift = Modifier("RSHIFT", "SHIFT", rshiftWidth)
    local rows = { num = Concat(Keys(locale.num), { Key("BACKSPACE", "Bksp", 2) }) }

    if locale.iso then
        rows.top = Concat({ Key("TAB", "Tab", 1.5) }, top, { Gap(0.25), Key("ENTER", "Enter", 1.25, 2) })
        rows.home = Concat({ Key("CAPSLOCK", "Caps", 1.75) }, Keys(locale.home))
        rows.bottom = Concat({ Modifier("LSHIFT", "SHIFT", 1.25) }, Keys(locale.bottom), { rshift })
        return rows
    end

    top[#top].w = 1.5
    rows.top = Concat({ Key("TAB", "Tab", 1.5) }, top)
    rows.home = Concat({ Key("CAPSLOCK", "Caps", 1.75) }, Keys(locale.home), { Key("ENTER", "Enter", 2.25) })
    rows.bottom = Concat({ Modifier("LSHIFT", "SHIFT", 2.25) }, Keys(locale.bottom), { rshift })
    return rows
end

local function PlaceBlock(block, startX, group, out)
    for row, keys in pairs(block) do
        local x = startX
        for _, key in ipairs(keys) do
            if key.gap then
                x = x + key.gap
            else
                out[#out + 1] = {
                    token = key.token, label = key.label, modifier = key.modifier,
                    w = key.w, h = key.h, x = x, row = row, group = group,
                }
                x = x + key.w
            end
        end
    end
end

-- Returns a flat list of key definitions positioned in key units (1u = one standard key).
function ns.BuildKeyboard(localeId, formId)
    local form = FORM_FACTORS[formId]
    local main = MainBlock(LOCALES[localeId], form.rshift)
    main.fn, main.space, main.mouse = form.fn, form.space, MOUSE

    local keys = {}
    PlaceBlock(main, 0, "main", keys)
    for _, extra in ipairs(form.extras) do
        PlaceBlock(extra.rows, extra.x, extra.group, keys)
    end
    return keys
end

-- Every bindable key of the full-size board, whatever size is currently shown.
function ns.AllKeyTokens(localeId)
    local tokens, seen = {}, {}
    for _, def in ipairs(ns.BuildKeyboard(localeId, "full")) do
        if def.token and not def.modifier and not seen[def.token] then
            seen[def.token] = true
            tokens[#tokens + 1] = def.token
        end
    end
    return tokens
end

ns.ROWS = { "fn", "num", "top", "home", "bottom", "space", "mouse" }

ns.LOCALE_OPTIONS = {
    { id = "qwerty", name = "QWERTY (US)" },
    { id = "qwerty_uk", name = "QWERTY (UK ISO)" },
    { id = "qwertz", name = "QWERTZ (DE)" },
    { id = "azerty", name = "AZERTY (FR)" },
}

ns.FORM_OPTIONS = {
    { id = "full", name = "Full (100%)" },
    { id = "tkl", name = "TKL (80%)" },
    { id = "75", name = "75%" },
    { id = "65", name = "65%" },
    { id = "60", name = "60%" },
}

ns.ROW_OPTIONS = {
    { id = "fn", name = "Function row" },
    { id = "num", name = "Number row" },
    { id = "top", name = "QWERTY row" },
    { id = "home", name = "ASDF row" },
    { id = "bottom", name = "ZXCV row" },
    { id = "space", name = "Bottom row" },
    { id = "numpad", name = "Numpad" },
    { id = "mouse", name = "Mouse buttons" },
}
