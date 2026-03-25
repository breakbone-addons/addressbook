## AddressBook helps you find NPCs and locations across Azeroth and Outland with one-click TomTom waypoint navigation. Built for TBC Anniversary.

## Features

### Browse & Navigate

Find any NPC by category, continent, and zone. Over 4,300 pre-populated locations including quest givers, class trainers, profession trainers, flight masters, innkeepers, repair vendors, banks, auction houses, battlemasters, and stable masters. Select an entry and set a TomTom waypoint with one click.

<img src="https://raw.githubusercontent.com/breakbone-addons/addressbook/main/screenshots/main.png" alt="AddressBook Main Window" width="500"/>

### TomTom Integration

Double-click any entry to create a TomTom waypoint with the crazy arrow pointing you directly to your destination. Works seamlessly — if TomTom isn't installed, coordinates are printed to chat instead.

### Continent & Zone Filtering

Narrow results with continent and zone dropdowns that work alongside the category tree. "Auto" mode detects your current zone and filters automatically — the list always shows what's relevant to where you are.

### Search Everything

Search across all categories by NPC name, zone, or description. Results update as you type.

### Custom Locations

Save your own locations to a personal address book. Stand anywhere and save with `/ab add` or the "Save Here" button. Update existing entries with `/ab record` to correct coordinates as you explore.

### Faction-Aware

Toggle faction filtering to show only NPCs friendly to your character's faction.

## Data Sources

Location data is extracted from the [Questie](https://github.com/Questie/Questie) addon's TBC NPC database. Coordinates are verified against the game client at runtime.

## Usage

- **Minimap button**: Left-click to open, right-click to quick-save your current location
- `/ab` — Toggle the address book
- `/ab search <query>` — Search from chat
- `/ab add [name]` — Save current location
- `/ab record <name>` — Update or create entry at your position
- `/ab waypoint <name>` — Set waypoint from chat
- `/ab help` — Show all commands

## Installation

Extract the `AddressBook` folder into your WoW AddOns directory:

```
World of Warcraft/_anniversary_/Interface/AddOns/AddressBook/
```

TomTom is optional but recommended for waypoint arrow navigation.
