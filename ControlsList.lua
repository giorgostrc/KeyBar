local _, ns = ...

local PANEL_WIDTH = 280
local ROW_HEIGHT = 20
local ICON_SIZE = 16
-- Opaque enough to read text on, whatever the skin's own background.
local LIST_BACKGROUND_ALPHA = 0.85
local TITLE = "Game Controls"

local ControlsList = { expanded = {} }
ns.ControlsList = ControlsList

-- Every game control the client knows about, grouped under its Key Bindings menu header.
-- GetBinding(i) returns (command, category, key1, key2); category is a global string name like BINDING_HEADER_MOVEMENT.
local function CollectGroups()
    local groups, byHeader = {}, {}
    for index = 1, GetNumBindings() do
        local command, category = GetBinding(index)
        local name = command and _G["BINDING_NAME_" .. command]
        if name and category then
            local header = _G[category] or category
            if not byHeader[header] then
                byHeader[header] = { header = header, entries = {} }
                groups[#groups + 1] = byHeader[header]
            end
            table.insert(byHeader[header].entries, { command = command, name = name, searchName = name:lower() })
        end
    end
    return groups
end

local function ShowRowTooltip(row)
    local element = row.element
    if element.header then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(element.name)
    local key1, key2 = GetBindingKey(element.command)
    GameTooltip:AddLine(key1 and table.concat({ key1, key2 }, ", ") or "Unbound", 0.6, 0.6, 0.6)
    local targetKey = ControlsList.targetKey
    local hint = targetKey and ("Click to bind to %s."):format(GetBindingText(targetKey))
        or "Drag onto a key, or click to pick up."
    GameTooltip:AddLine(hint, 1, 0.82, 0, true)
    GameTooltip:Show()
end

local function CreateRowRegions(row)
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.Icon:SetPoint("LEFT", 4, 0)

    row.Key = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.Key:SetPoint("RIGHT", -4, 0)

    row.Label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Label:SetPoint("LEFT", row.Icon, "RIGHT", 4, 0)
    row.Label:SetPoint("RIGHT", row.Key, "LEFT", -4, 0)
    row.Label:SetJustifyH("LEFT")
    row.Label:SetWordWrap(false)

    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnClick", function(self) ControlsList:OnRowClick(self.element) end)
    row:SetScript("OnDragStart", function(self)
        if not self.element.header then ns.Editing:PickUpControl(self.element.command) end
    end)
    row:SetScript("OnDragStop", function() ns.Editing:FinishDrag() end)
    row:SetScript("OnEnter", ShowRowTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)
end

local function InitRow(row, element)
    if not row.Label then CreateRowRegions(row) end
    row.element = element

    if element.header then
        row.Icon:Hide()
        row.Label:SetFontObject("GameFontNormal")
        row.Label:SetText(("%s %s (%d)"):format(element.expanded and "-" or "+", element.header, element.count))
        row.Key:SetText("")
        return
    end

    local art = ns.CommandArt(element.command, element.name)
    row.Icon:SetShown(art ~= nil)
    if art then ns.SetIconArt(row.Icon, art) end
    row.Label:SetFontObject("GameFontHighlightSmall")
    row.Label:SetText(element.name)
    row.Key:SetText(GetBindingKey(element.command) or "")
end

function ControlsList:Panel()
    if self.panel then return self.panel end

    local panel = CreateFrame("Frame", "KeyBarControls", ns.Keyboard, "BackdropTemplate")
    ns.ApplyFrameSkin(panel, ns.CurrentSkin(), LIST_BACKGROUND_ALPHA)
    panel:SetPoint("TOPLEFT", ns.Keyboard, "TOPRIGHT", 4, 0)
    panel:SetPoint("BOTTOMLEFT", ns.Keyboard, "BOTTOMRIGHT", 4, 0)
    panel:SetWidth(PANEL_WIDTH)
    panel:EnableMouse(true)
    panel:SetScript("OnShow", function()
        self.groups = CollectGroups()
        self:Refresh()
    end)
    panel:SetScript("OnHide", function() self:SetTargetKey(nil) end)

    panel.Title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.Title:SetPoint("TOPLEFT", 10, -6)
    panel.Title:SetPoint("RIGHT", -10, 0)
    panel.Title:SetJustifyH("LEFT")
    panel.Title:SetText(TITLE)

    panel.Search = CreateFrame("EditBox", nil, panel, "SearchBoxTemplate")
    panel.Search:SetPoint("TOPLEFT", 14, -24)
    panel.Search:SetPoint("RIGHT", -10, 0)
    panel.Search:SetHeight(20)
    panel.Search:HookScript("OnTextChanged", function() self:Refresh() end)

    panel.ScrollBox = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
    panel.ScrollBox:SetPoint("TOPLEFT", 8, -50)
    panel.ScrollBox:SetPoint("BOTTOMRIGHT", -22, 8)

    panel.ScrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    panel.ScrollBar:SetPoint("TOPLEFT", panel.ScrollBox, "TOPRIGHT", 6, 0)
    panel.ScrollBar:SetPoint("BOTTOMLEFT", panel.ScrollBox, "BOTTOMRIGHT", 6, 0)

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Button", InitRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(panel.ScrollBox, panel.ScrollBar, view)

    panel:Hide()
    self.panel = panel
    return panel
end

-- Groups start collapsed; a search shows every match regardless.
function ControlsList:BuildElements()
    local query = self.panel.Search:GetText():lower()
    local elements = {}
    for _, group in ipairs(self.groups) do
        local matches = {}
        for _, entry in ipairs(group.entries) do
            if query == "" or entry.searchName:find(query, 1, true) then
                matches[#matches + 1] = entry
            end
        end
        if #matches > 0 then
            local expanded = query ~= "" or self.expanded[group.header]
            elements[#elements + 1] = { header = group.header, expanded = expanded, count = #matches }
            if expanded then
                for _, entry in ipairs(matches) do
                    elements[#elements + 1] = entry
                end
            end
        end
    end
    return elements
end

function ControlsList:Refresh()
    if not self:IsShown() then return end
    local provider = CreateDataProvider(self:BuildElements())
    self.panel.ScrollBox:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
end

-- Opened from a key's menu, the list binds the clicked control straight to that key.
function ControlsList:OpenForKey(key)
    self:SetShown(true)
    self:SetTargetKey(key)
    self.panel.Search:SetFocus()
end

function ControlsList:SetTargetKey(key)
    self.targetKey = key
    self.panel.Title:SetText(key and ("Binding |cffffffff%s|r"):format(GetBindingText(key)) or TITLE)
end

function ControlsList:OnRowClick(element)
    if element.header then return self:ToggleGroup(element.header) end
    if not self.targetKey then return ns.Editing:PickUpControl(element.command) end
    ns.Editing:BindControl(self.targetKey, element.command)
    self:SetTargetKey(nil)
end

function ControlsList:ToggleGroup(header)
    self.expanded[header] = not self.expanded[header] or nil
    self:Refresh()
end

function ControlsList:ApplySkin(skin)
    if not self.panel then return end
    ns.ApplyFrameSkin(self.panel, skin, LIST_BACKGROUND_ALPHA)
end

function ControlsList:IsShown()
    return self.panel ~= nil and self.panel:IsShown()
end

function ControlsList:SetShown(shown)
    self:Panel():SetShown(shown)
end
