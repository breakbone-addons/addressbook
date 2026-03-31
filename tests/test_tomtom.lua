-- Tests for AddressBook TomTom integration

local T = {}

function T.test_has_tomtom_false_when_nil()
    TomTom = nil
    assert_false(AddressBook:HasTomTom())
end

function T.test_has_tomtom_true_when_available()
    TomTom = { AddWaypoint = function() return {} end }
    assert_true(AddressBook:HasTomTom())
    TomTom = nil
end

function T.test_set_waypoint_calls_tomtom()
    local called = false
    local capturedArgs = {}
    TomTom = {
        AddWaypoint = function(self, m, x, y, opts)
            called = true
            capturedArgs = { m = m, x = x, y = y, opts = opts }
            return { m, x, y }
        end,
        RemoveWaypoint = function() end,
        IsValidWaypoint = function() return true end,
    }

    AddressBook:SetWaypoint({ name = "Test", zone = "Shattrath City", x = 56.25, y = 81.54, mapID = 1955 })

    assert_true(called, "TomTom:AddWaypoint should have been called")
    assert_equal(1955, capturedArgs.m)
    -- Coordinates should be divided by 100
    assert_near(0.5625, capturedArgs.x)
    assert_near(0.8154, capturedArgs.y)
    assert_equal("Test", capturedArgs.opts.title)

    TomTom = nil
end

function T.test_set_waypoint_fallback_without_tomtom()
    TomTom = nil
    -- Should not error, just print coords to chat
    AddressBook:SetWaypoint({ name = "Test", zone = "Shattrath City", x = 56.25, y = 81.54, mapID = 1955 })
    -- Verify it printed something
    assert_true(#MockWoW._chatMessages > 0, "Should print fallback message to chat")
end

function T.test_clear_waypoint_no_active()
    -- Should not error when no waypoint is active
    AddressBook.activeWaypoint = nil
    AddressBook:ClearWaypoint()
    assert_nil(AddressBook.activeWaypoint)
end

function T.test_clear_waypoint_removes_active()
    local removed = false
    TomTom = {
        AddWaypoint = function(self, m, x, y, opts) return { m, x, y } end,
        RemoveWaypoint = function() removed = true end,
        IsValidWaypoint = function() return true end,
    }

    AddressBook:SetWaypoint({ name = "Test", zone = "Z", x = 50, y = 50, mapID = 1955 })
    assert_not_nil(AddressBook.activeWaypoint)

    AddressBook:ClearWaypoint()
    assert_true(removed, "TomTom:RemoveWaypoint should have been called")
    assert_nil(AddressBook.activeWaypoint)

    TomTom = nil
end

return T
