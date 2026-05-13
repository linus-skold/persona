-- Persona: Settings/FloatingSettings.lua
-- Free-floating, draggable settings window.  Open with /persona or /persona <tab>.
-- Tabs: Item Slots · Stats · Vault · Panel
local addonName, Persona = ...

local WIN_W  = 440
local WIN_H  = 530
local TAB_H  = 26
local MARGIN = 10
local ROW_H  = 22

-- ── Main window ───────────────────────────────────────────────
local win = CreateFrame("Frame", "PersonaFloatingSettings", UIParent, "BackdropTemplate")
win:SetSize(WIN_W, WIN_H)
win:SetPoint("CENTER")
win:SetFrameStrata("DIALOG")
win:SetFrameLevel(100)
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

-- ESC closes the window
tinsert(UISpecialFrames, "PersonaFloatingSettings")

-- ── Title bar ─────────────────────────────────────────────────
local titleBg = win:CreateTexture(nil, "BACKGROUND")
titleBg:SetPoint("TOPLEFT",  win, "TOPLEFT",   5,  -5)
titleBg:SetPoint("TOPRIGHT", win, "TOPRIGHT",  -5, -5)
titleBg:SetHeight(26)
titleBg:SetColorTexture(0.12, 0.08, 0.20, 0.98)

local titleFS = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
titleFS:SetPoint("LEFT", win, "LEFT", 14, 0)
titleFS:SetPoint("TOP",  win, "TOP",  0, -14)
titleFS:SetText("|cffcc99ffPersona|r  Configuration")

local closeBtn = CreateFrame("Button", nil, win, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", win, "TOPRIGHT", 2, 2)
closeBtn:SetScript("OnClick", function() win:Hide() end)

-- ── Tab system ────────────────────────────────────────────────
local TAB_DEFS = {
    { id = "slots",  label = "Item Slots" },
    { id = "stats",  label = "Stats"      },
    { id = "vault",  label = "Vault"      },
    { id = "panel",  label = "Panel"      },
}

local tabBtns   = {}
local tabPanels = {}
local activeTab = nil
local builtTabs = {}

-- Y offset where tab content starts (below title + tab row)
local CONTENT_Y = -(26 + TAB_H + 4)

local function SelectTab(id)
    activeTab = id
    for _, tb in pairs(tabBtns) do
        local on = tb.tabId == id
        tb.bg:SetColorTexture(on and 0.22 or 0.10,
                              on and 0.16 or 0.08,
                              on and 0.32 or 0.14, on and 1.0 or 0.88)
        tb.fs:SetTextColor(on and 1.0 or 0.60,
                           on and 0.9 or 0.55,
                           on and 1.0 or 0.75)
    end
    for panId, panel in pairs(tabPanels) do
        panel:SetShown(panId == id)
    end
end

local tabX = MARGIN + 4
for _, td in ipairs(TAB_DEFS) do
    local TAB_W = 96
    local tb = CreateFrame("Button", nil, win)
    tb:SetSize(TAB_W, TAB_H)
    tb:SetPoint("TOPLEFT", win, "TOPLEFT", tabX, -(26 + 2))
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
            -- builder called below after BuildX functions are defined
            win._buildTab(td.id)
        end
        SelectTab(td.id)
    end)
    tabBtns[td.id] = tb

    -- Each tab gets a ScrollFrame so content can overflow
    local sf = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     win, "TOPLEFT",     MARGIN,      CONTENT_Y - 2)
    sf:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -MARGIN - 16, MARGIN)
    sf:Hide()

    local sc = CreateFrame("Frame", nil, sf)
    sc:SetWidth(WIN_W - MARGIN * 2 - 24)
    sc:SetHeight(900)
    sf:SetScrollChild(sc)

    sf.child   = sc
    tabPanels[td.id] = sf
end

-- ── Widget helpers ────────────────────────────────────────────
-- All return new Y offset (y - consumed height)

local function Header(parent, text, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, y)
    fs:SetText("|cffcc99ff" .. text .. "|r")
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT",  parent, "TOPLEFT",  2, y - 15)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -2, y - 15)
    line:SetColorTexture(0.40, 0.26, 0.65, 0.70)
    return y - 20
end

local function Check(parent, label, y, getter, setter)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(20, 20)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, y)
    cb:SetChecked(getter and getter() or false)

    -- UICheckButtonTemplate creates a .Text sub-object for named frames;
    -- for anonymous frames it may or may not exist – create one manually either way.
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    lbl:SetText(label)
    lbl:SetTextColor(0.84, 0.84, 0.86)

    cb:SetScript("OnClick", function(self)
        if setter then setter(not not self:GetChecked()) end
    end)
    return cb, y - ROW_H
end

-- Left-right cycle button for option lists
local function Cycle(parent, labelText, y, options, getter, setter)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, y)
    lbl:SetText(labelText .. ":")
    lbl:SetTextColor(0.72, 0.72, 0.75)

    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(200, 20)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", 150, y)

    local prev = CreateFrame("Button", nil, holder)
    prev:SetSize(18, 18)
    prev:SetPoint("LEFT")
    prev:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    prev:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    prev:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

    local next_ = CreateFrame("Button", nil, holder)
    next_:SetSize(18, 18)
    next_:SetPoint("RIGHT")
    next_:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    next_:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    next_:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

    local valFS = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valFS:SetPoint("LEFT",  prev,  "RIGHT", 4, 0)
    valFS:SetPoint("RIGHT", next_, "LEFT",  -4, 0)
    valFS:SetJustifyH("CENTER")

    local function GetIdx()
        local cur = getter()
        for i, opt in ipairs(options) do
            if opt.value == cur then return i end
        end
        return 1
    end
    local function Refresh() valFS:SetText(options[GetIdx()].label) end

    prev:SetScript("OnClick", function()
        local i = GetIdx(); i = i > 1 and i - 1 or #options
        setter(options[i].value); Refresh()
    end)
    next_:SetScript("OnClick", function()
        local i = GetIdx(); i = i < #options and i + 1 or 1
        setter(options[i].value); Refresh()
    end)
    Refresh()
    return y - ROW_H - 2
end

local function Slider(parent, labelText, y, minV, maxV, step, getter, setter)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, y)
    lbl:SetText(labelText)
    lbl:SetTextColor(0.72, 0.72, 0.75)

    local sl = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    sl:SetPoint("TOPLEFT", parent, "TOPLEFT", 160, y + 2)
    sl:SetWidth(210)
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(step)
    sl:SetObeyStepOnDrag(true)
    sl:SetValue(getter())
    sl.Low:SetText(tostring(minV))
    sl.High:SetText(tostring(maxV))
    sl.Text:SetText(tostring(math.floor(getter())))

    sl:SetScript("OnValueChanged", function(self, v)
        self.Text:SetText(tostring(math.floor(v)))
        setter(v)
    end)
    return y - 34
end

-- ── Tab builders ──────────────────────────────────────────────

local function BuildSlots()
    local p = tabPanels["slots"].child
    local y = -6

    y = Header(p, "Item Levels", y)
    local _, ny = Check(p, "Show Item Level", y,
        function() return Persona.db.itemSlots.showIlvl end,
        function(v) Persona.db.itemSlots.showIlvl = v; Persona:RefreshAll() end)
    y = ny
    y = Cycle(p, "Position", y,
        { {value="outside", label="Outside slot"}, {value="inside", label="Inside slot"} },
        function() return Persona.db.itemSlots.ilvlPosition end,
        function(v) Persona.db.itemSlots.ilvlPosition = v; Persona:RefreshAll() end)

    y = y - 6
    y = Header(p, "Enchants", y)
    _, y = Check(p, "Show Enchants", y,
        function() return Persona.db.itemSlots.showEnchants end,
        function(v) Persona.db.itemSlots.showEnchants = v; Persona:RefreshAll() end)
    y = Cycle(p, "Display mode", y,
        { {value="effect", label="Effect  (short)"}, {value="name", label="Full name"} },
        function() return Persona.db.itemSlots.enchantDisplay end,
        function(v) Persona.db.itemSlots.enchantDisplay = v; Persona:RefreshAll() end)
    _, y = Check(p, "Warn: missing enchant on enchantable slots", y,
        function() return Persona.db.itemSlots.showMissingEnchant end,
        function(v) Persona.db.itemSlots.showMissingEnchant = v; Persona:RefreshAll() end)

    y = y - 6
    y = Header(p, "Gems & Durability", y)
    _, y = Check(p, "Show Gem icons", y,
        function() return Persona.db.itemSlots.showGems end,
        function(v) Persona.db.itemSlots.showGems = v; Persona:RefreshAll() end)
    _, y = Check(p, "Show Durability bar", y,
        function() return Persona.db.itemSlots.showDurability end,
        function(v) Persona.db.itemSlots.showDurability = v; Persona:RefreshAll() end)

    tabPanels["slots"].child:SetHeight(math.abs(y) + 20)
end

local function BuildStats()
    local p = tabPanels["stats"].child
    local y = -6

    y = Header(p, "Appearance", y)
    _, y = Check(p, "Class Color Headers & Background", y,
        function() return Persona.db.stats.classBackground end,
        function(v)
            Persona.db.stats.classBackground = v
            if Persona.Stats then Persona.Stats:Update() end
        end)
    _, y = Check(p, "Show Scrollbar", y,
        function() return Persona.db.stats.scrollbar end,
        function(v)
            Persona.db.stats.scrollbar = v
            if Persona.Stats then Persona.Stats:Update() end
        end)
    y = Cycle(p, "Stat Layout", y,
        {
            {value="auto",     label="Auto (spec-based)"},
            {value="tank",     label="Tank"},
            {value="healer",   label="Healer"},
            {value="caster",   label="Caster"},
            {value="physical", label="Physical DPS"},
        },
        function() return Persona.db.stats.layout end,
        function(v)
            Persona.db.stats.layout = v
            if Persona.Stats then Persona.Stats:ApplyLayout() end
        end)

    -- Per-stat toggles  (mirrored from Stats.lua IDs)
    local GROUPS = {
        { title = "Defense",
          stats = {
            {id="armor",      label="Armor"},
            {id="dodge",      label="Dodge"},
            {id="parry",      label="Parry"},
            {id="block",      label="Block"},
            {id="stagger",    label="Stagger"},
        }},
        { title = "Offense",
          stats = {
            {id="ap",         label="Attack Power"},
            {id="rap",        label="Ranged AP"},
            {id="sp",         label="Spell Power"},
            {id="melee_crit", label="Melee Crit"},
            {id="ranged_crit",label="Ranged Crit"},
            {id="spell_crit", label="Spell Crit"},
            {id="melee_speed",label="Melee Speed"},
            {id="haste",      label="Haste"},
            {id="mastery",    label="Mastery"},
        }},
        { title = "Misc",
          stats = {
            {id="speed",  label="Move Speed"},
            {id="leech",  label="Leech"},
            {id="avoid",  label="Avoidance"},
            {id="dura",   label="Durability"},
        }},
    }

    for _, grp in ipairs(GROUPS) do
        y = y - 6
        y = Header(p, grp.title, y)
        local col, rowY = 0, y
        for _, st in ipairs(grp.stats) do
            local xOff = col == 0 and 4 or 200
            local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
            cb:SetSize(18, 18)
            cb:SetPoint("TOPLEFT", p, "TOPLEFT", xOff, rowY)
            cb:SetChecked(not (Persona.db.stats.hiddenStats and Persona.db.stats.hiddenStats[st.id]))

            local lbl = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("LEFT", cb, "RIGHT", 3, 0)
            lbl:SetText(st.label)
            lbl:SetTextColor(0.82, 0.82, 0.85)

            local capturedId = st.id
            cb:SetScript("OnClick", function(self)
                Persona.db.stats.hiddenStats = Persona.db.stats.hiddenStats or {}
                if not not self:GetChecked() then
                    Persona.db.stats.hiddenStats[capturedId] = nil   -- visible
                else
                    Persona.db.stats.hiddenStats[capturedId] = true  -- hidden
                end
                if Persona.Stats then Persona.Stats:Update() end
            end)

            col = col + 1
            if col >= 2 then col = 0; rowY = rowY - ROW_H end
        end
        if col ~= 0 then rowY = rowY - ROW_H end
        y = rowY
    end

    tabPanels["stats"].child:SetHeight(math.abs(y) + 20)
end

local function BuildVault()
    local p = tabPanels["vault"].child
    local y = -6

    y = Header(p, "Great Vault  (shown in Stats pane)", y)
    _, y = Check(p, "Show vault progress", y,
        function() return Persona.db.vault.enabled end,
        function(v)
            Persona.db.vault.enabled = v
            if Persona.Stats then Persona.Stats:Update() end
        end)
    y = Cycle(p, "Display mode", y,
        {
            {value="progress", label="X / 8  (raw progress)"},
            {value="slots",    label="X / 3  (slots unlocked)"},
        },
        function() return Persona.db.vault.displayMode end,
        function(v)
            Persona.db.vault.displayMode = v
            if Persona.Stats then Persona.Stats:Update() end
        end)

    tabPanels["vault"].child:SetHeight(math.abs(y) + 20)
end

local function BuildPanel()
    local p = tabPanels["panel"].child
    local y = -6

    y = Header(p, "Background", y)
    y = Slider(p, "Alpha %", y, 0, 100, 5,
        function() return math.floor((Persona.db.panel.backgroundAlpha or 1.0) * 100) end,
        function(v)
            Persona.db.panel.backgroundAlpha = v / 100
            if Persona.PanelCustomizer then Persona.PanelCustomizer:ApplyAlpha() end
        end)

    y = y - 6
    y = Header(p, "Character Pose", y)
    y = Cycle(p, "On open, play", y,
        {
            {value=0,   label="Stand (default)"},
            {value=67,  label="Kneel"},
            {value=69,  label="Dance"},
            {value=363, label="Sit"},
            {value=1,   label="Combat Ready"},
            {value=311, label="Spell Cast"},
            {value=520, label="Heroic Pose"},
        },
        function() return Persona.db.panel.savedAnimation or 0 end,
        function(v)
            Persona.db.panel.savedAnimation = v
            if Persona.PanelCustomizer then Persona.PanelCustomizer:ApplyAnimation() end
        end)

    tabPanels["panel"].child:SetHeight(math.abs(y) + 20)
end

-- ── Dispatch table (referenced by tab OnClick above) ──────────
local BUILDERS = {
    slots = BuildSlots,
    stats = BuildStats,
    vault = BuildVault,
    panel = BuildPanel,
}
win._buildTab = function(id)
    if BUILDERS[id] then BUILDERS[id]() end
end

-- ── Public: open / toggle ─────────────────────────────────────
local firstOpen = true

function Persona.OpenSettings(tabId)
    if firstOpen then
        firstOpen = false
        -- Anchor near CharacterFrame if it's open, otherwise center
        if CharacterFrame and CharacterFrame:IsShown() then
            win:ClearAllPoints()
            win:SetPoint("LEFT", CharacterFrame, "RIGHT", 8, 0)
        end
    end

    local target = tabId or activeTab or "slots"

    -- Toggle off if already on the same tab
    if win:IsShown() and activeTab == target then
        win:Hide()
        return
    end

    win:Show()

    if not builtTabs[target] then
        builtTabs[target] = true
        win._buildTab(target)
    end
    SelectTab(target)
end

-- ── Slash command (replaces stub in Persona.lua) ──────────────
SLASH_PERSONA1 = "/persona"
SlashCmdList["PERSONA"] = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "" or msg == "config" or msg == "settings" then
        Persona.OpenSettings()
    elseif msg == "slots" or msg == "stats" or msg == "vault" then
        Persona.OpenSettings(msg)
    elseif msg == "reset" then
        PersonaDB = nil
        ReloadUI()
    else
        print("|cffcc99ffPersona|r  —  /persona  [settings | slots | stats | vault | reset]")
    end
end
