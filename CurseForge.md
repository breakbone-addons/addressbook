# AddressBook

An address book for World of Warcraft that helps you find NPCs and locations with one-click TomTom waypoint navigation.

## What It Does

Browse over 1,600 pre-populated NPC locations across Azeroth and Outland. Find trainers, flight masters, innkeepers, vendors, banks, and more — then set a TomTom waypoint with a single click.

## Key Features

**Browse by Category**
- Class Trainers, Profession Trainers, Weapon Masters
- Flight Masters
- Innkeepers, Repair Vendors, Banks, Auction Houses
- Battlemasters, Stable Masters

**Filter by Location**
- Continent and zone dropdowns narrow the list to where you are (or where you want to go)
- "Auto" mode detects your current zone and filters automatically

**TomTom Waypoints**
- Double-click any entry to set a TomTom waypoint with navigation arrow
- Works without TomTom too — coordinates are displayed in chat as a fallback

**Save Your Own Locations**
- Stand anywhere and save it to your personal address book
- Use `/ab add MySpot` or the "Save Here" button
- Update existing entries with `/ab record`

**Search Everything**
- Search across all categories by NPC name, zone, or description

## Slash Commands

- `/ab` — Open the address book
- `/ab search <query>` — Search from chat
- `/ab add [name]` — Save current location
- `/ab record <name>` — Update or create entry at your position
- `/ab waypoint <name>` — Set waypoint from chat
- `/ab help` — Show all commands

## Installation

Drop the AddressBook folder into your `Interface/AddOns/` directory and `/reload`.

TomTom is optional but recommended for waypoint arrow navigation.
