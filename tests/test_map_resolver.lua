-- Tests for AddressBook MapResolver

local T = {}

local function setupMapData()
    -- Set up some test map data
    MockWoW.SetMapData(1955, "Shattrath City", Enum.UIMapType.Zone, 101)
    MockWoW.SetMapData(1519, "Stormwind City", Enum.UIMapType.Zone, 13)
    MockWoW.SetMapData(1637, "Orgrimmar", Enum.UIMapType.Zone, 12)
    MockWoW.SetMapData(13, "Eastern Kingdoms", Enum.UIMapType.Continent, 946)
    MockWoW.SetMapData(12, "Kalimdor", Enum.UIMapType.Continent, 946)
    MockWoW.SetMapData(101, "Outland", Enum.UIMapType.Continent, 946)
    MockWoW.SetMapData(946, "Azeroth", Enum.UIMapType.World, 0)

    -- Rebuild the lookup from mock data
    AddressBook:BuildMapLookup()
    AddressBook:BuildContinentZoneMap()
end

function T.test_get_map_id_for_zone()
    setupMapData()
    local id = AddressBook:GetMapIDForZone("Shattrath City")
    assert_equal(1955, id)
end

function T.test_get_map_id_case_insensitive()
    setupMapData()
    local id = AddressBook:GetMapIDForZone("shattrath city")
    assert_equal(1955, id)
end

function T.test_get_map_id_returns_nil_for_unknown()
    setupMapData()
    local id = AddressBook:GetMapIDForZone("Nonexistent Zone")
    assert_nil(id)
end

function T.test_resolve_map_ids_populates_entries()
    setupMapData()
    local db = {
        ["Test"] = {
            ["Sub"] = {
                { name = "NPC1", zone = "Shattrath City", x = 50, y = 50 },
                { name = "NPC2", zone = "Stormwind City", x = 30, y = 40 },
            }
        }
    }
    local resolved, failed = AddressBook:ResolveMapIDs(db)
    assert_equal(2, resolved)
    assert_equal(0, failed)
    assert_equal(1955, db["Test"]["Sub"][1].mapID)
    assert_equal(1519, db["Test"]["Sub"][2].mapID)
end

function T.test_resolve_map_ids_counts_failures()
    setupMapData()
    local db = {
        ["Test"] = {
            ["Sub"] = {
                { name = "NPC1", zone = "Unknown Zone", x = 50, y = 50 },
            }
        }
    }
    local resolved, failed = AddressBook:ResolveMapIDs(db)
    assert_equal(0, resolved)
    assert_equal(1, failed)
end

function T.test_get_continent_for_zone()
    setupMapData()
    local cont = AddressBook:GetContinentForZone("Shattrath City")
    assert_equal("Outland", cont)
end

function T.test_get_zones_for_continent()
    setupMapData()
    local zones = AddressBook:GetZonesForContinent("Outland")
    assert_true(#zones > 0, "Outland should have zones")
    local found = false
    for _, z in ipairs(zones) do
        if z == "Shattrath City" then found = true; break end
    end
    assert_true(found, "Outland should include Shattrath City")
end

function T.test_get_continents()
    setupMapData()
    local conts = AddressBook:GetContinents()
    assert_true(#conts > 0, "Should have continents")
end

function T.test_get_all_zones_sorted()
    setupMapData()
    local zones = AddressBook:GetAllZonesSorted()
    assert_true(#zones > 0, "Should have zones")
    -- Verify sorted
    for i = 2, #zones do
        assert_true(zones[i - 1] <= zones[i],
            "Zones not sorted: " .. zones[i-1] .. " > " .. zones[i])
    end
end

function T.test_get_current_zone_name()
    setupMapData()
    MockWoW.SetPlayerZone(1955, 0.5, 0.5)
    local name = AddressBook:GetCurrentZoneName()
    assert_equal("Shattrath City", name)
end

return T
