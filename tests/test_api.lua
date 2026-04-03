-- Tests for AddressBook public API

local T = {}

function T.test_lookup_finds_by_exact_name()
    local results, definitive = AddressBook.API:Lookup("Innkeeper Haelthol")
    assert_true(#results > 0, "Should find Innkeeper Haelthol")
    assert_true(definitive, "Single NPC name should be definitive")
    assert_equal("Innkeeper Haelthol", results[1].name)
end

function T.test_lookup_returns_empty_for_no_match()
    local results, definitive = AddressBook.API:Lookup("xyzzy_nonexistent_99999")
    assert_equal(0, #results)
    assert_false(definitive)
end

function T.test_lookup_zone_filter()
    local results, definitive = AddressBook.API:Lookup("Innkeeper", { zone = "Shattrath" })
    assert_true(#results > 0, "Should find innkeepers in Shattrath")
    for _, r in ipairs(results) do
        assert_true(r.zone:lower():find("shattrath"), "All results should be in Shattrath: " .. r.zone)
    end
end

function T.test_lookup_category_filter()
    local results = AddressBook.API:Lookup("Innkeeper", { category = "Services" })
    assert_true(#results > 0, "Should find service innkeepers")
    for _, r in ipairs(results) do
        assert_equal("Services", r.category, "All results should be in Services: " .. r.category)
    end
end

function T.test_lookup_ambiguous_returns_false()
    -- "Rat" matches many different NPCs across many zones
    local results, definitive = AddressBook.API:Lookup("Rat")
    assert_true(#results > 1, "Should find multiple results")
    assert_false(definitive, "Multiple different names should not be definitive")
end

function T.test_lookup_definitive_same_name_multiple_zones()
    -- An NPC that appears in multiple zones but always has the same name
    local results, definitive = AddressBook.API:Lookup("Innkeeper Haelthol")
    assert_true(definitive, "Same NPC name across results should be definitive")
end

function T.test_lookup_returns_clean_copies()
    local results = AddressBook.API:Lookup("Innkeeper Haelthol")
    assert_true(#results > 0)
    -- Verify result has expected fields
    local r = results[1]
    assert_not_nil(r.name)
    assert_not_nil(r.zone)
    assert_not_nil(r.x)
    assert_not_nil(r.y)
    assert_not_nil(r.category)
    assert_not_nil(r.subcategory)
end

function T.test_lookup_action_nearest_sets_waypoint()
    local called = false
    local origSetWaypoint = AddressBook.SetWaypoint
    AddressBook.SetWaypoint = function(self, entry)
        called = true
    end

    AddressBook.API:Lookup("Innkeeper Haelthol", { action = "nearest", silent = true })
    assert_true(called, "SetWaypoint should have been called for definitive match with action=nearest")

    AddressBook.SetWaypoint = origSetWaypoint
end

function T.test_lookup_action_all_with_spawns()
    local called = false
    local origSetAll = AddressBook.SetAllWaypoints
    AddressBook.SetAllWaypoints = function(self, entry)
        called = true
    end

    -- Search for a creature with multiple spawns, using zone to ensure definitive match
    AddressBook:LoadMobDB()
    local testMob, testZone = nil, nil
    if AddressBook.MobDB then
        for zone, entries in pairs(AddressBook.MobDB) do
            for _, e in ipairs(entries) do
                -- Find a mob with a unique-ish name and multiple spawns
                if #e.spawns > 5 and #e.name > 12 then
                    testMob = e.name
                    testZone = zone
                    break
                end
            end
            if testMob then break end
        end
    end

    if testMob then
        AddressBook.API:Lookup(testMob, { zone = testZone, action = "all", silent = true })
        assert_true(called, "SetAllWaypoints should have been called for multi-spawn definitive match")
    end

    AddressBook.SetAllWaypoints = origSetAll
end

function T.test_waypoint_to_convenience()
    local called = false
    local origSetWaypoint = AddressBook.SetWaypoint
    AddressBook.SetWaypoint = function(self, entry)
        called = true
    end

    AddressBook.API:WaypointTo("Innkeeper Haelthol")
    assert_true(called, "WaypointTo should call SetWaypoint")

    AddressBook.SetWaypoint = origSetWaypoint
end

function T.test_zone_filter_case_insensitive()
    local results1 = AddressBook.API:Lookup("Innkeeper", { zone = "shattrath" })
    local results2 = AddressBook.API:Lookup("Innkeeper", { zone = "SHATTRATH" })
    assert_equal(#results1, #results2, "Zone filter should be case-insensitive")
end

return T
