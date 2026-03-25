AddressBook = AddressBook or {}

-- Coordinates in AddressBook are 0-100 scale.
-- TomTom:AddWaypoint expects 0-1 scale, so we divide by 100.

-- Set a TomTom waypoint for an entry, with fallback to chat coordinates
function AddressBook:SetWaypoint(entry)
    if not entry or not entry.x or not entry.y then
        self:Print("Invalid location data.")
        return
    end

    -- Resolve mapID if missing
    if not entry.mapID and entry.zone then
        entry.mapID = self:GetMapIDForZone(entry.zone)
    end

    if not entry.mapID then
        self:Print("Could not resolve map for " .. (entry.zone or "unknown zone"))
        return
    end

    -- Clear previous waypoint if one is active
    self:ClearWaypoint()

    if TomTom and TomTom.AddWaypoint then
        local ok, uid = pcall(TomTom.AddWaypoint, TomTom, entry.mapID,
            entry.x / 100, entry.y / 100, {
            title = entry.name,
            persistent = false,
            minimap = true,
            world = true,
            crazy = true,
        })

        if not ok then
            self:Print("|cffff0000TomTom error:|r " .. tostring(uid))
            return
        end

        self.activeWaypoint = uid
        self:Print("Waypoint set: " .. entry.name)
    else
        -- Fallback: print coordinates to chat (already 0-100)
        self:Print(format("|cffffd100%s|r: %s (|cff00ff00%.1f, %.1f|r)", entry.name, entry.zone, entry.x, entry.y))
        self:Print("Install TomTom for waypoint arrow navigation.")
    end
end

-- Clear the active waypoint
function AddressBook:ClearWaypoint()
    if self.activeWaypoint then
        if TomTom and TomTom.RemoveWaypoint then
            local ok, isValid = pcall(TomTom.IsValidWaypoint, TomTom, self.activeWaypoint)
            if ok and isValid then
                TomTom:RemoveWaypoint(self.activeWaypoint)
            end
        end
        self.activeWaypoint = nil
    end
end

-- Check if TomTom is available
function AddressBook:HasTomTom()
    return TomTom and TomTom.AddWaypoint and true or false
end
