local _, ns = ...

local FOLLOWER_ICON_SIZE = 20
local FOLLOWER_OFFSET_X, FOLLOWER_OFFSET_Y = 14, 4

-- GetCursorInfo() returns (type, info1, info2, info3); each binder receives the key plus those infos.
local CURSOR_BINDERS = {
    spell = function(key, _, _, spellID)
        SetBindingSpell(key, C_Spell.GetSpellName(spellID))
    end,
    item = function(key, itemID)
        SetBindingItem(key, C_Item.GetItemNameByID(itemID))
    end,
    macro = function(key, macroIndex)
        SetBindingMacro(key, (GetMacroInfo(macroIndex)))
    end,
    mount = function(key, mountID)
        local _, spellID = C_MountJournal.GetMountInfoByID(mountID)
        SetBindingSpell(key, C_Spell.GetSpellName(spellID))
    end,
}

-- Binds that the game can put on the cursor, keyed by their command verb.
local CURSOR_PICKERS = {
    SPELL = C_Spell.PickupSpell,
    ITEM = C_Item.PickupItem,
    MACRO = PickupMacro,
}

local COMMAND_BINDERS = {
    SPELL = SetBindingSpell,
    ITEM = SetBindingItem,
    MACRO = SetBindingMacro,
    CLICK = function(key, target)
        local button, mouseButton = target:match("^(.+):(.+)$")
        SetBindingClick(key, button, mouseButton)
    end,
}

local function BindCommand(key, command)
    local verb, payload = ns.ParseCommand(command)
    local binder = verb and COMMAND_BINDERS[verb]
    if binder then return binder(key, payload) end
    SetBinding(key, command)
end

-- Keys are edited like Blizzard's action bars: drop or click what's on the cursor onto a key, drag a key to
-- pick its bind up, and a bound key hands its old bind back to the cursor. Game controls can't sit on the
-- real cursor, so they are "held" by a label that follows the mouse instead.
local Editing = {}
ns.Editing = Editing

function Editing:IsUnlocked()
    return not ns.db.locked and not InCombatLockdown()
end

function Editing:CanEdit()
    if ns.BlockedInCombat() then return false end
    if not ns.db.locked then return true end
    UIErrorsFrame:AddMessage("KeyBar is locked.", 1, 0.1, 0.1)
    return false
end

function Editing:IsHolding()
    return self.heldCommand ~= nil or GetCursorInfo() ~= nil
end

function Editing:PlaceOnKey(key)
    if not self:CanEdit() then return end
    local previous = GetBindingAction(key)
    if not self:BindHeld(key) then return end
    ns.SaveCharacterBindings()
    self:PickUpCommand(previous)
end

function Editing:BindHeld(key)
    local held = self.heldCommand
    if held then
        self:Release()
        BindCommand(key, held)
        return true
    end

    local cursorType, info1, info2, info3 = GetCursorInfo()
    local binder = CURSOR_BINDERS[cursorType]
    if not binder then
        ns.Print(("Can't bind a %s to a key."):format(tostring(cursorType)))
        return false
    end
    ClearCursor()
    binder(key, info1, info2, info3)
    return true
end

function Editing:PickUpKey(key)
    if not self:IsUnlocked() then return end
    local command = GetBindingAction(key)
    if command == "" then return end
    SetBinding(key)
    ns.SaveCharacterBindings()
    self:PickUpCommand(command)
end

-- Spells the character doesn't know can't go on the cursor, so they are held like a game control.
function Editing:PickUpCommand(command)
    if command == "" then return end
    local verb, payload = ns.ParseCommand(command)
    local picker = verb and CURSOR_PICKERS[verb]
    if picker then picker(payload) end
    if GetCursorInfo() then return end
    self:Hold(command)
end

function Editing:PickUpControl(command)
    if not self:CanEdit() then return end
    self:Hold(command)
end

function Editing:BindControl(key, command)
    if not self:CanEdit() then return end
    BindCommand(key, command)
    ns.SaveCharacterBindings()
end

function Editing:ClearKey(key)
    if not self:CanEdit() then return end
    SetBinding(key)
    ns.SaveCharacterBindings()
end

-- A held control dragged off its key or list row lands where the mouse is released.
function Editing:FinishDrag()
    if not self.heldCommand then return end
    local target = GetMouseFoci()[1]
    if ns.keycaps[target] and target.bindKey then self:PlaceOnKey(target.bindKey) end
end

function Editing:Hold(command)
    ClearCursor()
    self.heldCommand = command
    local binding = ns.ResolveCommand(command)
    local follower = self:Follower()
    local hasIcon = binding.icon or binding.atlas
    follower.Icon:SetShown(hasIcon ~= nil)
    if hasIcon then ns.SetIconArt(follower.Icon, binding) end
    follower.Label:SetText(binding.name)
    follower:Show()
end

function Editing:Release()
    self.heldCommand = nil
    self:Follower():Hide()
end

function Editing:Discard()
    ClearCursor()
    self:Release()
end

-- Clicking anywhere but a key drops a held control, like clicking off an action dragged from a bar.
function Editing:OnGlobalMouseDown()
    if not self.heldCommand then return end
    if ns.keycaps[GetMouseFoci()[1]] then return end
    self:Release()
end

function Editing:Follower()
    if self.follower then return self.follower end

    local follower = CreateFrame("Frame", nil, UIParent)
    follower:SetFrameStrata("TOOLTIP")
    follower:SetSize(FOLLOWER_ICON_SIZE, FOLLOWER_ICON_SIZE)
    follower.Icon = follower:CreateTexture(nil, "ARTWORK")
    follower.Icon:SetAllPoints()
    follower.Label = follower:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    follower.Label:SetPoint("LEFT", follower, "RIGHT", 4, 0)
    follower:SetScript("OnUpdate", function(frame)
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale + FOLLOWER_OFFSET_X, y / scale + FOLLOWER_OFFSET_Y)
    end)
    follower:Hide()

    self.follower = follower
    return follower
end

function Editing:OpenKeyMenu(cap)
    local key = cap.bindKey
    if not key then return end
    MenuUtil.CreateContextMenu(cap, function(_, root)
        root:CreateTitle(GetBindingText(key))
        if ns.db.locked then
            root:CreateButton("Unlock KeyBar", function() ns.Keyboard:SetLocked(false) end)
            return
        end
        root:CreateButton("Clear", function() self:ClearKey(key) end):SetEnabled(GetBindingAction(key) ~= "")
        root:CreateButton("Bind game control...", function() ns.ControlsList:OpenForKey(key) end)
    end)
end
