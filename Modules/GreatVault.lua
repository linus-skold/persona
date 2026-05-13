-- Persona: Modules/GreatVault.lua  (v2)
-- Vault progress now lives inside Stats' scroll pane as a category.
-- This module's job: own the vault settings visibility and fire Stats:Update()
-- whenever weekly reward data changes.
local addonName, Persona = ...
local L = Persona.L

local GreatVault = {}
Persona.GreatVault = GreatVault

-- ── Event handler: refresh vault rows in Stats on data change ─
local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
evtFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
evtFrame:SetScript("OnEvent", function(_, event)
    if Persona.Stats then
        Persona.Stats:Update()
    end
end)

-- ── Public API ────────────────────────────────────────────────

--- Show or hide the vault category in the stats pane.
function GreatVault:SetShown(shown)
    Persona.db.vault.enabled = shown
    if Persona.Stats then Persona.Stats:Update() end
end

--- Called when display mode or row toggles change.
function GreatVault:Update()
    if Persona.Stats then Persona.Stats:Update() end
end

-- ── Module Setup ─────────────────────────────────────────────
function GreatVault:Setup()
    -- Nothing to build here — vault rows live inside Stats' scroll child.
    -- Just hook CharacterFrame show so we refresh when the panel opens.
    CharacterFrame:HookScript("OnShow", function()
        if Persona.Stats then Persona.Stats:Update() end
    end)
end

-- Self-register
Persona:RegisterModule(GreatVault)
