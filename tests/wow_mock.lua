-- WoW API Mock Layer for AddressBook Tests
-- Provides stubs for WoW globals, API functions, and data tables.
-- Call MockWoW.reset() between tests to restore clean state.

MockWoW = MockWoW or {}

-- ============================================================
-- CONFIGURABLE STATE
-- ============================================================

MockWoW._playerFaction = "Alliance"
MockWoW._playerMapID = 1955  -- Shattrath City
MockWoW._playerX = 0.5625
MockWoW._playerY = 0.8154
MockWoW._chatMessages = {}

-- Map database: [mapID] = { name, mapType, parentMapID }
MockWoW._mapData = {}

-- ============================================================
-- RESET
-- ============================================================

function MockWoW.reset()
    MockWoW._playerFaction = "Alliance"
    MockWoW._playerMapID = 1955
    MockWoW._playerX = 0.5625
    MockWoW._playerY = 0.8154
    MockWoW._chatMessages = {}

    -- Reset addon globals
    AddressBook = nil
    AddressBookDB = nil
    AddressBookCharDB = nil

    -- Reset UI stub globals
    StaticPopupDialogs = StaticPopupDialogs or {}
    SlashCmdList = SlashCmdList or {}
    SLASH_ADDRESSBOOK1 = nil
    SLASH_ADDRESSBOOK2 = nil

    -- Reload addon source files (non-UI)
    dofile("Core.lua")
    dofile("Data.lua")
    dofile("MapResolver.lua")
    dofile("UserData.lua")
    dofile("TomTomIntegration.lua")

    -- Initialize saved variables for testing
    AddressBookDB = {
        custom = {},
        minimap = {},
        settings = { showFactionOnly = false },
        favorites = {},
    }
    AddressBookCharDB = {}
end

-- ============================================================
-- HELPERS
-- ============================================================

function MockWoW.SetPlayerZone(mapID, x, y)
    MockWoW._playerMapID = mapID
    MockWoW._playerX = x or 0.5
    MockWoW._playerY = y or 0.5
end

function MockWoW.SetFaction(faction)
    MockWoW._playerFaction = faction
end

function MockWoW.SetMapData(mapID, name, mapType, parentMapID)
    MockWoW._mapData[mapID] = {
        mapID = mapID,
        name = name,
        mapType = mapType or 3,  -- Zone type
        parentMapID = parentMapID or 0,
    }
end

-- ============================================================
-- LUA 5.4 COMPAT
-- ============================================================

strmatch = strmatch or string.match
strfind = strfind or string.find
strsub = strsub or string.sub
strlower = strlower or string.lower
strupper = strupper or string.upper
strlen = strlen or string.len
strtrim = strtrim or function(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$")
end
strsplit = strsplit or function(delimiter, str, max)
    if not str then return nil end
    local parts = {}
    local pattern = "(.-)" .. delimiter
    local last_end = 1
    local s, e, cap = str:find(pattern, 1)
    while s do
        if s ~= 1 or cap ~= "" then
            parts[#parts + 1] = cap
        end
        last_end = e + 1
        if max and #parts >= max - 1 then break end
        s, e, cap = str:find(pattern, last_end)
    end
    parts[#parts + 1] = str:sub(last_end)
    return table.unpack(parts)
end

format = format or string.format
tinsert = tinsert or table.insert
tremove = tremove or table.remove

function wipe(t)
    if not t then return end
    for k in pairs(t) do t[k] = nil end
    return t
end

-- ============================================================
-- WOW API STUBS
-- ============================================================

function UnitFactionGroup(unit)
    if unit == "player" then
        return MockWoW._playerFaction
    end
    return nil
end

-- C_Map namespace
C_Map = C_Map or {}

function C_Map.GetBestMapForUnit(unit)
    if unit == "player" then
        return MockWoW._playerMapID
    end
    return nil
end

function C_Map.GetPlayerMapPosition(mapID, unit)
    if unit == "player" then
        return {
            GetXY = function()
                return MockWoW._playerX, MockWoW._playerY
            end
        }
    end
    return nil
end

function C_Map.GetMapInfo(mapID)
    if not mapID then return nil end
    local data = MockWoW._mapData[mapID]
    if data then return data end
    return nil
end

-- Enum namespace
Enum = Enum or {}
Enum.UIMapType = Enum.UIMapType or {
    Cosmic = 0,
    World = 1,
    Continent = 2,
    Zone = 3,
    Dungeon = 4,
    Micro = 5,
    Orphan = 6,
}

-- ============================================================
-- WOW UI STUBS
-- ============================================================

-- Frame stub
local FrameMethods = {}
FrameMethods.__index = function(t, k)
    local v = rawget(FrameMethods, k)
    if v then return v end
    return function() end
end
function FrameMethods:RegisterEvent() end
function FrameMethods:UnregisterEvent() end
function FrameMethods:SetScript() end
function FrameMethods:Show() end
function FrameMethods:Hide() end
function FrameMethods:IsShown() return false end
function FrameMethods:SetPoint() end
function FrameMethods:SetSize() end
function FrameMethods:SetWidth() end
function FrameMethods:SetHeight() end
function FrameMethods:CreateTexture() return setmetatable({}, FrameMethods) end
function FrameMethods:CreateFontString() return setmetatable({}, FrameMethods) end
function FrameMethods:SetTexture() end
function FrameMethods:SetText() end
function FrameMethods:SetFont() end
function FrameMethods:SetTextColor() end
function FrameMethods:SetBackdrop() end
function FrameMethods:SetBackdropColor() end
function FrameMethods:SetBackdropBorderColor() end
function FrameMethods:SetAllPoints() end
function FrameMethods:GetParent() return nil end
function FrameMethods:SetParent() end
function FrameMethods:GetText() return nil end

function CreateFrame(frameType, name, parent, template)
    local f = setmetatable({}, FrameMethods)
    if name then _G[name] = f end
    return f
end

function CreateFont(name)
    local f = setmetatable({}, FrameMethods)
    if name then _G[name] = f end
    return f
end

-- hooksecurefunc stub
function hooksecurefunc() end

-- LibStub stub
LibStub = function(name, silent)
    if name == "LibDataBroker-1.1" then
        return {
            NewDataObject = function(self, objName, obj) return obj end,
        }
    end
    if name == "LibDBIcon-1.0" then
        return {
            Register = function() end,
        }
    end
    return nil
end

-- StaticPopup stub
StaticPopupDialogs = StaticPopupDialogs or {}
function StaticPopup_Show() end

-- UIDropDownMenu stubs
function UIDropDownMenu_Initialize() end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton() end
function UIDropDownMenu_SetWidth() end
function UIDropDownMenu_SetText() end

-- DEFAULT_CHAT_FRAME
DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME or {
    AddMessage = function(self, msg)
        MockWoW._chatMessages[#MockWoW._chatMessages + 1] = msg
    end
}

-- UISpecialFrames
UISpecialFrames = UISpecialFrames or {}

-- GetTime stub
GetTime = GetTime or function() return 0 end

-- GameTooltip stub
GameTooltip = GameTooltip or setmetatable({}, { __index = function() return function() end end })

-- TomTom stub (nil by default, tests can set it)
TomTom = nil

-- ============================================================
-- INITIAL LOAD
-- ============================================================

dofile("Core.lua")
dofile("Data.lua")
dofile("MapResolver.lua")
dofile("UserData.lua")
dofile("TomTomIntegration.lua")

-- Initialize saved variables
AddressBookDB = {
    custom = {},
    minimap = {},
    settings = { showFactionOnly = false },
    favorites = {},
}
AddressBookCharDB = {}
