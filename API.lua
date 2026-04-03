AddressBook = AddressBook or {}
AddressBook.API = {}

--- Look up an NPC or location by name with optional filters and actions.
-- @param name string Required. NPC/location name to search for.
-- @param opts table Optional.
--   zone: string - narrow search to a specific zone (case-insensitive substring match)
--   category: string - narrow to category ("Creatures", "Trainers", etc.)
--   action: string - "none" (default), "nearest", "all"
--     "none": return results only
--     "nearest": if definitive, set waypoint to nearest spawn
--     "all": if definitive and has spawns, set waypoints to all spawns
--   silent: boolean - if true, suppress chat messages
-- @return results table, isDefinitive boolean
--   results: array of { name, zone, x, y, note, spawns, category, subcategory }
--   isDefinitive: true if all results match the same NPC name
function AddressBook.API:Lookup(name, opts)
    if not name or name == "" then return {}, false end
    opts = opts or {}

    local raw = AddressBook:Search(name)
    if not raw or #raw == 0 then return {}, false end

    -- Filter by zone
    if opts.zone then
        local zl = strlower(opts.zone)
        local filtered = {}
        for _, r in ipairs(raw) do
            if r.entry.zone and strlower(r.entry.zone):find(zl, 1, true) then
                filtered[#filtered + 1] = r
            end
        end
        raw = filtered
    end

    -- Filter by category
    if opts.category then
        local cl = strlower(opts.category)
        local filtered = {}
        for _, r in ipairs(raw) do
            if r.category and strlower(r.category):find(cl, 1, true) then
                filtered[#filtered + 1] = r
            end
        end
        raw = filtered
    end

    if #raw == 0 then return {}, false end

    -- Build clean result copies
    local results = {}
    for _, r in ipairs(raw) do
        local e = r.entry
        results[#results + 1] = {
            name = e.name,
            zone = e.zone,
            x = e.x,
            y = e.y,
            note = e.note,
            faction = e.faction,
            spawns = e.spawns,
            mapID = e.mapID,
            category = r.category,
            subcategory = r.subcategory,
        }
    end

    -- Check definitiveness: all results share the same name
    local isDefinitive = true
    local firstName = strlower(results[1].name)
    for i = 2, #results do
        if strlower(results[i].name) ~= firstName then
            isDefinitive = false
            break
        end
    end

    -- Execute action
    local action = opts.action or "none"
    local silent = opts.silent

    if action ~= "none" then
        if isDefinitive then
            -- Pick the best result (prefer one with spawns, or first)
            local best = results[1]
            for _, r in ipairs(results) do
                if r.spawns and #r.spawns > 0 then
                    best = r
                    break
                end
            end

            -- Resolve mapID if needed
            if not best.mapID and best.zone then
                best.mapID = AddressBook:GetMapIDForZone(best.zone)
            end

            if action == "all" and best.spawns and #best.spawns > 1 then
                AddressBook:SetAllWaypoints(best)
            elseif action == "nearest" and best.spawns and #best.spawns > 1 then
                -- Find nearest spawn to player
                local nearestEntry = self:_FindNearestSpawn(best)
                if nearestEntry then
                    AddressBook:SetWaypoint(nearestEntry)
                else
                    AddressBook:SetWaypoint(best)
                end
            else
                AddressBook:SetWaypoint(best)
            end
        else
            -- Ambiguous: open UI with search
            if not silent then
                self:Search(name)
            end
        end
    end

    return results, isDefinitive
end

--- Set a waypoint to the nearest spawn of a named NPC.
-- @param name string Required. NPC name.
-- @param zone string Optional. Zone to narrow search.
function AddressBook.API:WaypointTo(name, zone)
    local opts = { action = "nearest" }
    if zone then opts.zone = zone end
    return self:Lookup(name, opts)
end

--- Set waypoints at all spawn points for a named NPC.
-- @param name string Required. NPC name.
-- @param zone string Optional. Zone to narrow search.
function AddressBook.API:ShowSpawns(name, zone)
    local opts = { action = "all" }
    if zone then opts.zone = zone end
    return self:Lookup(name, opts)
end

--- Open AddressBook UI with a search query pre-populated.
-- @param query string Required. Search text.
function AddressBook.API:Search(query)
    if not query or query == "" then return end
    if not AddressBook.mainFrame then
        AddressBook:CreateMainFrame()
    end
    AddressBook.mainFrame:Show()
    if AddressBook.mainFrame._searchBox then
        AddressBook.mainFrame._searchBox:SetText(query)
    end
end

--- Find nearest spawn point from a multi-spawn entry relative to the player.
-- @param entry table Entry with spawns array, zone, and mapID.
-- @return table Single-spawn entry for the nearest point, or nil.
function AddressBook.API:_FindNearestSpawn(entry)
    if not entry.spawns or #entry.spawns < 2 then return nil end

    local mapID = entry.mapID
    if not mapID and entry.zone then
        mapID = AddressBook:GetMapIDForZone(entry.zone)
    end
    if not mapID then return nil end

    local playerMap = C_Map.GetBestMapForUnit("player")
    if not playerMap or playerMap ~= mapID then
        -- Not on the same map, can't calculate nearest — use first
        return nil
    end

    local pos = C_Map.GetPlayerMapPosition(playerMap, "player")
    if not pos then return nil end
    local px, py = pos:GetXY()
    px, py = px * 100, py * 100  -- Convert to 0-100 scale

    local bestDist = math.huge
    local bestSpawn = entry.spawns[1]
    for _, spawn in ipairs(entry.spawns) do
        local dx, dy = px - spawn[1], py - spawn[2]
        local dist = dx * dx + dy * dy
        if dist < bestDist then
            bestDist = dist
            bestSpawn = spawn
        end
    end

    return {
        name = entry.name,
        zone = entry.zone,
        x = bestSpawn[1],
        y = bestSpawn[2],
        note = entry.note,
        mapID = mapID,
    }
end
