# ItemTracker (WoW Patch 9.2.7)

**ItemTracker** is a flexible inventory and currency monitoring AddOn designed for **World of Warcraft Patch 9.2.7 (Shadowlands)**. It provides real-time tracking, net session gains, and hourly rate calculations (`items/hr` or `gold/hr`) across customizable, independent frames—making it an ideal companion for gold farming, material collection, or tracking PvP currencies.

---

## Features

- **Dynamic Multi-Frame Display:** Track multiple items or currencies on-screen simultaneously in independent, draggable frames.
- **List-Based Item Management:** Add items or currencies into a saved list and toggle tracking `ON` or `OFF` per item directly from the options menu.
- **Full Gold & Currency Support:** Monitor player Gold (`gold` or `c0`) with formatted gold/silver/copper displays, or track any WoW currency by ID (e.g., `c1792` for Honor).
- **Real-Time Rate Engine:** Tracks total counts across bags and bank while calculating net session gains and hourly farming rates in real time.
- **Convenient Controls:**
  - **Right-Click Any Frame:** Instantly open the Options menu.
  - **`[R]` Button:** Reset session baseline counts and timers for a specific frame.
  - **`[X]` Button:** Disable tracking for that item and close the frame.
- **Flexible Input Methods:** Enter numeric IDs, paste item/currency links, or **drag and drop** items directly into the input field.
- **Interactive Minimap Icon:** Easily open the Options menu or drag the button around the minimap border.

---

## Currency Tracking & `idTip`

ItemTracker allows you to track player gold as well as any game currency using a custom `c` prefix or keyword:

- **Gold:** Type `gold` or `c0` to track character money.
- **Currencies:** Type `c` followed by the **Currency ID** (e.g., `c1792` for Honor, `c1602` for Conquest, or `c1822` for Renown).
- **Links:** Shift-click currency or item links into the options edit box.

### Recommended Companion AddOn: `idTip`
Because World of Warcraft uses numeric IDs for currencies, we recommend installing the **idTip** AddOn alongside **ItemTracker**. **idTip** adds internal **Currency IDs** (as well as Item IDs and Spell IDs) directly to your in-game tooltips when hovering over currencies in your Character Sheet (`C` -> Currency tab), making it effortless to look up any Currency ID.

---

## Slash Commands

You can use either `/it` or `/itemtracker` in the in-game chat:

| Command | Action |
| :--- | :--- |
| `/it opt` or `/it options` | Open the Options & Saved Items Manager |
| `/it reset` | Reset session gains and timers on all active frames |
| `/it gold` | Enable or toggle Gold tracking |
| `/it c<CurrencyID>` | Enable or toggle tracking for a specific currency (e.g., `/it c1792`) |
| `/it <ItemID or Link>` | Enable or toggle tracking for a specific item |

---

## Installation

1. Download the latest release from the **Releases** tab.
2. Locate your World of Warcraft directory (e.g., `World of Warcraft\_retail_\Interface\AddOns\`).
3. Move or copy the `ItemTracker` folder into `Interface\AddOns\`.
4. Ensure your directory structure matches:
   ```text
   Interface/
   └── AddOns/
       └── ItemTracker/
           ├── ItemTracker.toc
           └── ItemTracker.lua

    Launch World of Warcraft (or type /reload in-game) and verify ItemTracker is enabled in your AddOns menu.

License

Distributed under the MIT License. See LICENSE for more information.
