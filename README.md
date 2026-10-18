# ForeverMacros 0.3.0

A standalone macro builder for World of Warcraft: Forever. Type **`/fm`** to open it, select a spell, choose your targeting options, and review the live macro preview.

## What's new in 0.3.0

- Build a reusable **FM Target** character macro from a hovered enemy or quest's unfinished kill objectives.
- Review and edit enemy names, choose a spell from the existing spell list, and preview the complete macro before saving.
- Updating **FM Target** replaces its old names and spell in place, preserving the macro slot used by your action bar.
- The existing hover shortcut now supports spells, enemies, and quests. A separate target-only hover shortcut is also available under **ForeverMacro** in Key Bindings.
- All interface text and documentation remain in English. Existing binding action IDs are unchanged.

## Install or update

1. Close WoW completely so that new binding definitions are loaded on the next launch.
2. Extract the `ForeverMacros` folder into the Forever client's `Interface\AddOns` folder. When updating, replace the existing addon files.
3. Check that `ForeverMacros.toc` is directly inside `Interface\AddOns\ForeverMacros`, without another nested folder of the same name.
4. Start the game, enable the addon, and type `/fm`.

For the beta, an example path is `World of Warcraft\_classic_beta_\Interface\AddOns\ForeverMacros`. Use the client folder you actually play from.

When installing from this repository, copy the **contents** of the repository's `ForeverMacro` source folder into your game's `Interface\AddOns\ForeverMacros` folder. The installed folder must match the `ForeverMacros.toc` filename. The repository folder itself can have any name.

## Build and update a target macro

1. Assign a key under **Key Bindings > ForeverMacro** to **Build a target macro from the hovered enemy or quest**, or reuse your existing general hover shortcut.
2. Hover a living enemy, a quest in the default quest log, or a quest header/objective in the default tracker, then press the key. This replaces the builder's previous enemy list with the new import.
3. Check the imported names. Each line must contain an enemy name, without progress counters or macro commands. You can correct names or enter them manually.
4. Choose whether to cast a spell after targeting. Enter a spell name/ID and click **Apply**, or click **Choose spell...** and select one from your spell list. Escape cancels the picker. The selected target spell is kept while importing a new list during the same session.
5. Review the preview, then click **Update FM Target**. The first update creates a character-specific macro named **FM Target**. Later updates replace that macro's entire body, including its previous targets and spell.
6. Click **Pick up macro** and place it on an action bar once. Subsequent updates reuse the same macro slot.

You can also open the target builder with `/fm target` or the **Target macro** button in the spell builder. **Use current enemy** imports your selected living enemy; **Load selected quest** imports the quest selected in the default quest log. `/fm target quest 123` imports the quest with that ID.

Example with two quest enemies and Shadow Word: Pain:

```text
#showtooltip Shadow Word: Pain
/cleartarget
/targetexact [noexists][dead] Young Wolf
/targetexact [noexists][dead] Forest Spider
/cast [@target,harm,nodead] Shadow Word: Pain
```

By default, exact-name matching uses `/targetexact`. Turn it off to use `/target` with partial-name matching. The macro clears your current target whenever you press it, then tries the names in order while there is no target or the target is dead. It casts only on a living hostile target. Targeting still follows the game's normal range and visibility rules; this is not a world-wide enemy search. If no matching living enemy is found, no spell is cast.

**Only the character macro named FM Target is replaced.** An account-wide macro with that name and ordinary spell macros are not modified. The name is reserved for this feature: rename any unrelated character macro called FM Target before using it. If duplicate character macros have that name, the addon asks you to rename the duplicates rather than choosing one arbitrarily. Importing or editing the preview never changes a saved macro until you click **Update FM Target**. A failed import does not erase the saved macro.

### Quest import limits

Quest import uses `C_QuestLog.GetQuestObjectives` and includes only unfinished `monster` objectives. It extracts names using the client's localized kill-objective format, with conservative English text fallbacks. Completed, item-collection, delivery, exploration, and other objective types are excluded.

The quest API supplies objective text, which is not always an exact NPC name. A group objective such as "Bandits slain" may refer to several differently named enemies. Review and correct these names, use partial matching deliberately, or hover the actual enemy instead. The addon has no external NPC/quest database and does not infer which creatures drop quest items. Unsupported or unreadable objectives show a message and allow manual entry. Third-party quest trackers are not guaranteed to expose compatible hover data.

Target updates and imports happen out of combat. The addon does not automatically rewrite the macro as quest progress changes. Import the quest again and update when you want a new list. Macros are limited to 255 bytes; if a quest has too many enemy names, remove some names or disable the tooltip/cast option. Oversized macros are rejected without changing the saved one.

## Build a macro

1. **Select a spell:** search and click a spell in the list on the left. Alternatively, enter its exact name or ID on the right and click **Apply** or press Enter.
2. **Choose a cast type:** normal, self, mouseover, or focus. Only one cast type can be selected at a time.
3. **Choose options:** fallback to normal cast, require a living mouseover/focus target, and include `#showtooltip`.
4. **Review the preview:** it updates immediately when an option changes. Select the text and press Ctrl+C to copy it.
5. Enter a macro name and choose character-specific or account-wide storage. Click **Create macro**, then **Pick up macro**, and place it on your action bar.

You can also open the builder with a spell selected: `/fm Shadow Word: Pain` or `/fm 589`. Type `/fm help` for command help.

If the spell list cannot be read, manual entry remains available. When a name cannot be verified, the builder asks you to check its spelling and targeting conditions. Enter spell names in your game client's language: the addon's interface is English, while generated macros use the localized spell names required by the client. After editing the spell field, confirm with **Apply** or Enter before creating the macro.

## Cast types and conditions

- **Normal cast:** `/cast SpellName`.
- **Self cast:** `[@player]`. Disabled when the API explicitly reports that the spell cannot target friendly units. For unverified manual names, make sure the spell can target yourself.
- **Mouseover:** `[@mouseover,harm,nodead]` for harmful spells and `help` for helpful spells. Uses `exists` when a spell supports both or its classification is unknown.
- **Focus:** the same target checks using `@focus`.

**Fallback is off by default.** Enabling it appends `[]`, allowing normal casting when the conditional target is invalid. This follows the game's normal targeting settings. Fallback does not check range or line of sight; an otherwise valid mouseover target outside spell range can still prevent the cast.

The living-target requirement and `#showtooltip` are enabled by default. Fallback and living-target checks apply only to mouseover/focus and are disabled for the other cast types.

Example: Shadow Word: Pain with mouseover and fallback:

```text
#showtooltip Shadow Word: Pain
/cast [@mouseover,harm,nodead][] Shadow Word: Pain
```

Ordinary spell macros never edit or delete existing macros. An identical spell macro body in the selected list is reused; conflicting names receive a number suffix. The separate target builder intentionally replaces the reserved **FM Target** character macro. Macro names are shortened to 16 characters and bodies are limited to 255 bytes. Created macros are stored by the game. Builder options are not saved between sessions.

## Optional keyboard shortcuts

Open **Key Bindings > ForeverMacro** and assign keys to these actions:

- **Open the macro builder**.
- **Build a macro from the hovered spell, enemy or quest**.
- **Build a target macro from the hovered enemy or quest**.

For example, assign F7 if it is available. The addon does not automatically assign keys or change F6. The general hover shortcut first checks for a quest, then a living hostile mouseover unit, then a spell tooltip. If none can be read, it opens the ordinary builder with a message. The target-only shortcut opens the target builder and clears its preview list if nothing readable is found. Neither shortcut executes a macro or casts a spell.

## Compatibility and testing

The TOC files target Interface `16001`, including a separate Camelot TOC. Use `/dump select(4, GetBuildInfo())` to check your client's Interface number.

The standalone spell builder was reported working in Forever by the user. The target builder, quest/enemy imports, and in-place target updates in 0.3.0 still need an in-game check.

Automated Lua 5.1 tests with simulated WoW APIs cover the existing spell builder plus localized kill-objective parsing, completed/non-kill objective filtering, enemy and quest hover paths, editable target previews, the spell picker, in-place replacement, character/account separation, duplicate target macros, and failed imports or API calls. Package checks validate matching TOCs, binding XML and category configuration, load order, and archive integrity. Simulated tests do not replace testing in the client.

Run the tests from the repository root using Python 3:

```text
python -m pip install -r tests/requirements.txt
python tests/run_tests.py
```

The list reads ordinary active player spells through `C_SpellBook`. Passive, future, and off-spec entries are excluded. Spells inside flyouts or outside these categories may be missing; enter their names manually. There is no separate rank selector. Macros use the spell name without a rank suffix.

The builder opens out of combat and closes when combat starts. Created macros then work as ordinary game macros. If macro creation is blocked by the client, copy the preview into `/macro` manually.

## Quick in-game check

Enable Lua errors with `/console scriptErrors 1`.

1. Type `/fm` and check that the interface and messages are in English.
2. Open Key Bindings and find **ForeverMacro**. Check both shortcut labels and any existing assignments.
3. Search for a spell, select it, and change each cast type and checkbox. The preview should update immediately.
4. Enter a spell name manually and confirm with Enter.
5. Create a macro, pick it up, and place it on your action bar. Check it under `/macro` as well.
6. Assign a free key to the hover shortcut and try it over a spell tooltip.
7. Enter combat with the builder open. It should close without errors.
8. Hover an enemy and press the target hover shortcut. Choose an offensive spell, update FM Target, and place it on an action bar.
9. Hover a quest with unfinished kill objectives. Review its imported names, update, and check that the same action bar macro now uses only the new names and spell.
10. Try a completed quest and a collection-only quest. No creature names should be invented and the saved macro should remain unchanged until a valid update.

## Implementation references

- [API definitions exported from the Forever client](https://github.com/Atraeau/WoW-Addons/blob/main/types/WowForeverAPI.lua)
- [Forever development environment and TOC information](https://github.com/Atraeau/WoW-Addons)
- [Modern keybinding category name resolution in the game UI source mirror](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SettingsDefinitions_Frame/Keybindings.lua)
- [Quest objective API definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua)
- [Default quest tracker block structure](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_QuestObjectiveTracker.lua)

The Ctrl-click issue in 0.1.0 was not established to be a Blizzard restriction. Current versions do not overlay spellbook buttons or modify their click handlers.
