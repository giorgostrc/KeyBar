local addonName, ns = ...

local Keyboard, Editing, ControlsList = ns.Keyboard, ns.Editing, ns.ControlsList

local DEFAULTS = {
    shown = true,
    locked = false,
    showTitle = true,
    setUpCharacters = {},
    skin = "minimal",
    scale = 1,
    locale = "qwerty",
    form = "tkl",
    rows = { fn = true, num = true, top = true, home = true, bottom = true, space = true, numpad = false, mouse = false },
}

local SCALE_OPTIONS = {
    { id = 0.6, name = "60%" },
    { id = 0.75, name = "75%" },
    { id = 0.9, name = "90%" },
    { id = 1, name = "100%" },
    { id = 1.25, name = "125%" },
}

local function ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = target[key] or {}
            ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

local function FindOption(options, id)
    for _, option in ipairs(options) do
        if tostring(option.id) == id then return option end
    end
end

local function OptionIds(options)
    local ids = {}
    for _, option in ipairs(options) do
        ids[#ids + 1] = tostring(option.id)
    end
    return table.concat(ids, ", ")
end

function ns.Print(message)
    print(("|cff33ccff%s|r: %s"):format(addonName, message))
end

local function SetOption(field, value)
    if ns.BlockedInCombat() then return end
    ns.db[field] = value
    Keyboard:Layout()
end

local function SetScale(scale)
    if ns.BlockedInCombat() then return end
    Keyboard:SetClampedScale(scale)
end

local function ToggleRow(row)
    if ns.BlockedInCombat() then return end
    ns.db.rows[row] = not ns.db.rows[row]
    Keyboard:Layout()
end

local function AddRadioGroup(parent, options, isSelected, onSelect)
    for _, option in ipairs(options) do
        parent:CreateRadio(option.name, function() return isSelected(option.id) end, function() onSelect(option.id) end)
    end
end

function ns.OpenMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(addonName)
        AddRadioGroup(root:CreateButton("Layout"), ns.LOCALE_OPTIONS,
            function(id) return ns.db.locale == id end, function(id) SetOption("locale", id) end)
        AddRadioGroup(root:CreateButton("Size"), ns.FORM_OPTIONS,
            function(id) return ns.db.form == id end, function(id) SetOption("form", id) end)
        AddRadioGroup(root:CreateButton("Skin"), ns.SKIN_OPTIONS,
            function(id) return ns.db.skin == id end, function(id) SetOption("skin", id) end)
        AddRadioGroup(root:CreateButton("Scale"), SCALE_OPTIONS,
            function(id) return ns.db.scale == id end, SetScale)

        local rows = root:CreateButton("Rows")
        for _, row in ipairs(ns.ROW_OPTIONS) do
            rows:CreateCheckbox(row.name, function() return ns.db.rows[row.id] end, function() ToggleRow(row.id) end)
        end

        root:CreateDivider()
        root:CreateCheckbox("Show title bar", function() return ns.db.showTitle end,
            function() SetOption("showTitle", not ns.db.showTitle) end)
        root:CreateCheckbox("Lock keys and position", function() return ns.db.locked end, function() Keyboard:SetLocked(not ns.db.locked) end)
        root:CreateCheckbox("Game controls list", function() return ControlsList:IsShown() end,
            function() ControlsList:SetShown(not ControlsList:IsShown()) end)
        root:CreateButton("Hide", function() Keyboard:SetVisible(false) end)
    end)
end

local function ChooseOption(options, field, arg)
    local option = FindOption(options, arg)
    if not option then return ns.Print(("Options: %s"):format(OptionIds(options))) end
    SetOption(field, option.id)
end

local SLASH_COMMANDS = {
    [""] = function() Keyboard:SetVisible(not Keyboard:IsShown()) end,
    show = function() Keyboard:SetVisible(true) end,
    hide = function() Keyboard:SetVisible(false) end,
    lock = function()
        Keyboard:SetLocked(not ns.db.locked)
        ns.Print(ns.db.locked and "Locked." or "Unlocked.")
    end,
    controls = function() ControlsList:SetShown(not ControlsList:IsShown()) end,
    menu = function() ns.OpenMenu(Keyboard) end,
    layout = function(arg) ChooseOption(ns.LOCALE_OPTIONS, "locale", arg) end,
    size = function(arg) ChooseOption(ns.FORM_OPTIONS, "form", arg) end,
    skin = function(arg) ChooseOption(ns.SKIN_OPTIONS, "skin", arg) end,
    title = function() SetOption("showTitle", not ns.db.showTitle) end,
    row = function(arg)
        if not FindOption(ns.ROW_OPTIONS, arg) then return ns.Print(("Rows: %s"):format(OptionIds(ns.ROW_OPTIONS))) end
        ToggleRow(arg)
    end,
    scale = function(arg)
        local scale = tonumber(arg)
        if not scale then return ns.Print(("Usage: /keybar scale %s-%s"):format(ns.MIN_SCALE, ns.MAX_SCALE)) end
        SetScale(scale)
    end,
    reset = function()
        if ns.BlockedInCombat() then return end
        ns.db.position = nil
        Keyboard:RestorePosition()
    end,
    keytest = function()
        ns.keytest = not ns.keytest
        ns.Print(ns.keytest and "Printing key tokens. Run again to stop." or "Stopped printing key tokens.")
    end,
}

local HELP = {
    "/keybar - toggle the keyboard",
    "/keybar controls - toggle the grouped game controls list",
    "/keybar lock - lock or unlock keys and position",
    "/keybar menu - open options (or hover the keyboard and click the gear)",
    "/keybar layout <" .. OptionIds(ns.LOCALE_OPTIONS) .. ">",
    "/keybar size <" .. OptionIds(ns.FORM_OPTIONS) .. ">",
    "/keybar row <" .. OptionIds(ns.ROW_OPTIONS) .. "> - toggle a row",
    "/keybar skin <" .. OptionIds(ns.SKIN_OPTIONS) .. ">",
    "/keybar title - show or hide the title bar",
    "/keybar scale <number>",
    "/keybar reset - reset position",
    "/keybar keytest - print the token of each key you press",
}

SLASH_KEYBAR1 = "/keybar"
SlashCmdList.KEYBAR = function(input)
    local command, arg = input:lower():match("^(%S*)%s*(.-)$")
    local handler = SLASH_COMMANDS[command]
    if handler then return handler(arg) end
    for _, line in ipairs(HELP) do
        ns.Print(line)
    end
end

-- Events like UPDATE_BINDINGS and SPELL_UPDATE_COOLDOWN fire in bursts; each burst costs one pass on the next frame.
local function OncePerFrame(fn)
    local pending = false
    local function run()
        pending = false
        fn()
    end
    return function()
        if pending then return end
        pending = true
        C_Timer.After(0, run)
    end
end

local RequestRefresh = OncePerFrame(function() Keyboard:Refresh() end)
local RefreshCooldowns = OncePerFrame(function() Keyboard:RefreshCooldowns() end)
local OnBindingsChanged = OncePerFrame(function()
    Keyboard:Refresh()
    Keyboard:UpdateClickActions()
    ControlsList:Refresh()
    ns.RefreshSpellbook()
end)

local EVENT_HANDLERS = {
    MODIFIER_STATE_CHANGED = function(key, down)
        Keyboard:SetTokenPressed(key, down == 1)
        RequestRefresh()
    end,
    GLOBAL_MOUSE_DOWN = function(button)
        Keyboard:OnMouseButton(button, true)
        Editing:OnGlobalMouseDown()
    end,
    GLOBAL_MOUSE_UP = function(button) Keyboard:OnMouseButton(button, false) end,
    -- Binds can't be edited in combat, so a held game control is dropped.
    PLAYER_REGEN_DISABLED = function() Editing:Release() end,
    PLAYER_REGEN_ENABLED = function()
        if Keyboard.clickActionsPending then Keyboard:UpdateClickActions() end
    end,
    UPDATE_BINDINGS = OnBindingsChanged,
    ACTIONBAR_SLOT_CHANGED = RequestRefresh,
    ACTIONBAR_PAGE_CHANGED = RequestRefresh,
    UPDATE_BONUS_ACTIONBAR = RequestRefresh,
    UPDATE_MACROS = RequestRefresh,
    SPELLS_CHANGED = RequestRefresh,
    UPDATE_SHAPESHIFT_FORMS = RequestRefresh,
    PET_BAR_UPDATE = RequestRefresh,
    BAG_UPDATE_DELAYED = RequestRefresh,
    SPELL_UPDATE_COOLDOWN = RefreshCooldowns,
    ACTIONBAR_UPDATE_COOLDOWN = RefreshCooldowns,
    BAG_UPDATE_COOLDOWN = RefreshCooldowns,
}

local function Start()
    KeyBarDB = ApplyDefaults(KeyBarDB or {}, DEFAULTS)
    ns.db = KeyBarDB
    Keyboard:Init()

    local events = CreateFrame("Frame")
    for event in pairs(EVENT_HANDLERS) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent", function(_, event, ...)
        EVENT_HANDLERS[event](...)
    end)
    ns.CharacterBinds:TryRun()
end

-- SavedVariables are loaded by PLAYER_LOGIN. Secure keys can't be set up in combat,
-- so a /reload mid-fight waits for combat to end.
EventUtil.RegisterOnceFrameEventAndCallback("PLAYER_LOGIN", function()
    if InCombatLockdown() then
        return EventUtil.RegisterOnceFrameEventAndCallback("PLAYER_REGEN_ENABLED", Start)
    end
    Start()
end)
