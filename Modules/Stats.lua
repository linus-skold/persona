-- Persona: Modules/Stats.lua  (v3)
-- Scroll frame + collapsible categories: Defense / Offense / Misc / Great Vault.
-- Category headers use class colour.  Each row has an id that can be hidden via settings.
local addonName, Persona = ...
local L = Persona.L

local Stats = {}
Persona.Stats = Stats

-- ── Spec → role ───────────────────────────────────────────────
local ROLE_SPEC = {
    [250]="tank",  [251]="physical",[252]="physical",
    [577]="physical",[581]="tank",  [1480]="caster",
    [102]="caster",[103]="physical",[104]="tank",   [105]="healer",
    [1467]="caster",[1468]="healer",[1473]="caster",
    [253]="physical",[254]="physical",[255]="physical",
    [62]="caster", [63]="caster",  [64]="caster",
    [268]="tank",  [270]="healer", [269]="physical",
    [65]="healer", [66]="tank",    [70]="physical",
    [256]="healer",[257]="healer", [258]="caster",
    [259]="physical",[260]="physical",[261]="physical",
    [262]="caster",[263]="physical",[264]="healer",
    [265]="caster",[266]="caster", [267]="caster",
    [71]="physical",[72]="physical",[73]="tank",
    [1000]="physical",
}

-- Spec → primary stat  (1=STR  2=AGI  4=INT)
-- Every spec has exactly one primary stat in WoW.
local SPEC_PRIMARY = {
    -- Death Knight
    [250]=1,[251]=1,[252]=1,
    -- Demon Hunter
    [577]=2,[581]=2,[1480]=4,
    -- Druid  (Guardian/Feral = AGI; Balance/Resto = INT)
    [102]=4,[103]=2,[104]=2,[105]=4,
    -- Evoker
    [1467]=4,[1468]=4,[1473]=4,
    -- Hunter
    [253]=2,[254]=2,[255]=2,
    -- Mage
    [62]=4,[63]=4,[64]=4,
    -- Monk  (Brew/WW = AGI; MW = INT)
    [268]=2,[269]=2,[270]=4,
    -- Paladin  (Holy = INT; Prot/Ret = STR)
    [65]=4,[66]=1,[70]=1,
    -- Priest
    [256]=4,[257]=4,[258]=4,
    -- Rogue
    [259]=2,[260]=2,[261]=2,
    -- Shaman  (Ele/Resto = INT; Enh = AGI)
    [262]=4,[263]=2,[264]=4,
    -- Warlock
    [265]=4,[266]=4,[267]=4,
    -- Warrior
    [71]=1,[72]=1,[73]=1,
    -- Tinker placeholder
    [1000]=2,
}

--- Returns the primary stat ID (1/2/4) for the current spec.
local function GetSpecPrimary()
    local spec = GetSpecialization and GetSpecialization()
    if not spec then return 1 end
    local ok, specId = pcall(GetSpecializationInfo, spec)
    return (ok and SPEC_PRIMARY[specId]) or 1
end

--- Returns a filter function that passes only when the current spec's
--- primary stat matches statId.  Passed as `roles` on primary stat rows.
local function PrimaryFilter(statId)
    return function() return GetSpecPrimary() == statId end
end

local function GetRole()
    local cfg = Persona.db.stats.layout
    if cfg ~= "auto" then return cfg end
    local spec = GetSpecialization and GetSpecialization()
    if not spec then return "physical" end
    local ok, specId = pcall(GetSpecializationInfo, spec)
    return (ok and ROLE_SPEC[specId]) or "physical"
end

-- ── Safe vault enum access ────────────────────────────────────
-- Enum may differ between expansion patches; fall back to known numeric values.
local VAULT_TYPE_DUNGEON = (Enum.WeeklyRewardChestThresholdType
    and Enum.WeeklyRewardChestThresholdType.Dungeon)    or 1
local VAULT_TYPE_RAID    = (Enum.WeeklyRewardChestThresholdType
    and Enum.WeeklyRewardChestThresholdType.Raid)       or 2
local VAULT_TYPE_WORLD   = 4   -- TWW / Midnight: World / Delves row

-- ── Layout constants ──────────────────────────────────────────
local CAT_H  = 22
local ROW_H  = 18
local SEP_H  = 2

-- ── Module state ──────────────────────────────────────────────
local scrollFrame, scrollChild, classGrad
local headerBar  -- fixed top bar: ilvl / durability / repair cost
local container  -- single frame wrapping all Persona content; hide this to hide everything
local categories = {}   -- array of category objects

local HEADER_H = 30   -- height of the fixed header bar

-- ── Row visibility ────────────────────────────────────────────
local function RowVisible(row, role)
    if row.id and Persona.db.stats.hiddenStats and
       Persona.db.stats.hiddenStats[row.id] then
        return false
    end
    if not row.roles then return true end
    -- Function filter: called at check time (used by primary stat filters)
    if type(row.roles) == "function" then return row.roles() end
    if type(row.roles) == "string" then return row.roles == role end
    for _, r in ipairs(row.roles) do if r == role then return true end end
    return false
end

-- ── Category / row factory ────────────────────────────────────
local function NewCategory(title)
    local cat = { rows = {}, collapsed = false }

    cat.header = CreateFrame("Button", nil, scrollChild)
    cat.header:SetHeight(CAT_H)
    cat.header:RegisterForClicks("LeftButtonUp")

    -- Main background (class-coloured, updated in UpdateBackground)
    cat.bgTex = cat.header:CreateTexture(nil, "BACKGROUND")
    cat.bgTex:SetAllPoints()
    cat.bgTex:SetColorTexture(0.10, 0.08, 0.14, 0.92)

    -- Highlight on mouseover
    local hi = cat.header:CreateTexture(nil, "HIGHLIGHT")
    hi:SetAllPoints()
    hi:SetColorTexture(0.22, 0.18, 0.30, 0.55)

    -- Left accent stripe (class colour, updated in UpdateBackground)
    cat.accentTex = cat.header:CreateTexture(nil, "OVERLAY")
    cat.accentTex:SetSize(3, CAT_H)
    cat.accentTex:SetPoint("LEFT", cat.header, "LEFT", 0, 0)
    cat.accentTex:SetColorTexture(0.55, 0.40, 0.85, 0.90)

    -- Collapse arrow (texture so it renders in any locale)
    -- Use a texture path that ships with every WoW client
    cat.arrow = cat.header:CreateTexture(nil, "OVERLAY")
    cat.arrow:SetSize(8, 8)
    cat.arrow:SetPoint("LEFT", cat.header, "LEFT", 7, 0)
    cat.arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    cat.arrow:SetVertexColor(0.90, 0.82, 1.00)

    -- Title
    cat.titleFS = cat.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cat.titleFS:SetPoint("LEFT", cat.header, "LEFT", 20, 0)
    cat.titleFS:SetText(title)
    cat.titleFS:SetTextColor(0.90, 0.82, 1.00)

    -- Separator line below category
    cat.line = scrollChild:CreateTexture(nil, "ARTWORK")
    cat.line:SetHeight(1)
    cat.line:SetColorTexture(0.35, 0.20, 0.55, 0.70)

    cat.header:SetScript("OnClick", function()
        cat.collapsed = not cat.collapsed
        -- Rotate arrow: down = expanded, right = collapsed
        if cat.collapsed then
            cat.arrow:SetTexture("Interface\\Buttons\\Arrow-Right-Up")  -- collapsed
        else
            cat.arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")   -- expanded
        end
        Stats:Relayout()
    end)

    table.insert(categories, cat)
    return cat
end

-- id: unique string used for hiddenStats toggle
-- roles: nil = always show; string or table of strings = spec-filtered
local function NewRow(cat, id, label, getter, roles)
    local row = { id = id, getter = getter, roles = roles }

    row.frame = CreateFrame("Frame", nil, scrollChild)
    row.frame:SetHeight(ROW_H)

    local stripe = row.frame:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints()
    if #cat.rows % 2 == 0 then
        stripe:SetColorTexture(0.06, 0.05, 0.09, 0.55)
    else
        stripe:SetColorTexture(0.09, 0.07, 0.12, 0.35)
    end

    row.labelFS = row.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.labelFS:SetPoint("LEFT", row.frame, "LEFT", 12, 0)
    row.labelFS:SetText(label)
    row.labelFS:SetTextColor(0.70, 0.70, 0.72)

    row.valueFS = row.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.valueFS:SetPoint("RIGHT", row.frame, "RIGHT", -7, 0)
    row.valueFS:SetJustifyH("RIGHT")
    row.valueFS:SetText("–")

    table.insert(cat.rows, row)
    return row
end

-- ── Relayout ──────────────────────────────────────────────────
function Stats:Relayout()
    if not scrollChild or not CharacterStatsPane then return end

    local nH   = CharacterStatsPane:GetHeight()
    local yOff = -(nH + 4)
    local role = GetRole()

    for _, cat in ipairs(categories) do
        local anyVisible = false
        for _, row in ipairs(cat.rows) do
            if RowVisible(row, role) then anyVisible = true; break end
        end

        if not anyVisible then
            cat.header:Hide()
            cat.line:Hide()
            for _, row in ipairs(cat.rows) do row.frame:Hide() end
        else
            cat.header:Show()
            cat.header:ClearAllPoints()
            cat.header:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",   0, yOff)
            cat.header:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT",  0, yOff)
            yOff = yOff - CAT_H

            for _, row in ipairs(cat.rows) do
                if not cat.collapsed and RowVisible(row, role) then
                    row.frame:Show()
                    row.frame:ClearAllPoints()
                    row.frame:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",   0, yOff)
                    row.frame:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT",  0, yOff)
                    yOff = yOff - ROW_H
                else
                    row.frame:Hide()
                end
            end

            cat.line:Show()
            cat.line:ClearAllPoints()
            cat.line:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",   4, yOff)
            cat.line:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -4, yOff)
            yOff = yOff - SEP_H - 1
        end
    end

    scrollChild:SetHeight(math.abs(yOff) + 8)
end

-- ── Coin formatter ──────────────────────────────────────────────
local function FormatCoin(copper)
    if not copper or copper == 0 then return "|cff888888-|r" end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then
        return string.format("|cffffd700%d|r|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t "
                          .. "|cffc7c7cf%d|r|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t",
                          g, s)
    elseif s > 0 then
        return string.format("|cffc7c7cf%d|r|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t "
                          .. "|cffeda55f%d|r|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t",
                          s, c)
    else
        return string.format("|cffeda55f%d|r|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t", c)
    end
end

local function GetTotalRepairCost()
    -- Read repairCost from tooltip data per slot (works anywhere, no vendor needed).
    -- This is how DejaCharacterStats calculates it via C_TooltipInfo.GetInventoryItem.
    local total = 0
    local SLOTS = {
        INVSLOT_HEAD, INVSLOT_NECK, INVSLOT_SHOULDER, INVSLOT_BACK,
        INVSLOT_CHEST, INVSLOT_WRIST, INVSLOT_HAND, INVSLOT_WAIST,
        INVSLOT_LEGS, INVSLOT_FEET, INVSLOT_FINGER1, INVSLOT_FINGER2,
        INVSLOT_TRINKET1, INVSLOT_TRINKET2, INVSLOT_MAINHAND, INVSLOT_OFFHAND,
    }
    for _, slot in ipairs(SLOTS) do
        local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
        if ok and data and data.repairCost and data.repairCost > 0 then
            total = total + data.repairCost
        end
    end
    return total
end

-- ── Header update ────────────────────────────────────────────
function Stats:UpdateHeader()
    if not headerBar then return end

    -- Average equipped item level
    local ilvlText = "–"
    -- GetAverageItemLevel() → avgAll, avgEquipped  (equipped is what the pane shows)
    local ok, avgAll, avgEq = pcall(GetAverageItemLevel)
    if ok and avgEq and avgEq > 0 then
        ilvlText = string.format("%.1f", avgEq)
    end
    headerBar.ilvlVal:SetText(ilvlText)

    -- Overall durability %
    local tot, mx = 0, 0
    for slot = 0, 19 do
        local cur, maxD = GetInventoryItemDurability(slot)
        if cur and maxD and maxD > 0 then tot = tot + cur; mx = mx + maxD end
    end
    local duraText
    if mx > 0 then
        local pct = tot / mx * 100
        local r, g, b = Persona.HPGradient(tot / mx)
        duraText = string.format("|cff%02x%02x%02x%.0f%%|r", r*255, g*255, b*255, pct)
    else
        duraText = "–"
    end
    headerBar.duraVal:SetText(duraText)

    -- Repair cost (only non-zero when at a repair NPC)
    local cost = GetTotalRepairCost()
    headerBar.costVal:SetText(FormatCoin(cost))
end

-- ── Update stat values ────────────────────────────────────────
function Stats:UpdateValues()
    for _, cat in ipairs(categories) do
        for _, row in ipairs(cat.rows) do
            if row.getter then
                local ok, val = pcall(row.getter)
                row.valueFS:SetText((ok and val) or "–")
            end
        end
    end
end

-- ── Class colour: background gradient + category headers ──────
function Stats:UpdateBackground()
    -- When class colour is enabled use the player's class colour;
    -- when disabled fall back to Persona's own purple/violet.
    local r, g, b
    if Persona.db.stats.classBackground then
        local _, cls = UnitClass("player")
        local c = Persona.classColors[cls] or { 0.6, 0.5, 0.9 }
        r, g, b = c[1], c[2], c[3]
    else
        r, g, b = 0.55, 0.35, 0.85   -- Persona purple
    end

    -- Full-pane gradient (always shown)
    if classGrad then
        classGrad:SetGradient("VERTICAL",
            CreateColor(r * 0.20, g * 0.16, b * 0.26, 0.94),
            CreateColor(r * 0.03, g * 0.02, b * 0.05, 0.94))
        classGrad:Show()
    end

    -- Category header tints
    for _, cat in ipairs(categories) do
        cat.bgTex:SetColorTexture(r*0.14, g*0.10, b*0.18, 0.93)
        cat.accentTex:SetColorTexture(r*0.85, g*0.75, b*1.00, 0.92)
        cat.titleFS:SetTextColor(
            math.min(1, r * 0.9 + 0.25),
            math.min(1, g * 0.8 + 0.20),
            math.min(1, b * 0.9 + 0.15))
    end

    -- Header bar border tint
    if headerBar then
        headerBar:SetBackdropBorderColor(r*0.60, g*0.45, b*0.85, 0.85)
    end
end

-- ── Public API ────────────────────────────────────────────────
function Stats:Update()
    if not scrollChild then return end
    self:UpdateBackground()
    self:UpdateHeader()
    self:UpdateValues()
    self:Relayout()
end

function Stats:SetEnabled(en)
    if container then container:SetShown(en) end
end

function Stats:ApplyLayout()
    self:Update()
end

-- ── Vault text helper ─────────────────────────────────────────
function Stats:GetVaultText(typeId)
    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then return "–" end
    local ok, acts = pcall(C_WeeklyRewards.GetActivities, typeId)
    if not ok or not acts or #acts == 0 then return "–" end

    local progress  = acts[1].progress  or 0
    local maxThresh = acts[#acts].threshold or 1
    local unlocked  = 0
    for _, a in ipairs(acts) do
        if (a.progress or 0) >= (a.threshold or 1) then unlocked = unlocked + 1 end
    end

    if Persona.db.vault.displayMode == "slots" then
        local n   = #acts
        local col = unlocked >= n and "|cff00ff00" or "|cffffcc00"
        return string.format("%s%d|r / %d slots", col, unlocked, n)
    else
        local col = progress >= maxThresh and "|cff00ff00"
                 or progress > 0           and "|cffffcc00"
                 or "|cffaaaaaa"
        return string.format("%s%d|r / %d", col, progress, maxThresh)
    end
end

-- ── Build categories ──────────────────────────────────────────
local function BuildCategories()

    -- Primary Stats
    local prim = NewCategory("Primary Stats")

    -- Each primary stat uses PrimaryFilter(statId) so only the spec's
    -- primary stat shows. Stamina is always shown (universal).
    -- 1=STR  2=AGI  4=INT

    NewRow(prim, "strength", "Strength", function()
        local v = UnitStat("player", 1)
        return v and (BreakUpLargeNumbers and BreakUpLargeNumbers(v) or tostring(v)) or "â"
    end, PrimaryFilter(1))

    NewRow(prim, "agility", "Agility", function()
        local v = UnitStat("player", 2)
        return v and (BreakUpLargeNumbers and BreakUpLargeNumbers(v) or tostring(v)) or "â"
    end, PrimaryFilter(2))

    NewRow(prim, "intellect", "Intellect", function()
        local v = UnitStat("player", 4)
        return v and (BreakUpLargeNumbers and BreakUpLargeNumbers(v) or tostring(v)) or "â"
    end, PrimaryFilter(4))

    NewRow(prim, "stamina", "Stamina", function()
        local v = UnitStat("player", 3)
        return v and (BreakUpLargeNumbers and BreakUpLargeNumbers(v) or tostring(v)) or "â"
    end)   -- always visible

    -- Defense
    local def = NewCategory("Defense")

    NewRow(def, "armor", "Armor", function()
        local _, eff = UnitArmor("player")
        eff = eff or 0
        local lvl = UnitLevel("player") or 70
        local pct = eff / (eff + 2500 + 25 * lvl) * 100
        local fmt = BreakUpLargeNumbers and BreakUpLargeNumbers(eff) or tostring(eff)
        return string.format("%s  (%.1f%%)", fmt, pct)
    end)

    NewRow(def, "dodge", "Dodge", function()
        local ok, v = pcall(GetDodgeChance)
        return ok and v and string.format("%.2f%%", v) or "â"
    end)

    NewRow(def, "parry", "Parry", function()
        local ok, v = pcall(GetParryChance)
        return ok and v and v > 0 and string.format("%.2f%%", v) or "â"
    end, {"tank", "physical"})

    NewRow(def, "block", "Block", function()
        local ok, v = pcall(GetBlockChance)
        return ok and v and v > 0 and string.format("%.2f%%", v) or "â"
    end, "tank")

    NewRow(def, "stagger", "Stagger", function()
        local ok, v = pcall(C_PaperDollInfo.GetStaggerPercentage, "player")
        return ok and v and v > 0 and string.format("%.2f%%", v) or "â"
    end, "tank")

    -- Offense
    local off = NewCategory("Offense")

    NewRow(off, "ap", "Attack Power", function()
        local b, p, n = UnitAttackPower("player")
        local v = (b or 0) + (p or 0) + (n or 0)
        return BreakUpLargeNumbers and BreakUpLargeNumbers(v) or tostring(v)
    end, {"tank", "physical"})

    NewRow(off, "rap", "Ranged AP", function()
        local b, p, n = UnitRangedAttackPower("player")
        local v = (b or 0) + (p or 0) + (n or 0)
        return v > 0 and (BreakUpLargeNumbers and BreakUpLargeNumbers(v) or tostring(v)) or "â"
    end, "physical")

    NewRow(off, "sp", "Spell Power", function()
        local max = 0
        for i = 2, 7 do
            local ok, v = pcall(GetSpellBonusDamage, i)
            if ok and type(v) == "number" and v > max then max = v end
        end
        return BreakUpLargeNumbers and BreakUpLargeNumbers(max) or tostring(max)
    end, {"caster", "healer"})

    NewRow(off, "melee_crit", "Melee Crit", function()
        local ok, v = pcall(GetCritChance)
        return ok and v and string.format("%.2f%%", v) or "â"
    end, {"tank", "physical"})

    NewRow(off, "ranged_crit", "Ranged Crit", function()
        local ok, v = pcall(GetRangedCritChance)
        return ok and v and string.format("%.2f%%", v) or "â"
    end, "physical")

    NewRow(off, "spell_crit", "Spell Crit", function()
        local ok, v = pcall(GetSpellCritChance, 7)
        return ok and v and string.format("%.2f%%", v) or "â"
    end, {"caster", "healer"})

    NewRow(off, "melee_speed", "Melee Speed", function()
        local ok, spd = pcall(UnitAttackSpeed, "player")
        return ok and spd and string.format("%.2fs", spd) or "â"
    end, {"tank", "physical"})

    NewRow(off, "haste", "Haste", function()
        local ok, v = pcall(GetHaste)
        return ok and v and string.format("%.2f%%", v) or "â"
    end)

    NewRow(off, "mastery", "Mastery", function()
        local ok, v = pcall(GetMastery)
        return ok and v and string.format("%.2f", v) or "â"
    end)

    -- Misc
    local misc = NewCategory("Misc")

    NewRow(misc, "speed", "Move Speed", function()
        return string.format("%.0f%%", (GetUnitSpeed("player") or 0) / 7 * 100)
    end)

    NewRow(misc, "gcd", "Global Cooldown", function()
        local ok, h = pcall(GetHaste)
        local haste = (ok and h) or 0
        local gcd = math.max(0.75, 1.5 / (1 + haste / 100))
        return string.format("%.2fs", gcd)
    end)

    NewRow(misc, "leech", "Leech", function()
        local ok, v = pcall(GetLeech)
        return ok and type(v) == "number" and string.format("%.2f%%", v) or "â"
    end)

    NewRow(misc, "avoid", "Avoidance", function()
        local ok, v = pcall(GetAvoidance)
        return ok and type(v) == "number" and string.format("%.2f%%", v) or "â"
    end)

    -- ── Great Vault ───────────────────────────────────────────
    local vault = NewCategory("Great Vault")
    Stats.vaultCategory = vault

    local VAULT_PROBE = {
        { id = VAULT_TYPE_DUNGEON, label = "Dungeons" },
        { id = VAULT_TYPE_RAID,    label = "Raids"    },
        { id = VAULT_TYPE_WORLD,   label = "World"    },
    }

    local addedIds = {}
    for _, vt in ipairs(VAULT_PROBE) do
        if not addedIds[vt.id] then
            addedIds[vt.id] = true
            local capturedId    = vt.id
            local capturedLabel = vt.label
            -- vault rows use nil roles so they always pass RoleMatch
            NewRow(vault, "vault_" .. capturedLabel:lower(), capturedLabel, function()
                if not Persona.db.vault.enabled then return "|cff888888disabled|r" end
                return Stats:GetVaultText(capturedId)
            end)
        end
    end

    -- Expose ordered list for settings window
    Stats.categoryList = categories
end

-- ── Setup ─────────────────────────────────────────────────────
function Stats:Setup()
    if not CharacterFrameInsetRight then return end

    -- Single container parented to CharacterFrameInsetRight.
    -- Hiding this one frame hides everything Persona draws in the stats pane.
    container = CreateFrame("Frame", "PersonaStatsContainer", CharacterFrameInsetRight)
    container:SetAllPoints(CharacterFrameInsetRight)

    -- Full-pane class gradient
    classGrad = container:CreateTexture("PersonaClassBG", "BACKGROUND")
    classGrad:SetAllPoints(container)

    -- ── Fixed header bar ─────────────────────────────────────
    headerBar = CreateFrame("Frame", "PersonaStatsHeader", container,
                            "BackdropTemplate")
    headerBar:SetPoint("TOPLEFT",  container, "TOPLEFT",   3, -3)
    headerBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", -3, -3)
    headerBar:SetHeight(HEADER_H)
    headerBar:SetBackdrop({
        bgFile  = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    headerBar:SetBackdropColor(0.06, 0.05, 0.10, 0.92)
    headerBar:SetBackdropBorderColor(0.35, 0.22, 0.55, 0.80)

    -- Three columns: iLvl | Durability | Repair Cost
    -- Each column: small grey label above, bright value below
    local function MakeCol(anchor, anchorPoint, xOff)
        local col = CreateFrame("Frame", nil, headerBar)
        col:SetWidth(62)
        col:SetHeight(HEADER_H)
        col:SetPoint(anchorPoint, headerBar, anchorPoint, xOff, 0)

        col.lbl = col:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        col.lbl:SetPoint("TOP", col, "TOP", 0, -4)
        col.lbl:SetTextColor(0.55, 0.52, 0.60)
        col.lbl:SetJustifyH("CENTER")

        col.val = col:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        col.val:SetPoint("BOTTOM", col, "BOTTOM", 0, 4)
        col.val:SetJustifyH("CENTER")
        col.val:SetText("–")
        return col
    end

    local colIlvl = MakeCol(headerBar, "LEFT",   4)
    colIlvl.lbl:SetText("Item Level")
    headerBar.ilvlVal = colIlvl.val

    -- Divider
    local div1 = headerBar:CreateTexture(nil, "ARTWORK")
    div1:SetSize(1, HEADER_H - 8)
    div1:SetPoint("LEFT", headerBar, "LEFT", 68, 0)
    div1:SetColorTexture(0.35, 0.22, 0.55, 0.60)

    local colDura = MakeCol(headerBar, "CENTER", 0)
    colDura.lbl:SetText("Durability")
    headerBar.duraVal = colDura.val

    local div2 = headerBar:CreateTexture(nil, "ARTWORK")
    div2:SetSize(1, HEADER_H - 8)
    div2:SetPoint("RIGHT", headerBar, "RIGHT", -68, 0)
    div2:SetColorTexture(0.35, 0.22, 0.55, 0.60)

    local colCost = MakeCol(headerBar, "RIGHT", -4)
    colCost.lbl:SetText("Repair")
    headerBar.costVal = colCost.val

    -- Tooltip: repair cost only available at a vendor
    colCost:EnableMouse(true)
    colCost:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("Repair Cost", 1, 1, 1)
        GameTooltip:AddLine("Updates when you open a repair NPC.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    colCost:SetScript("OnLeave", GameTooltip_Hide)

    -- ScrollFrame starts below the header
    scrollFrame = CreateFrame("ScrollFrame", "PersonaStatsScrollFrame",
                              container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     container, "TOPLEFT",      4, -(HEADER_H + 6))
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -2, 3)

    scrollFrame.ScrollBar:ClearAllPoints()
    scrollFrame.ScrollBar:SetPoint("TOPLEFT",    scrollFrame, "TOPRIGHT",    -16, -16)
    scrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", -16,  16)
    scrollFrame.ScrollBar:Hide()

    scrollFrame:HookScript("OnScrollRangeChanged", function()
        scrollFrame.ScrollBar:Hide()
    end)

    -- Scroll child
    scrollChild = CreateFrame("Frame", "PersonaStatsScrollChild", scrollFrame)
    scrollChild:SetWidth(191)
    scrollChild:SetHeight(600)
    scrollFrame:SetScrollChild(scrollChild)

    -- Native CharacterStatsPane → into scroll child
    CharacterStatsPane:SetParent(scrollChild)
    CharacterStatsPane:ClearAllPoints()
    CharacterStatsPane:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  0, 0)
    CharacterStatsPane:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, 0)
    if CharacterStatsPane.ClassBackground then
        CharacterStatsPane.ClassBackground:Hide()
    end

    CharacterStatsPane:HookScript("OnSizeChanged", function()
        Stats:Relayout()
    end)

    -- Custom categories
    BuildCategories()

    -- Expand button (use CharacterFrame:Expand/Collapse methods; Midnight API)
    local canExpand = CharacterFrame.Expand ~= nil
    if canExpand then
        local btn = CreateFrame("Button", "PersonaExpandButton", PaperDollFrame)
        btn:SetSize(32, 32)
        btn:SetPoint("BOTTOMLEFT", PaperDollFrame, "BOTTOMLEFT", 298, 3)
        btn:SetHighlightTexture("Interface\\BUTTONS\\UI-Common-MouseHilight")

        local function RefreshBtn()
            if CharacterFrame.Expanded then
                btn:SetNormalTexture("Interface\\BUTTONS\\UI-SpellbookIcon-PrevPage-Up")
                btn:SetPushedTexture("Interface\\BUTTONS\\UI-SpellbookIcon-PrevPage-Down")
            else
                btn:SetNormalTexture("Interface\\BUTTONS\\UI-SpellbookIcon-NextPage-Up")
                btn:SetPushedTexture("Interface\\BUTTONS\\UI-SpellbookIcon-NextPage-Down")
            end
        end

        btn:SetScript("OnClick", function()
            if CharacterFrame.Expanded then
                CharacterFrame:Collapse()
                if CharacterFrame.InsetRight then CharacterFrame.InsetRight:Hide() end
            else
                CharacterFrame:Expand()
                if CharacterFrame.InsetRight then CharacterFrame.InsetRight:Show() end
            end
            if CharacterFrame.UpdateSize then CharacterFrame:UpdateSize() end
            RefreshBtn()
        end)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(CharacterFrame.Expanded
                and L["Hide Character Stats"] or L["Show Character Stats"])
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", GameTooltip_Hide)

        PaperDollFrame:HookScript("OnShow", function()
            if Persona.db.stats.enabled and not CharacterFrame.Expanded then
                CharacterFrame:Expand()
                if CharacterFrame.InsetRight then CharacterFrame.InsetRight:Show() end
                if CharacterFrame.UpdateSize then CharacterFrame:UpdateSize() end
            end
            RefreshBtn()
        end)
        RefreshBtn()
    end

    hooksecurefunc("PaperDollFrame_UpdateStats", function() Stats:Update() end)

    CharacterFrame:HookScript("OnShow", function()
        container:Show()
        Stats:Update()
    end)

    -- PaperDollFrame has its own sidebar tabs (separate from CharacterFrame tabs):
    --   PaperDollSidebarTab1 = Stats  (CharacterStatsPane)
    --   PaperDollSidebarTab2 = Titles (PaperDollFrame.TitleManagerPane)
    --   PaperDollSidebarTab3 = Equipment Manager (PaperDollFrame.EquipmentManagerPane)
    -- PaperDollFrame_SetSidebar(self, index) is the plain Lua function called
    -- on every sidebar tab click. Hook it directly.
    hooksecurefunc("PaperDollFrame_SetSidebar", function(self, index)
        if index == 1 then
            container:Show()
            Stats:Update()
        else
            container:Hide()
        end
    end)

    -- Initial state: CharacterStatsPane:IsShown() tells us if sidebar 1 is active
    if CharacterStatsPane and not CharacterStatsPane:IsShown() then
        container:Hide()
    end

    -- Keep header values current whenever durability or gear changes
    local headerEvt = CreateFrame("Frame")
    headerEvt:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    headerEvt:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    headerEvt:SetScript("OnEvent", function() Stats:UpdateHeader() end)

    self:Update()
end

Persona:RegisterModule(Stats)
