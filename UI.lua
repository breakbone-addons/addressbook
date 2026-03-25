AddressBook = AddressBook or {}

local UI = AddressBook.UI

-- State
local expandedCategories = {}
local selectedCategory = nil
local selectedSubcategory = nil
local selectedEntryData = nil
local displayedRows = {}
local categoryButtons = {}
local searchText = ""
local searchTimer = nil
local selectedContinent = "Auto"  -- nil=All, "Auto"=auto-detect, or continent name
local selectedZone = "Auto"       -- nil=All, "Auto"=auto-detect, or zone name

-- Forward declarations
local RefreshCategoryList, RefreshEntryList, UpdateWaypointButton

function AddressBook:CreateMainFrame()
    if self.mainFrame then return end

    local frame = CreateFrame("Frame", "AddressBookMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(UI.FRAME_WIDTH, UI.FRAME_HEIGHT)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)

    -- Position: restore or center
    if AddressBookCharDB and AddressBookCharDB.windowPos and AddressBookCharDB.windowPos.x then
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", AddressBookCharDB.windowPos.x, AddressBookCharDB.windowPos.y)
    else
        frame:SetPoint("CENTER")
    end

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if AddressBookCharDB then
            local x, y = self:GetLeft(), self:GetTop() - UIParent:GetHeight()
            AddressBookCharDB.windowPos = { x = x, y = y }
        end
    end)

    -- Close on ESC
    tinsert(UISpecialFrames, "AddressBookMainFrame")

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    title:SetText("|cff33bbffAddressBook|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

    -- TomTom status indicator
    local tomtomStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tomtomStatus:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -8, -8)
    if AddressBook:HasTomTom() then
        tomtomStatus:SetText("|cff00ff00TomTom|r")
    else
        tomtomStatus:SetText("|cffff0000No TomTom|r")
    end

    -------------------------------------------------------------------
    -- FILTER ROW (continent, zone, search, save here)
    -------------------------------------------------------------------
    local filterY = -UI.HEADER_HEIGHT - 4

    -- Continent dropdown
    local continentDropdown = CreateFrame("Frame", "AddressBookContinentDropdown", frame, "UIDropDownMenuTemplate")
    continentDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", UI.PADDING + UI.CATEGORY_WIDTH - 12, filterY)
    UIDropDownMenu_SetWidth(continentDropdown, 100)
    UIDropDownMenu_SetText(continentDropdown, "Auto")

    local function ContinentDropdown_Init(self, level)
        local info = UIDropDownMenu_CreateInfo()

        -- Auto option
        info.text = "Auto"
        info.notCheckable = true
        info.func = function()
            selectedContinent = "Auto"
            selectedZone = "Auto"
            UIDropDownMenu_SetText(continentDropdown, "Auto")
            UIDropDownMenu_SetText(frame._zoneDropdown, "Auto")
            RefreshEntryList()
        end
        UIDropDownMenu_AddButton(info, level)

        -- All option
        info = UIDropDownMenu_CreateInfo()
        info.text = "All Continents"
        info.notCheckable = true
        info.func = function()
            selectedContinent = nil
            selectedZone = nil
            UIDropDownMenu_SetText(continentDropdown, "All")
            UIDropDownMenu_SetText(frame._zoneDropdown, "All")
            RefreshEntryList()
        end
        UIDropDownMenu_AddButton(info, level)

        -- Continent list
        local continents = AddressBook:GetContinents()
        for _, name in ipairs(continents) do
            info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.notCheckable = true
            info.func = function()
                selectedContinent = name
                selectedZone = nil
                UIDropDownMenu_SetText(continentDropdown, name)
                UIDropDownMenu_SetText(frame._zoneDropdown, "All")
                RefreshEntryList()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(continentDropdown, ContinentDropdown_Init)

    local contLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    contLabel:SetPoint("RIGHT", continentDropdown, "LEFT", 16, 2)
    contLabel:SetText("Continent:")
    contLabel:SetTextColor(UI.COLOR_HEADER.r, UI.COLOR_HEADER.g, UI.COLOR_HEADER.b)

    -- Zone dropdown
    local zoneDropdown = CreateFrame("Frame", "AddressBookZoneDropdown", frame, "UIDropDownMenuTemplate")
    zoneDropdown:SetPoint("LEFT", continentDropdown, "RIGHT", -16, 0)
    UIDropDownMenu_SetWidth(zoneDropdown, 110)
    UIDropDownMenu_SetText(zoneDropdown, "Auto")
    frame._zoneDropdown = zoneDropdown

    local function ZoneDropdown_Init(self, level)
        local info = UIDropDownMenu_CreateInfo()

        -- Auto option
        info.text = "Auto"
        info.notCheckable = true
        info.func = function()
            selectedZone = "Auto"
            UIDropDownMenu_SetText(zoneDropdown, "Auto")
            RefreshEntryList()
        end
        UIDropDownMenu_AddButton(info, level)

        -- All option
        info = UIDropDownMenu_CreateInfo()
        info.text = "All Zones"
        info.notCheckable = true
        info.func = function()
            selectedZone = nil
            UIDropDownMenu_SetText(zoneDropdown, "All")
            RefreshEntryList()
        end
        UIDropDownMenu_AddButton(info, level)

        -- Zone list based on selected continent
        local zones
        if selectedContinent and selectedContinent ~= "Auto" then
            zones = AddressBook:GetZonesForContinent(selectedContinent)
        else
            zones = AddressBook:GetAllZonesSorted()
        end
        for _, name in ipairs(zones) do
            info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.notCheckable = true
            info.func = function()
                selectedZone = name
                UIDropDownMenu_SetText(zoneDropdown, name)
                -- Auto-set continent if not already set
                if not selectedContinent or selectedContinent == "Auto" then
                    local cont = AddressBook:GetContinentForZone(name)
                    if cont then
                        selectedContinent = cont
                        UIDropDownMenu_SetText(continentDropdown, cont)
                    end
                end
                RefreshEntryList()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(zoneDropdown, ZoneDropdown_Init)

    -- Search box (second row)
    local filterY2 = filterY - 26
    local searchBox = self:CreateSearchBox(frame, 160)
    searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", UI.PADDING + UI.CATEGORY_WIDTH + 50, filterY2)

    searchBox:SetScript("OnTextChanged", function(self)
        searchText = strtrim(self:GetText() or "")
        RefreshEntryList()
    end)

    frame._searchBox = searchBox
    frame._continentDropdown = continentDropdown

    -- Save Here button
    local saveHereBtn = AddressBook:CreateButton(frame, "Save Here", 80, 22)
    saveHereBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -UI.PADDING - 8, filterY2)
    saveHereBtn:SetScript("OnClick", function()
        StaticPopup_Show("ADDRESSBOOK_SAVE_HERE")
    end)

    -------------------------------------------------------------------
    -- CATEGORY PANEL (left side)
    -------------------------------------------------------------------
    local catPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    catPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", UI.PADDING, -(UI.HEADER_HEIGHT + 58))
    catPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", UI.PADDING, UI.FOOTER_HEIGHT + UI.PADDING)
    catPanel:SetWidth(UI.CATEGORY_WIDTH)
    catPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    catPanel:SetBackdropColor(0.08, 0.08, 0.08, 0.8)

    -- Category scroll frame
    local catScroll = CreateFrame("ScrollFrame", "AddressBookCatScroll", catPanel, "UIPanelScrollFrameTemplate")
    catScroll:SetPoint("TOPLEFT", catPanel, "TOPLEFT", 4, -4)
    catScroll:SetPoint("BOTTOMRIGHT", catPanel, "BOTTOMRIGHT", -22, 4)

    local catChild = CreateFrame("Frame", nil, catScroll)
    catChild:SetWidth(UI.CATEGORY_WIDTH - 26)
    catScroll:SetScrollChild(catChild)

    frame._catPanel = catPanel
    frame._catScroll = catScroll
    frame._catChild = catChild

    -------------------------------------------------------------------
    -- ENTRY LIST (right side)
    -------------------------------------------------------------------
    local listPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    listPanel:SetPoint("TOPLEFT", catPanel, "TOPRIGHT", 4, 0)
    listPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -UI.PADDING, UI.FOOTER_HEIGHT + UI.PADDING)
    listPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    listPanel:SetBackdropColor(0.08, 0.08, 0.08, 0.8)

    -- Column headers
    local headerName = listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerName:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 8, -4)
    headerName:SetText("Name")
    headerName:SetTextColor(UI.COLOR_HEADER.r, UI.COLOR_HEADER.g, UI.COLOR_HEADER.b)

    local headerZone = listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerZone:SetPoint("LEFT", headerName, "LEFT", 164, 0)
    headerZone:SetText("Zone")
    headerZone:SetTextColor(UI.COLOR_HEADER.r, UI.COLOR_HEADER.g, UI.COLOR_HEADER.b)

    local headerNote = listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerNote:SetPoint("LEFT", headerName, "LEFT", 278, 0)
    headerNote:SetText("Note")
    headerNote:SetTextColor(UI.COLOR_HEADER.r, UI.COLOR_HEADER.g, UI.COLOR_HEADER.b)

    -- Entry scroll frame
    local entryScroll = CreateFrame("ScrollFrame", "AddressBookEntryScroll", listPanel, "UIPanelScrollFrameTemplate")
    entryScroll:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 4, -20)
    entryScroll:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -22, 4)

    local entryChild = CreateFrame("Frame", nil, entryScroll)
    entryChild:SetWidth(listPanel:GetWidth() - 26)
    entryScroll:SetScrollChild(entryChild)

    frame._listPanel = listPanel
    frame._entryScroll = entryScroll
    frame._entryChild = entryChild

    -------------------------------------------------------------------
    -- FOOTER BUTTONS
    -------------------------------------------------------------------
    local waypointBtn = AddressBook:CreateButton(frame, "Set Waypoint", 100, 24)
    waypointBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -UI.PADDING - 8, UI.PADDING + 8)
    waypointBtn:Disable()
    waypointBtn:SetScript("OnClick", function()
        if selectedEntryData then
            AddressBook:SetWaypoint(selectedEntryData.entry)
        end
    end)
    frame._waypointBtn = waypointBtn

    local clearBtn = AddressBook:CreateButton(frame, "Clear WP", 70, 24)
    clearBtn:SetPoint("RIGHT", waypointBtn, "LEFT", -4, 0)
    clearBtn:SetScript("OnClick", function()
        AddressBook:ClearWaypoint()
        AddressBook:Print("Waypoint cleared.")
    end)

    local addBtn = AddressBook:CreateButton(frame, "Add Entry", 80, 24)
    addBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", UI.PADDING + 8, UI.PADDING + 8)
    addBtn:SetScript("OnClick", function()
        StaticPopup_Show("ADDRESSBOOK_ADD_ENTRY")
    end)

    -- Faction filter checkbox
    local factionCheck = CreateFrame("CheckButton", "AddressBookFactionFilter", frame, "UICheckButtonTemplate")
    factionCheck:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
    factionCheck:SetSize(24, 24)
    factionCheck:SetChecked(AddressBookDB and AddressBookDB.settings and AddressBookDB.settings.showFactionOnly)
    _G["AddressBookFactionFilterText"]:SetText("My Faction")
    _G["AddressBookFactionFilterText"]:SetFontObject("GameFontNormalSmall")
    factionCheck:SetScript("OnClick", function(self)
        if AddressBookDB and AddressBookDB.settings then
            AddressBookDB.settings.showFactionOnly = self:GetChecked()
            RefreshEntryList()
        end
    end)

    -- Entry count
    local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("BOTTOM", frame, "BOTTOM", 0, UI.PADDING + 12)
    countText:SetTextColor(0.5, 0.5, 0.5)
    frame._countText = countText

    -------------------------------------------------------------------
    -- STATIC POPUPS
    -------------------------------------------------------------------
    StaticPopupDialogs["ADDRESSBOOK_SAVE_HERE"] = {
        text = "Save current location as:",
        button1 = "Save",
        button2 = "Cancel",
        hasEditBox = true,
        editBoxWidth = 200,
        OnAccept = function(self)
            local name = self.editBox:GetText()
            if name and name ~= "" then
                AddressBook:SaveHere(name, "Custom", nil)
            end
        end,
        OnShow = function(self)
            self.editBox:SetText("My Location")
            self.editBox:HighlightText()
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            local name = parent.editBox:GetText()
            if name and name ~= "" then
                AddressBook:SaveHere(name, "Custom", nil)
            end
            parent:Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopupDialogs["ADDRESSBOOK_ADD_ENTRY"] = {
        text = "Enter location name:",
        button1 = "Add",
        button2 = "Cancel",
        hasEditBox = true,
        editBoxWidth = 200,
        OnAccept = function(self)
            local name = self.editBox:GetText()
            if name and name ~= "" then
                if AddressBook.ShowEditDialog then
                    AddressBook:ShowEditDialog(nil, name)
                else
                    AddressBook:SaveHere(name, "Custom", nil)
                end
            end
        end,
        OnShow = function(self)
            self.editBox:SetText("")
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            local name = parent.editBox:GetText()
            if name and name ~= "" then
                AddressBook:SaveHere(name, "Custom", nil)
            end
            parent:Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopupDialogs["ADDRESSBOOK_CONFIRM_DELETE"] = {
        text = "Delete '%s' from your address book?",
        button1 = "Delete",
        button2 = "Cancel",
        OnAccept = function(self, data)
            if data then
                AddressBook:RemoveCustomEntry(data.category, data.subcategory, data.index)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    self.mainFrame = frame

    -- Initial expand
    if AddressBookCharDB and AddressBookCharDB.lastCategory then
        expandedCategories[AddressBookCharDB.lastCategory] = true
        selectedCategory = AddressBookCharDB.lastCategory
        selectedSubcategory = AddressBookCharDB.lastSubcategory
    else
        -- Expand first category
        local cats = self:GetCategories()
        if cats[1] then
            expandedCategories[cats[1].name] = true
            selectedCategory = cats[1].name
            if cats[1].subcategories[1] then
                selectedSubcategory = cats[1].subcategories[1]
            end
        end
    end

    RefreshCategoryList()
    RefreshEntryList()

    frame:Hide()
end

-------------------------------------------------------------------
-- REFRESH: Category List
-------------------------------------------------------------------
RefreshCategoryList = function()
    local frame = AddressBook.mainFrame
    if not frame then return end
    local catChild = frame._catChild

    -- Clear existing buttons
    for _, btn in ipairs(categoryButtons) do
        btn:Hide()
        btn:ClearAllPoints()
    end
    wipe(categoryButtons)

    local categories = AddressBook:GetCategories()
    local yOffset = 0

    -- Use ordered list if available
    local orderedCats = AddressBook.CategoryOrder or {}
    local catLookup = {}
    for _, cat in ipairs(categories) do
        catLookup[cat.name] = cat
    end

    -- Build ordered list, then append any extras
    local orderedList = {}
    for _, catName in ipairs(orderedCats) do
        if catLookup[catName] then
            orderedList[#orderedList + 1] = catLookup[catName]
            catLookup[catName] = nil
        end
    end
    for _, cat in ipairs(categories) do
        if catLookup[cat.name] then
            orderedList[#orderedList + 1] = cat
        end
    end

    for _, cat in ipairs(orderedList) do
        local isExpanded = expandedCategories[cat.name]
        local catBtn = AddressBook:CreateCategoryButton(catChild, cat.name, 1, isExpanded)
        catBtn:SetPoint("TOPLEFT", catChild, "TOPLEFT", 0, -yOffset)
        catBtn:SetPoint("RIGHT", catChild, "RIGHT", 0, 0)

        catBtn._categoryName = cat.name
        catBtn:SetScript("OnClick", function(self)
            expandedCategories[self._categoryName] = not expandedCategories[self._categoryName]
            selectedCategory = self._categoryName
            -- Select first subcategory when expanding
            if expandedCategories[self._categoryName] then
                local subOrder = AddressBook.SubcategoryOrder and AddressBook.SubcategoryOrder[self._categoryName]
                if subOrder and subOrder[1] then
                    selectedSubcategory = subOrder[1]
                elseif cat.subcategories[1] then
                    selectedSubcategory = cat.subcategories[1]
                end
            end
            -- Persist selection
            if AddressBookCharDB then
                AddressBookCharDB.lastCategory = selectedCategory
                AddressBookCharDB.lastSubcategory = selectedSubcategory
            end
            RefreshCategoryList()
            RefreshEntryList()
        end)

        categoryButtons[#categoryButtons + 1] = catBtn
        yOffset = yOffset + 18

        if isExpanded then
            -- Use ordered subcategories if available
            local subOrder = AddressBook.SubcategoryOrder and AddressBook.SubcategoryOrder[cat.name]
            local subs = subOrder or cat.subcategories

            for _, subName in ipairs(subs) do
                local subBtn = AddressBook:CreateCategoryButton(catChild, subName, 2, false)
                subBtn:SetPoint("TOPLEFT", catChild, "TOPLEFT", 0, -yOffset)
                subBtn:SetPoint("RIGHT", catChild, "RIGHT", 0, 0)

                -- Highlight selected subcategory
                if selectedCategory == cat.name and selectedSubcategory == subName then
                    subBtn._selectedBg:Show()
                end

                subBtn._categoryName = cat.name
                subBtn._subcategoryName = subName
                subBtn:SetScript("OnClick", function(self)
                    selectedCategory = self._categoryName
                    selectedSubcategory = self._subcategoryName
                    if AddressBookCharDB then
                        AddressBookCharDB.lastCategory = selectedCategory
                        AddressBookCharDB.lastSubcategory = selectedSubcategory
                    end
                    RefreshCategoryList()
                    RefreshEntryList()
                end)

                categoryButtons[#categoryButtons + 1] = subBtn
                yOffset = yOffset + 18
            end
        end
    end

    catChild:SetHeight(math.max(yOffset, 1))
end

-------------------------------------------------------------------
-- REFRESH: Entry List
-------------------------------------------------------------------
RefreshEntryList = function()
    local frame = AddressBook.mainFrame
    if not frame then return end
    local entryChild = frame._entryChild

    -- Recycle existing rows
    for _, row in ipairs(displayedRows) do
        AddressBook:RecycleRow(row)
    end
    wipe(displayedRows)

    selectedEntryData = nil
    UpdateWaypointButton()

    local entries
    if searchText ~= "" then
        entries = AddressBook:Search(searchText)
    elseif selectedCategory and selectedSubcategory then
        entries = AddressBook:GetEntries(selectedCategory, selectedSubcategory)
    else
        entries = {}
    end

    -- Resolve "Auto" continent/zone from player's current location
    local filterContinent = selectedContinent
    local filterZone = selectedZone
    if filterContinent == "Auto" or filterZone == "Auto" then
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local info = C_Map.GetMapInfo(mapID)
            if info and info.name then
                local autoZone = info.name
                local autoCont = AddressBook:GetContinentForZone(autoZone)
                if filterContinent == "Auto" then
                    filterContinent = autoCont
                end
                if filterZone == "Auto" then
                    filterZone = autoZone
                end
            end
        end
    end

    -- Apply continent/zone filter
    if filterZone or filterContinent then
        local filtered = {}
        for _, data in ipairs(entries) do
            local zone = data.entry.zone
            if filterZone and zone == filterZone then
                filtered[#filtered + 1] = data
            elseif not filterZone and filterContinent then
                local entryContinent = AddressBook:GetContinentForZone(zone)
                if entryContinent == filterContinent then
                    filtered[#filtered + 1] = data
                end
            end
        end
        entries = filtered
    end

    local yOffset = 0
    local listWidth = entryChild:GetParent():GetWidth() - 26

    for i, data in ipairs(entries) do
        local row = AddressBook:GetPooledRow(entryChild)
        row:SetPoint("TOPLEFT", entryChild, "TOPLEFT", 0, -yOffset)
        row:SetWidth(listWidth)

        local e = data.entry
        row._nameText:SetText(e.name or "")
        row._zoneText:SetText(e.zone or "")
        row._noteText:SetText(e.note or "")

        if data.isCustom then
            row._nameText:SetTextColor(UI.COLOR_CUSTOM.r, UI.COLOR_CUSTOM.g, UI.COLOR_CUSTOM.b)
            row._customIcon:SetText("*")
        else
            row._nameText:SetTextColor(UI.COLOR_NORMAL.r, UI.COLOR_NORMAL.g, UI.COLOR_NORMAL.b)
            row._customIcon:SetText("")
        end

        row._data = data
        row._entryIndex = i

        -- Left click: select
        row:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                -- Deselect previous
                for _, r in ipairs(displayedRows) do
                    if r._selected then r._selected:Hide() end
                end
                self._selected:Show()
                selectedEntryData = self._data
                AddressBook.selectedEntry = self._data
                UpdateWaypointButton()
            elseif button == "RightButton" then
                AddressBook:ShowEntryContextMenu(self)
            end
        end)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        -- Double click: set waypoint
        row:SetScript("OnDoubleClick", function(self)
            if self._data then
                AddressBook:SetWaypoint(self._data.entry)
            end
        end)

        -- Tooltip on hover
        row:SetScript("OnEnter", function(self)
            if self._data then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local d = self._data.entry
                GameTooltip:AddLine(d.name, 1, 0.82, 0)
                GameTooltip:AddLine(d.zone, 1, 1, 1)
                if d.note then
                    GameTooltip:AddLine(d.note, 0.7, 0.7, 0.7)
                end
                GameTooltip:AddLine(format("Coordinates: %.1f, %.1f", d.x, d.y), 0.5, 1.0, 0.5)
                if d.faction then
                    local fc = d.faction == "Alliance" and "|cff0070dd" or "|cffb30000"
                    GameTooltip:AddLine(fc .. d.faction .. "|r")
                end
                if self._data.isCustom then
                    GameTooltip:AddLine("|cff66ccffCustom entry|r")
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cffeda55fClick|r to select  |cffeda55fDouble-click|r to set waypoint", 0.5, 0.5, 0.5)
                GameTooltip:AddLine("|cffeda55fRight-click|r for options", 0.5, 0.5, 0.5)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        displayedRows[#displayedRows + 1] = row
        yOffset = yOffset + UI.ROW_HEIGHT
    end

    entryChild:SetHeight(math.max(yOffset, 1))

    -- Update count
    local countStr = #entries .. " location(s)"
    if searchText ~= "" then
        countStr = countStr .. " matching '" .. searchText .. "'"
    end
    frame._countText:SetText(countStr)
end

-------------------------------------------------------------------
-- REFRESH: Waypoint Button State
-------------------------------------------------------------------
UpdateWaypointButton = function()
    local frame = AddressBook.mainFrame
    if not frame then return end
    if selectedEntryData then
        frame._waypointBtn:Enable()
    else
        frame._waypointBtn:Disable()
    end
end

-------------------------------------------------------------------
-- PUBLIC REFRESH (called from other files)
-------------------------------------------------------------------
function AddressBook:RefreshUI()
    if self.mainFrame and self.mainFrame:IsShown() then
        RefreshCategoryList()
        RefreshEntryList()
    end
end

-------------------------------------------------------------------
-- EDIT DIALOG
-------------------------------------------------------------------
function AddressBook:ShowEditDialog(data, defaultName)
    -- Simple edit using StaticPopup for v1
    if data then
        -- Editing existing custom entry
        local dialog = StaticPopup_Show("ADDRESSBOOK_EDIT_ENTRY")
        if dialog then
            dialog.editBox:SetText(data.entry.name or "")
            dialog.editBox:HighlightText()
            dialog.data = { original = data }
        end
    else
        -- Adding new — just save here with the given name
        if defaultName then
            AddressBook:SaveHere(defaultName, "Custom", nil)
        end
    end
end

StaticPopupDialogs["ADDRESSBOOK_EDIT_ENTRY"] = {
    text = "Edit location name:",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 200,
    OnAccept = function(self)
        local name = self.editBox:GetText()
        local data = self.data and self.data.original
        if name and name ~= "" and data then
            local updated = {}
            for k, v in pairs(data.entry) do
                updated[k] = v
            end
            updated.name = name
            AddressBook:EditCustomEntry(data.category, data.subcategory, data.index, updated)
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local name = parent.editBox:GetText()
        local data = parent.data and parent.data.original
        if name and name ~= "" and data then
            local updated = {}
            for k, v in pairs(data.entry) do
                updated[k] = v
            end
            updated.name = name
            AddressBook:EditCustomEntry(data.category, data.subcategory, data.index, updated)
        end
        parent:Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
