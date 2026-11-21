local addonName, ns = ...

local UNIT = 40
local KEY_GAP = 3
local TITLE_HEIGHT = 16
local ROW_GAP_BEFORE = { num = 0.25, mouse = 0.5 }
local PRESS_FLASH_SECONDS = 0.15
local USABILITY_POLL_SECONDS = 0.2
local CORNER_BUTTON_SIZE = 16
local CORNER_BUTTON_GAP = 4
local CORNER_FADE_PER_SECOND = 5
local LOCKED_BUTTON_ALPHA = 0.35

-- Below half size the keys and their labels become unreadable.
ns.MIN_SCALE = 0.5
ns.MAX_SCALE = 2

-- Held modifiers are tracked through MODIFIER_STATE_CHANGED, which reports both press and release.
local MODIFIER_TOKENS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true }

local NEXT_ROW = {}
for index, row in ipairs(ns.ROWS) do
    NEXT_ROW[row] = ns.ROWS[index + 1]
end

local MOUSE_TOKENS = {
    LeftButton = "BUTTON1",
    RightButton = "BUTTON2",
    MiddleButton = "BUTTON3",
    Button4 = "BUTTON4",
    Button5 = "BUTTON5",
}

-- The keys are secure buttons, so the keyboard can't be moved, resized, shown or hidden in combat.
function ns.BlockedInCombat()
    if not InCombatLockdown() then return false end
    UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1)
    return true
end

local Keyboard = CreateFrame("Frame", "KeyBarFrame", UIParent, "BackdropTemplate")
Keyboard:Hide()
ns.Keyboard = Keyboard

function Keyboard:Init()
    self:SetClampedToScreen(true)
    self:SetMovable(true)
    self:EnableMouse(true)
    self:RegisterForDrag("LeftButton")
    self:SetScript("OnDragStart", self.StartDragging)
    self:SetScript("OnDragStop", self.StopDragging)
    self:SetScript("OnShow", self.OnShow)
    self:SetScript("OnHide", self.OnHide)

    self.Title = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.Board = CreateFrame("Frame", nil, self)
    self:CreateCornerControls()

    self.KeyListener = CreateFrame("Frame", nil, self)
    self.KeyListener:SetScript("OnKeyDown", function(_, key) self:OnKeyDown(key) end)

    self.caps, self.capsByToken, self.visibleCount = {}, {}, 0

    self:RestorePosition()
    ns.db.scale = Clamp(ns.db.scale, ns.MIN_SCALE, ns.MAX_SCALE)
    self:SetScale(ns.db.scale)
    self:EnableKeyListener()
    self:Layout()
    self:SetShown(ns.db.shown)
end

-- The listener must pass every key on to the game's bindings; a frame that keeps keys blocks all keybinds.
function Keyboard:EnableKeyListener()
    self.KeyListener:SetPropagateKeyboardInput(true)
    self.KeyListener:EnableKeyboard(true)
    if self.KeyListener:GetPropagateKeyboardInput() then return end
    self.KeyListener:EnableKeyboard(false)
    ns.Print("The client won't let KeyBar pass keys through, so key press highlights are off to keep your binds working.")
end

-- Propagating frames never receive OnKeyUp, so a press shows as a short flash like Blizzard's action buttons.
function Keyboard:OnKeyDown(key)
    if not InCombatLockdown() then
        self.KeyListener:SetPropagateKeyboardInput(true)
    end
    if ns.keytest then ns.Print("key token: " .. key) end
    if MODIFIER_TOKENS[key] then return end
    self:SetTokenPressed(key, true)
    C_Timer.After(PRESS_FLASH_SECONDS, function() self:SetTokenPressed(key, false) end)
end

function Keyboard:OnMouseButton(button, pressed)
    local token = MOUSE_TOKENS[button]
    if token then self:SetTokenPressed(token, pressed) end
end

function Keyboard:SetTokenPressed(token, pressed)
    local caps = self.capsByToken[token]
    if not caps then return end
    for _, cap in ipairs(caps) do
        cap:SetPressed(pressed)
    end
end

local function RowOffsets(defs)
    local present = {}
    for _, def in ipairs(defs) do
        present[def.row] = true
    end

    local rowY, y = {}, 0
    for _, row in ipairs(ns.ROWS) do
        if present[row] and ns.db.rows[row] then
            if y > 0 then y = y + (ROW_GAP_BEFORE[row] or 0) end
            rowY[row] = y
            y = y + 1
        end
    end
    return rowY, y
end

local function KeyHeight(def, rowY)
    local below = rowY[NEXT_ROW[def.row]]
    if def.h == 2 and below then
        return below + 1 - rowY[def.row]
    end
    return 1
end

local function CreateCornerButton(parent, texture, tooltip)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(CORNER_BUTTON_SIZE, CORNER_BUTTON_SIZE)
    button:SetNormalTexture(texture)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(tooltip())
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

local function LockedTooltip(action)
    return function()
        return ns.db.locked and ("Locked: unlock to " .. action) or action:gsub("^%l", string.upper)
    end
end

-- Move, scale, lock and settings icons that fade in while the mouse is over the keyboard, like Details! does.
function Keyboard:CreateCornerControls()
    local corner = CreateFrame("Frame", nil, self)
    corner:SetSize(4 * CORNER_BUTTON_SIZE + 3 * CORNER_BUTTON_GAP, CORNER_BUTTON_SIZE)
    corner:SetFrameLevel(self:GetFrameLevel() + 20)
    corner:SetAlpha(0)

    corner.Settings = CreateCornerButton(corner, "Interface\\Buttons\\UI-OptionsButton", function() return "Settings" end)
    corner.Settings:SetScript("OnClick", function(button) ns.OpenMenu(button) end)
    corner.Settings:SetPoint("RIGHT")

    corner.Lock = CreateCornerButton(corner, "Interface\\Buttons\\LockButton-Unlocked-Up",
        function() return ns.db.locked and "Unlock position and scale" or "Lock position and scale" end)
    corner.Lock:SetScript("OnClick", function() self:SetLocked(not ns.db.locked) end)
    corner.Lock:SetPoint("RIGHT", corner.Settings, "LEFT", -CORNER_BUTTON_GAP, 0)

    corner.Scale = CreateCornerButton(corner, "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up", LockedTooltip("drag left or right to scale"))
    corner.Scale:SetScript("OnMouseDown", function() self:BeginScaling() end)
    corner.Scale:SetScript("OnMouseUp", function() self:EndScaling() end)
    corner.Scale:SetPoint("RIGHT", corner.Lock, "LEFT", -CORNER_BUTTON_GAP, 0)

    corner.Move = CreateCornerButton(corner, "Interface\\Cursor\\UI-Cursor-Move", LockedTooltip("drag to move"))
    corner.Move:SetScript("OnMouseDown", function() self:BeginMoving() end)
    corner.Move:SetScript("OnMouseUp", function() self:EndMoving() end)
    corner.Move:SetPoint("RIGHT", corner.Scale, "LEFT", -CORNER_BUTTON_GAP, 0)

    corner:SetScript("OnUpdate", function(frame, elapsed)
        local target = self:IsMouseOver(CORNER_BUTTON_SIZE + 4, 0, 0, 0) and 1 or 0
        local alpha = frame:GetAlpha()
        if alpha == target then return end
        local step = elapsed * CORNER_FADE_PER_SECOND
        frame:SetAlpha(target > alpha and math.min(target, alpha + step) or math.max(target, alpha - step))
    end)

    self.Corner = corner
    self:UpdateLockButton()
end

function Keyboard:SetLocked(locked)
    ns.db.locked = locked
    self:UpdateLockButton()
end

-- Move and scale dim while locked so it's clear they're inactive.
function Keyboard:UpdateLockButton()
    local state = ns.db.locked and "Locked" or "Unlocked"
    self.Corner.Lock:SetNormalTexture("Interface\\Buttons\\LockButton-" .. state .. "-Up")
    local alpha = ns.db.locked and LOCKED_BUTTON_ALPHA or 1
    self.Corner.Move:SetAlpha(alpha)
    self.Corner.Scale:SetAlpha(alpha)
end

-- The move icon can sit outside the frame (title bar hidden), where StartMoving snaps the frame to the
-- cursor, so the frame follows the cursor's travel since the press instead.
function Keyboard:BeginMoving()
    if ns.db.locked or ns.BlockedInCombat() then return end
    local cursorX, cursorY = GetCursorPosition()
    self.moveStart = {
        cursorX = cursorX,
        cursorY = cursorY,
        left = self:GetLeft(),
        top = self:GetTop(),
        scale = self:GetEffectiveScale(),
    }
    self.Corner.Move:SetScript("OnUpdate", function() self:UpdateMoving() end)
end

function Keyboard:UpdateMoving()
    if InCombatLockdown() then return self:EndMoving() end
    local start = self.moveStart
    local cursorX, cursorY = GetCursorPosition()
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
        start.left + (cursorX - start.cursorX) / start.scale,
        start.top + (cursorY - start.cursorY) / start.scale)
end

function Keyboard:EndMoving()
    self.Corner.Move:SetScript("OnUpdate", nil)
    self.moveStart = nil
    self:SavePosition()
end

-- Scale follows the cursor's horizontal travel relative to the frame's on-screen width.
function Keyboard:BeginScaling()
    if ns.db.locked or ns.BlockedInCombat() then return end
    self.scaleStart = {
        cursorX = GetCursorPosition(),
        scale = self:GetScale(),
        width = self:GetWidth() * self:GetEffectiveScale(),
    }
    self.Corner.Scale:SetScript("OnUpdate", function() self:UpdateScaling() end)
end

function Keyboard:UpdateScaling()
    if InCombatLockdown() then return self:EndScaling() end
    local start = self.scaleStart
    local travel = GetCursorPosition() - start.cursorX
    self:SetClampedScale(start.scale * (start.width + travel) / start.width)
end

function Keyboard:EndScaling()
    self.Corner.Scale:SetScript("OnUpdate", nil)
    self.scaleStart = nil
end

-- Rescales within the safe range while keeping the top-left corner where it is on screen.
function Keyboard:SetClampedScale(scale)
    local left, top = self:GetLeft(), self:GetTop()
    ns.db.scale = Clamp(scale, ns.MIN_SCALE, ns.MAX_SCALE)
    if not left then return self:SetScale(ns.db.scale) end

    local oldEffective = self:GetEffectiveScale()
    self:SetScale(ns.db.scale)
    local ratio = oldEffective / self:GetEffectiveScale()
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * ratio, top * ratio)
    self:SavePosition()
end

-- The shared padding and the optional title row decide where the board sits inside the frame.
function Keyboard:ApplySkin()
    local skin = ns.CurrentSkin()
    local padding = ns.FRAME_PADDING
    self.boardTop = padding + (ns.db.showTitle and TITLE_HEIGHT or 0)

    ns.ApplyFrameSkin(self, skin)
    self.Title:SetShown(ns.db.showTitle)
    self.Title:ClearAllPoints()
    self.Title:SetPoint("TOPLEFT", padding, -(padding - 2))
    self.Board:ClearAllPoints()
    self.Board:SetPoint("TOPLEFT", padding, -self.boardTop)
    -- In the title row when there is one; otherwise just above the frame so no key is covered.
    self.Corner:ClearAllPoints()
    if ns.db.showTitle then
        self.Corner:SetPoint("TOPRIGHT", -padding, -(padding - 2))
    else
        self.Corner:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -padding, 2)
    end
    for _, cap in ipairs(self.caps) do
        cap:ApplySkin(skin)
    end
    ns.ControlsList:ApplySkin(skin)
end

function Keyboard:Layout()
    self:ApplySkin()
    local padding = ns.FRAME_PADDING
    local defs = ns.BuildKeyboard(ns.db.locale, ns.db.form)
    local rowY, height = RowOffsets(defs)
    local count, width = 0, 0
    wipe(self.capsByToken)

    for _, def in ipairs(defs) do
        local y = rowY[def.row]
        if y and (def.group ~= "numpad" or ns.db.rows.numpad) then
            count = count + 1
            self.caps[count] = self.caps[count] or ns.CreateKeycap(self.Board, count)
            local cap = self.caps[count]
            cap:ClearAllPoints()
            cap:SetPoint("TOPLEFT", def.x * UNIT, -y * UNIT)
            cap:SetKeyDef(def, def.w * UNIT - KEY_GAP, KeyHeight(def, rowY) * UNIT - KEY_GAP)
            cap:Show()
            if def.token then
                self.capsByToken[def.token] = self.capsByToken[def.token] or {}
                table.insert(self.capsByToken[def.token], cap)
            end
            width = math.max(width, def.x + def.w)
        end
    end

    for i = count + 1, #self.caps do
        self.caps[i]:Hide()
    end
    self.visibleCount = count
    self.Board:SetSize(width * UNIT, height * UNIT)
    self:SetSize(width * UNIT - KEY_GAP + 2 * padding, height * UNIT - KEY_GAP + self.boardTop + padding)
    self:Refresh()
    self:UpdateClickActions()
end

-- Click actions are disabled in setup mode so clicks edit binds instead of casting.
-- Bind changes during combat are applied once combat ends.
function Keyboard:UpdateClickActions()
    if InCombatLockdown() then
        self.clickActionsPending = true
        return
    end
    self.clickActionsPending = false
    local enabled = not ns.Setup.active
    for i = 1, self.visibleCount do
        local cap = self.caps[i]
        cap:UpdateClickActions(enabled and cap.def.token ~= nil and not cap.def.modifier)
    end
end

function Keyboard:ActiveModifiers()
    return ns.Setup.active and ns.Setup.mods or ns.CurrentModifiers()
end

function Keyboard:UpdateTitle(mods)
    local layer = ns.LayerName(mods)
    if not ns.Setup.active then
        return self.Title:SetText(("%s  |cffffffff%s|r"):format(addonName, layer))
    end
    local lock = InCombatLockdown() and "  |cffff4040(locked in combat)|r" or ""
    self.Title:SetText(("%s  |cff40c0ffSetup: %s|r%s"):format(addonName, layer, lock))
end

function Keyboard:Refresh()
    if not self:IsShown() then return end
    local mods = self:ActiveModifiers()
    local prefix = ns.ModifierPrefix(mods)
    self:UpdateTitle(mods)

    for i = 1, self.visibleCount do
        local cap = self.caps[i]
        local def = cap.def
        if def.modifier then
            cap:ShowModifier(mods[def.modifier])
        elseif not def.token then
            cap:ShowBinding(nil, nil, false)
        else
            local bindKey = prefix .. def.token
            local effectiveKey, isFallback = ns.EffectiveKey(bindKey, def.token)
            cap:ShowBinding(bindKey, ns.ResolveBinding(effectiveKey), isFallback)
        end
    end
end

-- Range has no event that's safe to share with Blizzard's bars, so it's polled while the keyboard is visible.
function Keyboard:OnShow()
    self:Refresh()
    self.usabilityTicker = C_Timer.NewTicker(USABILITY_POLL_SECONDS, function() self:RefreshUsability() end)
end

function Keyboard:OnHide()
    self.usabilityTicker:Cancel()
end

function Keyboard:RefreshUsability()
    for i = 1, self.visibleCount do
        self.caps[i]:UpdateUsability()
    end
end

function Keyboard:RefreshCooldowns()
    if not self:IsShown() then return end
    for i = 1, self.visibleCount do
        self.caps[i]:UpdateCooldown()
    end
end

function Keyboard:StartDragging()
    if ns.db.locked or ns.BlockedInCombat() then return end
    self:StartMoving()
end

function Keyboard:StopDragging()
    self:StopMovingOrSizing()
    self:SavePosition()
end

function Keyboard:SavePosition()
    local point, _, relativePoint, x, y = self:GetPoint()
    ns.db.position = { point, relativePoint, x, y }
end

function Keyboard:RestorePosition()
    local position = ns.db.position
    self:ClearAllPoints()
    if not position then
        return self:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 180)
    end
    local point, relativePoint, x, y = unpack(position)
    self:SetPoint(point, UIParent, relativePoint, x, y)
end

function Keyboard:SetVisible(shown)
    if ns.BlockedInCombat() then return end
    ns.db.shown = shown
    self:SetShown(shown)
end
