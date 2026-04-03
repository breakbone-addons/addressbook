AddressBook = AddressBook or {}

AddressBook.VERSION = "1.0.0"
AddressBook.ADDON_NAME = "AddressBook"
AddressBook.activeWaypoint = nil

-- Fixed-size fonts so UI layout doesn't break with user font scaling
local FONT_FILE = "Fonts\\FRIZQT__.TTF"

local fontTitle = CreateFont("AddressBookFontTitle")
fontTitle:SetFont(FONT_FILE, 13, "")
fontTitle:SetTextColor(1, 0.82, 0)

local fontNormal = CreateFont("AddressBookFontNormal")
fontNormal:SetFont(FONT_FILE, 11, "")
fontNormal:SetTextColor(1, 0.82, 0)

local fontSmall = CreateFont("AddressBookFontSmall")
fontSmall:SetFont(FONT_FILE, 10, "")
fontSmall:SetTextColor(1, 0.82, 0)

local fontHighlight = CreateFont("AddressBookFontHighlight")
fontHighlight:SetFont(FONT_FILE, 10, "")
fontHighlight:SetTextColor(1, 1, 1)

local fontWhite = CreateFont("AddressBookFontWhite")
fontWhite:SetFont(FONT_FILE, 11, "")
fontWhite:SetTextColor(1, 1, 1)
AddressBook.selectedEntry = nil
AddressBook.mainFrame = nil

-- Prefix color for chat messages
local CHAT_PREFIX = "|cff33bbff[AddressBook]|r "

function AddressBook:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(CHAT_PREFIX .. tostring(msg))
end

-- Search across both built-in and custom databases
function AddressBook:Search(query)
    local results = {}
    query = strlower(query)

    local function nameMatches(entryName)
        local nl = strlower(entryName)
        return nl:find(query, 1, true) or query:find(nl, 1, true)
    end

    local function searchDB(db, isCustom)
        for category, subcats in pairs(db) do
            for subcategory, entries in pairs(subcats) do
                for i, entry in ipairs(entries) do
                    if nameMatches(entry.name)
                        or (entry.note and strlower(entry.note):find(query, 1, true))
                        or (entry.zone and strlower(entry.zone):find(query, 1, true)) then
                        results[#results + 1] = {
                            entry = entry,
                            category = category,
                            subcategory = subcategory,
                            index = i,
                            isCustom = isCustom,
                        }
                    end
                end
            end
        end
    end

    if self.LocationDB then
        searchDB(self.LocationDB, false)
    end
    if AddressBookDB and AddressBookDB.custom then
        searchDB(AddressBookDB.custom, true)
    end

    -- Search MobDB and CritterDB (load on demand)
    self:LoadMobDB()
    self:LoadCritterDB()
    if self.MobDB then
        for zoneName, entries in pairs(self.MobDB) do
            for i, entry in ipairs(entries) do
                if nameMatches(entry.name)
                    or (entry.note and strlower(entry.note):find(query, 1, true))
                    or strlower(zoneName):find(query, 1, true) then
                    local primaryEntry = {
                        name = entry.name,
                        zone = zoneName,
                        x = entry.spawns[1][1],
                        y = entry.spawns[1][2],
                        note = entry.note,
                        spawns = entry.spawns,
                    }
                    results[#results + 1] = {
                        entry = primaryEntry,
                        category = "Creatures",
                        subcategory = zoneName,
                        index = i,
                        isCustom = false,
                        spawnCount = #entry.spawns,
                    }
                end
            end
        end
    end

    -- Search CritterDB
    if self.CritterDB then
        for zoneName, entries in pairs(self.CritterDB) do
            for i, entry in ipairs(entries) do
                if nameMatches(entry.name)
                    or (entry.note and strlower(entry.note):find(query, 1, true))
                    or strlower(zoneName):find(query, 1, true) then
                    local primaryEntry = {
                        name = entry.name,
                        zone = zoneName,
                        x = entry.spawns[1][1],
                        y = entry.spawns[1][2],
                        note = entry.note,
                        spawns = entry.spawns,
                    }
                    results[#results + 1] = {
                        entry = primaryEntry,
                        category = "Critters",
                        subcategory = zoneName,
                        index = i,
                        isCustom = false,
                        spawnCount = #entry.spawns,
                    }
                end
            end
        end
    end

    return results
end

-- Get merged entries for a category/subcategory (built-in + custom)
function AddressBook:GetEntries(category, subcategory)
    local results = {}
    local playerFaction = UnitFactionGroup("player")
    local factionFilter = AddressBookDB and AddressBookDB.settings and AddressBookDB.settings.showFactionOnly

    -- Monsters category uses MobDB (organized by zone)
    -- Load MobDB/CritterDB on demand
    if category == "Creatures" and subcategory then self:LoadMobDB() end
    if category == "Critters" and subcategory then self:LoadCritterDB() end

    -- Handle zone-based categories (Creatures and Critters)
    local mobSource = (category == "Creatures" and self.MobDB) or (category == "Critters" and self.CritterDB) or nil
    if mobSource and subcategory then
        local entries = mobSource[subcategory]
        if entries then
            for i, entry in ipairs(entries) do
                -- MobDB entries have spawns array; use first spawn as primary x,y
                local primaryEntry = {
                    name = entry.name,
                    zone = subcategory,
                    x = entry.spawns[1][1],
                    y = entry.spawns[1][2],
                    note = entry.note,
                    spawns = entry.spawns,
                }
                results[#results + 1] = {
                    entry = primaryEntry,
                    category = category,
                    subcategory = subcategory,
                    index = i,
                    isCustom = false,
                    spawnCount = #entry.spawns,
                }
            end
        end
        return results
    end

    local function addEntries(db, isCustom)
        local subcats = db[category]
        if not subcats then return end
        local entries = subcats[subcategory]
        if not entries then return end
        for i, entry in ipairs(entries) do
            if not factionFilter or not entry.faction or entry.faction == playerFaction then
                results[#results + 1] = {
                    entry = entry,
                    category = category,
                    subcategory = subcategory,
                    index = i,
                    isCustom = isCustom,
                }
            end
        end
    end

    if self.LocationDB then
        addEntries(self.LocationDB, false)
    end
    if AddressBookDB and AddressBookDB.custom then
        addEntries(AddressBookDB.custom, true)
    end

    return results
end

-- Get all categories with their subcategories
function AddressBook:GetCategories()
    local cats = {}
    local seen = {}

    local function addFromDB(db)
        for category, subcats in pairs(db) do
            if not seen[category] then
                seen[category] = {}
                cats[#cats + 1] = category
            end
            for subcategory in pairs(subcats) do
                if not seen[category][subcategory] then
                    seen[category][subcategory] = true
                end
            end
        end
    end

    if self.LocationDB then
        addFromDB(self.LocationDB)
    end
    if AddressBookDB and AddressBookDB.custom then
        addFromDB(AddressBookDB.custom)
    end

    -- Add Creatures category (zones as subcategories)
    if self.BuildMobDB then
        if not seen["Creatures"] then
            seen["Creatures"] = {}
            cats[#cats + 1] = "Creatures"
        end
        if self._mobZones then
            for _, zoneName in ipairs(self._mobZones) do
                seen["Creatures"][zoneName] = true
            end
        end
    end

    -- Add Critters category (zones as subcategories)
    if self.BuildCritterDB then
        if not seen["Critters"] then
            seen["Critters"] = {}
            cats[#cats + 1] = "Critters"
        end
        if self._critterZones then
            for _, zoneName in ipairs(self._critterZones) do
                seen["Critters"][zoneName] = true
            end
        end
    end

    table.sort(cats)

    local result = {}
    for _, cat in ipairs(cats) do
        local subs = {}
        for sub in pairs(seen[cat]) do
            subs[#subs + 1] = sub
        end
        table.sort(subs)
        result[#result + 1] = { name = cat, subcategories = subs }
    end

    return result
end

-- MobDB load/unload for memory management
function AddressBook:LoadMobDB()
    if not self.MobDB and self.BuildMobDB then
        self.MobDB = self:BuildMobDB()
        if not self._mobZones then self:BuildMobZoneIndex() end
    end
end

function AddressBook:LoadCritterDB()
    if not self.CritterDB and self.BuildCritterDB then
        self.CritterDB = self:BuildCritterDB()
        if not self._critterZones then self:BuildCritterZoneIndex() end
    end
end

function AddressBook:BuildMobZoneIndex()
    if not self.BuildMobDB then return end
    local tempLoad = not self.MobDB
    if tempLoad then self.MobDB = self:BuildMobDB() end
    self._mobZones = {}
    for zoneName in pairs(self.MobDB) do
        self._mobZones[#self._mobZones + 1] = zoneName
    end
    table.sort(self._mobZones)
    if tempLoad then self.MobDB = nil; collectgarbage("collect") end
end

function AddressBook:BuildCritterZoneIndex()
    if not self.BuildCritterDB then return end
    local tempLoad = not self.CritterDB
    if tempLoad then self.CritterDB = self:BuildCritterDB() end
    self._critterZones = {}
    for zoneName in pairs(self.CritterDB) do
        self._critterZones[#self._critterZones + 1] = zoneName
    end
    table.sort(self._critterZones)
    if tempLoad then self.CritterDB = nil; collectgarbage("collect") end
end

function AddressBook:UnloadMobDB()
    self.MobDB = nil
    self.CritterDB = nil
    collectgarbage("collect")
end

function AddressBook:IsMobDBLoaded()
    return self.MobDB ~= nil
end

-- Favorites
function AddressBook:GetFavoriteKey(entry)
    return (entry.name or "") .. "|" .. (entry.zone or "")
end

function AddressBook:IsFavorite(entry)
    if not AddressBookDB or not AddressBookDB.favorites then return false end
    return AddressBookDB.favorites[self:GetFavoriteKey(entry)] ~= nil
end

function AddressBook:ToggleFavorite(entry)
    if not AddressBookDB then return end
    if not AddressBookDB.favorites then AddressBookDB.favorites = {} end

    local key = self:GetFavoriteKey(entry)
    if AddressBookDB.favorites[key] then
        AddressBookDB.favorites[key] = nil
        self:Print("Removed from favorites: " .. entry.name)
    else
        -- Store a copy of the entry as the favorite
        AddressBookDB.favorites[key] = {
            name = entry.name,
            zone = entry.zone,
            x = entry.x,
            y = entry.y,
            faction = entry.faction,
            note = entry.note,
            mapID = entry.mapID,
        }
        self:Print("Added to favorites: " .. entry.name)
    end

    if self.RefreshUI then
        self:RefreshUI()
    end
end

function AddressBook:GetFavorites()
    local results = {}
    if not AddressBookDB or not AddressBookDB.favorites then return results end
    for key, entry in pairs(AddressBookDB.favorites) do
        results[#results + 1] = {
            entry = entry,
            category = "Favorites",
            subcategory = "Favorites",
            index = key,
            isCustom = false,
            isFavorite = true,
        }
    end
    table.sort(results, function(a, b) return a.entry.name < b.entry.name end)
    return results
end

function AddressBook:ToggleUI()
    if self.mainFrame then
        if self.mainFrame:IsShown() then
            self.mainFrame:Hide()
            -- Unload MobDB to free memory when window is closed
            self:UnloadMobDB()
        else
            self.mainFrame:Show()
        end
    end
end

-- Slash command handler
local function SlashHandler(msg)
    local cmd, rest = strsplit(" ", msg or "", 2)
    cmd = strlower(cmd or "")

    if cmd == "" then
        AddressBook:ToggleUI()
    elseif cmd == "search" and rest then
        local results = AddressBook:Search(rest)
        if #results == 0 then
            AddressBook:Print("No results for '" .. rest .. "'")
        else
            AddressBook:Print(#results .. " result(s) for '" .. rest .. "':")
            for i, r in ipairs(results) do
                if i > 10 then
                    AddressBook:Print("  ... and " .. (#results - 10) .. " more")
                    break
                end
                local e = r.entry
                AddressBook:Print(format("  %s - %s (%.1f, %.1f)%s",
                    e.name, e.zone, e.x, e.y,
                    e.note and (" - " .. e.note) or ""))
            end
        end
    elseif cmd == "add" then
        if AddressBook.ShowEditDialog then
            AddressBook:ShowEditDialog(nil)
        else
            AddressBook:SaveHere(rest or "My Location", "Custom", nil)
        end
    elseif cmd == "record" then
        -- Record current position and update an existing entry or create new
        if rest then
            local results = AddressBook:Search(rest)
            local mapID = C_Map.GetBestMapForUnit("player")
            local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
            if not pos then
                AddressBook:Print("Could not determine your position.")
            else
                local rawX, rawY = pos:GetXY()
                -- Convert to 0-100 scale
                local x = math.floor(rawX * 10000) / 100
                local y = math.floor(rawY * 10000) / 100
                local info = C_Map.GetMapInfo(mapID)
                local zoneName = info and info.name or "Unknown"

                if #results > 0 then
                    -- Update first matching entry's coordinates
                    local r = results[1]
                    r.entry.x = x
                    r.entry.y = y
                    r.entry.mapID = mapID
                    r.entry.zone = zoneName
                    AddressBook:Print(format("Updated '%s' to %s (%.1f, %.1f)",
                        r.entry.name, zoneName, x, y))
                else
                    -- Create new custom entry with this name
                    AddressBook:SaveHere(rest, "Custom", nil)
                end
            end
        else
            AddressBook:Print("Usage: /ab record <name> - Update or create entry at your position")
        end
    elseif cmd == "waypoint" or cmd == "wp" then
        if rest then
            local results = AddressBook:Search(rest)
            if #results > 0 then
                AddressBook:SetWaypoint(results[1].entry)
            else
                AddressBook:Print("No location found matching '" .. rest .. "'")
            end
        else
            AddressBook:Print("Usage: /ab waypoint <name>")
        end
    elseif cmd == "help" then
        AddressBook:Print("Commands:")
        AddressBook:Print("  /ab - Toggle address book")
        AddressBook:Print("  /ab search <query> - Search locations")
        AddressBook:Print("  /ab add [name] - Save current location")
        AddressBook:Print("  /ab record <name> - Update existing or create entry at your position")
        AddressBook:Print("  /ab waypoint <name> - Set waypoint to location")
        AddressBook:Print("  /ab help - Show this help")
    else
        AddressBook:Print("Unknown command. Type /ab help for usage.")
    end
end

-- Initialization
local eventFrame = CreateFrame("Frame", "AddressBookEventFrame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")

        -- Init SavedVariables
        if not AddressBookDB then
            AddressBookDB = {}
        end
        if not AddressBookDB.custom then
            AddressBookDB.custom = {}
        end
        if not AddressBookDB.minimap then
            AddressBookDB.minimap = {}
        end
        if not AddressBookDB.settings then
            AddressBookDB.settings = { showFactionOnly = true }
        end
        if not AddressBookDB.favorites then
            AddressBookDB.favorites = {} -- keyed by "name|zone" for quick lookup
        end

        if not AddressBookCharDB then
            AddressBookCharDB = {}
        end

        -- Resolve mapIDs for built-in location database
        if AddressBook.ResolveMapIDs and AddressBook.LocationDB then
            local resolved, failed = AddressBook:ResolveMapIDs(AddressBook.LocationDB)
            if failed > 0 then
                AddressBook:Print(format("Warning: %d locations could not resolve mapIDs", failed))
            end
        end

        -- Resolve mapIDs for custom entries too
        if AddressBook.ResolveMapIDs and AddressBookDB.custom then
            AddressBook:ResolveMapIDs(AddressBookDB.custom)
        end

        -- Build continent/zone hierarchy
        if AddressBook.BuildContinentZoneMap then
            AddressBook:BuildContinentZoneMap()
        end

        -- Build lightweight zone indexes (doesn't keep MobDB/CritterDB in memory)
        if AddressBook.BuildMobZoneIndex then
            AddressBook:BuildMobZoneIndex()
        end
        if AddressBook.BuildCritterZoneIndex then
            AddressBook:BuildCritterZoneIndex()
        end

        -- Register slash commands
        SLASH_ADDRESSBOOK1 = "/addressbook"
        SLASH_ADDRESSBOOK2 = "/ab"
        SlashCmdList["ADDRESSBOOK"] = SlashHandler

        -- Init minimap button
        if AddressBook.InitMinimapButton then
            AddressBook:InitMinimapButton()
        end

        -- Build UI
        if AddressBook.CreateMainFrame then
            AddressBook:CreateMainFrame()
        end

        local tomtomStatus = TomTom and "|cff00ff00detected|r" or "|cffff0000not found|r"
        AddressBook:Print("v" .. AddressBook.VERSION .. " loaded. TomTom: " .. tomtomStatus .. ". Type /ab help.")
    end
end)
