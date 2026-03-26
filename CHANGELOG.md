# AddressBook Changelog

## 1.2.0
- Added dungeon and raid instance entrances (42 dungeons, 15 raids covering Classic and TBC)
- Added Nearest button to highlight the closest location in the current list
- Added right-click minimap button menu showing favorites for quick waypoint access
- Reorganized header controls: continent/zone Auto checkboxes, improved layout
- Zone dropdown now only shows zones that have entries in the database
- Character limits on custom entry fields (30 name, 60 note)

## 1.1.0
- Added favorites: right-click any entry to mark as favorite, shown in green with a dedicated Favorites category
- Added full Add Entry dialog with name, coordinates, zone, and note fields
- Added "Current Location" button to auto-fill position in the Add Entry dialog
- Added note field for custom locations
- Expanded location database to 4,300+ entries
- Fixed TomTom waypoint integration for BCC Anniversary Edition mapIDs
- Removed redundant Save Here button (Add Entry now handles all entry creation)

## 1.0.0
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
