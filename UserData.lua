AddressBook = AddressBook or {}

-- Save player's current position as a custom entry
function AddressBook:SaveHere(name, category, note)
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        self:Print("Could not determine your current location.")
        return
    end

    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then
        self:Print("Could not get your map position.")
        return
    end

    local x, y = pos:GetXY()
    -- Convert from 0-1 to 0-100 scale
    x = math.floor(x * 10000) / 100
    y = math.floor(y * 10000) / 100

    local info = C_Map.GetMapInfo(mapID)
    local zoneName = info and info.name or "Unknown"

    category = category or "Custom"
    local subcategory = "My Locations"

    local entry = {
        name = name or "My Location",
        zone = zoneName,
        mapID = mapID,
        x = x,
        y = y,
        note = note,
    }

    self:AddCustomEntry(category, subcategory, entry)

    self:Print(format("Saved '%s' at %s (%.1f, %.1f)", entry.name, zoneName, x, y))
end

-- Save a manually entered location
function AddressBook:SaveManualEntry(name, zone, x, y, note)
    if not name or name == "" then
        self:Print("Name is required.")
        return
    end

    -- Try to resolve mapID from zone name
    local mapID
    if zone and zone ~= "" then
        if self.zoneToMapID then
            mapID = self.zoneToMapID[zone:lower()]
        end
        if not mapID then
            -- Try C_Map lookup
            for id = 1, 2500 do
                local info = C_Map.GetMapInfo(id)
                if info and info.name and info.name:lower() == zone:lower() then
                    mapID = id
                    break
                end
            end
        end
    end

    x = tonumber(x) or 0
    y = tonumber(y) or 0

    local entry = {
        name = name,
        zone = zone or "Unknown",
        mapID = mapID,
        x = x,
        y = y,
        note = note ~= "" and note or nil,
    }

    self:AddCustomEntry("Custom", "My Locations", entry)
    self:Print(format("Added '%s' at %s (%.1f, %.1f)", name, entry.zone, x, y))
end

-- Add a custom entry to the saved variables
function AddressBook:AddCustomEntry(category, subcategory, entry)
    if not AddressBookDB then AddressBookDB = {} end
    if not AddressBookDB.custom then AddressBookDB.custom = {} end
    if not AddressBookDB.custom[category] then AddressBookDB.custom[category] = {} end
    if not AddressBookDB.custom[category][subcategory] then AddressBookDB.custom[category][subcategory] = {} end

    local list = AddressBookDB.custom[category][subcategory]
    list[#list + 1] = entry

    if self.RefreshUI then
        self:RefreshUI()
    end
end

-- Remove a custom entry
function AddressBook:RemoveCustomEntry(category, subcategory, index)
    if not AddressBookDB or not AddressBookDB.custom then return end
    local cat = AddressBookDB.custom[category]
    if not cat then return end
    local entries = cat[subcategory]
    if not entries then return end

    if index > 0 and index <= #entries then
        local removed = tremove(entries, index)
        self:Print("Removed '" .. (removed.name or "entry") .. "'")

        -- Clean up empty tables
        if #entries == 0 then
            cat[subcategory] = nil
            local empty = true
            for _ in pairs(cat) do empty = false; break end
            if empty then
                AddressBookDB.custom[category] = nil
            end
        end

        if self.RefreshUI then
            self:RefreshUI()
        end
    end
end

-- Edit a custom entry
function AddressBook:EditCustomEntry(category, subcategory, index, newEntry)
    if not AddressBookDB or not AddressBookDB.custom then return end
    local cat = AddressBookDB.custom[category]
    if not cat then return end
    local entries = cat[subcategory]
    if not entries or not entries[index] then return end

    entries[index] = newEntry

    if self.RefreshUI then
        self:RefreshUI()
    end
end
