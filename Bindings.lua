local _, ns = ...

-- WoW writes modifier prefixes in this fixed order, e.g. "ALT-CTRL-SHIFT-Q".
local MODIFIER_ORDER = { "ALT", "CTRL", "SHIFT" }

-- Binding command prefix -> Blizzard button frame name prefix.
local BAR_BUTTON_FRAMES = {
    ACTIONBUTTON = "ActionButton",
    MULTIACTIONBAR1BUTTON = "MultiBarBottomLeftButton",
    MULTIACTIONBAR2BUTTON = "MultiBarBottomRightButton",
    MULTIACTIONBAR3BUTTON = "MultiBarRightButton",
    MULTIACTIONBAR4BUTTON = "MultiBarLeftButton",
    MULTIACTIONBAR5BUTTON = "MultiBar5Button",
    MULTIACTIONBAR6BUTTON = "MultiBar6Button",
    MULTIACTIONBAR7BUTTON = "MultiBar7Button",
}

ns.LAYERS = {
    {},
    { SHIFT = true },
    { CTRL = true },
    { ALT = true },
    { CTRL = true, SHIFT = true },
    { ALT = true, SHIFT = true },
    { ALT = true, CTRL = true },
    { ALT = true, CTRL = true, SHIFT = true },
}

-- Blizzard numbers bars 1-8: the main bar, then MULTIACTIONBAR1..7.
local BAR_NUMBERS = {}
for commandPrefix in pairs(BAR_BUTTON_FRAMES) do
    BAR_NUMBERS[commandPrefix] = (tonumber(commandPrefix:match("^MULTIACTIONBAR(%d)")) or 0) + 1
end

local COMMAND_ICONS = {
    TOGGLESPELLBOOK = "Interface\\Icons\\INV_Misc_Book_09",
    TOGGLEBACKPACK = "Interface\\Icons\\INV_Misc_Bag_08",
    OPENALLBAGS = "Interface\\Icons\\INV_Misc_Bag_08",
    TOGGLEWORLDMAP = "Interface\\Icons\\INV_Misc_Map_01",
    TOGGLEQUESTLOG = "Interface\\Icons\\INV_Misc_Note_01",
    TOGGLECOLLECTIONS = "Interface\\Icons\\Ability_Mount_RidingHorse",
    TOGGLETALENTS = "Interface\\Icons\\Ability_Marksmanship",
    TOGGLEGAMEMENU = "Interface\\Icons\\INV_Misc_Gear_01",
    TOGGLECHARACTER0 = "Interface\\Icons\\Achievement_Character_Human_Male",
    TOGGLECHARACTER2 = "Interface\\Icons\\Achievement_Reputation_01",
    TOGGLECHARACTER4 = "Interface\\Icons\\Ability_DualWield",
    TOGGLEPROFESSIONBOOK = "Interface\\Icons\\Trade_BlackSmithing",
    TOGGLECURRENCY = "Interface\\Icons\\INV_Misc_Coin_01",
    TOGGLESOCIAL = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend",
    TOGGLEACHIEVEMENT = "Interface\\Icons\\Achievement_Quests_Completed_08",
}

-- Movement shown as an arrow, rotated counter-clockwise from pointing up.
local COMMAND_ARROWS = {
    MOVEFORWARD = { rotation = 0 },
    MOVEBACKWARD = { rotation = math.pi },
    STRAFELEFT = { rotation = math.pi / 2 },
    STRAFERIGHT = { rotation = -math.pi / 2 },
    TURNLEFT = { rotation = math.pi / 2, caption = "Turn" },
    TURNRIGHT = { rotation = -math.pi / 2, caption = "Turn" },
}

-- Shorter than Blizzard's names, so they fit on a single key.
local COMMAND_LABELS = {
    JUMP = "Jump",
    TOGGLEAUTORUN = "Autorun",
    SITORSTAND = "Sit",
    TARGETNEARESTENEMY = "Target Enemy",
    INTERACTTARGET = "Interact",
    CAMERAZOOMIN = "Zoom In",
    CAMERAZOOMOUT = "Zoom Out",
}

-- Blizzard's localized name lives in the BINDING_NAME_<command> global; title-case the raw command otherwise.
local function CommandName(command)
    local name = _G["BINDING_NAME_" .. command]
    if name then return name end
    return (command:gsub("_", " "):lower():gsub("^%l", string.upper))
end

-- Micro menu buttons carry Blizzard's own art for many panel toggles (character, legacy, collections, ...).
-- Pick the button whose tooltip text is the longest match inside the binding's name.
local function MicroButtonArt(bindingName)
    if not MicroMenu then return nil end
    local best, bestLength = nil, 0
    for _, button in ipairs({ MicroMenu:GetChildren() }) do
        local text = button.tooltipText and button.tooltipText:gsub("%s*|c%x+%(.-%)|r", "")
        if text and #text > bestLength and bindingName:find(text, 1, true) then
            best, bestLength = button, #text
        end
    end
    local texture = best and best:GetNormalTexture()
    return texture and { icon = texture:GetTexture(), atlas = texture:GetAtlas() }
end

local commandArtCache = {}

-- Returns { icon, atlas } art for a game-control command, or nil when it has none.
-- Only hits are cached: micro buttons may not have their tooltip text yet on the first lookup.
function ns.CommandArt(command, name)
    local cached = commandArtCache[command]
    if cached then return cached end
    local icon = COMMAND_ICONS[command]
    local art = icon and { icon = icon } or MicroButtonArt(name)
    commandArtCache[command] = art
    return art
end

function ns.SetIconArt(texture, art)
    if art.atlas then return texture:SetAtlas(art.atlas) end
    texture:SetTexture(art.icon)
    texture:SetTexCoord(0, 1, 0, 1)
end

local function DisplayLabel(command, name, buttonPrefix, buttonIndex)
    if COMMAND_LABELS[command] then return COMMAND_LABELS[command] end
    local bar = buttonPrefix and BAR_NUMBERS[buttonPrefix]
    if bar then return ("Bar %d\n#%s"):format(bar, buttonIndex) end
    return (name:gsub("^Toggle ", ""):gsub(" Pane$", ""))
end

local function FromActionSlot(slot)
    if type(slot) ~= "number" or not HasAction(slot) then return nil end
    return { kind = "action", value = slot, icon = GetActionTexture(slot) }
end

local BUTTON_RESOLVERS = {
    SHAPESHIFTBUTTON = function(index)
        local icon = GetShapeshiftFormInfo(index)
        return icon and { kind = "stance", value = index, icon = icon }
    end,
    BONUSACTIONBUTTON = function(index)
        local _, texture, isToken = GetPetActionInfo(index)
        return texture and { kind = "pet", value = index, icon = isToken and _G[texture] or texture }
    end,
}
for commandPrefix, framePrefix in pairs(BAR_BUTTON_FRAMES) do
    BUTTON_RESOLVERS[commandPrefix] = function(index)
        local button = _G[framePrefix .. index]
        return button and FromActionSlot(button.action)
    end
end

-- Spellbook spells and collected mounts count as known. A name lookup alone can also resolve
-- spells this character can't cast, e.g. another class's spell inherited through account-wide binds.
local function IsSpellKnownByCharacter(spellID)
    if IsPlayerSpell(spellID) then return true end
    local mountID = C_MountJournal.GetMountFromSpell(spellID)
    return mountID ~= nil and select(11, C_MountJournal.GetMountInfoByID(mountID))
end

-- Returns (verb, payload) for commands made by SetBindingSpell and friends ("SPELL Fireball"),
-- and (buttonPrefix, buttonIndex) for button commands ("ACTIONBUTTON3").
function ns.ParseCommand(command)
    local verb, payload = command:match("^(%u+) (.+)$")
    local buttonPrefix, buttonIndex = command:match("^(.-BUTTON)(%d+)$")
    return verb, payload, buttonPrefix, buttonIndex
end

-- Spells the character doesn't know resolve to nil, so the key shows the spell's name as text.
local PAYLOAD_RESOLVERS = {
    SPELL = function(spell)
        local info = C_Spell.GetSpellInfo(spell)
        if not (info and IsSpellKnownByCharacter(info.spellID)) then return nil end
        return { kind = "spell", value = info.spellID, icon = info.iconID }
    end,
    ITEM = function(item)
        local itemID, _, _, _, icon = C_Item.GetItemInfoInstant(item)
        return itemID and { kind = "item", value = itemID, icon = icon }
    end,
    MACRO = function(macro)
        local index = GetMacroIndexByName(macro)
        if index == 0 then return nil end
        local _, icon = GetMacroInfo(index)
        return { kind = "macro", value = index, icon = icon }
    end,
    -- The target reads "FrameName:MouseButton".
    CLICK = function(target)
        local button = _G[target:match("^[^:]+")]
        return button and FromActionSlot(button.action)
    end,
}

function ns.CurrentModifiers()
    return { ALT = IsAltKeyDown(), CTRL = IsControlKeyDown(), SHIFT = IsShiftKeyDown() }
end

function ns.ModifierPrefix(mods)
    local prefix = ""
    for _, mod in ipairs(MODIFIER_ORDER) do
        if mods[mod] then prefix = prefix .. mod .. "-" end
    end
    return prefix
end

function ns.LayerName(mods)
    local names = {}
    for _, mod in ipairs(MODIFIER_ORDER) do
        if mods[mod] then names[#names + 1] = ns.ModifierLabel(mod) end
    end
    return #names > 0 and table.concat(names, "+") or "Base"
end

-- Macros resolve to the spell they would cast, including a specific rank such as "/cast Frostbolt(Rank 1)".
local function BindingSpellID(binding)
    if binding.kind == "spell" then return binding.value end
    if binding.kind == "macro" then return GetMacroSpell(binding.value) end
    if binding.kind ~= "action" then return nil end
    local actionType, id = GetActionInfo(binding.value)
    if actionType == "spell" then return id end
    if actionType ~= "macro" then return nil end
    local macroName = GetActionText(binding.value)
    return macroName and GetMacroSpell(macroName)
end

-- Spell subtext reads like "Rank 3".
local function RankNumber(spellID)
    local subtext = C_Spell.GetSpellSubtext(spellID)
    return subtext and tonumber(subtext:match("%d+"))
end

local function BindingItemID(binding)
    if binding.kind == "item" then return binding.value end
    if binding.kind == "macro" then
        local _, itemLink = GetMacroItem(binding.value)
        return itemLink and C_Item.GetItemInfoInstant(itemLink)
    end
    if binding.kind ~= "action" then return nil end
    local actionType, id = GetActionInfo(binding.value)
    return actionType == "item" and id or nil
end

-- Bag count of a consumable-class item (potion, food, drink, mana gem, ...), including charges; nil for anything else.
local function ConsumableCount(binding)
    local itemID = BindingItemID(binding)
    if not itemID or select(6, C_Item.GetItemInfoInstant(itemID)) ~= Enum.ItemClass.Consumable then return nil end
    return C_Item.GetItemCount(itemID, false, true)
end

-- Returns (rank, highestRank) when the spell is a lower rank than the highest known; nil otherwise.
-- Looking a spell up by name yields the highest rank the character knows.
local function LowerRank(spellID)
    local name = spellID and C_Spell.GetSpellName(spellID)
    local highest = name and C_Spell.GetSpellInfo(name)
    if not highest or highest.spellID == spellID then return nil end
    local rank, highestRank = RankNumber(spellID), RankNumber(highest.spellID)
    if rank and highestRank and rank < highestRank then return rank, highestRank end
end

-- Resolves a full key ("SHIFT-Q") to { kind, value, icon, label }, or nil when unbound.
function ns.ResolveBinding(key)
    local command = GetBindingAction(key, true)
    if command == "" then return nil end

    local verb, payload, buttonPrefix, buttonIndex = ns.ParseCommand(command)
    local payloadResolver = verb and PAYLOAD_RESOLVERS[verb]
    local buttonResolver = buttonPrefix and BUTTON_RESOLVERS[buttonPrefix]

    local name = payload or CommandName(command)
    local art = not (payloadResolver or buttonResolver) and ns.CommandArt(command, name) or nil
    local binding = (payloadResolver and payloadResolver(payload))
        or (buttonResolver and buttonResolver(tonumber(buttonIndex)))
        or { kind = "command", icon = art and art.icon, atlas = art and art.atlas }
    binding.name = name
    binding.command = command
    binding.label = DisplayLabel(command, name, buttonPrefix, buttonIndex)
    binding.arrow = COMMAND_ARROWS[command]
    binding.rank, binding.highestRank = LowerRank(BindingSpellID(binding))
    binding.count = ConsumableCount(binding)
    return binding
end

-- An unbound modifier layer falls back to the base key. Returns (key whose bind applies, isFallback).
function ns.EffectiveKey(key, baseKey)
    if key == baseKey or GetBindingAction(key, true) ~= "" then return key, false end
    return baseKey, true
end

-- Verb -> secure action type, which is also the attribute holding the payload.
local PAYLOAD_CLICK_TYPES = { SPELL = "spell", ITEM = "item", MACRO = "macro" }

-- A secure "click" sends its target only a key-up, which Blizzard's action buttons ignore while
-- "cast on key down" is on. Clicking down then up, like a key press, fires them either way, and
-- clicking the button itself follows bar paging (stances, stealth) in combat.
local function KeyPressMacro(frameName, mouseButton)
    return ("/click %s %s true\n/click %s %s false"):format(frameName, mouseButton, frameName, mouseButton)
end

-- Binding command prefix -> (type, attribute, value) for a secure click; receives the button index as a string.
local BUTTON_CLICK_ACTIONS = {
    SHAPESHIFTBUTTON = function(index) return "click", "clickbutton", _G["StanceButton" .. index] end,
    BONUSACTIONBUTTON = function(index) return "pet", "action", tonumber(index) end,
}
for commandPrefix, framePrefix in pairs(BAR_BUTTON_FRAMES) do
    BUTTON_CLICK_ACTIONS[commandPrefix] = function(index)
        return "macro", "macrotext", KeyPressMacro(framePrefix .. index, "LeftButton")
    end
end

-- Returns (type, attribute, value) for a secure click that does what the key does, or nil for game controls.
function ns.ClickAction(key, baseKey)
    local command = GetBindingAction((ns.EffectiveKey(key, baseKey)), true)
    local verb, payload, buttonPrefix, buttonIndex = ns.ParseCommand(command)
    if verb == "CLICK" then
        local frameName, mouseButton = payload:match("^([^:]+):?(.*)$")
        return "macro", "macrotext", KeyPressMacro(frameName, mouseButton ~= "" and mouseButton or "LeftButton")
    end

    local actionType = verb and PAYLOAD_CLICK_TYPES[verb]
    if actionType then return actionType, actionType, payload end

    local buttonAction = buttonPrefix and BUTTON_CLICK_ACTIONS[buttonPrefix]
    if buttonAction then return buttonAction(buttonIndex) end
end

local function ApplyDuration(cooldown, duration)
    if duration then
        cooldown:SetCooldownFromDurationObject(duration, true)
    else
        cooldown:Clear()
    end
end

-- Duration objects let the Cooldown widget draw secret (combat-restricted) values without Lua reading them.
local COOLDOWN_UPDATERS = {
    action = function(cooldown, slot)
        ApplyDuration(cooldown, C_ActionBar.GetActionCooldownDuration(slot))
    end,
    spell = function(cooldown, spellID)
        ApplyDuration(cooldown, C_Spell.GetSpellCooldownDuration(spellID))
    end,
    item = function(cooldown, itemID)
        local start, duration = C_Container.GetItemCooldown(itemID)
        cooldown:SetCooldown(start, duration)
    end,
    macro = function(cooldown, macroIndex)
        local spellID = GetMacroSpell(macroIndex)
        ApplyDuration(cooldown, spellID and C_Spell.GetSpellCooldownDuration(spellID))
    end,
}

function ns.UpdateCooldown(cooldown, binding)
    local updater = COOLDOWN_UPDATERS[binding.kind]
    if updater then
        updater(cooldown, binding.value)
    else
        cooldown:Clear()
    end
end

-- Each check returns (isUsable, notEnoughPower, inRange); inRange is nil when the range doesn't apply or there's no target.
local function SpellUsability(spellID)
    local isUsable, notEnoughPower = C_Spell.IsSpellUsable(spellID)
    return isUsable, notEnoughPower, C_Spell.IsSpellInRange(spellID, "target")
end

local USABILITY_CHECKS = {
    action = function(slot)
        local isUsable, notEnoughPower = C_ActionBar.IsUsableAction(slot)
        return isUsable, notEnoughPower, C_ActionBar.IsActionInRange(slot)
    end,
    spell = SpellUsability,
    macro = function(macroIndex)
        local spellID = GetMacroSpell(macroIndex)
        if not spellID then return true end
        return SpellUsability(spellID)
    end,
}

-- Same precedence as Blizzard's action buttons: out of range, then not enough power, then unusable.
function ns.UsabilityState(binding)
    local check = USABILITY_CHECKS[binding.kind]
    if not check then return "usable" end
    local isUsable, notEnoughPower, inRange = check(binding.value)
    if inRange == false then return "outOfRange" end
    if notEnoughPower then return "notEnoughPower" end
    if not isUsable then return "unusable" end
    return "usable"
end

local TOOLTIP_SETTERS = {
    action = function(tooltip, slot) tooltip:SetAction(slot) end,
    spell = function(tooltip, spellID) tooltip:SetSpellByID(spellID) end,
    item = function(tooltip, itemID) tooltip:SetItemByID(itemID) end,
    stance = function(tooltip, index) tooltip:SetShapeshift(index) end,
    pet = function(tooltip, index) tooltip:SetPetAction(index) end,
}

function ns.ShowBindingTooltip(owner, key, binding, isFallback)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if not binding then
        GameTooltip:SetText("Unbound")
        GameTooltip:AddLine(key, 0.6, 0.6, 0.6)
        return GameTooltip:Show()
    end

    local setter = TOOLTIP_SETTERS[binding.kind]
    if setter then
        setter(GameTooltip, binding.value)
    else
        GameTooltip:SetText(binding.name)
    end
    GameTooltip:AddLine(key, 0.6, 0.6, 0.6)
    if binding.highestRank then
        GameTooltip:AddLine(("Highest known: Rank %d"):format(binding.highestRank), 0.6, 0.6, 0.6)
    end
    if binding.kind == "command" and not (binding.icon or binding.atlas) then
        GameTooltip:AddLine(binding.command, 0.45, 0.45, 0.45)
    end
    if isFallback then
        GameTooltip:AddLine("Not bound on this layer: the base key fires instead.", 1, 0.82, 0, true)
    end
    GameTooltip:Show()
end
