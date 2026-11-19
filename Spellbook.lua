local _, ns = ...

local ActionStatus = ActionButtonUtil.ActionBarActionStatus

-- Binds made by name ("SPELL Frostbolt") cast the highest known rank, so any rank of the spell counts as bound.
local function IsSpellKeyBound(spellID)
    local name = C_Spell.GetSpellName(spellID)
    return name ~= nil and GetBindingKey("SPELL " .. name) ~= nil
end

-- The spellbook flags spells missing from every action bar with a pulsing highlight and a tooltip line.
-- A spell bound straight to a key isn't missing, so it's marked as placed after Blizzard computes the status.
-- Only that highlight and the tooltip read actionBarStatus; casting from the spellbook never does.
local function MarkKeyBoundSpell(item)
    if item.actionBarStatus ~= ActionStatus.MissingFromAllBars then return end
    if not IsSpellKeyBound(item.spellBookItemInfo.spellID) then return end
    item.actionBarStatus = ActionStatus.NotMissing
    item:UpdateActionBarAnim()
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", function()
    hooksecurefunc(SpellBookItemMixin, "UpdateActionBarStatus", MarkKeyBoundSpell)
end)

-- Blizzard only recomputes the status for action bar changes, so key bind changes trigger it here.
function ns.RefreshSpellbook()
    if not (PlayerSpellsFrame and PlayerSpellsFrame:IsShown()) then return end
    PlayerSpellsFrame.SpellBookFrame:ForEachDisplayedSpell(function(item)
        item:UpdateActionBarStatus()
    end)
end
