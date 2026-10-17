local _, Addon = ...

BINDING_HEADER_FOREVERMACROS = "ForeverMacro"

Addon.modes = {
    { key = "normal", label = "Normal cast" },
    { key = "self", label = "Self cast (on yourself)" },
    { key = "mouseover", label = "Mouseover" },
    { key = "focus", label = "Focus" },
}

function Addon.Trim(text)
    return (text or ""):match("^%s*(.-)%s*$")
end

-- Do not cut a UTF-8 code point in half when shortening macro names.
function Addon.ShortName(text, limit)
    local count = 0
    for position in text:gmatch("()[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > limit then
            return text:sub(1, position - 1)
        end
    end
    return text
end

function Addon.BuildBody(spell, mode, fallback, options)
    options = options or {}
    if not spell or not spell.name or Addon.Trim(spell.name) == ""
        or spell.name:find("[%c%[%];/]") then
        return nil, "The spell does not have a valid name."
    end
    local condition = ""
    if mode == "self" then
        if spell.helpful == false then
            return nil, "Self cast requires a spell that can target friendly units."
        end
        condition = "[@player] "
    elseif mode == "mouseover" or mode == "focus" then
        local filter = "exists"
        if spell.helpful and not spell.harmful then
            filter = "help"
        elseif spell.harmful and not spell.helpful then
            filter = "harm"
        end
        condition = "[@" .. mode .. "," .. filter
        if options.alive ~= false then condition = condition .. ",nodead" end
        condition = condition .. "]"
        if fallback then
            condition = condition .. "[]"
        end
        condition = condition .. " "
    elseif mode ~= "normal" then
        return nil, "Unknown macro option."
    end
    local body = "/cast " .. condition .. spell.name
    if options.tooltip ~= false then body = "#showtooltip " .. spell.name .. "\n" .. body end
    if #body > 255 then
        return nil, "The macro exceeds 255 bytes."
    end
    return body
end

function Addon.MacroLimits()
    local limits = Constants and Constants.MacroConsts
    return (limits and limits.MAX_ACCOUNT_MACROS) or MAX_ACCOUNT_MACROS or 120,
        (limits and limits.MAX_CHARACTER_MACROS) or MAX_CHARACTER_MACROS or 18
end

-- Only create new macros. Never edit or delete an existing macro.
function Addon.SaveMacro(requestedName, body, perCharacter)
    if InCombatLockdown() then
        return nil, "Macros can only be created out of combat."
    end
    if Addon.creationBlocked then
        return nil, "The client blocked macro creation. Copy the preview into /macro."
    end
    if not CreateMacro or not GetNumMacros or not GetMacroInfo then
        return nil, "The macro creation API is unavailable. Copy the text into /macro."
    end
    local name = Addon.Trim(requestedName)
    if name == "" or name:find("[%c]") then
        return nil, "Enter a macro name without control characters."
    end
    if not body or body == "" or #body > 255 then
        return nil, "The macro body must contain 1-255 bytes."
    end
    local accountMax, characterMax = Addon.MacroLimits()
    local accountCount, characterCount = GetNumMacros()
    local offset = perCharacter and accountMax or 0
    local count = perCharacter and characterCount or accountCount
    local maximum = perCharacter and characterMax or accountMax
    local names = {}
    for index = 1, accountMax + characterMax do
        local oldName, _, oldBody = GetMacroInfo(index)
        if oldName then
            names[oldName] = true
            if index > offset and index <= offset + maximum and oldBody == body then
                return index, nil, true
            end
        end
    end
    if count >= maximum then
        return nil, "The selected macro list is full. Free a slot or choose the other list."
    end
    local base = Addon.ShortName(name, 16)
    name = base
    local suffix = 2
    while names[name] do
        local ending = " " .. suffix
        name = Addon.ShortName(base, 16 - #ending) .. ending
        suffix = suffix + 1
    end
    local ok, index = pcall(CreateMacro, name, 134400, body, perCharacter)
    if not ok or type(index) ~= "number" or index < 1 then
        return nil, "The client could not create the macro. Copy the preview into /macro."
    end
    local savedName, _, savedBody = GetMacroInfo(index)
    if not savedName or savedBody ~= body then
        return nil, "Could not verify the macro. Check /macro before trying again."
    end
    return index
end
