local _, ns = ...

local ICON_INSET = 6
-- Keys at least this much wider than tall (Tab, Shift, Space, ...) put the icon on the left with its name beside it.
local WIDE_KEY_RATIO = 1.75
local ARROW_TEXTURE = "Interface\\Minimap\\MinimapArrow"
local ARROW_SIZE = 18
local LABEL_FONT_SIZES = { 10, 9, 8 }
local CORNER_FONT_SIZE = 9
local FALLBACK_ALPHA = 0.35
local FALLBACK_TEXT_ALPHA = 0.45
local COUNT_COLOR = { 1, 1, 1 }
-- Muted so a lower rank reads as information, not a warning.
local RANK_COLOR = { 0.75, 0.75, 0.75 }
-- Like Blizzard's buttons, macros carry their name under the icon; game controls do too, as their art alone is ambiguous.
local NAMED_KINDS = { macro = "name", command = "label" }

-- Blizzard's action button tints.
local ICON_TINTS = {
    usable = { 1, 1, 1 },
    outOfRange = { 0.8, 0.1, 0.1 },
    notEnoughPower = { 0.5, 0.5, 1 },
    unusable = { 0.4, 0.4, 0.4 },
}
local KEY_LABEL_OUT_OF_RANGE = { 1, 0.1, 0.1 }

local KeycapMixin = {}
ns.keycaps = {}

function ns.CreateKeycap(parent, index)
    local name = "KeyBarKey" .. index
    -- A secure action button so a click can cast; its attributes can only change outside combat.
    local cap = Mixin(CreateFrame("Button", name, parent, "SecureActionButtonTemplate, BackdropTemplate"), KeycapMixin)
    -- Both edges, so the secure handler can honour the "cast on key down" setting.
    -- Right-click is left out: it opens the key's menu from OnMouseUp instead of casting.
    cap:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
    cap:RegisterForDrag("LeftButton")

    -- Blizzard's action button template supplies the icon, empty slot and border art, pushed state and cooldown swipe.
    cap.Art = CreateFrame("CheckButton", name .. "Art", cap, "ActionButtonTemplate")
    cap.Art:EnableMouse(false)
    cap.Art.HotKey:Hide()
    cap.Art.Name:Hide()
    cap.Art.Count:Hide()
    cap.Art:Hide()
    cap.artSize = cap.Art:GetWidth()

    local overlay = CreateFrame("Frame", nil, cap)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(cap.Art:GetFrameLevel() + 5)

    -- Where Blizzard's buttons show their hotkey.
    cap.KeyLabel = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
    cap.KeyLabel:SetPoint("TOPRIGHT", -3, -3)
    cap.KeyLabel:SetJustifyH("RIGHT")

    -- A game control with no art, written across the key.
    cap.CommandLabel = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cap.CommandLabel:SetPoint("TOPLEFT", 2, -13)
    cap.CommandLabel:SetPoint("BOTTOMRIGHT", -2, 2)
    cap.CommandLabel:SetWordWrap(true)
    cap.CommandLabel:SetMaxLines(3)

    -- A consumable's bag count, or a lower spell rank, in the icon's corner like Blizzard's stack count.
    cap.CornerLabel = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    local font, _, flags = cap.CornerLabel:GetFont()
    cap.CornerLabel:SetFont(font, CORNER_FONT_SIZE, flags)
    cap.CornerLabel:SetPoint("BOTTOMRIGHT", cap.Art, "BOTTOMRIGHT", -2, 2)

    -- A macro or game control's name: under the icon like Blizzard's macro names, or beside it on wide keys.
    cap.NameLabel = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")

    cap.Arrow = overlay:CreateTexture(nil, "ARTWORK")
    cap.Arrow:SetTexture(ARROW_TEXTURE)
    cap.Arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
    cap.Arrow:SetPoint("CENTER", 0, 1)

    cap:SetScript("OnEnter", cap.OnEnter)
    cap:SetScript("OnLeave", GameTooltip_Hide)
    cap:SetScript("PreClick", cap.OnPreClick)
    -- Hooked, not replaced: the template's own OnClick does the secure casting.
    cap:HookScript("OnClick", cap.OnClickFinished)
    cap:SetScript("PostClick", cap.OnPostClick)
    cap:SetScript("OnMouseUp", cap.OnMouseUp)
    cap:SetScript("OnReceiveDrag", cap.OnReceiveDrag)
    cap:SetScript("OnDragStart", cap.OnDragStart)
    cap:SetScript("OnDragStop", function() ns.Editing:FinishDrag() end)

    ns.keycaps[cap] = true
    cap:ApplySkin(ns.CurrentSkin())
    return cap
end

function KeycapMixin:ApplySkin(skin)
    self.skin = skin
    self:SetBackdrop(skin.key.backdrop)
    self:SetBackdropColor(unpack(skin.key.background))
    self.Art:GetNormalTexture():SetAlpha(skin.buttonArt and 1 or 0)
    self:UpdateBorder()
end

function KeycapMixin:SetKeyDef(def, width, height)
    self.def = def
    self:SetSize(width, height)
    self.KeyLabel:SetText(def.label)
    local artScale = (math.min(width, height) - ICON_INSET) / self.artSize
    self.Art:SetScale(artScale)
    self:AnchorIconAndName(width >= WIDE_KEY_RATIO * height, artScale)
    self:SetAlpha(def.token and 1 or 0.45)
    self:SetPressed(false)
end

function KeycapMixin:AnchorIconAndName(wide, artScale)
    local art, name = self.Art, self.NameLabel
    art:ClearAllPoints()
    name:ClearAllPoints()
    name:SetWordWrap(wide)
    name:SetMaxLines(wide and 2 or 1)
    if not wide then
        art:SetPoint("CENTER")
        name:SetPoint("BOTTOMLEFT", 2, 2)
        name:SetPoint("BOTTOMRIGHT", -2, 2)
        return name:SetJustifyH("CENTER")
    end
    -- The art is scaled, so its offset is in its own units; the name sits just below the key label's line.
    art:SetPoint("LEFT", ICON_INSET / 2 / artScale, 0)
    name:SetPoint("LEFT", art, "RIGHT", 4, -4)
    name:SetPoint("RIGHT", -3, -4)
    name:SetJustifyH("LEFT")
end

local function IconName(binding)
    local field = NAMED_KINDS[binding.kind]
    return field and binding[field] or ""
end

function KeycapMixin:ShowBinding(bindKey, binding, isFallback, modifierActive)
    self.bindKey, self.binding, self.isFallback = bindKey, binding, isFallback
    self.modifierActive = modifierActive
    self:UpdateBorder()

    local icon = binding and (binding.icon or binding.atlas)
    local arrow = binding and binding.arrow
    local alpha = isFallback and FALLBACK_ALPHA or 1
    local textAlpha = isFallback and FALLBACK_TEXT_ALPHA or 1
    self.Arrow:SetShown(arrow ~= nil)
    self.Arrow:SetAlpha(alpha)
    if arrow then self.Arrow:SetRotation(arrow.rotation) end

    local text = binding and not icon and (arrow and (arrow.caption or "") or binding.label)
    self:FitCommandLabel(text or "")
    self.CommandLabel:SetJustifyV(arrow and "BOTTOM" or "MIDDLE")
    self.CommandLabel:SetAlpha(textAlpha)

    -- An unbound key shows Blizzard's empty action slot.
    self.Art:SetShown(bindKey ~= nil and (icon ~= nil or binding == nil))
    self.Art:SetAlpha(alpha)
    self.Art.icon:SetShown(icon ~= nil)
    self.NameLabel:SetText(icon and IconName(binding) or "")
    self.NameLabel:SetAlpha(textAlpha)
    self:UpdateCornerLabel(icon and binding)
    if icon then
        ns.SetIconArt(self.Art.icon, binding)
        self.Art.icon:SetDesaturated(isFallback or binding.count == 0)
    end
    self:UpdateCooldown()
    self:UpdateUsability()
end

function KeycapMixin:UpdateCornerLabel(binding)
    local label = self.CornerLabel
    if binding and binding.count then
        label:SetText(binding.count)
        return label:SetTextColor(unpack(COUNT_COLOR))
    end
    label:SetText(binding and binding.rank and ("R" .. binding.rank) or "")
    label:SetTextColor(unpack(RANK_COLOR))
end

function KeycapMixin:UpdateUsability()
    local state = self.Art.icon:IsShown() and ns.UsabilityState(self.binding) or "usable"
    self.Art.icon:SetVertexColor(unpack(ICON_TINTS[state]))
    self.KeyLabel:SetTextColor(unpack(state == "outOfRange" and KEY_LABEL_OUT_OF_RANGE or self.skin.key.label))
end

-- Shrinks the font until the label fits; a single word wider than the key may break mid-word as a last resort.
function KeycapMixin:FitCommandLabel(text)
    local label = self.CommandLabel
    local font, _, flags = GameFontHighlightSmall:GetFont()
    label:SetNonSpaceWrap(false)
    label:SetText(text)
    for _, size in ipairs(LABEL_FONT_SIZES) do
        label:SetFont(font, size, flags)
        if not label:IsTruncated() then return end
    end
    label:SetNonSpaceWrap(true)
end

function KeycapMixin:ShowModifier(active)
    self:ShowBinding(nil, nil, false, active)
end

function KeycapMixin:UpdateCooldown()
    if not self.Art.icon:IsShown() then return self.Art.cooldown:Clear() end
    ns.UpdateCooldown(self.Art.cooldown, self.binding)
end

function KeycapMixin:SetPressed(pressed)
    self.pressed = pressed
    self.Art:SetButtonState(pressed and "PUSHED" or "NORMAL")
    self:UpdateBorder()
end

function KeycapMixin:UpdateBorder()
    local colors = self.skin.key
    local color = (self.pressed and colors.pressed)
        or (self.modifierActive and colors.modifierActive)
        or colors.border
    self:SetBackdropBorderColor(unpack(color))
end

local function ShowModifierTooltip(cap)
    local latched = ns.Keyboard.latched[cap.def.modifier]
    GameTooltip:SetOwner(cap, "ANCHOR_RIGHT")
    GameTooltip:SetText(cap.def.label)
    GameTooltip:AddLine(latched and "Click to release this layer." or "Click to keep this layer shown.", 1, 1, 1)
    GameTooltip:Show()
end

function KeycapMixin:OnEnter()
    if self.def.modifier then return ShowModifierTooltip(self) end
    if not self.bindKey then return end
    ns.ShowBindingTooltip(self, self.bindKey, self.binding, self.isFallback)
end

-- While something is held, a click places it instead of casting, so the key's actions pause for that click.
function KeycapMixin:OnPreClick()
    self.placingHeld = ns.Editing:IsHolding() and not InCombatLockdown()
    if self.placingHeld then self:ClearClickActions() end
end

function KeycapMixin:OnClickFinished(_, down)
    if down then return end
    if self.def.modifier then return ns.Keyboard:ToggleLatch(self.def.modifier) end
    if self.placingHeld and self.bindKey then ns.Editing:PlaceOnKey(self.bindKey) end
end

function KeycapMixin:OnPostClick()
    if self.placingHeld then self:UpdateClickActions(ns.Keyboard.latched) end
end

function KeycapMixin:OnMouseUp(button)
    if button ~= "RightButton" then return end
    if ns.Editing:IsHolding() then return ns.Editing:Discard() end
    ns.Editing:OpenKeyMenu(self)
end

function KeycapMixin:OnReceiveDrag()
    if self.bindKey then ns.Editing:PlaceOnKey(self.bindKey) end
end

function KeycapMixin:OnDragStart()
    if self.bindKey then ns.Editing:PickUpKey(self.bindKey) end
end

local CLICK_FIELDS = { "spell", "item", "macro", "macrotext", "action", "clickbutton" }

local function SetLayerClickAction(cap, layer, actionType, field, value)
    local attributePrefix = ns.ModifierPrefix(layer):lower()
    cap:SetAttribute(attributePrefix .. "type", actionType)
    for _, name in ipairs(CLICK_FIELDS) do
        cap:SetAttribute(attributePrefix .. name, name == field and value or nil)
    end
end

-- Secure buttons pick attributes by the modifiers held at click time ("shift-type", "alt-ctrl-spell", ...),
-- so every layer is configured up front and clicking keeps working in combat. Latched modifiers join the
-- held ones, so a click casts what the key shows.
-- While unlocked, mouse clicks cast on release: a press that turns into a drag picks the bind up without casting it.
function KeycapMixin:UpdateClickActions(latched)
    if ns.db.locked then
        self:SetAttribute("useOnKeyDown", nil)
    else
        self:SetAttribute("useOnKeyDown", false)
    end
    local token = self.def.token
    if not token or self.def.modifier then return self:ClearClickActions() end
    for _, layer in ipairs(ns.LAYERS) do
        local bindPrefix = ns.ModifierPrefix(ns.CombineModifiers(layer, latched))
        SetLayerClickAction(self, layer, ns.ClickAction(bindPrefix .. token, token))
    end
end

function KeycapMixin:ClearClickActions()
    for _, layer in ipairs(ns.LAYERS) do
        SetLayerClickAction(self, layer)
    end
end
