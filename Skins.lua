local _, ns = ...

local FLAT_KEY = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

-- Colors are { r, g, b, a }. Gold comes from tinting long-standing grey Blizzard borders.
ns.SKINS = {
    classic = {
        frame = {
            backdrop = {
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            },
            background = { 0, 0, 0, 0.45 },
            border = { 0.4, 0.4, 0.4, 1 },
            padding = 8,
        },
        key = {
            backdrop = FLAT_KEY,
            background = { 0.04, 0.04, 0.05, 0.7 },
            border = { 0.22, 0.22, 0.25, 1 },
            pressed = { 1, 0.82, 0, 1 },
            modifierActive = { 0.25, 0.6, 1, 1 },
            label = { 0.85, 0.85, 0.85 },
        },
        buttonArt = true,
    },

    minimal = {
        frame = {
            backdrop = { bgFile = "Interface\\Buttons\\WHITE8X8" },
            background = { 0, 0, 0, 0.2 },
            border = { 0, 0, 0, 0 },
            padding = 6,
        },
        key = {
            backdrop = FLAT_KEY,
            background = { 0, 0, 0, 0.35 },
            border = { 1, 1, 1, 0.08 },
            pressed = { 1, 1, 1, 0.75 },
            modifierActive = { 0.3, 0.65, 1, 0.9 },
            label = { 0.7, 0.7, 0.7 },
        },
        buttonArt = false,
    },

    gilded = {
        frame = {
            backdrop = {
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true,
                tileSize = 32,
                edgeSize = 20,
                insets = { left = 5, right = 5, top = 5, bottom = 5 },
            },
            background = { 1, 1, 1, 0.9 },
            border = { 1, 0.8, 0.4, 1 },
            padding = 13,
        },
        key = {
            backdrop = {
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            },
            background = { 0.06, 0.05, 0.03, 0.85 },
            border = { 0.85, 0.68, 0.3, 1 },
            pressed = { 1, 0.95, 0.6, 1 },
            modifierActive = { 0.4, 0.75, 1, 1 },
            label = { 0.85, 0.85, 0.85 },
        },
        buttonArt = true,
    },
}

ns.SKIN_OPTIONS = {
    { id = "classic", name = "Classic" },
    { id = "minimal", name = "Minimal" },
    { id = "gilded", name = "Gilded" },
}

function ns.CurrentSkin()
    return ns.SKINS[ns.db.skin]
end

-- backgroundAlpha overrides the skin's background opacity, e.g. to keep a text list readable.
function ns.ApplyFrameSkin(frame, skin, backgroundAlpha)
    local r, g, b, a = unpack(skin.frame.background)
    frame:SetBackdrop(skin.frame.backdrop)
    frame:SetBackdropColor(r, g, b, backgroundAlpha or a)
    frame:SetBackdropBorderColor(unpack(skin.frame.border))
end
