local _, Addon = ...
local panel, selectedSpell, savedIndex
local Refresh

local function Label(parent, text, x, y, width, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

local function Status(text)
    panel.status:SetText(text or "")
end

local function Button(text, x, y, width, callback)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", x, y)
    button:SetSize(width, 24)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

local function Check(text, x, y, checked)
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", x, y)
    check:SetSize(26, 26)
    Label(check, text, 29, -6, 500)
    check:SetChecked(checked)
    check:SetScript("OnClick", function() Refresh() end)
    return check
end

local function TextArea(x, y, width, height)
    local box = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    box:SetPoint("TOPLEFT", x, y)
    box:SetSize(width, height)
    box:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
    box:SetBackdropColor(0, 0, 0, 0.65)
    local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -29, 8)
    local text = CreateFrame("EditBox", nil, scroll)
    text:SetWidth(width - 47)
    text:SetHeight(height - 16)
    text:SetMultiLine(true)
    text:SetFontObject("GameFontHighlightSmall")
    text:SetAutoFocus(false)
    text:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    text:SetScript("OnTextChanged", function(self)
        -- Leave enough scrollable space even when a long preview wraps.
        self:SetHeight(math.max(height - 16, #self:GetText() * 0.8))
    end)
    scroll:SetScrollChild(text)
    return text
end

Refresh = function()
    savedIndex = nil
    panel.pickup:Disable()
    panel.tooltip:SetEnabled(not not panel.cast:GetChecked())
    local body, err = Addon.BuildTargetBody(panel.targets:GetText(), selectedSpell, {
        cast = panel.cast:GetChecked(), exact = panel.exact:GetChecked(), tooltip = panel.tooltip:GetChecked(),
    })
    panel.body = body
    panel.preview:SetText(body or "")
    panel.bytes:SetText(tostring(body and #body or 0) .. "/255 bytes")
    panel.update:SetEnabled(body ~= nil and not InCombatLockdown() and not Addon.creationBlocked)
    Status(err or "Update replaces the entire character macro named FM Target. Other macros are unchanged.")
end

local function SetSpell(spell)
    if spell then
        selectedSpell = spell
        panel.spell:SetText(spell.name)
        panel.spell:ClearFocus()
    end
    Refresh()
end

local function EnsurePanel()
    if panel then return end
    panel = CreateFrame("Frame", "ForeverMacrosTargetFrame", UIParent, "BackdropTemplate")
    panel:SetSize(650, 640)
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
        insets = {left = 11, right = 12, top = 12, bottom = 11},
    })
    tinsert(UISpecialFrames, "ForeverMacrosTargetFrame")
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    Label(panel, "ForeverMacros - Target macro", 24, -22, 450, "GameFontNormalLarge")
    Button("Spell macros", 480, -19, 120, function() Addon.CloseTarget(); Addon.Open() end)
    panel.source = Label(panel, "Source: manual entry", 24, -57, 600)
    Button("Use current enemy", 24, -82, 175, function()
        local name = Addon.GetEnemyName("target")
        if name then
            Addon.OpenTarget({name}, "Enemy imported. Review the preview.", name)
        else
            Status("Select a living enemy first, or use the hover shortcut.")
        end
    end)
    Button("Load selected quest", 209, -82, 180, function()
        local id
        if C_QuestLog and C_QuestLog.GetSelectedQuest then
            local ok, value = pcall(C_QuestLog.GetSelectedQuest)
            if ok then id = value end
        end
        local names, message, title = Addon.GetQuestTargets(id)
        Addon.OpenTarget(names, message, title or "Selected quest")
    end)
    Label(panel, "Enemy names (one per line; each import replaces this list)", 24, -122, 600, "GameFontNormal")
    panel.targets = TextArea(24, -145, 602, 95)
    panel.targets:SetScript("OnTextChanged", function(self)
        self:SetHeight(math.max(79, #self:GetText() * 0.8))
        Refresh()
    end)
    panel.exact = Check("Match exact enemy names (/targetexact instead of /target)", 21, -246, true)
    panel.cast = Check("Cast a spell after targeting", 21, -274, true)
    Label(panel, "Spell name or ID", 24, -311, 600)
    panel.spell = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    panel.spell:SetPoint("TOPLEFT", 30, -332)
    panel.spell:SetSize(310, 24)
    panel.spell:SetAutoFocus(false)
    panel.spell:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    panel.spell:SetScript("OnTextChanged", function(_, userInput)
        if userInput then
            selectedSpell = nil
            Refresh()
            Status("Click Apply or press Enter to confirm the spell.")
        end
    end)
    local function Apply()
        local spell, err = Addon.ResolveSpell(panel.spell:GetText())
        if spell then SetSpell(spell) else Status(err) end
    end
    panel.spell:SetScript("OnEnterPressed", Apply)
    Button("Apply", 354, -332, 85, Apply)
    Button("Choose spell...", 449, -332, 177, function()
        panel:Hide()
        Addon.PickTargetSpell(function(spell)
            if InCombatLockdown() then return end
            panel:Show()
            SetSpell(spell)
        end)
    end)
    panel.tooltip = Check("Show the spell icon and tooltip (#showtooltip)", 21, -368, true)
    Label(panel, "Preview", 24, -406, 400, "GameFontNormal")
    panel.bytes = Label(panel, "", 535, -408, 90)
    panel.preview = TextArea(24, -429, 602, 95)
    panel.preview:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self:SetText(panel.body or "") end
        self:SetHeight(math.max(79, #self:GetText() * 0.8))
    end)
    panel.status = Label(panel, "", 24, -537, 602)
    panel.status:SetHeight(43)
    panel.status:SetJustifyV("TOP")
    panel.update = Button("Update FM Target", 24, -594, 185, function()
        local index, err = Addon.SaveTargetMacro(panel.body)
        if not index then Status(err); return end
        savedIndex = index
        panel.pickup:Enable()
        panel.update:Disable()
        Status("FM Target updated. Its previous targets and spell have been replaced.")
    end)
    panel.pickup = Button("Pick up macro", 219, -594, 185, function()
        if InCombatLockdown() or not savedIndex then return end
        local name, _, body = GetMacroInfo(savedIndex)
        if name ~= Addon.targetMacroName or body ~= panel.body then
            Refresh()
            Status("FM Target has changed. Update it again before picking it up.")
            return
        end
        if GetCursorInfo() then Status("Place or release the item on your cursor first."); return end
        PickupMacro(savedIndex)
    end)
    Button("Close", 414, -594, 212, function() panel:Hide() end)
    panel:SetScript("OnHide", function()
        panel.targets:ClearFocus()
        panel.spell:ClearFocus()
        panel.preview:ClearFocus()
    end)
    panel:Hide()
end

function Addon.OpenTarget(names, message, source)
    if InCombatLockdown() then print("ForeverMacros: open the target builder out of combat."); return end
    Addon.Close()
    EnsurePanel()
    panel:Show()
    if names then
        panel.source:SetText("Source: " .. (source or "Hover import"))
        panel.targets:SetText(table.concat(names, "\n"))
    end
    Refresh()
    if message then Status(message) end
end

function Addon.CloseTarget()
    if panel then panel:Hide() end
end

function Addon.TargetCreationBlocked()
    if panel and panel:IsShown() then
        panel.update:Disable()
        Status("The client blocked macro changes. Copy the preview into /macro.")
    end
end

function ForeverMacros_OpenTargetHovered()
    if InCombatLockdown() then print("ForeverMacros: import targets out of combat."); return end
    local names, message, source = Addon.ReadTargetHover()
    Addon.OpenTarget(names or {}, message or "Hover an enemy or quest and use the target hover shortcut.", source)
end
