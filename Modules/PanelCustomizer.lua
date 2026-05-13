-- Persona: Modules/PanelCustomizer.lua
-- Adjust background alpha and save & restore character pose.
local addonName, Persona = ...
local L = Persona.L

local PanelCustomizer = {}
Persona.PanelCustomizer = PanelCustomizer

local modelFrame
local animApplied = false

-- ── Model frame discovery ─────────────────────────────────────
local MODEL_CANDIDATES = { "CharacterModelFrame", "DressUpFrame" }

local function FindModelFrame()
    for _, name in ipairs(MODEL_CANDIDATES) do
        local f = _G[name]
        if f and f.SetAnimation then return f end
    end
    if PaperDollFrame then
        for _, val in pairs(PaperDollFrame) do
            if type(val) == "table" and type(val.SetAnimation) == "function" then
                return val
            end
        end
    end
    return nil
end

-- ── Animation / pose ──────────────────────────────────────────
function PanelCustomizer:ApplyAnimation()
    if not modelFrame then modelFrame = FindModelFrame() end
    if not modelFrame then return end
    local animId = Persona.db.panel.savedAnimation or 0
    local ok = pcall(modelFrame.SetAnimation, modelFrame, animId)
    if not ok then
        pcall(modelFrame.PlayAnimKit, modelFrame, animId, false)
    end
end

-- ── Background alpha ──────────────────────────────────────────
function PanelCustomizer:ApplyAlpha()
    local alpha = Persona.db.panel.backgroundAlpha or 1.0
    if CharacterFrameInset then
        CharacterFrameInset:SetAlpha(alpha)
    end
end

-- ── OnShow handler ────────────────────────────────────────────
local function OnCharacterFrameShow()
    PanelCustomizer:ApplyAlpha()
    animApplied = false

    local function TryAnim()
        if not animApplied then
            animApplied = true
            PanelCustomizer:ApplyAnimation()
        end
    end
    C_Timer.After(0.4, TryAnim)
end

-- ── UNIT_MODEL_CHANGED: play pose as soon as model is ready ───
local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("UNIT_MODEL_CHANGED")
evtFrame:SetScript("OnEvent", function(_, _, unit)
    if unit == "player" and CharacterFrame:IsShown() and not animApplied then
        animApplied = true
        PanelCustomizer:ApplyAnimation()
    end
end)

-- ── Module Setup ─────────────────────────────────────────────
function PanelCustomizer:Setup()
    modelFrame = FindModelFrame()
    CharacterFrame:HookScript("OnShow", OnCharacterFrameShow)
    if CharacterFrame:IsShown() then
        OnCharacterFrameShow()
    end
end

function PanelCustomizer:Update()
    self:ApplyAlpha()
    self:ApplyAnimation()
end

Persona:RegisterModule(PanelCustomizer)
