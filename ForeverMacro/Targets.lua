local _, Addon = ...
Addon.targetMacroName = "FM Target"

local function Read(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if ok and not (issecretvalue and issecretvalue(value)) then return value end
end

function Addon.CleanTargetName(name)
    if type(name) ~= "string" or (issecretvalue and issecretvalue(name)) then return nil end
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    name = name:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|H.-|h(.-)|h", "%1")
    name = Addon.Trim(name)
    if name == "" or name:find("[%c%[%];/|]") then return nil end
    return name
end

-- Match the client's localized kill-objective format; only the name is captured.
local function ObjectivePattern(format)
    if type(format) ~= "string" then return nil end
    local pattern, position, captures = "^", 1, 0
    while position <= #format do
        local rest = format:sub(position)
        local token = rest:match("^%%[1-9]%$[sd]") or rest:match("^%%[sd]")
        if token then
            if token:sub(-1) == "s" then
                pattern, captures = pattern .. "(.-)", captures + 1
            else
                pattern = pattern .. "%d+"
            end
            position = position + #token
        elseif rest:sub(1, 2) == "%%" then
            pattern, position = pattern .. "%%", position + 2
        else
            local char = format:sub(position, position)
            if char:find("[%^%$%(%)%%%.%[%]%*%+%-%?]") then char = "%" .. char end
            pattern, position = pattern .. char, position + 1
        end
    end
    if captures ~= 1 then return nil end
    return pattern .. "$"
end

function Addon.ParseKillObjective(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local pattern = ObjectivePattern(QUEST_MONSTERS_KILLED)
    local name = pattern and text:match(pattern)
    -- Conservative English fallbacks, rather than treating arbitrary quest prose as a name.
    name = name or text:match("^(.-) slain:%s*%d+%s*/%s*%d+%s*$")
        or text:match("^(.-) killed:%s*%d+%s*/%s*%d+%s*$")
        or text:match("^(.-):%s*%d+%s*/%s*%d+%s*$")
    return name and Addon.CleanTargetName(name)
end

function Addon.GetQuestTargets(questID)
    local api = C_QuestLog
    if issecretvalue and issecretvalue(questID) then
        return {}, "The quest ID is restricted. Enter enemy names manually."
    end
    questID = tonumber(questID)
    if not questID or questID <= 0 then return {}, "Select or hover a quest first." end
    local objectives = Read(api and api.GetQuestObjectives, questID)
    local title = Read(api and api.GetTitleForQuestID, questID) or ("Quest " .. questID)
    if type(objectives) ~= "table" then
        return {}, "Quest objectives could not be read. Enter enemy names manually.", title
    end
    local names, seen, unresolved = {}, {}, 0
    for _, objective in ipairs(objectives) do
        if objective.type == "monster" and not objective.finished then
            local name = Addon.ParseKillObjective(objective.text)
            if name then
                if not seen[name] then names[#names + 1], seen[name] = name, true end
            else
                unresolved = unresolved + 1
            end
        end
    end
    local message = "Review the imported enemy names before updating FM Target."
    if #names == 0 then
        message = "No readable, unfinished kill objectives. Enter enemy names manually."
    elseif unresolved > 0 then
        message = "Some kill objectives could not be parsed. Review and complete the enemy list."
    end
    return names, message, title
end

local function QuestFromFrame(frame)
    for _ = 1, 12 do
        if not frame then return end
        local id = frame.questID or (type(frame.info) == "table" and frame.info.questID)
        if not id and frame.parentModule and frame.parentModule == QuestObjectiveTracker then id = frame.id end
        if type(id) == "number" and id > 0 then return id end
        frame = frame.parentBlock or (frame.GetParent and frame:GetParent())
    end
end

function Addon.GetHoveredQuestID()
    -- A protected/secret frame value is treated as unavailable, never guessed.
    local ok, id = pcall(function()
        local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
        for _, frame in ipairs(foci or {}) do
            local questID = QuestFromFrame(frame)
            if questID then return questID end
        end
        if GameTooltip and GameTooltip:IsShown() and GameTooltip.GetOwner then
            return QuestFromFrame(GameTooltip:GetOwner())
        end
    end)
    if ok and not (issecretvalue and issecretvalue(id)) then return id end
end

function Addon.GetEnemyName(unit)
    if Read(UnitExists, unit) and Read(UnitCanAttack, "player", unit)
        and not Read(UnitIsDeadOrGhost, unit) then
        return Addon.CleanTargetName(Read(UnitName, unit))
    end
end

function Addon.ReadTargetHover()
    local questID = Addon.GetHoveredQuestID()
    if questID then
        local names, message, title = Addon.GetQuestTargets(questID)
        return names, message, title
    end
    local name = Addon.GetEnemyName("mouseover")
    if name then return {name}, "Enemy imported. Choose a spell and review the preview.", name end
end

function Addon.BuildTargetBody(text, spell, options)
    options = options or {}
    local names, seen = {}, {}
    for line in ((text or "") .. "\n"):gmatch("(.-)\n") do
        line = line:gsub("\r$", "")
        if Addon.Trim(line) ~= "" then
            local name = Addon.CleanTargetName(line)
            if not name then return nil, "Use one enemy name per line, without macro commands or conditions." end
            if not seen[name] then names[#names + 1], seen[name] = name, true end
        end
    end
    if #names == 0 then return nil, "Enter at least one enemy name." end
    local lines = {}
    if options.cast then
        if spell and spell.harmful == false then
            return nil, "Choose a spell that can target enemies, or turn off the cast option."
        end
        local body, err = Addon.BuildBody(spell, "normal", false, {tooltip = false})
        if not body then return nil, err or "Choose a spell first." end
        if options.tooltip ~= false then lines[#lines + 1] = "#showtooltip " .. spell.name end
    end
    for _, name in ipairs(names) do
        lines[#lines + 1] = (options.exact == false and "/target " or "/targetexact ")
            .. "[noexists][dead] " .. name
    end
    if options.cast then lines[#lines + 1] = "/cast [@target,harm,nodead] " .. spell.name end
    local body = table.concat(lines, "\n")
    if #body > 255 then return nil, "The macro exceeds 255 bytes. Remove names or shorten the spell name." end
    return body
end

function Addon.SaveTargetMacro(body)
    if InCombatLockdown() then return nil, "Update FM Target out of combat." end
    if Addon.creationBlocked then return nil, "The client blocked macro changes. Copy the preview into /macro." end
    if type(body) ~= "string" or #body == 0 or #body > 255 then return nil, "No valid target macro to save." end
    if not GetMacroInfo or not GetNumMacros or not CreateMacro or not EditMacro then
        return nil, "The macro API is unavailable. Copy the preview into /macro."
    end
    local accountMax, characterMax = Addon.MacroLimits()
    local found
    for index = accountMax + 1, accountMax + characterMax do
        local name = GetMacroInfo(index)
        if name == Addon.targetMacroName then
            if found then return nil, "Multiple character macros named FM Target exist. Rename the duplicates first." end
            found = index
        end
    end
    local ok, index
    if found then
        -- Replace in one write, preserving the macro slot and action bar placement.
        ok, index = pcall(EditMacro, found, Addon.targetMacroName, 134400, body)
        index = ok and (index or found)
    else
        local _, count = GetNumMacros()
        if count >= characterMax then return nil, "Your character macro list is full. Free one slot for FM Target." end
        ok, index = pcall(CreateMacro, Addon.targetMacroName, 134400, body, true)
    end
    if not ok or type(index) ~= "number" then return nil, "The client could not update FM Target. Check /macro." end
    local savedName, _, savedBody = GetMacroInfo(index)
    if savedName ~= Addon.targetMacroName or savedBody ~= body then
        return nil, "Could not verify FM Target. Check /macro before trying again."
    end
    return index
end
