local _, Addon = ...
local panel, selectedSpell, createdIndex
local mode, spells, filtered, page = "normal", {}, {}, 1
local PAGE_SIZE = 10
local Refresh, RenderList, SelectSpell

local function Label(parent, text, x, y, width, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y)
    if width then label:SetWidth(width) end
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

local function Button(parent, text, x, y, width, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", x, y)
    button:SetSize(width, 24)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

local function Input(parent, x, y, width)
    local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    input:SetPoint("TOPLEFT", x, y)
    input:SetSize(width, 24)
    input:SetAutoFocus(false)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return input
end

local function Check(text, x, y, checked, callback)
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", x, y)
    check:SetSize(26, 26)
    -- Own label avoids relying on a template's optional Text member.
    Label(check, text, 29, -6, 370)
    check:SetChecked(checked)
    check:SetScript("OnClick", callback)
    return check
end

function Addon.SetStatus(text)
    if panel then panel.status:SetText(text or "") end
end

Refresh = function()
    createdIndex = nil
    panel.pickup:Disable()
    local conditional = mode == "mouseover" or mode == "focus"
    panel.fallback:SetEnabled(conditional)
    panel.alive:SetEnabled(conditional)
    for _, choice in ipairs(panel.choices) do
        choice:SetChecked(choice.mode == mode)
        choice:SetEnabled(choice.mode ~= "self" or not selectedSpell or selectedSpell.helpful ~= false)
    end
    local body, err
    if selectedSpell then
        body, err = Addon.BuildBody(selectedSpell, mode, panel.fallback:GetChecked(), {
            tooltip = panel.tooltip:GetChecked(), alive = panel.alive:GetChecked(),
        })
    end
    panel.body = body
    panel.preview:SetText(body or "")
    panel.preview:ClearFocus()
    panel.byteCount:SetText(tostring(body and #body or 0) .. "/255 bytes")
    panel.create:SetEnabled(body ~= nil and not InCombatLockdown() and not Addon.creationBlocked)
    Addon.SetStatus(err or (not selectedSpell and "Select a spell from the list or enter its name above."
        or selectedSpell.manual and "Manual name: check the spelling and targeting conditions."
        or "Select the preview and copy with Ctrl+C, or create the macro directly."))
end

SelectSpell = function(spell)
    selectedSpell = spell
    mode = "normal"
    panel.spellInput:SetText(spell.name)
    panel.spellInput:ClearFocus()
    panel.name:SetText(Addon.ShortName(spell.name, 16))
    panel.fallback:SetChecked(false)
    Refresh()
    RenderList()
end

RenderList = function()
    local query = Addon.Trim(panel.search:GetText()):lower()
    filtered = {}
    for _, spell in ipairs(spells) do
        if spell.name:lower():find(query, 1, true) then filtered[#filtered + 1] = spell end
    end
    local pages = math.max(1, math.ceil(#filtered / PAGE_SIZE))
    page = math.min(page, pages)
    for index, row in ipairs(panel.rows) do
        local spell = filtered[(page - 1) * PAGE_SIZE + index]
        row.spell = spell
        row:SetShown(spell ~= nil)
        if spell then
            row.icon:SetTexture(spell.icon or 134400)
            row.label:SetText((selectedSpell and spell.name == selectedSpell.name and "|cff60ff90" or "|cffffffff") .. spell.name .. "|r")
        end
    end
    panel.pages:SetText(page .. "/" .. pages .. "  (" .. #filtered .. ")")
    panel.previous:SetEnabled(page > 1)
    panel.next:SetEnabled(page < pages)
end

function Addon.RefreshSpellList()
    if not panel or not panel:IsShown() then return end
    local err
    spells, err = Addon.GetSpellList()
    RenderList()
    if err then Addon.SetStatus(err) end
end

local function EnsurePanel()
    if panel then return end
    panel = CreateFrame("Frame", "ForeverMacrosFrame", UIParent, "BackdropTemplate")
    panel:SetSize(800, 615)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    tinsert(UISpecialFrames, "ForeverMacrosFrame")
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    Label(panel, "ForeverMacros 0.2.1", 22, -21, nil, "GameFontNormalLarge")
    Label(panel, "1. Select a spell", 24, -59, nil, "GameFontNormal")
    Label(panel, "Search your learned spells", 24, -85)
    panel.search = Input(panel, 30, -106, 215)
    panel.search:SetScript("OnTextChanged", function() page = 1; RenderList() end)
    panel.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    Button(panel, "Refresh", 24, -141, 100, function() Addon.RefreshSpellList() end)
    panel.rows = {}
    for index = 1, PAGE_SIZE do
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(245, 29)
        row:SetPoint("TOPLEFT", 24, -178 - (index - 1) * 32)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(24, 24)
        row.icon:SetPoint("LEFT", 0, 0)
        row.label = Label(row, "", 30, -7, 210)
        row.label:SetWordWrap(false)
        row:SetScript("OnClick", function(self) if self.spell then SelectSpell(self.spell) end end)
        row:SetScript("OnEnter", function(self)
            if not self.spell or not self.spell.id then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spell.id)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        panel.rows[index] = row
    end
    panel.previous = Button(panel, "<", 24, -505, 40, function() page = page - 1; RenderList() end)
    panel.next = Button(panel, ">", 224, -505, 40, function() page = page + 1; RenderList() end)
    panel.pages = Label(panel, "", 82, -512, 135)
    Label(panel, "Missing a spell? Enter its name on the right.", 24, -548, 245)

    Label(panel, "2. Configure the macro", 305, -59, nil, "GameFontNormal")
    Label(panel, "Spell name or ID (manual entry is also supported)", 305, -85, 465)
    panel.spellInput = Input(panel, 311, -106, 330)
    local function ApplySpell()
        local spell, err = Addon.ResolveSpell(panel.spellInput:GetText())
        if spell then SelectSpell(spell) else Addon.SetStatus(err) end
    end
    panel.spellInput:SetScript("OnEnterPressed", ApplySpell)
    panel.spellInput:SetScript("OnTextChanged", function(_, userInput)
        if userInput then
            selectedSpell = nil
            Refresh()
            Addon.SetStatus("Click Apply or press Enter to confirm the spell name.")
        end
    end)
    Button(panel, "Apply", 655, -106, 115, ApplySpell)
    panel.choices = {}
    for index, option in ipairs(Addon.modes) do
        local choice = Check(option.label, 302, -142 - (index - 1) * 26, index == 1,
            function() mode = option.key; Refresh() end)
        choice.mode = option.key
        panel.choices[index] = choice
    end
    panel.fallback = Check("Fall back to normal cast if no valid target exists", 302, -252, false, Refresh)
    panel.alive = Check("Require a living mouseover/focus target", 302, -278, true, Refresh)
    panel.tooltip = Check("Show the spell icon and tooltip (#showtooltip)", 302, -304, true, Refresh)
    Label(panel, "Macro name (max. 16 characters)", 305, -344)
    panel.name = Input(panel, 311, -365, 195)
    panel.name:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    panel.name:SetScript("OnTextChanged", function(_, userInput) if userInput then Refresh() end end)
    panel.character = Check("This character only", 535, -363, true, Refresh)
    Label(panel, "3. Preview", 305, -408, nil, "GameFontNormal")
    panel.byteCount = Label(panel, "", 685, -410, 90)
    local box = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 305, -431)
    box:SetSize(465, 76)
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    box:SetBackdropColor(0, 0, 0, 0.65)
    local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -29, 8)
    panel.preview = CreateFrame("EditBox", nil, scroll)
    panel.preview:SetWidth(418)
    panel.preview:SetHeight(60)
    panel.preview:SetMultiLine(true)
    panel.preview:SetFontObject("GameFontHighlightSmall")
    panel.preview:SetAutoFocus(false)
    panel.preview:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self:SetText(panel.body or "") end
    end)
    panel.preview:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(panel.preview)
    panel.status = Label(panel, "", 305, -518, 465)
    panel.status:SetHeight(43)
    panel.status:SetJustifyV("TOP")
    panel.create = Button(panel, "Create macro", 305, -572, 130, function()
        local index, err, existing = Addon.SaveMacro(panel.name:GetText(), panel.body,
            not not panel.character:GetChecked())
        if not index then Addon.SetStatus(err); return end
        createdIndex = index
        panel.pickup:Enable()
        panel.create:Disable()
        Addon.SetStatus(existing and "The macro already exists. Pick it up to place it on your action bar."
            or "Macro created. Pick it up and place it on your action bar.")
    end)
    panel.pickup = Button(panel, "Pick up macro", 445, -572, 175, function()
        if InCombatLockdown() or not createdIndex then return end
        local _, _, body = GetMacroInfo(createdIndex)
        if body ~= panel.body then
            Refresh()
            Addon.SetStatus("The macro list has changed. Click Create macro again.")
            return
        end
        if GetCursorInfo() then
            Addon.SetStatus("Your cursor is already holding something. Place or release it first.")
            return
        end
        PickupMacro(createdIndex)
    end)
    Button(panel, "Close", 630, -572, 140, function() panel:Hide() end)
    panel:SetScript("OnHide", function()
        panel.search:ClearFocus()
        panel.spellInput:ClearFocus()
        panel.name:ClearFocus()
        panel.preview:ClearFocus()
    end)
    panel:Hide()
end

function Addon.Open(spell)
    if InCombatLockdown() then
        print("ForeverMacros: open the macro builder out of combat.")
        return
    end
    EnsurePanel()
    panel:Show()
    if spell then SelectSpell(spell) else Refresh() end
    Addon.RefreshSpellList()
end

function Addon.Close()
    if panel then panel:Hide() end
end

function Addon.ShowCreationBlocked()
    if panel and panel:IsShown() then
        panel.create:Disable()
        Addon.SetStatus("The client blocked macro creation. Copy the preview into /macro.")
    end
end
