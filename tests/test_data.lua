-- Data validation tests for AddressBook's built-in location database

local T = {}

function T.test_all_entries_have_required_fields()
    local missing = {}
    for cat, subs in pairs(AddressBook.LocationDB) do
        for sub, entries in pairs(subs) do
            for i, entry in ipairs(entries) do
                if not entry.name or entry.name == "" then
                    missing[#missing + 1] = cat .. "/" .. sub .. " #" .. i .. ": missing name"
                end
                if not entry.zone or entry.zone == "" then
                    missing[#missing + 1] = cat .. "/" .. sub .. " #" .. i .. " (" .. (entry.name or "?") .. "): missing zone"
                end
                if not entry.x then
                    missing[#missing + 1] = cat .. "/" .. sub .. " #" .. i .. " (" .. (entry.name or "?") .. "): missing x"
                end
                if not entry.y then
                    missing[#missing + 1] = cat .. "/" .. sub .. " #" .. i .. " (" .. (entry.name or "?") .. "): missing y"
                end
            end
        end
    end
    assert_equal(0, #missing, "Entries with missing fields:\n" .. table.concat(missing, "\n"))
end

function T.test_coordinates_in_valid_range()
    local out_of_range = {}
    for cat, subs in pairs(AddressBook.LocationDB) do
        for sub, entries in pairs(subs) do
            for i, entry in ipairs(entries) do
                if entry.x and (entry.x < 0 or entry.x > 100) then
                    out_of_range[#out_of_range + 1] = entry.name .. ": x=" .. entry.x
                end
                if entry.y and (entry.y < 0 or entry.y > 100) then
                    out_of_range[#out_of_range + 1] = entry.name .. ": y=" .. entry.y
                end
            end
        end
    end
    assert_equal(0, #out_of_range, "Out of range:\n" .. table.concat(out_of_range, "\n"))
end

function T.test_coordinates_are_numbers()
    local bad = {}
    for cat, subs in pairs(AddressBook.LocationDB) do
        for sub, entries in pairs(subs) do
            for _, entry in ipairs(entries) do
                if type(entry.x) ~= "number" then
                    bad[#bad + 1] = entry.name .. ": x is " .. type(entry.x)
                end
                if type(entry.y) ~= "number" then
                    bad[#bad + 1] = entry.name .. ": y is " .. type(entry.y)
                end
            end
        end
    end
    assert_equal(0, #bad, "Non-number coords:\n" .. table.concat(bad, "\n"))
end

function T.test_faction_values_are_valid()
    local valid = { Alliance = true, Horde = true }
    local bad = {}
    for cat, subs in pairs(AddressBook.LocationDB) do
        for sub, entries in pairs(subs) do
            for _, entry in ipairs(entries) do
                if entry.faction and not valid[entry.faction] then
                    bad[#bad + 1] = entry.name .. ": faction=" .. tostring(entry.faction)
                end
            end
        end
    end
    assert_equal(0, #bad, "Invalid factions:\n" .. table.concat(bad, "\n"))
end

function T.test_category_order_matches_location_db()
    for _, cat in ipairs(AddressBook.CategoryOrder) do
        assert_not_nil(AddressBook.LocationDB[cat],
            "CategoryOrder has '" .. cat .. "' but LocationDB does not")
    end
end

function T.test_subcategory_order_matches_location_db()
    for cat, subs in pairs(AddressBook.SubcategoryOrder) do
        local dbCat = AddressBook.LocationDB[cat]
        if dbCat then
            for _, sub in ipairs(subs) do
                assert_not_nil(dbCat[sub],
                    "SubcategoryOrder[" .. cat .. "] has '" .. sub .. "' but LocationDB does not")
            end
        end
    end
end

function T.test_no_duplicate_entries_in_subcategory()
    local dupes = {}
    for cat, subs in pairs(AddressBook.LocationDB) do
        for sub, entries in pairs(subs) do
            local seen = {}
            for _, entry in ipairs(entries) do
                local key = (entry.name or "") .. "|" .. (entry.zone or "") .. "|" .. tostring(entry.x) .. "|" .. tostring(entry.y)
                if seen[key] then
                    dupes[#dupes + 1] = cat .. "/" .. sub .. ": " .. entry.name .. " in " .. entry.zone
                end
                seen[key] = true
            end
        end
    end
    assert_equal(0, #dupes, "Duplicate entries:\n" .. table.concat(dupes, "\n"))
end

function T.test_database_has_expected_categories()
    local expected = { "Quests", "Instances", "Trainers", "Vendors", "Transportation", "Services", "PvP" }
    for _, cat in ipairs(expected) do
        assert_not_nil(AddressBook.LocationDB[cat], "Missing category: " .. cat)
    end
end

function T.test_entry_count_is_reasonable()
    local count = 0
    for cat, subs in pairs(AddressBook.LocationDB) do
        for sub, entries in pairs(subs) do
            count = count + #entries
        end
    end
    assert_true(count > 5000, "Expected 5000+ entries, got " .. count)
end

function T.test_names_are_strings()
    local bad = {}
    for cat, subs in pairs(AddressBook.LocationDB) do
        for sub, entries in pairs(subs) do
            for _, entry in ipairs(entries) do
                if type(entry.name) ~= "string" then
                    bad[#bad + 1] = cat .. "/" .. sub .. ": name is " .. type(entry.name)
                end
            end
        end
    end
    assert_equal(0, #bad, "Non-string names:\n" .. table.concat(bad, "\n"))
end

return T
