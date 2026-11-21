local _, ns = ...

-- Shared by every skin so the window covers the same area whichever skin is active;
-- it fits the thickest border (Blizzard's) with room to spare.
ns.FRAME_PADDING = 14

local WHITE = "Interface\\Buttons\\WHITE8X8"
local TOOLTIP_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
local DIALOG_BORDER = "Interface\\DialogFrame\\UI-DialogBox-Border"

local FLAT_KEY = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 }

local BEVELED_KEY = {
    bgFile = WHITE,
    edgeFile = TOOLTIP_BORDER,
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local function DialogFrame(background, edgeSize, inset)
    return {
        bgFile = background,
        edgeFile = DIALOG_BORDER,
        tile = true,
        tileSize = 32,
        edgeSize = edgeSize,
        insets = { left = inset, right = inset, top = inset, bottom = inset },
    }
end

-- Colors are { r, g, b, a }.
local SKINS = {
    -- Flat, quiet chrome so the icons carry the colour.
    minimal = {
        frame = {
            backdrop = FLAT_KEY,
            background = { 0.05, 0.05, 0.06, 0.3 },
            border = { 1, 1, 1, 0.06 },
        },
        key = {
            backdrop = FLAT_KEY,
            background = { 0, 0, 0, 0.25 },
            border = { 1, 1, 1, 0.08 },
            pressed = { 1, 1, 1, 0.9 },
            modifierActive = { 0.33, 0.63, 1, 1 },
            label = { 0.68, 0.7, 0.74 },
        },
        buttonArt = false,
    },

    -- The game tooltip look: rounded grey edge on near-black.
    classic = {
        frame = {
            backdrop = {
                bgFile = WHITE,
                edgeFile = TOOLTIP_BORDER,
                edgeSize = 14,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            },
            background = { 0.03, 0.03, 0.04, 0.85 },
            border = { 0.55, 0.55, 0.58, 1 },
        },
        key = {
            backdrop = FLAT_KEY,
            background = { 0.06, 0.06, 0.07, 0.8 },
            border = { 0.24, 0.24, 0.27, 1 },
            pressed = { 1, 0.82, 0, 1 },
            modifierActive = { 0.25, 0.6, 1, 1 },
            label = { 0.85, 0.85, 0.85 },
        },
        buttonArt = true,
    },

    -- Blizzard's dialog frame, tinted gold.
    gilded = {
        frame = {
            backdrop = DialogFrame("Interface\\DialogFrame\\UI-DialogBox-Background-Dark", 20, 5),
            background = { 1, 1, 1, 0.9 },
            border = { 1, 0.8, 0.4, 1 },
        },
        key = {
            backdrop = BEVELED_KEY,
            background = { 0.06, 0.05, 0.03, 0.85 },
            border = { 0.85, 0.68, 0.3, 1 },
            pressed = { 1, 0.95, 0.6, 1 },
            modifierActive = { 0.4, 0.75, 1, 1 },
            label = { 0.85, 0.85, 0.85 },
        },
        buttonArt = true,
    },

    -- Blizzard's window frames: the silver dialog border tinted to their aged bronze on a warm dark ground,
    -- with gold highlights from NORMAL_FONT_COLOR.
    blizzard = {
        frame = {
            backdrop = DialogFrame("Interface\\DialogFrame\\UI-DialogBox-Background", 24, 7),
            background = { 0.9, 0.82, 0.72, 1 },
            border = { 0.8, 0.58, 0.36, 1 },
        },
        key = {
            backdrop = BEVELED_KEY,
            background = { 0.07, 0.05, 0.03, 0.75 },
            border = { 0.58, 0.42, 0.26, 1 },
            pressed = { 1, 0.82, 0, 1 },
            modifierActive = { 0.2, 0.6, 1, 1 },
            label = { 0.78, 0.72, 0.62 },
        },
        buttonArt = true,
    },
}

ns.SKIN_OPTIONS = {
    { id = "minimal", name = "Minimal" },
    { id = "classic", name = "Classic" },
    { id = "blizzard", name = "Blizzard" },
    { id = "gilded", name = "Gilded" },
}

function ns.CurrentSkin()
    return SKINS[ns.db.skin]
end

-- backgroundAlpha overrides the skin's background opacity, e.g. to keep a text list readable.
function ns.ApplyFrameSkin(frame, skin, backgroundAlpha)
    local r, g, b, a = unpack(skin.frame.background)
    frame:SetBackdrop(skin.frame.backdrop)
    frame:SetBackdropColor(r, g, b, backgroundAlpha or a)
    frame:SetBackdropBorderColor(unpack(skin.frame.border))
end
