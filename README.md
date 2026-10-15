# ItemTrackerMM
Lightweight World of Warcraft (9.2.7) AddOn for real-time item &amp; currency tracking, multi-frame session monitoring, and hourly rate calculations.

# ItemTracker (WoW Patch 9.2.7)

**ItemTracker** is a multi-frame inventory and currency tracking AddOn created specifically for **World of Warcraft Patch 9.2.7 (Shadowlands)**. It provides real-time tracking, net session gains, and items-per-hour rate calculations across multiple customizable frames—making it an essential tool for gold farming, material collection, or monitoring consumable usage.

---

## Features

- **Multi-Frame Tracking:** Create as many independent tracking frames as you need to monitor multiple items or currencies simultaneously.
- **Summary Frame ("All Trackers"):** An all-in-one summary window that displays real-time totals, session gains, and rates for every active tracker in one place.
- **Currency & Gold Support:** Track any game currency by ID (e.g., Honor, Conquest, Cataloged Research) or player Gold (`/it gold` or `/it c0`) with formatted gold/silver/copper displays.
- **Real-Time Rate Engine:** Calculates gains per hour (`items/hr` or `gold/hr`) alongside total inventory counts (bags + bank).
- **Flexible Input Methods:**
  - Type numeric Item/Currency IDs directly.
  - **Shift-click** item/currency links from your bags, chat, or profession windows into the input field.
  - **Drag and drop** items directly onto the input box with your cursor.
- **Per-Character Persistence:** Saved variables and frame positions persist independently on a per-character basis (`SavedVariablesPerCharacter`).
- **Interactive Minimap Icon:** Easily toggle the options window or drag the icon around the minimap border.

---

## Controls & Usage

### Individual Tracker Frames
- **Left-Click + Drag:** Move the frame anywhere across your screen.
- **Right-Click Frame:** Open the **ItemTracker Options** window.
- **`[R]` Button:** Reset session baseline counts and hourly timers for that specific frame.
- **`[X]` Button:** Close/hide the individual frame.

### Options Window & Frame Manager
- **`+ Create Tracker`:** Type an Item ID, Currency ID (`c1792`), link, or `gold`, then click to generate a new frame.
- **Show/Hide & Delete:** Independently toggle or delete active tracker frames.
- **Toggle Summary Frame:** Open or close the consolidated **All Trackers Summary** window.

---

## Slash Commands

You can use either `/it` or `/itemtracker` in the in-game chat:

| Command | Action |
| :--- | :--- |
| `/it opt` or `/it options` | Open the Options & Frame Manager window |
| `/it all` or `/it summary` | Toggle the "All Trackers Summary" frame |
| `/it reset` | Reset session gains and timers on all active frames |
| `/it gold` | Create a new tracker frame for player Gold |
| `/it c<CurrencyID>` | Create a new tracker frame for a specific currency (e.g., `/it c1792` for Honor) |
| `/it <ItemID or Link>` | Create a new tracker frame for a specific item |

---

## File Structure

Ensure your directory structure matches the following inside your WoW installation:

```text
Interface/
└── AddOns/
    └── ItemTracker/
        ├── ItemTracker.toc
        └── ItemTracker.lua
