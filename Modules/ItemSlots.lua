-- Persona: Modules/ItemSlots.lua
-- Per-slot ilvl, gems, enchant, durability display (BetterCharacterPanel-style).
-- Supports ilvl inside the slot icon OR outside next to it, controlled by settings.
local addonName, Persona = ...
local L = Persona.L

local ItemSlots = {}
Persona.ItemSlots = ItemSlots

-- ── Compat shims ──────────────────────────────────────────────
local GetDetailedItemLevelInfo = (C_Item and C_Item.GetDetailedItemLevelInfo)
    or GetDetailedItemLevelInfo
local GetItemQualityColor = (C_Item and C_Item.GetItemQualityColor)
    or GetItemQualityColor
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant)
    or GetItemInfoInstant
local GetInventoryItemDurability = (C_Item and C_Item.GetInventoryItemDurability)
    or GetInventoryItemDurability
local GetInventoryItemQuality = (C_Item and C_Item.GetInventoryItemQuality)
    or GetInventoryItemQuality

-- ── Constants ─────────────────────────────────────────────────
local NUM_SOCKET_TEXTURES = 4

-- Which side of the character panel each slot is on
local BUTTON_SIDE = {
    [INVSLOT_HEAD]      = "left",
    [INVSLOT_NECK]      = "left",
    [INVSLOT_SHOULDER]  = "left",
    [INVSLOT_BACK]      = "left",
    [INVSLOT_CHEST]     = "left",
    [INVSLOT_WRIST]     = "left",
    [INVSLOT_HAND]      = "right",
    [INVSLOT_WAIST]     = "right",
    [INVSLOT_LEGS]      = "right",
    [INVSLOT_FEET]      = "right",
    [INVSLOT_FINGER1]   = "right",
    [INVSLOT_FINGER2]   = "right",
    [INVSLOT_TRINKET1]  = "right",
    [INVSLOT_TRINKET2]  = "right",
    [INVSLOT_MAINHAND]  = "center",
    [INVSLOT_OFFHAND]   = "center",
}

-- Slots enchantable in each expansion (expansion index → set of slot IDs)
local ENCHANTABLE = {
    [12] = { -- Midnight
        [INVSLOT_MAINHAND] = true, [INVSLOT_HEAD]     = true,
        [INVSLOT_SHOULDER] = true, [INVSLOT_CHEST]    = true,
        [INVSLOT_LEGS]     = true, [INVSLOT_FEET]     = true,
        [INVSLOT_FINGER1]  = true, [INVSLOT_FINGER2]  = true,
        [INVSLOT_BACK]     = true, [INVSLOT_WRIST]    = true,
    },
    [11] = {
        [INVSLOT_MAINHAND] = true, [INVSLOT_HEAD]     = true,
        [INVSLOT_SHOULDER] = true, [INVSLOT_CHEST]    = true,
        [INVSLOT_LEGS]     = true, [INVSLOT_FEET]     = true,
        [INVSLOT_FINGER1]  = true, [INVSLOT_FINGER2]  = true,
    },
    [10] = {
        [INVSLOT_BACK]     = true, [INVSLOT_CHEST]    = true,
        [INVSLOT_WRIST]    = true, [INVSLOT_LEGS]     = true,
        [INVSLOT_FEET]     = true, [INVSLOT_MAINHAND] = true,
        [INVSLOT_FINGER1]  = true, [INVSLOT_FINGER2]  = true,
    },
}

-- Required sockets per expansion
local REQUIRED_SOCKETS = {
    [12] = { [INVSLOT_NECK] = 1, [INVSLOT_FINGER1] = 1, [INVSLOT_FINGER2] = 1 },
    [11] = { [INVSLOT_NECK] = 1, [INVSLOT_FINGER1] = 1, [INVSLOT_FINGER2] = 1 },
    [10] = { [INVSLOT_NECK] = 2, [INVSLOT_FINGER1] = 2, [INVSLOT_FINGER2] = 2 },
}

-- Stat IDs for primary-stat mismatch detection
local PRIMARY_STATS = {
    [ITEM_MOD_STRENGTH_SHORT]     = 1,
    [ITEM_MOD_AGILITY_SHORT]      = 2,
    [ITEM_MOD_INTELLECT_SHORT]    = 4,
}
local SPEC_PRIMARY = {
    -- (same map as BetterCharacterPanel)
    [250]=1,[251]=1,[252]=1, [577]=2,[581]=2,[1480]=4,
    [102]=4,[103]=2,[104]=2,[105]=4, [1467]=4,[1468]=4,[1473]=4,
    [253]=2,[254]=2,[255]=2, [62]=4,[63]=4,[64]=4,
    [268]=2,[270]=4,[269]=2, [65]=4,[66]=1,[70]=1,
    [256]=4,[257]=4,[258]=4, [259]=2,[260]=2,[261]=2,
    [262]=4,[263]=2,[264]=4, [265]=4,[266]=4,[267]=4,
    [71]=1,[72]=1,[73]=1,
}
local ARMOR_CLASS = {
    WARRIOR="Plate",PALADIN="Plate",DEATHKNIGHT="Plate",
    HUNTER="Mail",SHAMAN="Mail",EVOKER="Mail",
    ROGUE="Leather",DRUID="Leather",MONK="Leather",DEMONHUNTER="Leather",
    MAGE="Cloth",PRIEST="Cloth",WARLOCK="Cloth",TINKER="Mail",
}
local SLOTS_CHECK_PRIMARY = {
    [INVSLOT_HEAD]=true,[INVSLOT_SHOULDER]=true,[INVSLOT_CHEST]=true,
    [INVSLOT_BACK]=true,[INVSLOT_WRIST]=true,[INVSLOT_HAND]=true,
    [INVSLOT_WAIST]=true,[INVSLOT_LEGS]=true,[INVSLOT_FEET]=true,
    [INVSLOT_MAINHAND]=true,[INVSLOT_OFFHAND]=true,
}

-- ── Enchant string tables (full name → effect shorthand) ──────
local ENCHANT_EFFECTS = {
    -- Generic prefixes to strip
    ["^Enchant "]            = "",
    ["^Weapon %- "]          = "",
    ["^Shoulders %- "]       = "",
    ["^Chest %- "]           = "",
    ["^Ring %- "]            = "",
    ["^Boots %- "]           = "",
    ["^Helm %- "]            = "",
}
-- Explicit replacement map for known enchants
local ENCHANT_SHORT = {
    -- Universal stat names
    ["Stamina"]              = "Stam",
    ["Intellect"]            = "Int",
    ["Agility"]              = "Agi",
    ["Strength"]             = "Str",
    ["Mastery"]              = "Mast",
    ["Versatility"]          = "Vers",
    ["Critical Strike"]      = "Crit",
    ["Avoidance"]            = "Avoid",
    ["Haste"]                = "Haste",
    -- TWW / Midnight enchants
    ["Acuity of the Ren'dorei"] = "Proc PrimStat",
    ["Arcane Mastery"]          = "Proc Mast",
    ["Berserker's Rage"]        = "Proc Haste",
    ["Flames of the Sin'dorei"] = "Dot→AoE",
    ["Jan'alai's Precision"]    = "Proc Crit",
    ["Strength of Halazzi"]     = "Bleed",
    ["Worldsoul Aegis"]         = "Shield→AoE",
    ["Worldsoul Tenacity"]      = "Proc Vers",
    ["Empowered Blessing of Speed"] = "Speed+Vigor",
    ["Blessing of Speed"]       = "Speed",
    ["Empowered Rune of Avoidance"] = "Avoid+MS",
    ["Rune of Avoidance"]       = "Avoid",
    ["Empowered Hex of Leeching"] = "Leech",
    ["Hex of Leeching"]         = "Leech",
    ["Akil'zon's Swiftness"]    = "Speed",
    ["Flight of the Eagle"]     = "Speed",
    ["Amirdrassil's Grace"]     = "Avoid",
    ["Thalassian Recovery"]     = "Leech",
    ["Mark of Nalorakk"]        = "Str+Stam",
    ["Mark of the Magister"]    = "Int+Mana",
    ["Mark of the Rootwarden"]  = "Agi+Speed",
    ["Mark of the Worldsoul"]   = "PrimStat",
    ["Arcanoweave Spellthread"] = "Int+Mana",
    ["Shadowed Belt Clasp"]     = "Stam",
    ["Watcher's Loam"]          = "Stam",
    ["Plainsrunner's Breeze"]   = "Speed",
    ["Graceful Avoidance"]      = "Avoid",
    ["Regenerative Leech"]      = "Leech",
    ["Cavalry's March"]         = "MntSpeed",
    ["Scout's March"]           = "Speed",
    ["Defender's March"]        = "Stam",
    ["Stormrider's Agi"]        = "Agi+Speed",
    ["Council's Intellect"]     = "Int+Mana",
    ["Oathsworn's Strength"]    = "Str+Stam",
    ["Crystalline Radiance"]    = "PrimStat",
    ["Chant of Armored Avoidance"] = "Avoid",
    ["Chant of Armored Leech"]  = "Leech",
    ["Chant of Armored Speed"]  = "Speed",
    ["Chant of Winged Grace"]   = "Avoid+Fall",
    ["Chant of Leeching Fangs"] = "Leech+Recup",
    ["Chant of Burrowing Rapidity"] = "Speed+HScd",
    ["Cursed Haste"]            = "Haste+\124cffcc0000-Vers\124r",
    ["Cursed Crit"]             = "Crit+\124cffcc0000-Haste\124r",
    ["Cursed Mastery"]          = "Mast+\124cffcc0000-Crit\124r",
    ["Cursed Versatility"]      = "Vers+\124cffcc0000-Mast\124r",
    ["Incandescent Essence"]    = "Essence",
    ["Shaladrassil's Roots"]    = "Leech+Stam",
    ["Silvermoon's Mending"]    = "Leech",
    ["Farstrider's Hunt"]       = "Speed+Stam",
    ["Lynx's Dexterity"]        = "Avoid+Stam",
    ["Eyes of the Eagle"]       = "Crit%+",
    ["Silvermoon's Alacrity"]   = "Haste%",
    ["Zul'jin's Mastery"]       = "Mast",
    ["Silvermoon's Tenacity"]   = "Vers",
}

local enchantPattern   = ENCHANTED_TOOLTIP_LINE:gsub("%%s", "(.*)")

-- ── Upgrade track colours ────────────────────────────────────
-- Maps upgrade track name → WoW item quality colour (hex string).
-- Myth uses Artifact gold; each lower track steps down one quality tier.
local UPGRADE_TRACKS = {
    { name = "Myth",       hex = "e6cc80" },  -- Artifact / Heirloom gold
    { name = "Hero",       hex = "ff8000" },  -- Legendary orange
    { name = "Champion",   hex = "a335ee" },  -- Epic purple
    { name = "Veteran",    hex = "0070dd" },  -- Rare blue
    { name = "Adventurer", hex = "1eff00" },  -- Uncommon green
    { name = "Explorer",   hex = "9d9d9d" },  -- Common grey
}

--- Returns a coloured "X/Y" upgrade level string, or nil if not found.
local function GetUpgradeText(unit, slot)
    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, unit, slot)
    if not ok or not data then return nil end

    for _, line in ipairs(data.lines) do
        -- Strip colour escape codes so we match plain text
        local text = (line.leftText or ""):gsub("|c%x%x%x%x%x%x%x%x(.-)%|r", "%1"):gsub("|[cCrR].-|", "")
        for _, track in ipairs(UPGRADE_TRACKS) do
            local cur, max = text:match(track.name .. "%s+(%d+)/(%d+)")
            if cur then
                return string.format("|cff%s%s/%s|r", track.hex, cur, max)
            end
        end
    end
    return nil
end
local atlasPattern     = "(.*)%s*|A:(.*):20:20|a"
local coloredPattern   = "|cn(.*):(.*)|r"

local function ProcessEnchantEffect(text)
    -- strip generic prefixes
    for pat, rep in pairs(ENCHANT_EFFECTS) do
        text = text:gsub(pat, rep)
    end
    -- apply shorthand replacements (longest first to avoid partial matches)
    for name, short in pairs(ENCHANT_SHORT) do
        text = text:gsub(name, short)
    end
    return text
end

local function GetEnchantInfo(unit, slot)
    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, unit, slot)
    if not ok or not data then return nil, nil end

    for _, line in ipairs(data.lines) do
        local raw = line.leftText
        if raw then
            local enchantText = raw:match(enchantPattern)
            if enchantText then
                -- strip colour codes wrapper
                local _, plain = enchantText:match(coloredPattern)
                if plain then enchantText = plain end
                -- extract atlas icon if present
                local maybeText, atlas = enchantText:match(atlasPattern)
                if maybeText then enchantText = maybeText end
                return atlas, enchantText   -- full name always returned here
            end
        end
    end
    return nil, nil
end

local function GetEnchantDisplay(unit, slot)
    local atlas, fullName = GetEnchantInfo(unit, slot)
    if not fullName then return nil, nil end
    local cfg = Persona.db.itemSlots.enchantDisplay
    if cfg == "effect" then
        return atlas, ProcessEnchantEffect(fullName)
    else
        return atlas, fullName
    end
end

-- ── Socket / stat extraction ──────────────────────────────────
local function ExtractItemData(unit, slot)
    local result = { sockets = {}, stats = {}, invalidStats = false }
    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, unit, slot)
    if not ok or not data then return result end

    for _, line in ipairs(data.lines) do
        if line.type == 3 then          -- socket line
            if line.gemIcon then
                table.insert(result.sockets, line.gemIcon)
            else
                local socketTypeName = line.socketType or "Meta"
                table.insert(result.sockets,
                    "Interface\\ItemSocketingFrame\\UI-EmptySocket-" .. socketTypeName)
            end
        elseif line.type == 0 then      -- stat line
            local val, stat = (line.leftText or ""):match("%+(%d+) (.*)")
            if stat then
                local id = PRIMARY_STATS[stat]
                if id then result.stats[id] = tonumber(val) end
            end
        end
    end

    local itemLink = GetInventoryItemLink(unit, slot)
    if itemLink then
        local itemType, itemSubType = select(6, GetItemInfoInstant(itemLink))
        local unitClass = UnitClassBase(unit)
        if itemType == Enum.ItemClass.Armor and
           itemSubType ~= Enum.ItemArmorSubclass.Shield and
           itemSubType ~= Enum.ItemArmorSubclass.Relic and
           itemSubType ~= Enum.ItemArmorSubclass.Cosmetic and
           itemSubType ~= Enum.ItemArmorSubclass.Generic then
            local expected = ARMOR_CLASS[unitClass]
            if expected and itemSubType ~= Enum.ItemArmorSubclass[expected] then
                result.invalidStats = true
            end
        end
    end
    return result
end

local function CanEnchantSlot(unit, slot)
    local expansion = GetExpansionForLevel(UnitLevel(unit))
    local slots = ENCHANTABLE[expansion] or ENCHANTABLE[11] or {}
    if slots[slot] then return true end
    if slot == INVSLOT_OFFHAND then
        local link = GetInventoryItemLink(unit, slot)
        if link then
            local equip = select(4, GetItemInfoInstant(link))
            return equip ~= "INVTYPE_HOLDABLE" and equip ~= "INVTYPE_SHIELD"
        end
        return false
    end
    return false
end

-- ── Per-button display frame ──────────────────────────────────
local function CreateButtonDisplay(button)
    local parent = button:GetParent()
    local f = CreateFrame("Frame", nil, parent)
    f:SetWidth(110)

    -- ilvl text (used when ilvlPosition == "outside")
    f.ilvlOutside = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")

    -- ilvl text overlay (used when ilvlPosition == "inside")
    f.ilvlInside = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
    f.ilvlInside:SetPoint("BOTTOM", button, "BOTTOM", 0, 3)
    f.ilvlInside:SetTextColor(1, 1, 1)

    -- Upgrade level badge: "3/8" coloured by track, top-right corner of icon
    f.upgradeFS = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
    f.upgradeFS:SetFont(f.upgradeFS:GetFont(), 9, "OUTLINE")
    f.upgradeFS:SetPoint("TOPRIGHT", button, "TOPRIGHT", 1, -1)
    f.upgradeFS:SetJustifyH("RIGHT")
    f.upgradeFS:Hide()

    -- enchant text
    f.enchant = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
    f.enchant:SetTextColor(0.2, 1, 0.4, 1)

    -- red X for wrong primary stat
    f.wrongStat = button:CreateTexture(nil, "OVERLAY")
    f.wrongStat:SetPoint("CENTER", button, "CENTER")
    f.wrongStat:SetAtlas("common-icon-redx")
    local sc = 0.8
    f.wrongStat:SetSize(button:GetWidth() * sc, button:GetHeight() * sc)
    f.wrongStat:Hide()

    -- durability bar
    f.durability = CreateFrame("StatusBar", nil, f)
    f.durability:SetMinMaxValues(0, 1)
    f.durability:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    f.durability:GetStatusBarTexture():SetHorizTile(false)
    f.durability:GetStatusBarTexture():SetVertTile(false)
    f.durability:SetHeight(40)
    f.durability:SetWidth(2)
    f.durability:SetOrientation("VERTICAL")
    f.durability:Hide()

    -- socket icons
    f.sockets = {}
    for i = 1, NUM_SOCKET_TEXTURES do
        local t = f:CreateTexture(nil, "OVERLAY")
        t:SetSize(14, 14)
        t:Hide()
        f.sockets[i] = t
    end

    return f
end

local function AnchorDisplay(button, side)
    local f = button.PersonaDisplay
    if not f then return end

    f:ClearAllPoints()
    f.ilvlOutside:ClearAllPoints()
    f.enchant:ClearAllPoints()
    f.durability:ClearAllPoints()

    if side == "left" then
        -- slot is on left panel → extras go to the right of the button
        f:SetPoint("TOPLEFT",    button, "TOPRIGHT")
        f:SetPoint("BOTTOMLEFT", button, "BOTTOMRIGHT")
        f.ilvlOutside:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 2)
        f.enchant:SetPoint("TOPLEFT",        f, "TOPLEFT",    8, -6)
        f.durability:SetPoint("TOPRIGHT",    button, "TOPLEFT",   2, 0)
        f.durability:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT", 2, 0)
        -- sockets right of ilvl
        if f.sockets[1] then
            f.sockets[1]:SetPoint("LEFT", f.ilvlOutside, "RIGHT", 4, 0)
            for i = 2, NUM_SOCKET_TEXTURES do
                f.sockets[i]:SetPoint("LEFT", f.sockets[i-1], "RIGHT", 2, 0)
            end
        end
    elseif side == "right" then
        -- slot is on right panel → extras go to the left of the button
        f:SetPoint("TOPRIGHT",    button, "TOPLEFT")
        f:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT")
        f.ilvlOutside:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 2)
        f.enchant:SetPoint("TOPRIGHT",        f, "TOPRIGHT",   -8, -6)
        f.durability:SetPoint("TOPLEFT",     button, "TOPRIGHT",   -2, 0)
        f.durability:SetPoint("BOTTOMLEFT",  button, "BOTTOMRIGHT", -2, 0)
        if f.sockets[1] then
            f.sockets[1]:SetPoint("RIGHT", f.ilvlOutside, "LEFT", -4, 0)
            for i = 2, NUM_SOCKET_TEXTURES do
                f.sockets[i]:SetPoint("RIGHT", f.sockets[i-1], "LEFT", -2, 0)
            end
        end
    else  -- center (weapons)
        f:SetPoint("BOTTOMLEFT",  button, "BOTTOMLEFT",  -110, 0)
        f:SetPoint("TOPRIGHT",    button, "TOPRIGHT",       0, -110)
        f.ilvlOutside:SetPoint("BOTTOM", button, "TOP", 0, 6)
        f.durability:SetHeight(2)
        f.durability:SetWidth(button:GetWidth())
        f.durability:SetOrientation("HORIZONTAL")
        f.durability:SetPoint("BOTTOMLEFT",  button, "BOTTOMLEFT",  0, -3)
        f.durability:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, -3)
        if button:GetID() == INVSLOT_MAINHAND then
            f.enchant:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT", -4, 0)
            if f.sockets[1] then
                f.sockets[1]:SetPoint("RIGHT", f.ilvlOutside, "LEFT", -4, 0)
                for i = 2, NUM_SOCKET_TEXTURES do
                    f.sockets[i]:SetPoint("RIGHT", f.sockets[i-1], "LEFT", -2, 0)
                end
            end
        else
            f.enchant:SetPoint("BOTTOMLEFT", button, "BOTTOMRIGHT", 4, 0)
            if f.sockets[1] then
                f.sockets[1]:SetPoint("LEFT", f.ilvlOutside, "RIGHT", 4, 0)
                for i = 2, NUM_SOCKET_TEXTURES do
                    f.sockets[i]:SetPoint("LEFT", f.sockets[i-1], "RIGHT", 2, 0)
                end
            end
        end
    end
end

-- ── Item-load queue (deferred data) ──────────────────────────
local itemLoadQueue = {}

local function UpdateButtonFull(button, unit)
    if not button:IsShown() then return end
    local f = button.PersonaDisplay
    if not f then return end

    local cfg    = Persona.db.itemSlots
    local slot   = button:GetID()
    local link   = GetInventoryItemLink(unit, slot)
    local inside = cfg.ilvlPosition == "inside"

    -- ── iLvl ────────────────────────────────────────────────
    local ilvlText = ""
    if cfg.showIlvl and link then
        local ilvl    = GetDetailedItemLevelInfo(link)
        local quality = GetInventoryItemQuality(unit, slot)
        local hex     = quality and select(4, GetItemQualityColor(quality)) or "ffffff"
        ilvlText = ilvl and ("|c" .. hex .. ilvl .. "|r") or ""
    end

    if inside then
        f.ilvlInside:SetText(ilvlText)
        f.ilvlOutside:SetText("")
    else
        f.ilvlOutside:SetText(ilvlText)
        f.ilvlInside:SetText("")
    end

    -- ── Upgrade level badge ──────────────────────────────────
    if link then
        local upgradeText = GetUpgradeText(unit, slot)
        if upgradeText then
            f.upgradeFS:SetText(upgradeText)
            f.upgradeFS:Show()
        else
            f.upgradeFS:Hide()
        end
    else
        f.upgradeFS:Hide()
    end

    -- ── Enchant ──────────────────────────────────────────────
    if cfg.showEnchants then
        local atlas, enchantText = GetEnchantDisplay(unit, slot)
        local canEnchant = CanEnchantSlot(unit, slot)

        if enchantText then
            local maxLen = 18
            if enchantText:find("|c") then maxLen = maxLen + #"|cffffffff|r" end
            enchantText = enchantText:sub(1, maxLen)
            local qualStr = atlas and ("|A:" .. atlas .. ":12:12|a") or ""
            if slot == INVSLOT_OFFHAND then
                f.enchant:SetText(qualStr .. enchantText)
            else
                f.enchant:SetText(enchantText .. qualStr)
            end
        elseif cfg.showMissingEnchant and canEnchant and link
            and IsLevelAtEffectiveMaxLevel(UnitLevel(unit)) then
            f.enchant:SetText("|cffff4444" .. L["No Enchant"] .. "|r")
        else
            f.enchant:SetText("")
        end
    else
        f.enchant:SetText("")
    end

    -- ── Gems / sockets ───────────────────────────────────────
    local itemData = (cfg.showGems or SLOTS_CHECK_PRIMARY[slot]) and ExtractItemData(unit, slot)
                     or { sockets = {}, stats = {}, invalidStats = false }

    if cfg.showGems then
        local expansion = GetExpansionForLevel(UnitLevel(unit))
        local reqSockets = REQUIRED_SOCKETS[expansion] or REQUIRED_SOCKETS[11] or {}
        for i = 1, NUM_SOCKET_TEXTURES do
            local st = f.sockets[i]
            if itemData.sockets[i] then
                st:SetTexture(itemData.sockets[i])
                st:SetVertexColor(1, 1, 1)
                st:Show()
            elseif reqSockets[slot] and i <= reqSockets[slot] then
                st:SetTexture("Interface\\ItemSocketingFrame\\UI-EmptySocket-Red")
                st:SetVertexColor(1, 0, 0)
                st:Show()
            else
                st:Hide()
            end
        end
    else
        for i = 1, NUM_SOCKET_TEXTURES do f.sockets[i]:Hide() end
    end

    -- ── Wrong-primary-stat indicator ──────────────────────────
    if SLOTS_CHECK_PRIMARY[slot] and link then
        local isInspect = not UnitIsUnit("player", unit)
        local primaryStat
        if isInspect then
            local specId = GetInspectSpecialization(unit)
            primaryStat = specId and SPEC_PRIMARY[specId]
        else
            local specInfo = GetSpecialization and GetSpecialization()
            if specInfo then
                local specId = select(1, GetSpecializationInfo(specInfo))
                primaryStat = SPEC_PRIMARY[specId]
            end
        end

        local match = true
        if primaryStat then
            match = false
            for sid in pairs(itemData.stats) do
                if sid == primaryStat then match = true break end
            end
            if itemData.invalidStats and slot ~= INVSLOT_BACK then match = false end
        end

        f.wrongStat:SetShown(not match)
        button.icon:SetDesaturated(not match)
    else
        f.wrongStat:Hide()
        button.icon:SetDesaturated(false)
    end
end

local function UpdateButtonBasic(button, unit)
    local f = button.PersonaDisplay
    if not f then return end

    local slot = button:GetID()
    local link = GetInventoryItemLink(unit, slot)

    if link then
        -- Extract numeric item ID from the hyperlink (|Hitem:12345:...|h)
        local itemId = tonumber(link:match("|Hitem:(%d+)"))
        if itemId then
            itemLoadQueue[itemId] = { button = button, unit = unit }
            C_Item.RequestLoadItemDataByID(itemId)
        else
            -- Fallback: data likely cached, update immediately
            UpdateButtonFull(button, unit)
        end
    else
        -- slot empty: clear everything
        local cfg = Persona.db.itemSlots
        f.ilvlOutside:SetText("")
        f.ilvlInside:SetText("")
        f.enchant:SetText("")
        f.upgradeFS:Hide()
        f.wrongStat:Hide()
        button.icon:SetDesaturated(false)
        for i = 1, NUM_SOCKET_TEXTURES do f.sockets[i]:Hide() end
    end

    -- Durability (always live, no load needed)
    local cur, maxD = GetInventoryItemDurability(slot)
    local perc = cur and maxD and maxD > 0 and (cur / maxD) or nil
    local showDura = Persona.db.itemSlots.showDurability and UnitIsUnit("player", unit)

    if showDura and perc and perc < 1 then
        f.durability:SetValue(perc)
        f.durability:SetStatusBarColor(Persona.HPGradient(perc))
        f.durability:Show()
    else
        f.durability:Hide()
    end
end

-- ── Hook PaperDollItemSlotButton_Update ───────────────────────
local function OnButtonUpdate(button, unit)
    unit = unit or "player"
    if not BUTTON_SIDE[button:GetID()] then return end  -- ignore bag slots etc.

    if not button.PersonaDisplay then
        button.PersonaDisplay = CreateButtonDisplay(button)
        AnchorDisplay(button, BUTTON_SIDE[button:GetID()])
    end

    UpdateButtonBasic(button, unit)
end

-- ── Character slot names for full refresh ────────────────────
local CHAR_SLOTS = {
    "CharacterHeadSlot",    "CharacterNeckSlot",    "CharacterShoulderSlot",
    "CharacterChestSlot",   "CharacterWaistSlot",   "CharacterLegsSlot",
    "CharacterFeetSlot",    "CharacterWristSlot",   "CharacterHandsSlot",
    "CharacterFinger0Slot", "CharacterFinger1Slot",
    "CharacterTrinket0Slot","CharacterTrinket1Slot","CharacterBackSlot",
    "CharacterMainHandSlot","CharacterSecondaryHandSlot",
}

local function RefreshAllSlots(unit)
    unit = unit or "player"
    for _, name in ipairs(CHAR_SLOTS) do
        local btn = _G[name]
        if btn then UpdateButtonBasic(btn, unit) end
    end
end

-- ── Event listener ────────────────────────────────────────────
local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("ADDON_LOADED")
evtFrame:RegisterEvent("SOCKET_INFO_UPDATE")
evtFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
evtFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")

evtFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        -- Hook inspect UI when it loads
        if name == "Blizzard_InspectUI" then
            hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
                OnButtonUpdate(button, InspectFrame and InspectFrame.unit or "target")
            end)
        end

    elseif event == "SOCKET_INFO_UPDATE" or
           (event == "UNIT_INVENTORY_CHANGED" and ... == "player") then
        if CharacterFrame:IsShown() then
            RefreshAllSlots("player")
        end

    elseif event == "ITEM_DATA_LOAD_RESULT" then
        local itemID, success = ...
        local queued = itemLoadQueue[itemID]
        if queued then
            UpdateButtonFull(queued.button, queued.unit)
            itemLoadQueue[itemID] = nil
        end
    end
end)

-- ── Module Setup ─────────────────────────────────────────────
function ItemSlots:Setup()
    hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
        OnButtonUpdate(button, "player")
    end)
end

function ItemSlots:Update()
    RefreshAllSlots("player")
end

-- Self-register
Persona:RegisterModule(ItemSlots)
