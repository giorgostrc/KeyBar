local _, ns = ...

local HINT = "Drop spells, items, macros or mounts on a key  ·  Right-click clears  ·  Drag key onto key swaps  ·  Click Shift/Ctrl/Alt to change layer"

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
    if command == "" then return SetBinding(key) end
    local verb, payload = ns.ParseCommand(command)
    local binder = verb and COMMAND_BINDERS[verb]
    if binder then return binder(key, payload) end
    SetBinding(key, command)
end

local Setup = { active = false, mods = {} }
ns.Setup = Setup

function Setup:CanEdit()
    return self.active and not ns.BlockedInCombat()
end

-- Toggling swaps the keys' secure click actions, which is only allowed outside combat.
function Setup:SetActive(active)
    if ns.BlockedInCombat() then return end
    self.active = active
    self:LayerBar():SetShown(active)
    ns.ControlsList:SetShown(active)
    self:UpdateLayerBar()
    ns.Keyboard:Refresh()
    ns.Keyboard:UpdateClickActions()
end

function Setup:SetLayer(mods)
    self.mods = CopyTable(mods)
    self:UpdateLayerBar()
    ns.Keyboard:Refresh()
end

function Setup:ToggleModifier(mod)
    self.mods[mod] = not self.mods[mod] or nil
    self:SetLayer(self.mods)
end

function Setup:OnKeycapClick(cap, button)
    if not self:CanEdit() then return end
    if cap.def.modifier then return self:ToggleModifier(cap.def.modifier) end
    if not cap.bindKey then return end
    if button == "RightButton" then return self:ClearKey(cap.bindKey) end
    if GetCursorInfo() then self:BindCursor(cap.bindKey) end
end

function Setup:OnKeycapReceiveDrag(cap)
    if not self:CanEdit() or not cap.bindKey then return end
    self:BindCursor(cap.bindKey)
end

function Setup:BindCursor(key)
    local cursorType, info1, info2, info3 = GetCursorInfo()
    local binder = CURSOR_BINDERS[cursorType]
    ClearCursor()
    if not binder then
        return ns.Print(("Can't bind a %s to a key."):format(tostring(cursorType)))
    end
    binder(key, info1, info2, info3)
    ns.SaveCharacterBindings()
end

function Setup:ClearKey(key)
    SetBinding(key)
    ns.SaveCharacterBindings()
end

function Setup:BeginSwap(cap)
    self.swapSource = self:CanEdit() and cap.bindKey and cap or nil
end

function Setup:FinishSwap(target)
    local source = self.swapSource
    self.swapSource = nil
    if not source or not ns.keycaps[target] or target == source or not target.bindKey then return end
    if not self:CanEdit() then return end

    local sourceCommand = GetBindingAction(source.bindKey)
    local targetCommand = GetBindingAction(target.bindKey)
    BindCommand(source.bindKey, targetCommand)
    BindCommand(target.bindKey, sourceCommand)
    ns.SaveCharacterBindings()
end

-- Game controls have no cursor object, so dragging one from the list shows a label that follows the mouse.
function Setup:BeginCommandDrag(command, name)
    if not self:CanEdit() then return end
    self.draggedCommand = command
    local follower = self:DragFollower()
    follower.Label:SetText(name)
    follower:Show()
end

function Setup:FinishCommandDrag(target)
    local command = self.draggedCommand
    self.draggedCommand = nil
    self:DragFollower():Hide()
    if not command or not ns.keycaps[target] or not target.bindKey or not self:CanEdit() then return end
    BindCommand(target.bindKey, command)
    ns.SaveCharacterBindings()
end

function Setup:DragFollower()
    if self.dragFollower then return self.dragFollower end

    local follower = CreateFrame("Frame", nil, UIParent)
    follower:SetFrameStrata("TOOLTIP")
    follower:SetSize(1, 1)
    follower.Label = follower:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    follower.Label:SetPoint("BOTTOMLEFT")
    follower:SetScript("OnUpdate", function(frame)
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale + 14, y / scale + 4)
    end)
    follower:Hide()

    self.dragFollower = follower
    return follower
end

function Setup:LayerBar()
    if self.layerBar then return self.layerBar end

    local bar = CreateFrame("Frame", nil, ns.Keyboard)
    bar:SetPoint("BOTTOMLEFT", ns.Keyboard, "TOPLEFT", 4, 2)
    bar:SetSize(1, 40)
    bar.buttons = {}

    local previous
    for index, layer in ipairs(ns.LAYERS) do
        local button = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
        button:SetText(ns.LayerName(layer))
        button:SetSize(button:GetTextWidth() + 20, 20)
        button:SetPoint("BOTTOMLEFT", previous or bar, previous and "BOTTOMRIGHT" or "BOTTOMLEFT", previous and 2 or 0, 0)
        button:SetScript("OnClick", function() self:SetLayer(layer) end)
        button.layer = layer
        bar.buttons[index] = button
        previous = button
    end

    bar.Hint = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.Hint:SetPoint("BOTTOMLEFT", bar.buttons[1], "TOPLEFT", 0, 4)
    bar.Hint:SetText(HINT)

    self.layerBar = bar
    return bar
end

function Setup:UpdateLayerBar()
    local current = ns.ModifierPrefix(self.mods)
    for _, button in ipairs(self:LayerBar().buttons) do
        if ns.ModifierPrefix(button.layer) == current then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end
end

function Setup:OnCombatChanged()
    if self.active then ns.Keyboard:UpdateTitle(self.mods) end
end
