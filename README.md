# ForeverMacros 0.2.1

A standalone macro builder for World of Warcraft: Forever. Type **`/fm`** to open it, select a spell, choose your targeting options, and review the live macro preview.

## What's new in 0.2.1

- Both shortcuts now belong to their own **ForeverMacro** category in Key Bindings, instead of Other.
- All addon labels, messages, help text, and documentation are in English.
- Existing binding action IDs and the addon folder name are unchanged, so existing key assignments can continue to work.

## Install or update

1. Close WoW completely so that new binding definitions are loaded on the next launch.
2. Extract the `ForeverMacros` folder into the Forever client's `Interface\AddOns` folder. When updating, replace the existing addon files.
3. Check that `ForeverMacros.toc` is directly inside `Interface\AddOns\ForeverMacros`, without another nested folder of the same name.
4. Start the game, enable the addon, and type `/fm`.

For the beta, an example path is `World of Warcraft\_classic_beta_\Interface\AddOns\ForeverMacros`. Use the client folder you actually play from.

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

The addon never edits or deletes existing macros. An identical macro body in the selected list is reused; conflicting names receive a number suffix. Macro names are shortened to 16 characters and bodies are limited to 255 bytes. Created macros are stored by the game. Builder options are not saved between sessions.

## Optional keyboard shortcuts

Open **Key Bindings > ForeverMacro** and assign a key to either action:

- **Open the macro builder**.
- **Build a macro from the spell under the cursor**.

For example, assign F7 if it is available. The addon does not automatically assign keys or change F6. The hover shortcut tries to read the visible spell tooltip. If it cannot read a spell, it opens the normal builder with a message instead. It does not cast the spell.

## Compatibility and testing

The TOC files target Interface `16001`, including a separate Camelot TOC. Use `/dump select(4, GetBuildInfo())` to check your client's Interface number.

The standalone builder in 0.2.0 was reported working in Forever by the user. Version 0.2.1 changes language and binding categorization; the updated category and translated layout still need an in-game check.

Automated Lua 5.1 tests with simulated WoW APIs cover file loading, `/fm` without a selected spell, all cast types, preview options, list filtering, manual entry, missing/failing APIs, duplicate macros, name conflicts, full macro lists, cursor pickup, hover opening, combat restrictions, and blocked macro creation. Package checks validate matching TOCs, binding XML and category configuration, English-only distributed source text, and archive integrity. Simulated tests do not replace testing in the client.

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

## Implementation references

- [API definitions exported from the Forever client](https://github.com/Atraeau/WoW-Addons/blob/main/types/WowForeverAPI.lua)
- [Forever development environment and TOC information](https://github.com/Atraeau/WoW-Addons)
- [Modern keybinding category name resolution in the game UI source mirror](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SettingsDefinitions_Frame/Keybindings.lua)

The Ctrl-click issue in 0.1.0 was not established to be a Blizzard restriction. Current versions do not overlay spellbook buttons or modify their click handlers.
