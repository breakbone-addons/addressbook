# AddressBook

A location and NPC address book for World of Warcraft (BCC Anniversary Edition) with TomTom waypoint integration.

## Features

- **1,600+ Pre-Populated Locations** — Class trainers, profession trainers, flight masters, innkeepers, repair vendors, banks, auction houses, battlemasters, stable masters, and more across Eastern Kingdoms, Kalimdor, and Outland.
- **TomTom Integration** — Click any entry to create a TomTom waypoint with navigation arrow. Falls back to coordinate display if TomTom is not installed.
- **Continent & Zone Filtering** — Filter by continent and zone with dropdowns. "Auto" mode detects your current location automatically.
- **Search** — Find any NPC or location by name, zone, or description.
- **Custom Locations** — Save your own locations. Stand anywhere and use `/ab add` or the "Save Here" button.
- **Minimap Button** — Left-click opens the address book. Right-click quick-saves your current location.

## Slash Commands

| Command | Description |
|---------|-------------|
| `/ab` | Toggle the address book window |
| `/ab search <query>` | Search locations and print results to chat |
| `/ab add [name]` | Save your current location |
| `/ab record <name>` | Update an existing entry's coordinates to your current position, or create a new entry |
| `/ab waypoint <name>` | Set a TomTom waypoint to the first matching entry |
| `/ab help` | Show available commands |

## Installation

1. Download and extract to your `Interface/AddOns/` folder
2. The folder should be named `AddressBook`
3. Restart WoW or type `/reload`

## Optional Dependencies

- **TomTom** — Enables waypoint arrow navigation. Without it, AddressBook displays coordinates in chat.

## Data Sources

Location data is sourced from the [Questie](https://github.com/Questie/Questie) addon's NPC database (GPL licensed). Coordinates are verified against the game client's C_Map API at runtime.
