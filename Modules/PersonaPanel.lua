-- Persona: Modules/PersonaPanel.lua
-- Standalone character panel. No dependency on CharacterFrame's secure tabs.
-- Opens with /persona.  Has its own PlayerModel, tab system, stats, vault, gear.
local addonName, Persona = ...

local PersonaPanel = {}
Persona.PersonaPanel = PersonaPanel

-- ── Constants ────────────────────────────────────────────────
local W, H          = 640, 500
local LEFT_W        = 210   -- model + header column width
local TAB_H         = 26
local HEADER_H      = 30

-- ── Inventory slots to show in Gear tab ──────────────────────
local GEAR_SLOTS = {
    { id = INVSLOT_HEAD,      name = "Head"       },
    { id = INVSLOT_NECK,      name = "Neck"       },
    { id = INVSLOT_SHOULDER,  name = "Shoulders"  },
    { id = INVSLOT_BACK,      name = "Back"       },
    { id = INVSLOT_CHEST,     name = "Chest"      },
    { id = INVSLOT_WRIST,     name = "Wrist"      },
    { id = INVSLOT_HAND,      name = "Hands"      },
    { id = INVSLOT_WAIST,     name = "Waist"      },
    { id = INVSLOT_LEGS,      name = "Legs"       },
    { id = INVSLOT_FEET,      name = "Feet"       },
    { id = INVSLOT_FINGER1,   name = "Ring 1"     },
    { id = INVSLOT_FINGER2,   name = "Ring 2"     },
    { id = INVSLOT_TRINKET1,  name = "Trinket 1"  },
    { id = INVSLOT_TRINKET2,  name = "Trinket 2"  },
    { id = INVSLOT_MAINHAND,  name = "Main Hand"  },
    { id = INVSLOT_OFFHAND,   name = "Off Hand"   },
}

-- ── Main frame ───────────────────────────────────────────────
local win = CreateFrame("Frame", "PersonaPanelFrame", UIParent, "BackdropTemplate")
win:SetSize(W, H)
win:SetPoint("CENTER")
win:SetFrameStrata("HIGH")
win:SetMovable(true)
win:SetClampedToScreen(true)
win:EnableMouse(true)
win:RegisterForDrag("LeftButton")
win:SetScript("OnDragStart", win.StartMoving)
win:SetScript("OnDragStop",  win.StopMovingOrSizing)
win:Hide()

win:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
})
win:SetBackdropColor(0.06, 0.05, 0.09, 0.97)
win:SetBackdropBorderColor(0.45, 0.30, 0.70, 1.0)

tinsert(UISpecialFrames, "PersonaPanelFrame")

-- ── Title bar ────────────────────────────────────────────────
local titleBg = win:CreateTexture(nil, "BACKGROUND")
titleBg:SetPoint("TOPLEFT",  win, "TOPLEFT",   5,  -5)
titleBg:SetPoint("TOPRIGHT", win, "TOPRIGHT",  -5, -5)
titleBg:SetHeight(26)
titleBg:SetColorTexture(0.10, 0.07, 0.16, 0.98)

local titleFS = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
titleFS:SetPoint("LEFT",   win, "LEFT",  14, 0)
titleFS:SetPoint("TOP",    win, "TOP",   0, -13)
titleFS:SetText("|cffcc99ffPersona|r")

local closeBtn = CreateFrame("Button", nil, win, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", win, "TOPRIGHT", 2, 2)
closeBtn:SetScript("OnClick", function() win:Hide() end)

-- ── Left pane: PlayerModel + mini header ─────────────────────
local leftPane = CreateFrame("Frame", nil, win, "BackdropTemplate")
leftPane:SetPoint("TOPLEFT",    win, "TOPLEFT",  6,   -(26 + TAB_H + 4))
leftPane:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 6,  6)
leftPane:SetWidth(LEFT_W)
leftPane:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
leftPane:SetBackdropColor(0.04, 0.03, 0.07, 0.95)
leftPane:SetBackdropBorderColor(0.35, 0.22, 0.55, 0.80)

-- Mini stat header (ilvl / durability / repair)
local miniHeader = CreateFrame("Frame", nil, leftPane)
miniHeader:SetPoint("TOPLEFT",  leftPane, "TOPLEFT",   3, -3)
miniHeader:SetPoint("TOPRIGHT", leftPane, "TOPRIGHT",  -3, -3)
miniHeader:SetHeight(HEADER_H)

local function MakeMiniStat(anchor, anchorPoint, xOff, labelText)
    local col = CreateFrame("Frame", nil, miniHeader)
    col:SetWidth(LEFT_W / 3 - 4)
    col:SetHeight(HEADER_H)
    col:SetPoint(anchorPoint, miniHeader, anchorPoint, xOff, 0)

    local lbl = col:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOP", col, "TOP", 0, -4)
    lbl:SetText(labelText)
    lbl:SetTextColor(0.55, 0.52, 0.60)
    lbl:SetJustifyH("CENTER")

    local val = col:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val:SetPoint("BOTTOM", col, "BOTTOM", 0, 4)
    val:SetJustifyH("CENTER")
    val:SetText("-")
    col.val = val
    return col
end

local colIlvl = MakeMiniStat(miniHeader, "LEFT",   2,  "iLvl")
local colDura = MakeMiniStat(miniHeader, "CENTER", 0,  "Durability")
local colCost = MakeMiniStat(miniHeader, "RIGHT",  -2, "Repair")

-- PlayerModel
local model = CreateFrame("PlayerModel", "PersonaPanelModel", leftPane)
model:SetPoint("TOPLEFT",     leftPane, "TOPLEFT",     3, -(HEADER_H + 4))
model:SetPoint("BOTTOMRIGHT", leftPane, "BOTTOMRIGHT", -3, 3)
model:SetUnit("player")

-- Rotate model on drag
model:EnableMouse(true)
model:EnableMouseWheel(true)
local dragging, lastX = false, 0
model:SetScript("OnMouseDown", function(self, btn)
    if btn == "LeftButton" then dragging = true; lastX = GetCursorPosition() end
end)
model:SetScript("OnMouseUp",   function() dragging = false end)
model:SetScript("OnUpdate", function(self)
    if dragging then
        local x = GetCursorPosition()
        local delta = (x - lastX) / self:GetWidth()
        self:SetFacing(self:GetFacing() - delta * 3.14)
        lastX = x
    end
end)
model:SetScript("OnMouseWheel", function(self, delta)
    self:SetCamDistanceScale(math.max(0.5, math.min(3, self:GetCamDistanceScale() - delta * 0.1)))
end)

-- ── Right pane & tab system ───────────────────────────────────
local rightPane = CreateFrame("Frame", nil, win)
rightPane:SetPoint("TOPLEFT",     win, "TOPLEFT",  LEFT_W + 10, -(26 + TAB_H + 4))
rightPane:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -6,  6)

-- Tab definitions
local TAB_DEFS = {
    { id = "stats", label = "Stats"     },
    { id = "gear",  label = "Gear"      },
    { id = "vault", label = "Vault"     },
}

local tabBtns   = {}
local tabPanels = {}
local activeTab = nil
local builtTabs = {}

local function SelectTab(id)
    activeTab = id
    for _, tb in pairs(tabBtns) do
        local on = tb.tabId == id
        tb.bg:SetColorTexture(on and 0.22 or 0.10,
                              on and 0.16 or 0.08,
                              on and 0.32 or 0.14, on and 1.0 or 0.88)
        tb.fs:SetTextColor(on and 1.0 or 0.60,
                           on and 0.90 or 0.55,
                           on and 1.0 or 0.75)
    end
    for panId, panel in pairs(tabPanels) do
        panel:SetShown(panId == id)
    end
end

local tabX = 0
for _, td in ipairs(TAB_DEFS) do
    local TAB_W = 80
    local tb = CreateFrame("Button", nil, win)
    tb:SetSize(TAB_W, TAB_H)
    tb:SetPoint("TOPLEFT", win, "TOPLEFT", LEFT_W + 10 + tabX, -(26 + 2))
    tabX = tabX + TAB_W + 2

    tb.bg = tb:CreateTexture(nil, "BACKGROUND")
    tb.bg:SetAllPoints()
    tb.bg:SetColorTexture(0.10, 0.08, 0.14, 0.88)

    local hi = tb:CreateTexture(nil, "HIGHLIGHT")
    hi:SetAllPoints()
    hi:SetColorTexture(0.25, 0.18, 0.38, 0.55)

    tb.fs = tb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tb.fs:SetPoint("CENTER")
    tb.fs:SetText(td.label)

    tb.tabId = td.id
    tb:SetScript("OnClick", function()
        if not builtTabs[td.id] then
            builtTabs[td.id] = true
            PersonaPanel["Build_" .. td.id](PersonaPanel)
        end
        SelectTab(td.id)
    end)
    tabBtns[td.id] = tb

    -- Each tab gets a scrollable content area
    local sf = CreateFrame("ScrollFrame", nil, rightPane, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     rightPane, "TOPLEFT",      0,  0)
    sf:SetPoint("BOTTOMRIGHT", rightPane, "BOTTOMRIGHT", -16, 0)
    sf:Hide()

    sf.ScrollBar:ClearAllPoints()
    sf.ScrollBar:SetPoint("TOPLEFT",    sf, "TOPRIGHT",    -14, -16)
    sf.ScrollBar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", -14,  16)

    local sc = CreateFrame("Frame", nil, sf)
    sc:SetWidth(rightPane:GetWidth() - 20)
    sc:SetHeight(800)
    sf:SetScrollChild(sc)
    sf.child = sc

    tabPanels[td.id] = sf
end

-- ── Shared widget helpers ─────────────────────────────────────
local function SectionHeader(parent, text, y)
    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT",  parent, "TOPLEFT",   0, y)
    bg:SetPoint("TOPRIGHT", parent, "TOPRIGHT",  0, y)
    bg:SetHeight(20)
    bg:SetColorTexture(0.12, 0.08, 0.18, 0.90)

    local accent = parent:CreateTexture(nil, "OVERLAY")
    accent:SetSize(3, 20)
    accent:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    accent:SetColorTexture(0.70, 0.55, 1.00, 0.90)

    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", parent, "LEFT", 8, y - 10)
    fs:SetText(text)
    fs:SetTextColor(0.90, 0.82, 1.00)
    return y - 22
end

local function StatRow(parent, label, y, getterFn)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT",  parent, "TOPLEFT",   0, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT",  0, y)
    row:SetHeight(18)

    local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", row, "LEFT", 10, 0)
    lbl:SetText(label)
    lbl:SetTextColor(0.70, 0.70, 0.72)

    local val = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    val:SetJustifyH("RIGHT")
    val:SetText("-")

    row.Refresh = function()
        if getterFn then
            local ok, v = pcall(getterFn)
            val:SetText(ok and v or "-")
        end
    end
    row.Refresh()
    return row, y - 18
end

-- ── Stats tab ─────────────────────────────────────────────────
function PersonaPanel:Build_stats()
    local p = tabPanels["stats"].child
    local y = -4

    -- We pull category/row data from Persona.Stats if available,
    -- otherwise fall back to a minimal set of direct API calls.
    if Persona.Stats and Persona.Stats.categoryList then
        for _, cat in ipairs(Persona.Stats.categoryList) do
            local catTitle = cat.titleFS and cat.titleFS:GetText() or "—"
            y = SectionHeader(p, catTitle, y)
            for _, row in ipairs(cat.rows) do
                local label = row.labelFS and row.labelFS:GetText() or ""
                local _, ny = StatRow(p, label, y, row.getter)
                y = ny
            end
            y = y - 4
        end
    else
        -- Fallback: show a handful of always-available stats
        y = SectionHeader(p, "General", y)
        _, y = StatRow(p, "Health",     y, function() return BreakUpLargeNumbers(UnitHealthMax("player")) end)
        _, y = StatRow(p, "Move Speed", y, function() return string.format("%.0f%%", (GetUnitSpeed("player") or 0) / 7 * 100) end)
        y = y - 4
        y = SectionHeader(p, "Secondary", y)
        _, y = StatRow(p, "Haste",        y, function() local ok,v = pcall(GetHaste)   return ok and v and string.format("%.2f%%",v) or "-" end)
        _, y = StatRow(p, "Crit",         y, function() local ok,v = pcall(GetCritChance) return ok and v and string.format("%.2f%%",v) or "-" end)
        _, y = StatRow(p, "Mastery",      y, function() local ok,v = pcall(GetMastery) return ok and v and string.format("%.2f",v) or "-" end)
        _, y = StatRow(p, "Versatility",  y, function() local ok,v = pcall(GetVersatility) return ok and v and string.format("%.2f%%",v) or "-" end)
    end

    p:SetHeight(math.abs(y) + 20)
    self.statsRows = { GetChildren = function() return p:GetChildren() end }
end

-- ── Gear tab ──────────────────────────────────────────────────
function PersonaPanel:Build_gear()
    local p = tabPanels["gear"].child
    local y = -4

    -- Column headers
    local hdr = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hdr:SetPoint("TOPLEFT", p, "TOPLEFT", 8, y)
    hdr:SetText("|cff888888Slot              iLvl   Enchant|r")
    y = y - 18

    local gearRows = {}
    for _, slot in ipairs(GEAR_SLOTS) do
        local row = CreateFrame("Frame", nil, p)
        row:SetPoint("TOPLEFT",  p, "TOPLEFT",   0, y)
        row:SetPoint("TOPRIGHT", p, "TOPRIGHT",  0, y)
        row:SetHeight(18)

        -- Alternate stripe
        local stripe = row:CreateTexture(nil, "BACKGROUND")
        stripe:SetAllPoints()
        if (#gearRows % 2 == 0) then
            stripe:SetColorTexture(0.07, 0.05, 0.10, 0.55)
        else
            stripe:SetColorTexture(0.10, 0.07, 0.13, 0.35)
        end

        -- Item icon (16x16)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(14, 14)
        icon:SetPoint("LEFT", row, "LEFT", 4, 0)

        local slotLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        slotLbl:SetPoint("LEFT", row, "LEFT", 22, 0)
        slotLbl:SetText(slot.name)
        slotLbl:SetTextColor(0.65, 0.65, 0.68)
        slotLbl:SetWidth(70)

        local ilvlFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ilvlFS:SetPoint("LEFT", row, "LEFT", 98, 0)
        ilvlFS:SetWidth(40)
        ilvlFS:SetJustifyH("LEFT")

        local enchantFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        enchantFS:SetPoint("LEFT", row, "LEFT", 142, 0)
        enchantFS:SetTextColor(0.3, 1.0, 0.5)

        row.slotId   = slot.id
        row.icon     = icon
        row.ilvlFS   = ilvlFS
        row.enchantFS = enchantFS

        table.insert(gearRows, row)
        y = y - 18
    end

    p:SetHeight(math.abs(y) + 20)
    self.gearRows = gearRows
end

-- ── Vault tab ─────────────────────────────────────────────────
function PersonaPanel:Build_vault()
    local p = tabPanels["vault"].child
    local y = -4

    y = SectionHeader(p, "Great Vault", y)

    local VAULT_TYPES = {
        { id = (Enum.WeeklyRewardChestThresholdType and Enum.WeeklyRewardChestThresholdType.Dungeon) or 1, label = "Dungeons" },
        { id = (Enum.WeeklyRewardChestThresholdType and Enum.WeeklyRewardChestThresholdType.Raid)    or 2, label = "Raids"    },
        { id = 4, label = "World" },
    }

    local vaultRows = {}
    for _, vt in ipairs(VAULT_TYPES) do
        local capturedId = vt.id
        local row, ny = StatRow(p, vt.label, y, function()
            if not Persona.Stats then return "-" end
            return Persona.Stats:GetVaultText(capturedId)
        end)
        y = ny
        table.insert(vaultRows, row)
    end

    y = y - 8
    y = SectionHeader(p, "Display Mode", y)

    local modeRow = CreateFrame("Frame", nil, p)
    modeRow:SetPoint("TOPLEFT",  p, "TOPLEFT",   0, y)
    modeRow:SetPoint("TOPRIGHT", p, "TOPRIGHT",  0, y)
    modeRow:SetHeight(24)

    local modeLabel = modeRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    modeLabel:SetPoint("LEFT", modeRow, "LEFT", 10, 0)
    modeLabel:SetTextColor(0.70, 0.70, 0.72)

    local function RefreshModeLabel()
        local m = Persona.db.vault.displayMode
        modeLabel:SetText("Current: " .. (m == "slots" and "Slots (x/3)" or "Progress (x/8)"))
    end
    RefreshModeLabel()

    local toggleBtn = CreateFrame("Button", nil, modeRow, "UIPanelButtonTemplate")
    toggleBtn:SetSize(80, 20)
    toggleBtn:SetPoint("RIGHT", modeRow, "RIGHT", -6, 0)
    toggleBtn:SetText("Toggle")
    toggleBtn:SetScript("OnClick", function()
        Persona.db.vault.displayMode = (Persona.db.vault.displayMode == "slots") and "progress" or "slots"
        RefreshModeLabel()
        PersonaPanel:UpdateVault()
    end)

    y = y - 26
    p:SetHeight(math.abs(y) + 20)
    self.vaultRows = vaultRows
end

-- ── Update functions ──────────────────────────────────────────

function PersonaPanel:UpdateHeader()
    -- iLvl
    local ok, _, avgEq = pcall(GetAverageItemLevel)
    colIlvl.val:SetText(ok and avgEq and string.format("%.1f", avgEq) or "-")

    -- Durability
    local tot, mx = 0, 0
    for s = 0, 19 do
        local c, m = GetInventoryItemDurability(s)
        if c and m and m > 0 then tot = tot + c; mx = mx + m end
    end
    if mx > 0 then
        local pct = tot / mx * 100
        local r, g, b = Persona.HPGradient(tot / mx)
        colDura.val:SetText(string.format("|cff%02x%02x%02x%.0f%%|r", r*255, g*255, b*255, pct))
    else
        colDura.val:SetText("-")
    end

    -- Repair cost
    local total = 0
    for _, slot in ipairs(GEAR_SLOTS) do
        local ok2, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot.id)
        if ok2 and data and data.repairCost and data.repairCost > 0 then
            total = total + data.repairCost
        end
    end
    if total == 0 then
        colCost.val:SetText("|cff888888-|r")
    else
        local g = math.floor(total/10000)
        local s = math.floor((total%10000)/100)
        if g > 0 then
            colCost.val:SetText(string.format("|cffffd700%dg|r |cffc7c7cf%ds|r", g, s))
        else
            colCost.val:SetText(string.format("|cffc7c7cf%ds|r", s))
        end
    end
end

function PersonaPanel:UpdateStats()
    if not builtTabs["stats"] then return end
    local p = tabPanels["stats"].child
    for _, child in ipairs({p:GetChildren()}) do
        if child.Refresh then child:Refresh() end
    end
end

function PersonaPanel:UpdateGear()
    if not builtTabs["gear"] or not self.gearRows then return end
    local enchantPat = ENCHANTED_TOOLTIP_LINE:gsub("%%s", "(.*)")

    for _, row in ipairs(self.gearRows) do
        local slotId = row.slotId
        local link   = GetInventoryItemLink("player", slotId)

        if link then
            -- Icon
            local tex = GetInventoryItemTexture("player", slotId)
            if tex then row.icon:SetTexture(tex); row.icon:Show()
            else row.icon:Hide() end

            -- iLvl
            local ilvl = GetDetailedItemLevelInfo and GetDetailedItemLevelInfo(link)
            local quality = GetInventoryItemQuality("player", slotId)
            if ilvl then
                local hex = quality and select(4, GetItemQualityColor(quality)) or "ffffff"
                row.ilvlFS:SetText("|c"..hex..ilvl.."|r")
            else
                row.ilvlFS:SetText("-")
            end

            -- Enchant (abbreviated)
            local ench = ""
            local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slotId)
            if ok and data then
                for _, line in ipairs(data.lines) do
                    local m = (line.leftText or ""):match(enchantPat)
                    if m then
                        m = m:gsub("|c%x%x%x%x%x%x%x%x(.-)%|r", "%1")
                              :gsub("^Enchant ", ""):gsub("^%a+ %- ", "")
                        ench = m:sub(1, 22)
                        break
                    end
                end
            end
            row.enchantFS:SetText(ench)
        else
            row.icon:Hide()
            row.ilvlFS:SetText("")
            row.enchantFS:SetText("")
        end
    end
end

function PersonaPanel:UpdateVault()
    if not builtTabs["vault"] or not self.vaultRows then return end
    for _, row in ipairs(self.vaultRows) do
        if row.Refresh then row:Refresh() end
    end
end

function PersonaPanel:UpdateAll()
    self:UpdateHeader()
    if activeTab == "stats" then self:UpdateStats() end
    if activeTab == "gear"  then self:UpdateGear()  end
    if activeTab == "vault" then self:UpdateVault()  end
end

-- ── Open / close ──────────────────────────────────────────────
function PersonaPanel:Toggle()
    if win:IsShown() then
        win:Hide()
    else
        win:Show()
        -- Apply saved animation to model
        if Persona.db.panel.savedAnimation and Persona.db.panel.savedAnimation ~= 0 then
            C_Timer.After(0.3, function()
                pcall(model.SetAnimation, model, Persona.db.panel.savedAnimation)
            end)
        end
        if not activeTab then
            -- Build and select default tab on first open
            builtTabs["stats"] = true
            self:Build_stats()
            SelectTab("stats")
        end
        self:UpdateAll()
    end
end

-- Update title with character name
win:HookScript("OnShow", function()
    local name = UnitName("player") or ""
    local _, cls = UnitClass("player")
    local c = Persona.classColors[cls] or { 1, 1, 1 }
    titleFS:SetText(string.format("|cffcc99ffPersona|r  |cff%02x%02x%02x%s|r",
        c[1]*255, c[2]*255, c[3]*255, name))
    PersonaPanel:UpdateAll()
end)

-- Refresh on equipment / durability changes
local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
evtFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
evtFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
evtFrame:SetScript("OnEvent", function()
    if win:IsShown() then PersonaPanel:UpdateAll() end
end)

-- ── Module Setup ──────────────────────────────────────────────
function PersonaPanel:Setup()
    -- Expose model reference in case PanelCustomizer wants it
    Persona.personaModel = model
end

Persona:RegisterModule(PersonaPanel)
