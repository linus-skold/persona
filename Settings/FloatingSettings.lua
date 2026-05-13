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

    -- Main button
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(200, 20)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 150, y)
    btn:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 8,
        insets = {left=3, right=3, top=3, bottom=3},
    })
    btn:SetBackdropColor(0.10, 0.08, 0.14, 0.95)
    btn:SetBackdropBorderColor(0.40, 0.30, 0.60, 0.90)

    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btnText:SetPoint("LEFT",  btn, "LEFT",  6, 0)
    btnText:SetPoint("RIGHT", btn, "RIGHT", -18, 0)
    btnText:SetJustifyH("LEFT")
    btnText:SetWordWrap(false)

    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(10, 6)
    arrow:SetPoint("RIGHT", btn, "RIGHT", -5, -1)
    arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    arrow:SetVertexColor(0.80, 0.70, 1.00)

    local function Refresh()
        local cur = getter()
        for _, opt in ipairs(options) do
            if opt.value == cur then btnText:SetText(opt.label); return end
        end
        btnText:SetText("-")
    end
    Refresh()

    -- Drop list (parented to UIParent so it floats above everything)
    local listFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    listFrame:SetFrameStrata("TOOLTIP")
    listFrame:SetFrameLevel(200)
    listFrame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 8,
        insets = {left=4, right=4, top=4, bottom=4},
    })
    listFrame:SetBackdropColor(0.06, 0.05, 0.09, 0.98)
    listFrame:SetBackdropBorderColor(0.45, 0.30, 0.70, 1.0)
    listFrame:Hide()

    local ITEM_H = 18
    local listItems = {}
    for i, opt in ipairs(options) do
        local item = CreateFrame("Button", nil, listFrame)
        item:SetHeight(ITEM_H)
        item:SetPoint("TOPLEFT",  listFrame, "TOPLEFT",   5, -(4 + (i-1)*ITEM_H))
        item:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT",  -5, -(4 + (i-1)*ITEM_H))

        local hl = item:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(0.25, 0.18, 0.40, 0.65)

        local dot = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        dot:SetPoint("LEFT", item, "LEFT", 3, 0)
        dot:SetWidth(12)
        dot:SetJustifyH("LEFT")
        dot:SetTextColor(0.80, 0.70, 1.00)

        local txt = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("LEFT",  item, "LEFT",  16, 0)
        txt:SetPoint("RIGHT", item, "RIGHT", -4, 0)
        txt:SetJustifyH("LEFT")
        txt:SetText(opt.label)

        item.dot      = dot
        item.optValue = opt.value
        table.insert(listItems, item)

        local capturedOpt = opt
        item:SetScript("OnClick", function()
            setter(capturedOpt.value)
            Refresh()
            listFrame:Hide()
        end)
    end

    listFrame:SetWidth(btn:GetWidth())
    listFrame:SetHeight(4 + #options * ITEM_H + 4)

    local function UpdateDots()
        local cur = getter()
        for _, li in ipairs(listItems) do
            li.dot:SetText(li.optValue == cur and "|cffcc99ff●|r" or "")
        end
    end

    -- Click-catcher behind the list to close it
    local catcher = CreateFrame("Frame", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:SetFrameLevel(199)
    catcher:EnableMouse(true)
    catcher:Hide()
    catcher:SetScript("OnMouseDown", function()
        listFrame:Hide(); catcher:Hide()
    end)

    btn:SetScript("OnClick", function()
        if listFrame:IsShown() then
            listFrame:Hide(); catcher:Hide()
        else
            listFrame:ClearAllPoints()
            -- Open upward if too close to bottom of screen
            local _, by = btn:GetCenter()
            local listH = listFrame:GetHeight()
            if by and by - listH < 60 then
                listFrame:SetPoint("BOTTOMLEFT", btn, "TOPLEFT",   0,  2)
            else
                listFrame:SetPoint("TOPLEFT",    btn, "BOTTOMLEFT", 0, -2)
            end
            UpdateDots()
            listFrame:Show()
            catcher:Show()
        end
    end)

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

-- Shared callback so the Position cycle can refresh the upgrade sub-options.
local _upgradePosRefresh = nil

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

    -- ── Upgrade Level ─────────────────────────────────────────
    y = y - 6
    y = Header(p, "Upgrade Level", y)
    _, y = Check(p, "Show upgrade level (e.g. 3/8)", y,
        function() return Persona.db.itemSlots.upgradeLevel.enabled end,
        function(v) Persona.db.itemSlots.upgradeLevel.enabled = v; Persona:RefreshAll() end)

    y = Slider(p, "Text size", y, 6, 18, 1,
        function() return Persona.db.itemSlots.upgradeLevel.fontSize or 9 end,
        function(v)
            Persona.db.itemSlots.upgradeLevel.fontSize = math.floor(v)
            Persona:RefreshAll()
        end)

    -- Upgrade has its own Inside/Outside setting, independent of ilvl.
    y = Cycle(p, "Placement", y,
        { {value="outside", label="Outside slot"}, {value="inside", label="Inside slot"} },
        function() return Persona.db.itemSlots.upgradeLevel.position or "outside" end,
        function(v)
            Persona.db.itemSlots.upgradeLevel.position = v
            Persona:RefreshAll()
            if _upgradePosRefresh then _upgradePosRefresh() end
        end)

    -- Two sub-frames: only one shown based on upgradeLevel.position.
    local posRowH = ROW_H + 4

    local insideHolder = CreateFrame("Frame", nil, p)
    insideHolder:SetPoint("TOPLEFT",  p, "TOPLEFT",  0, y)
    insideHolder:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, y)
    insideHolder:SetHeight(posRowH)
    Cycle(insideHolder, "Position", -2,
        {
            {value="TOPLEFT",     label="Top Left"},
            {value="TOP",         label="Top"},
            {value="TOPRIGHT",    label="Top Right"},
            {value="LEFT",        label="Left"},
            {value="CENTER",      label="Center"},
            {value="RIGHT",       label="Right"},
            {value="BOTTOMLEFT",  label="Bottom Left"},
            {value="BOTTOM",      label="Bottom"},
            {value="BOTTOMRIGHT", label="Bottom Right"},
        },
        function() return Persona.db.itemSlots.upgradeLevel.insideAnchor or "TOPRIGHT" end,
        function(v) Persona.db.itemSlots.upgradeLevel.insideAnchor = v; Persona:RefreshAll() end)

    local outsideHolder = CreateFrame("Frame", nil, p)
    outsideHolder:SetPoint("TOPLEFT",  p, "TOPLEFT",  0, y)
    outsideHolder:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, y)
    outsideHolder:SetHeight(posRowH)
    Cycle(outsideHolder, "Position", -2,
        {
            {value="below", label="Below ilvl"},
            {value="above", label="Above ilvl  (moves down if enchant present)"},
            {value="right", label="Right  (clears gems)"},
            {value="left",  label="Left   (clears gems)"},
        },
        function() return Persona.db.itemSlots.upgradeLevel.outsideAnchor or "below" end,
        function(v) Persona.db.itemSlots.upgradeLevel.outsideAnchor = v; Persona:RefreshAll() end)

    _upgradePosRefresh = function()
        local isInside = Persona.db.itemSlots.upgradeLevel.position == "inside"
        insideHolder:SetShown(isInside)
        outsideHolder:SetShown(not isInside)
    end
    _upgradePosRefresh()

    y = y - posRowH

    -- ── Upgrade Colours ───────────────────────────────────────
    y = y - 6
    y = Header(p, "Upgrade Colours", y)

    local DEFAULTS = {
        Myth       = { r=0.90, g=0.80, b=0.50 },
        Hero       = { r=1.00, g=0.50, b=0.00 },
        Champion   = { r=0.64, g=0.21, b=0.93 },
        Veteran    = { r=0.00, g=0.44, b=0.87 },
        Adventurer = { r=0.12, g=1.00, b=0.00 },
        Explorer   = { r=0.62, g=0.62, b=0.62 },
    }

    -- Store swatch updaters so reset can refresh them all immediately
    local swatchUpdaters = {}

    local resetBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 20)
    resetBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 4, y)
    resetBtn:SetText("Reset to default")
    resetBtn:SetScript("OnClick", function()
        local cc = Persona.db.itemSlots.upgradeLevel.customColors
        for name, col in pairs(DEFAULTS) do
            cc[name] = { r=col.r, g=col.g, b=col.b }
        end
        -- Refresh every swatch immediately
        for _, fn in ipairs(swatchUpdaters) do fn() end
        Persona:RefreshAll()
    end)
    y = y - 26

    local TRACKS = { "Myth", "Hero", "Champion", "Veteran", "Adventurer", "Explorer" }
    for _, name in ipairs(TRACKS) do
        local lbl = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", p, "TOPLEFT", 8, y)
        lbl:SetText(name .. ":")
        lbl:SetTextColor(0.72, 0.72, 0.75)
        lbl:SetWidth(80)

        local swatch = CreateFrame("Button", nil, p, "BackdropTemplate")
        swatch:SetSize(60, 16)
        swatch:SetPoint("TOPLEFT", p, "TOPLEFT", 94, y)
        swatch:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8, insets = {left=2, right=2, top=2, bottom=2}
        })

        local capturedName = name
        local function UpdateSwatch()
            local cc = Persona.db.itemSlots.upgradeLevel.customColors[capturedName]
            if cc then swatch:SetBackdropColor(cc.r, cc.g, cc.b, 1) end
        end
        UpdateSwatch()
        table.insert(swatchUpdaters, UpdateSwatch)  -- register for reset

        swatch:SetScript("OnClick", function()
            local cc = Persona.db.itemSlots.upgradeLevel.customColors[capturedName]
            local prev = { r=cc.r, g=cc.g, b=cc.b }
            ColorPickerFrame:SetupColorPickerAndShow({
                r = cc.r, g = cc.g, b = cc.b,
                hasOpacity = false,
                swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    Persona.db.itemSlots.upgradeLevel.customColors[capturedName] = {r=r, g=g, b=b}
                    UpdateSwatch()
                    Persona:RefreshAll()
                end,
                cancelFunc = function()
                    Persona.db.itemSlots.upgradeLevel.customColors[capturedName] = prev
                    UpdateSwatch()
                    Persona:RefreshAll()
                end,
            })
        end)
        swatch:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Click to pick colour for " .. capturedName, 1, 1, 1)
            GameTooltip:Show()
        end)
        swatch:SetScript("OnLeave", GameTooltip_Hide)

        y = y - 22
    end

    tabPanels["slots"].child:SetHeight(math.abs(y) + 20)
end

-- ── Stats tab state ──────────────────────────────────────────
local statsFrameCache = {}   -- frames/regions to hide on rebuild
local rowMeta         = {}   -- [catTitle] = {{id,label,frame}, ...} for hit-testing
local BuildStats             -- forward declaration (referenced by drag widgets)

-- ── Drag-to-reorder widgets (created once, reused) ────────────
local dragGhost, dragInsert, dropCatcher, dragTracker
local dragState   = { active=false }
local FinalizeDrop  -- set by InitDragWidgets, used by row OnMouseUp

local function InitDragWidgets()
    if dragGhost then return end

    -- Floating label that follows the cursor
    dragGhost = CreateFrame("Frame", nil, UIParent)
    dragGhost:SetFrameStrata("TOOLTIP")
    dragGhost:SetSize(220, ROW_H)
    dragGhost:Hide()
    local gb = dragGhost:CreateTexture(nil, "BACKGROUND")
    gb:SetAllPoints(); gb:SetColorTexture(0.10, 0.07, 0.20, 0.92)
    dragGhost.lbl = dragGhost:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dragGhost.lbl:SetPoint("LEFT", dragGhost, "LEFT", 6, 0)
    dragGhost.lbl:SetTextColor(1, 0.9, 0.4)

    -- Yellow insert-bar shown between rows
    dragInsert = CreateFrame("Frame", nil, UIParent)
    dragInsert:SetFrameStrata("TOOLTIP")
    dragInsert:SetHeight(2)
    dragInsert:Hide()
    local ib = dragInsert:CreateTexture(nil, "ARTWORK")
    ib:SetAllPoints(); ib:SetColorTexture(1, 0.85, 0.2, 1)

    -- Full-screen mouse-up catcher so release anywhere outside works
    dropCatcher = CreateFrame("Frame", nil, UIParent)
    dropCatcher:SetAllPoints(UIParent)
    dropCatcher:SetFrameStrata("HIGH")
    dropCatcher:EnableMouse(true)
    dropCatcher:Hide()

    -- Per-frame tracker moves ghost + insert bar
    dragTracker = CreateFrame("Frame", nil, UIParent)
    dragTracker:Hide()
    dragTracker:SetScript("OnUpdate", function()
        if not dragState.active then dragTracker:Hide(); return end
        local cx, cy = GetCursorPosition()
        local scale  = UIParent:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale

        -- Move ghost 12px right, 9px down from cursor tip
        dragGhost:ClearAllPoints()
        dragGhost:SetPoint("LEFT", UIParent, "BOTTOMLEFT", cx + 12, cy - 9)

        -- Hit-test: find insertion index in this category
        local meta = dragState.catTitle and rowMeta[dragState.catTitle]
        if not meta or #meta == 0 then return end

        local dstIdx = #meta   -- default: after last
        for i, m in ipairs(meta) do
            if m.frame and m.frame:IsShown() then
                local top = m.frame:GetTop()
                -- cursor above mid of row i → insert before it
                if top and cy > top - ROW_H * 0.5 then
                    dstIdx = i - 1; break
                end
            end
        end
        dragState.dstIdx = dstIdx

        -- Anchor insert bar
        if dstIdx <= 0 then
            local f = meta[1] and meta[1].frame
            if f and f:IsShown() then
                dragInsert:ClearAllPoints()
                dragInsert:SetPoint("LEFT",  f, "TOPLEFT",  4, 0)
                dragInsert:SetPoint("RIGHT", f, "TOPRIGHT", -4, 0)
                dragInsert:Show()
            end
        elseif dstIdx >= #meta then
            local f = meta[#meta] and meta[#meta].frame
            if f and f:IsShown() then
                dragInsert:ClearAllPoints()
                dragInsert:SetPoint("LEFT",  f, "BOTTOMLEFT",  4, 0)
                dragInsert:SetPoint("RIGHT", f, "BOTTOMRIGHT", -4, 0)
                dragInsert:Show()
            end
        else
            local f = meta[dstIdx] and meta[dstIdx].frame
            if f and f:IsShown() then
                dragInsert:ClearAllPoints()
                dragInsert:SetPoint("LEFT",  f, "BOTTOMLEFT",  4, 0)
                dragInsert:SetPoint("RIGHT", f, "BOTTOMRIGHT", -4, 0)
                dragInsert:Show()
            end
        end
    end)

    -- Finalise drop: compute new order, update DB, refresh everything
    FinalizeDrop = function()
        if not dragState.active then return end
        dragState.active = false
        dragGhost:Hide(); dragInsert:Hide()
        dropCatcher:Hide(); dragTracker:Hide()

        local src = dragState.srcIdx
        local dst = dragState.dstIdx
        if not src or dst == nil or dst == src or dst == src - 1 then return end

        local order = Persona.db.stats.statOrder
                  and Persona.db.stats.statOrder[dragState.catTitle]
        if not order then return end

        local item = tremove(order, src)
        -- After removal indices shift: dst > src means dst was already past src
        local insertAt = (dst > src) and dst or (dst + 1)
        insertAt = math.max(1, math.min(insertAt, #order + 1))
        table.insert(order, insertAt, item)

        if Persona.Stats then Persona.Stats:Update() end
        builtTabs["stats"] = false
        if activeTab == "stats" then
            BuildStats()
            builtTabs["stats"] = true
        end
    end
    dropCatcher:SetScript("OnMouseUp", FinalizeDrop)
end

BuildStats = function()
    InitDragWidgets()

    -- Hide all objects (frames + regions) from previous build
    for _, f in ipairs(statsFrameCache) do
        if f and f.Hide then f:Hide() end
    end
    statsFrameCache = {}
    rowMeta = {}

    local p = tabPanels["stats"].child
    local y = -6

    y = Header(p, "Appearance", y)
    _, y = Check(p, "Use Class Colour  (off = Persona purple)", y,
        function() return Persona.db.stats.classBackground end,
        function(v)
            Persona.db.stats.classBackground = v
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
    y = Cycle(p, "Value Display", y,
        {
            {value="percent", label="Percent  (e.g. 15.23%)"},
            {value="raw",     label="Rating   (e.g. 1,234)"},
            {value="raw_pct", label="Rating + Percent"},
        },
        function() return Persona.db.stats.displayStyle or "percent" end,
        function(v)
            Persona.db.stats.displayStyle = v
            if Persona.Stats then Persona.Stats:UpdateValues() end
        end)

    -- Per-stat rows: visibility toggle + drag-to-reorder handle
    local GROUPS = {
        { title = "Primary Stats",
          stats = {
            {id="strength",   label="Strength"},
            {id="agility",    label="Agility"},
            {id="intellect",  label="Intellect"},
            {id="stamina",    label="Stamina"},
        }},
        { title = "Defense",
          stats = {
            {id="armor",     label="Armor"},
            {id="dodge",     label="Dodge"},
            {id="parry",     label="Parry"},
            {id="block",     label="Block"},
            {id="stagger",   label="Stagger"},
        }},
        { title = "Offense",
          stats = {
            {id="ap",          label="Attack Power"},
            {id="sp",          label="Spell Power"},
            {id="crit",        label="Crit Chance"},
            {id="dmg_mh",      label="Damage (MH)"},
            {id="dmg_oh",      label="Damage (OH)"},
            {id="weapon_dps",  label="Weapon DPS (MH)"},
            {id="dps_oh",      label="Weapon DPS (OH)"},
            {id="melee_speed", label="Attack Speed (MH)"},
            {id="speed_oh",    label="Attack Speed (OH)"},
            {id="haste",       label="Haste"},
            {id="mastery",     label="Mastery"},
        }},
        { title = "Misc",
          stats = {
            {id="speed",  label="Move Speed"},
            {id="gcd",    label="Global Cooldown"},
            {id="leech",  label="Leech"},
            {id="avoid",  label="Avoidance"},
        }},
    }

    local function GetOrder(catTitle, stats)
        local db = Persona.db.stats.statOrder
        if not db[catTitle] then db[catTitle] = {} end
        local order = db[catTitle]
        if #order == 0 then
            for _, st in ipairs(stats) do order[#order+1] = st.id end
        else
            local inOrder = {}
            for _, id in ipairs(order) do inOrder[id] = true end
            for _, st in ipairs(stats) do
                if not inOrder[st.id] then order[#order+1] = st.id end
            end
        end
        return order
    end

    for _, grp in ipairs(GROUPS) do
        y = y - 6
        y = Header(p, grp.title, y)
        local order = GetOrder(grp.title, grp.stats)

        local byId = {}
        for _, st in ipairs(grp.stats) do byId[st.id] = st end

        rowMeta[grp.title] = {}

        for listIdx, id in ipairs(order) do
            local st = byId[id]
            if st then
                local ROW_Y = y

                -- Row container frame (used for hit-testing drag position)
                local rowFrame = CreateFrame("Frame", nil, p)
                rowFrame:SetHeight(ROW_H)
                rowFrame:SetPoint("TOPLEFT",  p, "TOPLEFT",  0, ROW_Y)
                rowFrame:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, ROW_Y)
                rowFrame:EnableMouse(true)

                -- Hover highlight texture (auto-shown by WoW on mouse-over)
                local hl = rowFrame:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetColorTexture(0.55, 0.40, 0.85, 0.18)

                -- Visibility checkbox
                local cb = CreateFrame("CheckButton", nil, rowFrame, "UICheckButtonTemplate")
                cb:SetSize(18, 18)
                cb:SetPoint("LEFT", rowFrame, "LEFT", 4, 0)
                cb:SetChecked(not (Persona.db.stats.hiddenStats
                                   and Persona.db.stats.hiddenStats[st.id]))

                local lbl = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                lbl:SetPoint("LEFT", cb, "RIGHT", 3, 0)
                lbl:SetText(st.label)
                lbl:SetTextColor(0.82, 0.82, 0.85)

                -- Hover: tint label warm yellow (lbl must be declared first)
                rowFrame:SetScript("OnEnter", function()
                    lbl:SetTextColor(1, 0.95, 0.6)
                end)
                rowFrame:SetScript("OnLeave", function()
                    lbl:SetTextColor(0.82, 0.82, 0.85)
                end)

                local capturedId    = st.id
                local capturedTitle = grp.title
                local capturedStats = grp.stats

                cb:SetScript("OnClick", function(self)
                    Persona.db.stats.hiddenStats = Persona.db.stats.hiddenStats or {}
                    if not not self:GetChecked() then
                        Persona.db.stats.hiddenStats[capturedId] = nil
                    else
                        Persona.db.stats.hiddenStats[capturedId] = true
                    end
                    if Persona.Stats then Persona.Stats:Update() end
                end)

                -- Whole row is draggable
                local capturedIdx = listIdx
                rowFrame:SetScript("OnMouseDown", function(_, btn)
                    if btn ~= "LeftButton" then return end
                    if not Persona.db.stats.statOrder then return end
                    local liveOrder = GetOrder(capturedTitle, capturedStats)
                    local liveIdx = capturedIdx
                    for i, v in ipairs(liveOrder) do
                        if v == capturedId then liveIdx = i; break end
                    end
                    dragState.active   = true
                    dragState.id       = capturedId
                    dragState.catTitle = capturedTitle
                    dragState.srcIdx   = liveIdx
                    dragState.dstIdx   = liveIdx
                    dragGhost.lbl:SetText(st.label)
                    dragGhost:Show()
                    dragTracker:Show()
                    dropCatcher:Show()
                end)
                rowFrame:SetScript("OnMouseUp", function(_, btn)
                    if btn ~= "LeftButton" then return end
                    if FinalizeDrop then FinalizeDrop() end
                end)

                -- Track this row for drop hit-testing
                rowMeta[grp.title][#rowMeta[grp.title]+1] = {
                    id    = st.id,
                    label = st.label,
                    frame = rowFrame,
                }

                y = y - ROW_H
            end  -- if st
        end
    end

    tabPanels["stats"].child:SetHeight(math.abs(y) + 20)
    -- Record all frames + regions for next rebuild
    for _, f in ipairs({p:GetChildren()}) do
        statsFrameCache[#statsFrameCache+1] = f
    end
    for _, r in ipairs({p:GetRegions()}) do
        statsFrameCache[#statsFrameCache+1] = r
    end
end

local vaultFrameCache = {}

local function BuildVault()
    for _, f in ipairs(vaultFrameCache) do if f and f.Hide then f:Hide() end end
    vaultFrameCache = {}
    local p = tabPanels["vault"].child
    local y = -6

    y = Header(p, "Great Vault  (shown in Stats pane)", y)
    _, y = Check(p, "Show vault section", y,
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

    y = Header(p, "Rows", y)

    -- Row definitions matching Stats.lua VAULT_ROWS
    local ROWS = {
        { key="dungeons", label="Dungeons" },
        { key="raids",    label="Raids"    },
        { key="world",    label="World"    },
    }

    local function GetVaultOrder()
        local db    = Persona.db.vault
        local order = db.vaultRowOrder
        if not order or #order == 0 then
            db.vaultRowOrder = {}
            for _, r in ipairs(ROWS) do db.vaultRowOrder[#db.vaultRowOrder+1] = r.key end
            order = db.vaultRowOrder
        end
        local inOrder = {}
        for _, k in ipairs(order) do inOrder[k] = true end
        for _, r in ipairs(ROWS) do
            if not inOrder[r.key] then order[#order+1] = r.key end
        end
        return order
    end

    local function MoveVaultRow(key, dir)
        local order = GetVaultOrder()
        local idx
        for i, k in ipairs(order) do if k == key then idx = i; break end end
        if not idx then return end
        local swap = idx + dir
        if swap < 1 or swap > #order then return end
        order[idx], order[swap] = order[swap], order[idx]
        if Persona.Stats then Persona.Stats:Update() end
    end

    local byKey = {}
    for _, r in ipairs(ROWS) do byKey[r.key] = r end

    local order = GetVaultOrder()
    for listIdx, key in ipairs(order) do
        local r = byKey[key]
        if r then
            local capturedKey = key

            -- Checkbox
            local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
            cb:SetSize(18, 18)
            cb:SetPoint("TOPLEFT", p, "TOPLEFT", 4, y)
            local hidden = Persona.db.vault.hiddenVaultRows
            cb:SetChecked(not (hidden and hidden[key]))

            local lbl = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("LEFT", cb, "RIGHT", 3, 0)
            lbl:SetText(r.label)
            lbl:SetTextColor(0.82, 0.82, 0.85)

            cb:SetScript("OnClick", function(self)
                Persona.db.vault.hiddenVaultRows = Persona.db.vault.hiddenVaultRows or {}
                Persona.db.vault.hiddenVaultRows[capturedKey] = not not not self:GetChecked()
                if Persona.Stats then Persona.Stats:Update() end
            end)

            -- ▲ button
            local btnUp = CreateFrame("Button", nil, p)
            btnUp:SetSize(14, 14)
            btnUp:SetPoint("TOPRIGHT", p, "TOPRIGHT", -20, y)
            local arUp = btnUp:CreateTexture(nil, "ARTWORK")
            arUp:SetAllPoints()
            arUp:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
            btnUp:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
            local capturedIdx = listIdx
            btnUp:SetScript("OnClick", function()
                MoveVaultRow(capturedKey, -1)
                builtTabs["vault"] = false
                if activeTab == "vault" then BuildVault(); builtTabs["vault"] = true end
            end)

            -- ▼ button
            local btnDn = CreateFrame("Button", nil, p)
            btnDn:SetSize(14, 14)
            btnDn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -4, y)
            local arDn = btnDn:CreateTexture(nil, "ARTWORK")
            arDn:SetAllPoints()
            arDn:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
            btnDn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
            btnDn:SetScript("OnClick", function()
                MoveVaultRow(capturedKey, 1)
                builtTabs["vault"] = false
                if activeTab == "vault" then BuildVault(); builtTabs["vault"] = true end
            end)

            y = y - ROW_H
        end
    end

    tabPanels["vault"].child:SetHeight(math.abs(y) + 20)
    for _, f in ipairs({tabPanels["vault"].child:GetChildren()}) do
        vaultFrameCache[#vaultFrameCache+1] = f
    end
    for _, r in ipairs({tabPanels["vault"].child:GetRegions()}) do
        vaultFrameCache[#vaultFrameCache+1] = r
    end
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
