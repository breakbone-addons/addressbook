# AddressBook Changelog

## v1.4.1

- Release package shrunk by ~820 KB: no longer ships developer-only files (`art/`, `screenshots/`, `tests/`, `CURSEFORGE.md`, `site-content.json`, `scripts/`)
- Minimap icon file size reduced from 16 KB to 5 KB via lossless RLE compression (visually identical)
- Vendored libraries directory renamed from `Libs/` to `libs/` (lowercase, matches the rest of the Breakbone addon family)
- `LICENSE` file now included in the release zip
- Changelog version headers now consistently use the `v` prefix

## v1.4.0
- Added 7,500+ creatures and 425 critters with all spawn points across 110 zones (outdoor + instances)
- Added public API for other addons: Lookup, WaypointTo, ShowSpawns, Search
- Added sortable column headers (click Name, Zone, or Note to sort)
- Added bidirectional search matching (handles plurals like "Voidshriekers" finding "Voidshrieker")
- Instance creatures show entrance waypoints when outside, "inside instance" message when inside
- Instance zones mapped to correct continents for filtering
- Creature/critter data loads on demand and unloads when window closes to save memory
- Removed junk entries: triggers, invisible stalkers, quest credit markers
- Right-click creatures with multiple spawns to "Set All Waypoints" on the map
- TomTom waypoints now show "From: AddressBook"
- Clicking a category clears the search box
- Total database: 13,600+ locations with 83,000+ spawn points
- Test suite expanded to 61 tests

## v1.3.0
- Added 1,360 vendor NPCs across 13 subcategories (food, reagents, profession supplies, weapons, armor, and more)
- Added 50-test suite covering data validation, favorites, custom entries, map resolution, and TomTom integration
- Fixed font scaling: UI layout is now stable regardless of user font size settings
- Fixed 11 duplicate vendor entries caught by test suite
- Zone dropdown now filters by selected continent
- Total database: 5,800+ locations

## v1.2.0
- Added dungeon and raid instance entrances (42 dungeons, 15 raids covering Classic and TBC)
- Added Nearest button to highlight the closest location in the current list
- Added right-click minimap button menu showing favorites for quick waypoint access
- Reorganized header controls: continent/zone Auto checkboxes, improved layout
- Zone dropdown now only shows zones that have entries in the database
- Character limits on custom entry fields (30 name, 60 note)

## v1.1.0
- Added favorites: right-click any entry to mark as favorite, shown in green with a dedicated Favorites category
- Added full Add Entry dialog with name, coordinates, zone, and note fields
- Added "Current Location" button to auto-fill position in the Add Entry dialog
- Added note field for custom locations
- Expanded location database to 4,300+ entries
- Fixed TomTom waypoint integration for BCC Anniversary Edition mapIDs
- Removed redundant Save Here button (Add Entry now handles all entry creation)

## v1.0.0
- Initial release
- Browse 1,600+ NPC locations: trainers, flight masters, innkeepers, vendors, banks, auction houses, battlemasters, and more
- TomTom waypoint integration with one-click navigation
- Fallback coordinate display when TomTom is not installed
- Continent and zone filtering with auto-detect based on player location
- Search across all entries by name, zone, or note
- Save custom locations with /ab add or the Save Here button
- Update existing entry coordinates with /ab record
- Minimap button (LibDBIcon) with left-click to open, right-click to quick-save
- Per-character saved window position and last-viewed category
- Faction filtering toggle
- Right-click context menu on entries (set waypoint, edit, delete)
