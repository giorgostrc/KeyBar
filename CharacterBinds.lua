local _, ns = ...

-- Every character keeps its own WoW binding set. Its first login with KeyBar asks where that set starts;
-- after that KeyBar never changes it on its own.

local DIALOG_WIDTH = 440
local DIALOG_BUTTON_WIDTH = 190
local DIALOG_PADDING = 18

local DIALOG_TEXT = [[How should %s's keybinds start?

|cffffd200Keep current binds|r: this character's own binds, or else the account's binds without other characters' spells, items and macros.

|cffffd200KeyBar defaults|r: Blizzard's defaults with 1 to =, Q, E, R, T, F, G, Z, X, C and V cleared, with and without Shift. Character on ",", friendly and enemy nameplates on "[" and "]", Autorun on "\", strafe on A and D.]]

-- Freed for the player's own spells, items and macros; WASD stays as movement.
local DEFAULTS_CLEARED_KEYS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "Q", "E", "R", "T", "F", "G", "Z", "X", "C", "V" }
local DEFAULTS_CLEARED_PREFIXES = { "", "SHIFT-" }

-- Spell, item, macro and click binds carry a payload ("SPELL Frostbolt"); controls are bare commands.
local function IsCharacterBind(command)
    return command:find("^%u+ ") ~= nil
end

-- WoW's account set mixes in every character's spells, items and macros, so only its controls are kept.
local function KeepCurrentBinds()
    if GetCurrentBindingSet() == Enum.BindingSet.Character then return end
    for _, token in ipairs(ns.AllKeyTokens(ns.db.locale)) do
        for _, layer in ipairs(ns.LAYERS) do
            local key = ns.ModifierPrefix(layer) .. token
            if IsCharacterBind(GetBindingAction(key)) then
                SetBinding(key)
            end
        end
    end
end

local function MoveBinding(command, key)
    for _, oldKey in ipairs({ GetBindingKey(command) }) do
        SetBinding(oldKey)
    end
    SetBinding(key, command)
end

local function LoadKeyBarDefaults()
    LoadBindings(Enum.BindingSet.Default)
    for _, prefix in ipairs(DEFAULTS_CLEARED_PREFIXES) do
        for _, key in ipairs(DEFAULTS_CLEARED_KEYS) do
            SetBinding(prefix .. key)
        end
    end
    MoveBinding("TOGGLECHARACTER0", ",")
    MoveBinding("FRIENDNAMEPLATES", "[")
    MoveBinding("NAMEPLATES", "]")
    MoveBinding("TOGGLEAUTORUN", "\\")
    MoveBinding("STRAFELEFT", "A")
    MoveBinding("STRAFERIGHT", "D")
end

local CharacterBinds = { variablesLoaded = false, done = false }
ns.CharacterBinds = CharacterBinds

function CharacterBinds:Start(loadStartingBinds)
    loadStartingBinds()
    SaveBindings(Enum.BindingSet.Character)
    ns.db.setUpCharacters[UnitGUID("player")] = true
end

-- Runs once per session, after keybinds have loaded (VARIABLES_LOADED) and outside combat.
function CharacterBinds:TryRun()
    if self.done or not (self.variablesLoaded and ns.db) then return end
    if InCombatLockdown() then
        return EventUtil.RegisterOnceFrameEventAndCallback("PLAYER_REGEN_ENABLED", function() self:TryRun() end)
    end
    self.done = true
    if not ns.db.setUpCharacters[UnitGUID("player")] then
        self:ShowStartDialog()
    end
end

function CharacterBinds:ShowStartDialog()
    local dialog = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    ns.ApplyFrameSkin(dialog, ns.CurrentSkin(), 0.95)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetPoint("CENTER", 0, 120)
    dialog:SetWidth(DIALOG_WIDTH)
    dialog:EnableMouse(true)

    local text = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    -- A fixed width, rather than left and right anchors, lets the height be measured before the first layout.
    text:SetPoint("TOPLEFT", DIALOG_PADDING, -DIALOG_PADDING)
    text:SetWidth(DIALOG_WIDTH - 2 * DIALOG_PADDING)
    text:SetJustifyH("LEFT")
    text:SetText(DIALOG_TEXT:format(UnitName("player")))
    dialog:SetHeight(text:GetStringHeight() + 76)

    local function AddChoice(label, loadStartingBinds, offsetX)
        local button = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        button:SetSize(DIALOG_BUTTON_WIDTH, 24)
        button:SetPoint("BOTTOM", offsetX, 18)
        button:SetText(label)
        button:SetScript("OnClick", function()
            if ns.BlockedInCombat() then return end
            dialog:Hide()
            self:Start(loadStartingBinds)
        end)
    end
    AddChoice("Keep current binds", KeepCurrentBinds, -(DIALOG_BUTTON_WIDTH / 2 + 6))
    AddChoice("KeyBar defaults", LoadKeyBarDefaults, DIALOG_BUTTON_WIDTH / 2 + 6)
end

EventUtil.RegisterOnceFrameEventAndCallback("VARIABLES_LOADED", function()
    CharacterBinds.variablesLoaded = true
    CharacterBinds:TryRun()
end)
