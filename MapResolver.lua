AddressBook = AddressBook or {}

-- Build a zone name -> mapID lookup table at runtime
-- This avoids hardcoding mapIDs which differ between WoW versions
local zoneLookup = nil

function AddressBook:BuildMapLookup()
    zoneLookup = {}

    -- Iterate possible mapIDs and record zone-type maps
    for id = 1, 2500 do
        local info = C_Map.GetMapInfo(id)
        if info and info.name and info.name ~= "" then
            local key = strlower(info.name)
            -- Prefer Zone-type maps, but record all
            if not zoneLookup[key] then
                zoneLookup[key] = id
            elseif info.mapType == Enum.UIMapType.Zone then
                -- Zone-type maps take priority over continent/micro/etc
                zoneLookup[key] = id
            end
        end
    end

    return zoneLookup
end

function AddressBook:GetMapIDForZone(zoneName)
    if not zoneLookup then
        self:BuildMapLookup()
    end
    if not zoneName then return nil end
    return zoneLookup[strlower(zoneName)]
end

-- Resolve mapIDs for all entries in a database table
function AddressBook:ResolveMapIDs(db)
    if not db then return end
    if not zoneLookup then
        self:BuildMapLookup()
    end

    local resolved, failed = 0, 0
    for category, subcats in pairs(db) do
        for subcategory, entries in pairs(subcats) do
            for _, entry in ipairs(entries) do
                if entry.zone and not entry.mapID then
                    local mapID = self:GetMapIDForZone(entry.zone)
                    if mapID then
                        entry.mapID = mapID
                        resolved = resolved + 1
                    else
                        failed = failed + 1
                    end
                end
            end
        end
    end

    return resolved, failed
end

-- Continent/Zone hierarchy
local continentZones = {}  -- continentName -> { zoneName1, zoneName2, ... }
local zoneToContinent = {} -- zoneName -> continentName
local continentList = {}   -- sorted list of continent names

function AddressBook:BuildContinentZoneMap()
    wipe(continentZones)
    wipe(zoneToContinent)
    wipe(continentList)

    if not zoneLookup then
        self:BuildMapLookup()
    end

    -- Walk all known zone mapIDs and trace each to its continent parent
    for zoneName, mapID in pairs(zoneLookup) do
        local info = C_Map.GetMapInfo(mapID)
        if info and info.mapType == Enum.UIMapType.Zone then
            -- Walk up the parent chain to find the continent
            local parentID = info.parentMapID
            local continentName = nil
            local depth = 0
            while parentID and parentID > 0 and depth < 5 do
                local parentInfo = C_Map.GetMapInfo(parentID)
                if not parentInfo then break end
                if parentInfo.mapType == Enum.UIMapType.Continent then
                    continentName = parentInfo.name
                    break
                end
                parentID = parentInfo.parentMapID
                depth = depth + 1
            end

            if continentName and info.name then
                zoneToContinent[info.name] = continentName
                if not continentZones[continentName] then
                    continentZones[continentName] = {}
                end
                continentZones[continentName][info.name] = true
            end
        end
    end

    -- Build sorted continent list
    for name in pairs(continentZones) do
        continentList[#continentList + 1] = name
    end
    table.sort(continentList)

    -- Convert zone sets to sorted lists
    for continent, zones in pairs(continentZones) do
        local sorted = {}
        for z in pairs(zones) do
            sorted[#sorted + 1] = z
        end
        table.sort(sorted)
        continentZones[continent] = sorted
    end
end

function AddressBook:GetContinents()
    return continentList
end

function AddressBook:GetZonesForContinent(continent)
    if not continent then return {} end
    return continentZones[continent] or {}
end

function AddressBook:GetContinentForZone(zoneName)
    return zoneToContinent[zoneName]
end

function AddressBook:GetAllZonesSorted()
    local all = {}
    for z in pairs(zoneToContinent) do
        all[#all + 1] = z
    end
    table.sort(all)
    return all
end
