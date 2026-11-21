local _, ns = ...

local ICON_INSET = 6
local ARROW_TEXTURE = "Interface\\Minimap\\MinimapArrow"
local ARROW_SIZE = 18
local LABEL_FONT_SIZES = { 10, 9, 8 }
local CORNER_FONT_SIZE = 9
local COUNT_COLOR = { 1, 1, 1 }
-- Muted so a lower rank reads as information, not a warning.
local RANK_COLOR = { 0.75, 0.75, 0.75 }

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
    cap:RegisterForClicks("AnyUp", "AnyDown")
    cap:RegisterForDrag("LeftButton")

    -- Blizzard's action button template supplies the icon, border art, pushed state and cooldown swipe.
    cap.Art = CreateFrame("CheckButton", name .. "Art", cap, "ActionButtonTemplate")
    cap.Art:EnableMouse(false)
    cap.Art:SetPoint("CENTER")
    cap.Art.HotKey:Hide()
    cap.Art.Name:Hide()
    cap.Art.Count:Hide()
    cap.Art:Hide()
    cap.artSize = cap.Art:GetWidth()

    local overlay = CreateFrame("Frame", nil, cap)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(cap.Art:GetFrameLevel() + 5)

    cap.KeyLabel = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    cap.KeyLabel:SetPoint("TOPLEFT", 3, -2)

    cap.CommandLabel = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cap.CommandLabel:SetPoint("TOPLEFT", 2, -13)
    cap.CommandLabel:SetPoint("BOTTOMRIGHT", -2, 2)
    cap.CommandLabel:SetWordWrap(true)
    cap.CommandLabel:SetMaxLines(3)

    cap.Arrow = overlay:CreateTexture(nil, "ARTWORK")
    cap.Arrow:SetTexture(ARROW_TEXTURE)
    cap.Arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
    cap.Arrow:SetPoint("CENTER", 0, 1)

    -- A consumable's bag count, or a lower spell rank.
    cap.CornerLabel = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    local font, _, flags = cap.CornerLabel:GetFont()
    cap.CornerLabel:SetFont(font, CORNER_FONT_SIZE, flags)
    cap.CornerLabel:SetPoint("BOTTOMRIGHT", -3, 3)

    cap:SetScript("OnEnter", cap.OnEnter)
    cap:SetScript("OnLeave", GameTooltip_Hide)
    -- Hooked, not replaced: the template's own OnClick does the secure casting.
    cap:HookScript("OnClick", function(self, button, down)
        if not down then ns.Setup:OnKeycapClick(self, button) end
    end)
    cap:SetScript("OnReceiveDrag", function(self) ns.Setup:OnKeycapReceiveDrag(self) end)
    cap:SetScript("OnDragStart", function(self) ns.Setup:BeginSwap(self) end)
    cap:SetScript("OnDragStop", function() ns.Setup:FinishSwap(GetMouseFoci()[1]) end)

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
    self.Art:SetScale((math.min(width, height) - ICON_INSET) / self.artSize)
    self:SetAlpha(def.token and 1 or 0.45)
    self:SetPressed(false)
end

function KeycapMixin:ShowBinding(bindKey, binding, isFallback, modifierActive)
    self.bindKey, self.binding, self.isFallback = bindKey, binding, isFallback
    self.modifierActive = modifierActive
    self:UpdateBorder()

    local icon = binding and (binding.icon or binding.atlas)
    local arrow = binding and binding.arrow
    self.Arrow:SetShown(arrow ~= nil)
    self.Arrow:SetAlpha(isFallback and 0.35 or 1)
    if arrow then self.Arrow:SetRotation(arrow.rotation) end

    local text = binding and not icon and (arrow and (arrow.caption or "") or binding.label)
    self:FitCommandLabel(text or "")
    self.CommandLabel:SetJustifyV(arrow and "BOTTOM" or "MIDDLE")
    self.CommandLabel:SetAlpha(isFallback and 0.45 or 1)
    self.Art:SetShown(icon ~= nil)
    self:UpdateCornerLabel(icon and binding)
    if icon then
        ns.SetIconArt(self.Art.icon, binding)
        self.Art.icon:SetDesaturated(isFallback or binding.count == 0)
        self.Art:SetAlpha(isFallback and 0.35 or 1)
        self:UpdateCooldown()
    end
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
    local state = self.Art:IsShown() and ns.UsabilityState(self.binding) or "usable"
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
    if not self.Art:IsShown() then return end
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

function KeycapMixin:OnEnter()
    if not self.bindKey then return end
    ns.ShowBindingTooltip(self, self.bindKey, self.binding, self.isFallback)
end

local CLICK_FIELDS = { "spell", "item", "macro", "macrotext", "action", "clickbutton" }

-- Secure buttons pick attributes by the modifiers held at click time ("shift-type", "alt-ctrl-spell", ...),
-- so every layer is configured up front and clicking keeps working in combat.
function KeycapMixin:UpdateClickActions(enabled)
    local token = self.def.token
    for _, layer in ipairs(ns.LAYERS) do
        local bindPrefix = ns.ModifierPrefix(layer)
        local actionType, field, value
        if enabled then
            actionType, field, value = ns.ClickAction(bindPrefix .. token, token)
        end
        local attributePrefix = bindPrefix:lower()
        self:SetAttribute(attributePrefix .. "type", actionType)
        for _, name in ipairs(CLICK_FIELDS) do
            self:SetAttribute(attributePrefix .. name, name == field and value or nil)
        end
    end
end
