-- Tests for AddressBook favorites system

local T = {}

local function makeEntry(name, zone, x, y, faction, note)
    return { name = name, zone = zone or "Stormwind City", x = x or 50, y = y or 50, faction = faction, note = note }
end

function T.test_get_favorite_key_format()
    local entry = makeEntry("Test NPC", "Orgrimmar")
    local key = AddressBook:GetFavoriteKey(entry)
    assert_equal("Test NPC|Orgrimmar", key)
end

function T.test_is_favorite_returns_false_when_not_favorited()
    local entry = makeEntry("Test NPC", "Orgrimmar")
    assert_false(AddressBook:IsFavorite(entry))
end

function T.test_toggle_favorite_adds_entry()
    local entry = makeEntry("Test NPC", "Orgrimmar", 55, 45, "Horde", "Innkeeper")
    AddressBook:ToggleFavorite(entry)
    assert_true(AddressBook:IsFavorite(entry))
end

function T.test_toggle_favorite_removes_entry()
    local entry = makeEntry("Test NPC", "Orgrimmar")
    AddressBook:ToggleFavorite(entry)
    assert_true(AddressBook:IsFavorite(entry))
    AddressBook:ToggleFavorite(entry)
    assert_false(AddressBook:IsFavorite(entry))
end

function T.test_favorite_preserves_fields()
    local entry = makeEntry("Innkeeper Haelthol", "Shattrath City", 56.25, 81.54, nil, "Innkeeper")
    AddressBook:ToggleFavorite(entry)

    local key = AddressBook:GetFavoriteKey(entry)
    local stored = AddressBookDB.favorites[key]
    assert_not_nil(stored)
    assert_equal("Innkeeper Haelthol", stored.name)
    assert_equal("Shattrath City", stored.zone)
    assert_equal(56.25, stored.x)
    assert_equal(81.54, stored.y)
    assert_equal("Innkeeper", stored.note)
end

function T.test_get_favorites_returns_sorted()
    AddressBook:ToggleFavorite(makeEntry("Zara", "Darnassus"))
    AddressBook:ToggleFavorite(makeEntry("Anna", "Ironforge"))
    AddressBook:ToggleFavorite(makeEntry("Mike", "Orgrimmar"))

    local favs = AddressBook:GetFavorites()
    assert_equal(3, #favs)
    assert_equal("Anna", favs[1].entry.name)
    assert_equal("Mike", favs[2].entry.name)
    assert_equal("Zara", favs[3].entry.name)
end

function T.test_get_favorites_empty()
    local favs = AddressBook:GetFavorites()
    assert_equal(0, #favs)
end

function T.test_favorite_key_handles_special_chars()
    local entry = makeEntry("L'lura Goldspun", "Shattrath City")
    local key = AddressBook:GetFavoriteKey(entry)
    assert_equal("L'lura Goldspun|Shattrath City", key)
end

return T
