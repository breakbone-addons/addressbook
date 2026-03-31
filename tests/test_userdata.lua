-- Tests for AddressBook custom entry CRUD (UserData.lua)

local T = {}

function T.test_add_custom_entry_creates_structure()
    AddressBook:AddCustomEntry("Custom", "My Locations", {
        name = "Test Spot", zone = "Orgrimmar", x = 50, y = 50
    })
    assert_not_nil(AddressBookDB.custom["Custom"])
    assert_not_nil(AddressBookDB.custom["Custom"]["My Locations"])
    assert_equal(1, #AddressBookDB.custom["Custom"]["My Locations"])
    assert_equal("Test Spot", AddressBookDB.custom["Custom"]["My Locations"][1].name)
end

function T.test_add_multiple_entries()
    AddressBook:AddCustomEntry("Custom", "My Locations", { name = "A", zone = "Z", x = 1, y = 1 })
    AddressBook:AddCustomEntry("Custom", "My Locations", { name = "B", zone = "Z", x = 2, y = 2 })
    assert_equal(2, #AddressBookDB.custom["Custom"]["My Locations"])
end

function T.test_remove_custom_entry()
    AddressBook:AddCustomEntry("Custom", "My Locations", { name = "A", zone = "Z", x = 1, y = 1 })
    AddressBook:AddCustomEntry("Custom", "My Locations", { name = "B", zone = "Z", x = 2, y = 2 })
    AddressBook:RemoveCustomEntry("Custom", "My Locations", 1)
    assert_equal(1, #AddressBookDB.custom["Custom"]["My Locations"])
    assert_equal("B", AddressBookDB.custom["Custom"]["My Locations"][1].name)
end

function T.test_remove_cleans_empty_tables()
    AddressBook:AddCustomEntry("Custom", "My Locations", { name = "A", zone = "Z", x = 1, y = 1 })
    AddressBook:RemoveCustomEntry("Custom", "My Locations", 1)
    -- Subcategory should be cleaned up
    local sub = AddressBookDB.custom["Custom"] and AddressBookDB.custom["Custom"]["My Locations"]
    assert_true(sub == nil or #sub == 0, "Expected empty or nil subcategory after last removal")
end

function T.test_edit_custom_entry()
    AddressBook:AddCustomEntry("Custom", "My Locations", { name = "Old", zone = "Z", x = 1, y = 1 })
    AddressBook:EditCustomEntry("Custom", "My Locations", 1, { name = "New", zone = "Z", x = 2, y = 3 })
    assert_equal("New", AddressBookDB.custom["Custom"]["My Locations"][1].name)
    assert_equal(2, AddressBookDB.custom["Custom"]["My Locations"][1].x)
end

function T.test_save_manual_entry_converts_coordinates()
    -- Mock the map resolver
    local origResolve = AddressBook.GetMapIDForZone
    AddressBook.GetMapIDForZone = function(self, zone) return 1519 end

    AddressBook:SaveManualEntry("Test", "Stormwind City", "45.5", "67.2", "A note")

    AddressBook.GetMapIDForZone = origResolve

    local entries = AddressBookDB.custom["Custom"]["My Locations"]
    assert_not_nil(entries)
    assert_equal(1, #entries)
    assert_equal(45.5, entries[1].x)
    assert_equal(67.2, entries[1].y)
end

function T.test_save_manual_entry_rejects_empty_name()
    local origResolve = AddressBook.GetMapIDForZone
    AddressBook.GetMapIDForZone = function(self, zone) return 1519 end

    AddressBook:SaveManualEntry("", "Stormwind City", "50", "50", nil)

    AddressBook.GetMapIDForZone = origResolve

    -- Should not have been saved
    local custom = AddressBookDB.custom["Custom"]
    assert_true(custom == nil or custom["My Locations"] == nil or #custom["My Locations"] == 0,
        "Empty name should not be saved")
end

return T
