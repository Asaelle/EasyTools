# EasyTools

**EasyTools** is a specialized toolkit designed for **developers, testers, and power users** in World of Warcraft.

Its primary purpose is to expose hidden game engine data such as internal IDs, spawn timers, and raw quest events directly in the interface. By providing precise logging and coordinate tracking, it serves as an essential utility for debugging, data mining, and verifying game mechanics.

## Key Capabilities

### 🔍 Deep Data Inspection (IDs)

Instantly view internal database IDs in tooltips without external websites. Essential for distinguishing between different versions of items or spells.

- **Core IDs:** `ItemId`, `SpellId`, `CreatureId`, `QuestId`, `AchievementId`, `CurrencyId`, `MountId`.
- **Item Data:** `BonusId`, `GemId`, `EnchantId`.
- **Talent Data:** `TraitNodeId`, `TraitEntryId`, `TraitDefinitionId`.
- **Context:** Displays the source context (e.g., `28 (World Quest 4)`).

### ⏱️ Precision Timing

- **NPC Alive Time:** Displays exactly how long an NPC has been alive (including spawn time) in the tooltip.
- **Minimap Seconds:** Adds a "seconds" display to the minimap clock (e.g., `11:22:35`) for precise event timing.

### 📜 Quest Debugging & Logging

A complete suite for tracking quest states and locations.

- **Visual IDs:** Injects `[QuestID]` into the Objective Tracker, Quest Log, and NPC Dialogs.
- **Event Announcements:** Color-coded chat alerts for quest state changes:
  - **Accepted** (Cyan)
  - **Completed** (Green)
  - **Removed** (Red)
  - **Unflagged** (Orange)
- **Persistent Logging:** Automatically records all quest activity to `SavedVariables` with granular data:
  `Timestamp; QuestID; Name; Status; MapZone; X-Coord; Y-Coord`

## Configuration & Usage

### SavedVariables

Quest history is stored in `EasyToolsDB.QuestLog` in the following format:

```
"2025-12-07 23:02:35;83105;Rush-order Requisition;accepted;Dornogal;53.0;52.5"
```

## Installation

1. Copy the `EasyTools` folder to your `World of Warcraft/_retail_/Interface/AddOns/` directory
2. Restart WoW or reload UI (`/reload`)

## Compatibility

- **Interface**: 11.0.0+ (The War Within)
- **Retail only** (no Classic support)

## Credits

Based on:

- **idTip** - ID tooltip display
- **NPCTime** - NPC alive time
- **QuestsChanged** - Quest tracking
- **AllTheThings** - Quest name retrieval and dual-step completion detection

## File Structure

```
EasyTools/
├── Defines.lua          # Global defines
├── Utils.lua            # Global set of utility functions
├── Settings.lua         # Settings file for addon options
├── EasyTools.toc        # Addon metadata
├── EasyTools.lua        # Main addon logic
├── README.md            # This file
└── Modules/
    ├── TooltipID.lua    # Tooltip IDs
    └── QuestId.lua      # Quest IDs
    └── ...
    └── ...
```
