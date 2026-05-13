-- Persona: Modules/PanelCustomizer.lua
-- Adjusts the background alpha of the character frame.
local addonName, Persona = ...

local PanelCustomizer = {}
Persona.PanelCustomizer = PanelCustomizer

function PanelCustomizer:ApplyAlpha()
    local alpha = Persona.db.panel.backgroundAlpha or 1.0
    if CharacterFrameInset then
        CharacterFrameInset:SetAlpha(alpha)
    end
end

function PanelCustomizer:Setup()
    CharacterFrame:HookScript("OnShow", function()
        PanelCustomizer:ApplyAlpha()
    end)
    if CharacterFrame:IsShown() then
        self:ApplyAlpha()
    end
end

function PanelCustomizer:Update()
    self:ApplyAlpha()
end

Persona:RegisterModule(PanelCustomizer)
