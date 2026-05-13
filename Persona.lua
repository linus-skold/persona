-- Persona.lua  ·  Core: namespace, defaults, saved-var init, events, slash commands
local addonName, Persona = ...
local L = Persona.L

-- ============================================================
-- Default configuration
-- ============================================================
Persona.defaults = {
    -- Item Slots
    itemSlots = {
        showIlvl            = true,
        ilvlPosition        = "outside",  -- "inside" | "outside"
        showGems            = true,
        showEnchants        = true,
        enchantDisplay      = "effect",   -- "effect" | "name"
        showMissingEnchant  = true,
        showDurability      = true,
    },
    -- Stats Panel
    stats = {
        enabled             = true,
        scrollbar           = false,
        classBackground     = true,
        layout              = "auto",
        hiddenStats         = {},     -- [rowId] = true to hide that stat row
    },
    -- Great Vault
    vault = {
        enabled             = true,
        displayMode         = "progress", -- "progress" | "slots"
        showDungeons        = true,
        showRaids           = true,
        showPvP             = true,
    },
    -- Panel Customizer
    panel = {
        width               = 0,          -- 0 = use default
        height              = 0,
        backgroundAlpha     = 1.0,
        savedAnimation      = 0,          -- 0 = Stand
        customAnimId        = 0,
    },
}

-- ============================================================
-- Deep-merge helper (fills missing keys from defaults)
-- ============================================================
local function MergeDefaults(db, defaults)
    if type(db) ~= "table" then db = {} end
    if type(defaults) ~= "table" then return db end
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            db[k] = MergeDefaults(db[k], v)
        elseif db[k] == nil then
            db[k] = v
        end
    end
    return db
end

-- ============================================================
-- ADDON_LOADED  – init SavedVars then fire module Setup()
-- ============================================================
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")

initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Merge saved vars with defaults
        PersonaDB = MergeDefaults(PersonaDB, Persona.defaults)
        Persona.db = PersonaDB

        -- Expose per-section shortcuts for modules
        Persona.db.itemSlots    = Persona.db.itemSlots
        Persona.db.stats        = Persona.db.stats
        Persona.db.vault        = Persona.db.vault
        Persona.db.panel        = Persona.db.panel

        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        -- Modules register themselves via Persona.modules table.
        -- Fire Setup on each after vars are ready.
        for _, mod in ipairs(Persona.modules or {}) do
            if mod.Setup then mod:Setup() end
        end
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-- ============================================================
-- Module registration
-- ============================================================
Persona.modules = {}

function Persona:RegisterModule(mod)
    table.insert(self.modules, mod)
end

-- ============================================================
-- Utility: refresh all modules that expose an Update()
-- ============================================================
function Persona:RefreshAll()
    for _, mod in ipairs(self.modules or {}) do
        if mod.Update then mod:Update() end
    end
end

-- ============================================================
-- Slash commands   /persona
-- ============================================================
SLASH_PERSONA1 = "/persona"
SlashCmdList["PERSONA"] = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "config" or msg == "settings" or msg == "" then
        Settings.OpenToCategory(Persona.settingsCategoryID)
    elseif msg == "reset" then
        PersonaDB = MergeDefaults({}, Persona.defaults)
        Persona.db = PersonaDB
        ReloadUI()
    else
        print("|cffcc99ffPersona|r commands:")
        print("  /persona          – " .. L["/persona config"])
        print("  /persona reset    – " .. L["/persona reset"])
    end
end

-- ============================================================
-- Public helpers used by multiple modules
-- ============================================================

--- Returns the quality hex colour string for an item quality index.
function Persona.QualityHex(quality)
    if not quality then return "ffffff" end
    local hex = select(4, C_Item and C_Item.GetItemQualityColor and
        C_Item.GetItemQualityColor(quality) or GetItemQualityColor(quality))
    return hex or "ffffff"
end

--- Colour-gradient: perc 0→1, (r1,g1,b1, r2,g2,b2 …) pairs
function Persona.ColorGradient(perc, ...)
    if perc >= 1 then
        local r, g, b = select(select("#", ...) - 2, ...)
        return r, g, b
    elseif perc <= 0 then
        return ...
    end
    local num = select("#", ...) / 3
    local seg, rel = math.modf(perc * (num - 1))
    local r1, g1, b1, r2, g2, b2 = select(seg * 3 + 1, ...)
    return r1 + (r2 - r1) * rel, g1 + (g2 - g1) * rel, b1 + (b2 - b1) * rel
end

function Persona.HPGradient(perc)
    return Persona.ColorGradient(perc, 1, 0, 0, 1, 1, 0, 0, 1, 0)
end

-- Class colour table (fallback white if class unknown)
Persona.classColors = {}
do
    local classes = {
        "WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST",
        "DEATHKNIGHT","SHAMAN","MAGE","WARLOCK","MONK",
        "DRUID","DEMONHUNTER","EVOKER","TINKER",
    }
    for _, cls in ipairs(classes) do
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
        Persona.classColors[cls] = c and { c.r, c.g, c.b } or { 1, 1, 1 }
    end
end
