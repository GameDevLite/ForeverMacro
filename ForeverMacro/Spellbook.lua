local addonName, Addon = ...

local function Read(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if ok then return value end
end

function Addon.ResolveSpell(identifier)
    identifier = Addon.Trim(tostring(identifier or ""))
    if identifier == "" then return nil, "Enter a spell name or spell ID." end
    local id = tonumber(identifier)
    local info = Read(C_Spell and C_Spell.GetSpellInfo, id or identifier)
    if info then
        id = info.spellID or id
        if Read(C_Spell and C_Spell.IsSpellPassive, id or identifier) then
            return nil, "Passive spells cannot be cast using a macro."
        end
        return {
            id = id, name = info.name, icon = info.iconID,
            helpful = Read(C_Spell and C_Spell.IsSpellHelpful, id or identifier),
            harmful = Read(C_Spell and C_Spell.IsSpellHarmful, id or identifier),
        }
    end
    if id then return nil, "Could not read the spell ID. Try the exact spell name instead." end
    if identifier:find("[%c%[%];/]") then return nil, "Enter only the spell name." end
    return { name = identifier, manual = true }
end

function Addon.GetSpellList()
    local spells, seen = {}, {}
    local api = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
    if not api or bank == nil or spellType == nil then
        return spells, "The spell list is unavailable. Enter the spell name manually on the right."
    end
    local count = Read(api.GetNumSpellBookSkillLines)
    if type(count) ~= "number" then
        return spells, "Could not read the spell list. Enter the spell name manually on the right."
    end
    for lineIndex = 1, count do
        local line = Read(api.GetSpellBookSkillLineInfo, lineIndex)
        if line and not line.offSpecID and not line.shouldHide then
            for slot = (line.itemIndexOffset or 0) + 1,
                (line.itemIndexOffset or 0) + (line.numSpellBookItems or 0) do
                local item = Read(api.GetSpellBookItemInfo, slot, bank)
                if item and item.itemType == spellType and not item.isPassive and not item.isOffSpec
                    and item.spellID and item.name and not seen[item.name] then
                    seen[item.name] = true
                    spells[#spells + 1] = {
                        id = item.spellID, name = item.name, icon = item.iconID,
                        helpful = Read(api.IsSpellBookItemHelpful, slot, bank),
                        harmful = Read(api.IsSpellBookItemHarmful, slot, bank),
                    }
                end
            end
        end
    end
    table.sort(spells, function(a, b) return a.name:lower() < b.name:lower() end)
    if #spells == 0 then return spells, "No spells found. You can enter the spell name manually." end
    return spells
end

function ForeverMacros_OpenBuilder()
    Addon.Open()
end

function ForeverMacros_OpenHovered()
    if InCombatLockdown() then
        print("ForeverMacros: open the macro builder out of combat.")
        return
    end
    if GameTooltip and GameTooltip:IsShown() and GameTooltip.GetSpell then
        local ok, name, id = pcall(GameTooltip.GetSpell, GameTooltip)
        if ok and (id or name) then
            local spell = Addon.ResolveSpell(id or name)
            if spell then Addon.Open(spell); return end
        end
    end
    Addon.Open()
    Addon.SetStatus("Could not read a spell under the cursor. Select one from the list or enter its name.")
end

BINDING_NAME_FOREVERMACROS_OPEN = "Open the macro builder"
BINDING_NAME_FOREVERMACROS_HOVER = "Build a macro from the spell under the cursor"

local controller = CreateFrame("Frame")
controller:RegisterEvent("PLAYER_REGEN_DISABLED")
controller:RegisterEvent("SPELLS_CHANGED")
controller:RegisterEvent("ADDON_ACTION_FORBIDDEN")
controller:RegisterEvent("ADDON_ACTION_BLOCKED")
controller:SetScript("OnEvent", function(_, event, source, action)
    if event == "PLAYER_REGEN_DISABLED" then
        Addon.Close()
    elseif event == "SPELLS_CHANGED" then
        Addon.RefreshSpellList()
    elseif source == addonName and type(action) == "string"
        and (action:find("CreateMacro", 1, true) or action:find("EditMacro", 1, true)) then
        Addon.creationBlocked = true
        Addon.ShowCreationBlocked()
    end
end)

SLASH_FOREVERMACROS1 = "/fm"
SLASH_FOREVERMACROS2 = "/forevermacros"
SlashCmdList.FOREVERMACROS = function(message)
    message = Addon.Trim(message)
    if message == "help" then
        print("ForeverMacros 0.2.1: /fm opens the macro builder. /fm SpellName selects a spell.")
        print("Assign a key under Key Bindings > ForeverMacro for the hover shortcut.")
        return
    end
    if message ~= "" then
        local spell, err = Addon.ResolveSpell(message)
        Addon.Open(spell)
        if err then Addon.SetStatus(err) end
    else
        Addon.Open()
    end
end
