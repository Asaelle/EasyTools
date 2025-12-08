# EasyTools

A World of Warcraft addon that combines multiple utility features for tracking IDs, NPC information, and quest events.

## Features

### ID Tooltip Display
Displays various IDs in tooltips when hovering over items, spells, NPCs, quests, achievements, etc.

- **ItemId**, **SpellId**, **CreatureId**, **QuestId**, **AchievementId**, **CurrencyId**, **MountId**, etc.
- **BonusId**, **GemId**, **EnchantId** for items
- **TraitNodeId**, **TraitEntryId**, **TraitDefinitionId** for talents
- **Context** with human-readable name (e.g., `28 (World Quest 4)`)

### NPC Alive Time
Shows how long an NPC has been alive in the tooltip, including spawn time.

### Minimap Clock with Seconds
Replaces the default minimap clock to display seconds when using local time (e.g., `11:22:35`). Respects your 12h/24h time format settings.

### Quest ID Display
- **Objective Tracker**: Displays `[QuestID]` before quest names in the tracker (under minimap)
- **Quest Log**: Shows QuestID in the top-right of the quest details panel
- **Quest Dialog**: Shows QuestID when accepting or turning in quests

### Quest Event Tracking
Announces quest events in chat:
- **Quest accepted** (cyan)
- **Quest complete** (green)
- **Quest removed** (red)
- **Quest unflagged** (orange)

Each announcement includes: QuestID, Quest Name, Map, and Coordinates.

### Quest Event Logging
All quest events are saved to `SavedVariables` for later review.

Format: `time;questID;name;type;map;x;y`

Example:
```
"2025-12-07 23:02:35;83105;Rush-order Requisition;accepted;Dornogal;53.0;52.5"
```

## File Structure

```
EasyTools/
├── EasyTools.toc           # Addon metadata
├── EasyTools.lua           # Main addon logic
├── README.md               # This file
└── Modules/
    ├── ItemContext.lua     # Item context enum (Dungeon Normal, Raid Mythic, etc.)
    └── TooltipKinds.lua    # Tooltip ID types and mappings
```

## SavedVariables

- **EasyToolsDB.QuestLog**: Array of quest event log entries

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
