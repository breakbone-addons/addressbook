AddressBook = AddressBook or {}

-- UI Constants
AddressBook.UI = AddressBook.UI or {}
local UI = AddressBook.UI

UI.FRAME_WIDTH = 600
UI.FRAME_HEIGHT = 450
UI.CATEGORY_WIDTH = 160
UI.ROW_HEIGHT = 20
UI.HEADER_HEIGHT = 30
UI.FOOTER_HEIGHT = 0
UI.PADDING = 8
UI.SCROLL_STEP = UI.ROW_HEIGHT * 3

-- Colors
UI.COLOR_HEADER = { r = 1.0, g = 0.82, b = 0.0 }
UI.COLOR_SELECTED = { r = 0.2, g = 0.4, b = 0.8, a = 0.4 }
UI.COLOR_HOVER = { r = 0.3, g = 0.3, b = 0.3, a = 0.3 }
UI.COLOR_CUSTOM = { r = 0.4, g = 0.8, b = 1.0 }
UI.COLOR_NORMAL = { r = 1.0, g = 1.0, b = 1.0 }
UI.COLOR_CATEGORY = { r = 1.0, g = 0.82, b = 0.0 }
UI.COLOR_SUBCATEGORY = { r = 0.8, g = 0.8, b = 0.8 }

-- Frame pool for entry rows
AddressBook.framePool = {}

-- Get or create a pooled row frame
function AddressBook:GetPooledRow(parent)
    local row = tremove(self.framePool)
    if not row then
        row = CreateFrame("Button", nil, parent, "BackdropTemplate")
        row:SetHeight(UI.ROW_HEIGHT)

        -- Highlight texture
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(UI.COLOR_HOVER.r, UI.COLOR_HOVER.g, UI.COLOR_HOVER.b, UI.COLOR_HOVER.a)
        row._highlight = highlight

        -- Selected texture
        local selected = row:CreateTexture(nil, "BACKGROUND")
        selected:SetAllPoints()
        selected:SetColorTexture(UI.COLOR_SELECTED.r, UI.COLOR_SELECTED.g, UI.COLOR_SELECTED.b, UI.COLOR_SELECTED.a)
        selected:Hide()
        row._selected = selected

        -- Name text
        local nameText = row:CreateFontString(nil, "OVERLAY", "AddressBookFontSmall")
        nameText:SetPoint("LEFT", row, "LEFT", 4, 0)
        nameText:SetPoint("RIGHT", row, "LEFT", 164, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)
        nameText:SetNonSpaceWrap(false)
        row._nameText = nameText

        -- Zone text
        local zoneText = row:CreateFontString(nil, "OVERLAY", "AddressBookFontSmall")
        zoneText:SetPoint("LEFT", row, "LEFT", 168, 0)
        zoneText:SetPoint("RIGHT", row, "LEFT", 278, 0)
        zoneText:SetJustifyH("LEFT")
        zoneText:SetWordWrap(false)
        zoneText:SetNonSpaceWrap(false)
        zoneText:SetTextColor(0.7, 0.7, 0.7)
        row._zoneText = zoneText

        -- Note text
        local noteText = row:CreateFontString(nil, "OVERLAY", "AddressBookFontSmall")
        noteText:SetPoint("LEFT", row, "LEFT", 282, 0)
        noteText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        noteText:SetJustifyH("LEFT")
        noteText:SetWordWrap(false)
        noteText:SetNonSpaceWrap(false)
        noteText:SetTextColor(0.6, 0.6, 0.6)
        row._noteText = noteText

        -- Custom indicator
        local customIcon = row:CreateFontString(nil, "OVERLAY", "AddressBookFontSmall")
        customIcon:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        customIcon:SetText("")
        customIcon:SetTextColor(UI.COLOR_CUSTOM.r, UI.COLOR_CUSTOM.g, UI.COLOR_CUSTOM.b)
        row._customIcon = customIcon
    end

    row:SetParent(parent)
    row:Show()
    return row
end

-- Return a row to the pool
function AddressBook:RecycleRow(row)
    row:Hide()
    row:ClearAllPoints()
    row:SetScript("OnClick", nil)
    row:SetScript("OnDoubleClick", nil)
    row:SetScript("OnEnter", nil)
    row:SetScript("OnLeave", nil)
    row._data = nil
    row._entryIndex = nil
    row._isCustom = nil
    if row._selected then row._selected:Hide() end
    self.framePool[#self.framePool + 1] = row
end

-- Create a search box
function AddressBook:CreateSearchBox(parent, width)
    local box = CreateFrame("EditBox", "AddressBookSearchBox", parent, "InputBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box:SetMaxLetters(50)

    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    return box
end

-- Create a standard button
function AddressBook:CreateButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 80, height or 22)
    btn:SetText(text)
    return btn
end

-- Create a category tree button
function AddressBook:CreateCategoryButton(parent, text, level, isExpanded, noArrow)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(18)

    local indent = (level - 1) * 12

    -- Toggle icon for expand/collapse (level 1 categories only)
    local toggleIcon = btn:CreateTexture(nil, "OVERLAY")
    toggleIcon:SetSize(14, 14)
    toggleIcon:SetPoint("LEFT", btn, "LEFT", indent, 0)
    btn._toggleIcon = toggleIcon

    local label = btn:CreateFontString(nil, "OVERLAY", "AddressBookFontSmall")
    label:SetPoint("LEFT", toggleIcon, "RIGHT", 2, 0)
    label:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    btn._label = label

    if level == 1 then
        label:SetTextColor(UI.COLOR_CATEGORY.r, UI.COLOR_CATEGORY.g, UI.COLOR_CATEGORY.b)
        if noArrow then
            toggleIcon:SetTexture(nil)
        elseif isExpanded then
            toggleIcon:SetTexture("Interface\\Buttons\\UI-MinusButton-UP")
        else
            toggleIcon:SetTexture("Interface\\Buttons\\UI-PlusButton-UP")
        end
    else
        label:SetTextColor(UI.COLOR_SUBCATEGORY.r, UI.COLOR_SUBCATEGORY.g, UI.COLOR_SUBCATEGORY.b)
        toggleIcon:SetTexture(nil)
    end

    -- Highlight
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.3, 0.3, 0.3, 0.3)

    -- Selected background
    local sel = btn:CreateTexture(nil, "BACKGROUND")
    sel:SetAllPoints()
    sel:SetColorTexture(UI.COLOR_SELECTED.r, UI.COLOR_SELECTED.g, UI.COLOR_SELECTED.b, UI.COLOR_SELECTED.a)
    sel:Hide()
    btn._selectedBg = sel

    return btn
end

-- Persistent context menu frame
local contextMenuFrame = CreateFrame("Frame", "AddressBookContextMenu", UIParent, "UIDropDownMenuTemplate")

-- Context menu for entry rows
function AddressBook:ShowEntryContextMenu(row)
    local data = row._data
    if not data then return end

    local function InitMenu(self, level)
        if not level then return end

        local info = UIDropDownMenu_CreateInfo()

        -- Title
        info.text = data.entry.name
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        -- Set Waypoint
        info = UIDropDownMenu_CreateInfo()
        info.text = "Set Waypoint"
        info.notCheckable = true
        info.func = function()
            AddressBook:SetWaypoint(data.entry)
        end
        UIDropDownMenu_AddButton(info, level)

        -- Set All Waypoints (for entries with multiple spawns)
        if data.entry.spawns and #data.entry.spawns > 1 then
            info = UIDropDownMenu_CreateInfo()
            info.text = "Set All Waypoints (" .. #data.entry.spawns .. ")"
            info.notCheckable = true
            info.func = function()
                AddressBook:SetAllWaypoints(data.entry)
            end
            UIDropDownMenu_AddButton(info, level)
        end

        -- Favorite toggle
        info = UIDropDownMenu_CreateInfo()
        local isFav = AddressBook:IsFavorite(data.entry)
        info.text = isFav and "Remove Favorite" or "Add Favorite"
        info.notCheckable = true
        info.func = function()
            AddressBook:ToggleFavorite(data.entry)
        end
        UIDropDownMenu_AddButton(info, level)

        if data.isCustom then
            -- Edit
            info = UIDropDownMenu_CreateInfo()
            info.text = "Edit"
            info.notCheckable = true
            info.func = function()
                if AddressBook.ShowEditDialog then
                    AddressBook:ShowEditDialog(data)
                end
            end
            UIDropDownMenu_AddButton(info, level)

            -- Delete
            info = UIDropDownMenu_CreateInfo()
            info.text = "Delete"
            info.notCheckable = true
            info.func = function()
                AddressBook:RemoveCustomEntry(data.category, data.subcategory, data.index)
            end
            UIDropDownMenu_AddButton(info, level)
        end

        -- Cancel
        info = UIDropDownMenu_CreateInfo()
        info.text = "Cancel"
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
    end

    UIDropDownMenu_Initialize(contextMenuFrame, InitMenu, "MENU")
    ToggleDropDownMenu(1, nil, contextMenuFrame, "cursor", 0, 0)
end
