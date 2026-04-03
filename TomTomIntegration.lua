AddressBook = AddressBook or {}

-- Coordinates in AddressBook are 0-100 scale.
-- TomTom:AddWaypoint expects 0-1 scale, so we divide by 100.

-- Instance entrance lookup: instance zone name -> { zone, x, y }
-- Built lazily from Data.lua Instances category
local instanceEntrances = nil

local function BuildInstanceEntrances()
    instanceEntrances = {}
    if not AddressBook.LocationDB or not AddressBook.LocationDB["Instances"] then return end
    for _, subcategory in pairs(AddressBook.LocationDB["Instances"]) do
        for _, entry in ipairs(subcategory) do
            instanceEntrances[entry.name] = {
                zone = entry.zone,
                x = entry.x,
                y = entry.y,
            }
        end
    end
end

-- Check if a zone name is an instance and the player is NOT inside it
-- Returns entrance entry if we should redirect, nil otherwise
function AddressBook:GetInstanceEntrance(zoneName)
    if not instanceEntrances then BuildInstanceEntrances() end
    local entrance = instanceEntrances[zoneName]
    if not entrance then return nil end

    -- Check if the player is currently inside this instance
    local playerZone = self:GetCurrentZoneName()
    if playerZone and playerZone == zoneName then
        -- Player is inside the instance, use instance coordinates directly
        return nil
    end

    return entrance
end

-- Set a TomTom waypoint for an entry, with fallback to chat coordinates
function AddressBook:SetWaypoint(entry)
    if not entry or not entry.x or not entry.y then
        self:Print("Invalid location data.")
        return
    end

    -- Skip waypoint for instance creatures with placeholder coords (-1, -1)
    if entry.x < 0 or entry.y < 0 then
        local entrance = self:GetInstanceEntrance(entry.zone)
        if entrance then
            -- Outside: redirect to entrance
            entry = {
                name = entry.name,
                zone = entrance.zone,
                x = entrance.x,
                y = entrance.y,
                note = entry.note,
            }
            self:Print(entry.name .. " is inside " .. (entry.zone or "an instance") .. " — waypoint set to entrance")
        else
            -- Inside the instance but no real coords
            self:Print(entry.name .. " is in this instance (no precise coordinates available)")
            return
        end
    end

    -- Check if this is an instance creature and player is outside
    local entrance = self:GetInstanceEntrance(entry.zone)
    local wpX, wpY, wpZone, wpMapID, wpTitle

    if entrance then
        -- Redirect to instance entrance
        wpZone = entrance.zone
        wpX = entrance.x
        wpY = entrance.y
        wpMapID = self:GetMapIDForZone(wpZone)
        wpTitle = entry.name .. " (inside " .. entry.zone .. ")"
    else
        -- Normal waypoint
        wpZone = entry.zone
        wpX = entry.x
        wpY = entry.y
        wpMapID = entry.mapID
        wpTitle = entry.name
    end

    -- Resolve mapID if missing
    if not wpMapID and wpZone then
        wpMapID = self:GetMapIDForZone(wpZone)
    end

    if not wpMapID then
        self:Print("Could not resolve map for " .. (wpZone or "unknown zone"))
        return
    end

    -- Clear previous waypoint if one is active
    self:ClearWaypoint()

    if TomTom and TomTom.AddWaypoint then
        local ok, uid = pcall(TomTom.AddWaypoint, TomTom, wpMapID,
            wpX / 100, wpY / 100, {
            title = wpTitle,
            from = "AddressBook",
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
        if entrance then
            self:Print("Waypoint set: " .. entry.name .. " — pointing to " .. entry.zone .. " entrance in " .. wpZone)
        else
            self:Print("Waypoint set: " .. entry.name)
        end
    else
        self:Print(format("|cffffd100%s|r: %s (|cff00ff00%.1f, %.1f|r)", wpTitle, wpZone, wpX, wpY))
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

-- Set waypoints for ALL spawn points of a multi-spawn entry
function AddressBook:SetAllWaypoints(entry)
    if not entry or not entry.spawns or #entry.spawns == 0 then
        self:Print("No spawn data available.")
        return
    end

    -- Check if this is an instance creature and player is outside
    local entrance = self:GetInstanceEntrance(entry.zone)
    if entrance then
        -- Outside the instance: just set a single waypoint to the entrance
        self:SetWaypoint(entry)
        return
    end

    -- Resolve mapID if missing
    local mapID = entry.mapID
    if not mapID and entry.zone then
        mapID = self:GetMapIDForZone(entry.zone)
    end
    if not mapID then
        self:Print("Could not resolve map for " .. (entry.zone or "unknown zone"))
        return
    end

    -- Clear previous waypoints
    self:ClearAllWaypoints()

    if TomTom and TomTom.AddWaypoint then
        self.activeWaypoints = {}
        local count = 0
        for i, spawn in ipairs(entry.spawns) do
            local ok, uid = pcall(TomTom.AddWaypoint, TomTom, mapID,
                spawn[1] / 100, spawn[2] / 100, {
                title = entry.name .. " #" .. i,
                from = "AddressBook",
                persistent = false,
                minimap = true,
                world = true,
                crazy = (i == 1),
            })
            if ok and uid then
                self.activeWaypoints[#self.activeWaypoints + 1] = uid
                count = count + 1
            end
        end
        self:Print(format("Set %d waypoints for %s", count, entry.name))
    else
        self:Print(format("|cffffd100%s|r: %d spawn points in %s", entry.name, #entry.spawns, entry.zone))
        self:Print("Install TomTom for waypoint arrow navigation.")
    end
end

-- Clear all multi-spawn waypoints
function AddressBook:ClearAllWaypoints()
    self:ClearWaypoint()
    if self.activeWaypoints then
        if TomTom and TomTom.RemoveWaypoint then
            for _, uid in ipairs(self.activeWaypoints) do
                local ok, isValid = pcall(TomTom.IsValidWaypoint, TomTom, uid)
                if ok and isValid then
                    TomTom:RemoveWaypoint(uid)
                end
            end
        end
        self.activeWaypoints = nil
    end
end

-- Check if TomTom is available
function AddressBook:HasTomTom()
    return TomTom and TomTom.AddWaypoint and true or false
end
