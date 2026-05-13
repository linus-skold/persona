-- Persona: Settings/Settings.lua
-- Thin wrapper: registers Persona in Blizzard's Settings pane.
-- All real configuration is in FloatingSettings.lua (the free-floating window).
local addonName, Persona = ...

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, arg1)
    if arg1 ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")

    -- Create a minimal Blizzard settings category that opens our floating window.
    local ok = pcall(function()
        local category = Settings.RegisterVerticalLayoutCategory("Persona")
        Persona.settingsCategoryID = category:GetID()

        -- Single button/note in the Blizzard pane pointing to /persona
        local initializer = CreateSettingsListSectionHeaderInitializer(
            "Use  |cffcc99ff/persona|r  to open the full Persona settings window.")
        Settings.RegisterAddOnCategory(category)
        category:AddInitializer(initializer)
    end)

    if not ok then
        -- Fallback for versions that lack the new Settings API
        local panel = CreateFrame("Frame", "PersonaBlizzardPanel", UIParent)
        panel.name = "Persona"
        local note = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        note:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
        note:SetText("Use  /persona  to open the Persona settings window.")
        if InterfaceOptions_AddCategory then
            InterfaceOptions_AddCategory(panel)
        end
    end
end)
