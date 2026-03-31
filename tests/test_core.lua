-- Tests for AddressBook core functions

local T = {}

function T.test_search_finds_by_name()
    local results = AddressBook:Search("Innkeeper Haelthol")
    assert_true(#results > 0, "Should find Innkeeper Haelthol")
    assert_equal("Innkeeper Haelthol", results[1].entry.name)
end

function T.test_search_is_case_insensitive()
    local results = AddressBook:Search("innkeeper haelthol")
    assert_true(#results > 0, "Case insensitive search should find results")
end

function T.test_search_finds_by_zone()
    local results = AddressBook:Search("Shattrath")
    assert_true(#results > 0, "Should find entries in Shattrath")
    local found_shattrath = false
    for _, r in ipairs(results) do
        if r.entry.zone == "Shattrath City" then
            found_shattrath = true
            break
        end
    end
    assert_true(found_shattrath, "Should find Shattrath City entries")
end

function T.test_search_finds_by_note()
    local results = AddressBook:Search("Dungeon")
    assert_true(#results > 0, "Should find entries with 'Dungeon' in note")
end

function T.test_search_returns_empty_for_no_match()
    local results = AddressBook:Search("xyzzy_nonexistent_12345")
    assert_equal(0, #results)
end

function T.test_get_entries_returns_entries()
    local results = AddressBook:GetEntries("Services", "Innkeepers")
    assert_true(#results > 0, "Should have innkeeper entries")
    for _, r in ipairs(results) do
        assert_equal("Services", r.category)
        assert_equal("Innkeepers", r.subcategory)
    end
end

function T.test_get_entries_faction_filter()
    AddressBookDB.settings.showFactionOnly = true
    MockWoW.SetFaction("Alliance")

    local results = AddressBook:GetEntries("Services", "Innkeepers")
    for _, r in ipairs(results) do
        assert_true(r.entry.faction ~= "Horde",
            "Horde entries should be filtered: " .. r.entry.name)
    end
end

function T.test_get_categories_returns_expected()
    local cats = AddressBook:GetCategories()
    assert_true(#cats > 0, "Should have categories")
    -- Check that Quests is in the list
    local found = false
    for _, c in ipairs(cats) do
        if c.name == "Quests" then found = true; break end
    end
    assert_true(found, "Should include Quests category")
end

function T.test_get_entries_merges_custom()
    AddressBook:AddCustomEntry("Services", "Innkeepers", {
        name = "Custom Innkeeper", zone = "TestZone", x = 50, y = 50, note = "Test"
    })
    local results = AddressBook:GetEntries("Services", "Innkeepers")
    local found = false
    for _, r in ipairs(results) do
        if r.entry.name == "Custom Innkeeper" then
            found = true
            assert_true(r.isCustom, "Custom entry should be marked isCustom")
            break
        end
    end
    assert_true(found, "Custom entry should appear in merged results")
end

return T
