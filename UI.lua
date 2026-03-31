AddressBook = AddressBook or {}

local UI = AddressBook.UI

-- Helper: get editBox from a StaticPopup dialog (handles BCC API differences)
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
local selectedZone = nil          -- nil=All, "Auto"=auto-detect, or zone name

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

    -- Title bar (standard WoW dialog header)
    local titleBar = frame:CreateTexture(nil, "ARTWORK")
    titleBar:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    titleBar:SetSize(220, 64)
    titleBar:SetPoint("TOP", 0, 12)

    local title = frame:CreateFontString(nil, "OVERLAY", "AddressBookFontTitle")
    title:SetPoint("TOP", titleBar, "TOP", 0, -14)
    title:SetText("AddressBook")

    -- Close button (top right)
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

    -- TomTom status indicator (left of close)
    local tomtomStatus = frame:CreateFontString(nil, "OVERLAY", "AddressBookFontSmall")
    tomtomStatus:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -8, -8)
    if AddressBook:HasTomTom() then
        tomtomStatus:SetText("|cff00ff00TomTom|r")
    else
        tomtomStatus:SetText("|cffff0000No TomTom|r")
    end

    -------------------------------------------------------------------
    -- ROW 1: Continent dropdown + Auto + My Faction (left), Search + count (right)
    -------------------------------------------------------------------
    local row1Y = -UI.HEADER_HEIGHT - 4

    local contLabel = frame:CreateFontString(nil, "OVERLAY", "AddressBookFontSmall")
    contLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", UI.PADDING + 10, row1Y - 5)
    contLabel:SetText("Continent:")
    contLabel:SetTextColor(UI.COLOR_HEADER.r, UI.COLOR_HEADER.g, UI.COLOR_HEADER.b)

    local continentDropdown = CreateFrame("Frame", "AddressBookContinentDropdown", frame, "UIDropDownMenuTemplate")
    continentDropdown:SetPoint("LEFT", contLabel, "RIGHT", -12, -2)
    UIDropDownMenu_SetWidth(continentDropdown, 130)

    -- Continent Auto checkbox
    local contAutoCheck = CreateFrame("CheckButton", "AddressBookContAutoFilter", frame, "UICheckButtonTemplate")
    contAutoCheck:SetPoint("LEFT", continentDropdown, "RIGHT", -8, 0)
    contAutoCheck:SetSize(20, 20)
    contAutoCheck:SetChecked(true)
    _G["AddressBookContAutoFilterText"]:SetText("Auto")
    _G["AddressBookContAutoFilterText"]:SetFontObject("AddressBookFontSmall")

    -- My Faction checkbox (right of continent Auto)
    local factionCheck = CreateFrame("CheckButton", "AddressBookFactionFilter", frame, "UICheckButtonTemplate")
    factionCheck:SetPoint("LEFT", contAutoCheck, "RIGHT", 32, 0)
    factionCheck:SetSize(20, 20)
    factionCheck:SetChecked(AddressBookDB and AddressBookDB.settings and AddressBookDB.settings.showFactionOnly)
    _G["AddressBookFactionFilterText"]:SetText("My Faction")
    _G["AddressBookFactionFilterText"]:SetFontObject("AddressBookFontSmall")
    factionCheck:SetScript("OnClick", function(self)
        if AddressBookDB and AddressBookDB.settings then
            AddressBookDB.settings.showFactionOnly = self:GetChecked()
            RefreshEntryList()
        end
    end)

    -- Search label + box + count (right side of row 1)
    local searchLabel = frame:CreateFontString(nil, "OVERLAY", "AddressBookFontSmall")
    searchLabel:SetPoint("LEFT", factionCheck, "RIGHT", 80, 0)
    searchLabel:SetText("Search:")
    searchLabel:SetTextColor(UI.COLOR_HEADER.r, UI.COLOR_HEADER.g, UI.COLOR_HEADER.b)

    local searchBox = self:CreateSearchBox(frame, 120)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
    searchBox:SetPoint("RIGHT", frame, "RIGHT", -UI.PADDING - 8, 0)

    searchBox:SetScript("OnTextChanged", function(self)
        searchText = strtrim(self:GetText() or "")
        RefreshEntryList()
    end)

    frame._searchBox = searchBox

    -- Entry count (right side, same row as TomTom status)
    local countText = frame:CreateFontString(nil, "OVERLAY", "AddressBookFontSmall")
    countText:SetPoint("RIGHT", tomtomStatus, "LEFT", -12, 0)
    countText:SetTextColor(0.5, 0.5, 0.5)
    frame._countText = countText

    -- Resolve initial continent for Auto default
    local resolvedZone = AddressBook:GetCurrentZoneName()
    local resolvedCont = resolvedZone and AddressBook:GetContinentForZone(resolvedZone)
    UIDropDownMenu_SetText(continentDropdown, resolvedCont or "All")

    local function ContinentDropdown_Init(self, level)
        local info = UIDropDownMenu_CreateInfo()

        info.text = "All Continents"
        info.notCheckable = true
        info.func = function()
            selectedContinent = nil
            selectedZone = nil
            contAutoCheck:SetChecked(false)
            UIDropDownMenu_SetText(continentDropdown, "All")
            UIDropDownMenu_SetText(frame._zoneDropdown, "All")
            if frame._zoneAutoCheck then frame._zoneAutoCheck:SetChecked(false) end
            RefreshEntryList()
        end
        UIDropDownMenu_AddButton(info, level)

        local continents = AddressBook:GetContinents()
        for _, name in ipairs(continents) do
            info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.notCheckable = true
            info.func = function()
                selectedContinent = name
                selectedZone = nil
                contAutoCheck:SetChecked(false)
                UIDropDownMenu_SetText(continentDropdown, name)
                UIDropDownMenu_SetText(frame._zoneDropdown, "All")
                if frame._zoneAutoCheck then frame._zoneAutoCheck:SetChecked(false) end
                RefreshEntryList()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(continentDropdown, ContinentDropdown_Init)

    contAutoCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            selectedContinent = "Auto"
            -- Resolve and select current continent in dropdown
            local rZone = AddressBook:GetCurrentZoneName()
            local rCont = rZone and AddressBook:GetContinentForZone(rZone)
            UIDropDownMenu_SetText(continentDropdown, rCont or "All")
        else
            selectedContinent = nil
            UIDropDownMenu_SetText(continentDropdown, "All")
        end
        RefreshEntryList()
    end)

    frame._continentDropdown = continentDropdown

    -------------------------------------------------------------------
    -- ROW 2: Zone dropdown + Auto checkbox, Nearest, Set WP, Clear WP, Add Entry
    -------------------------------------------------------------------
    local row2Y = row1Y - 26

    local zoneLabel = frame:CreateFontString(nil, "OVERLAY", "AddressBookFontSmall")
    zoneLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", UI.PADDING + 10, row2Y - 5)
    zoneLabel:SetText("Zone:")
    zoneLabel:SetTextColor(UI.COLOR_HEADER.r, UI.COLOR_HEADER.g, UI.COLOR_HEADER.b)

    local zoneDropdown = CreateFrame("Frame", "AddressBookZoneDropdown", frame, "UIDropDownMenuTemplate")
    zoneDropdown:SetPoint("LEFT", contLabel, "RIGHT", -12, row2Y - row1Y)
    UIDropDownMenu_SetWidth(zoneDropdown, 130)
    UIDropDownMenu_SetText(zoneDropdown, "All")
    frame._zoneDropdown = zoneDropdown

    -- Zone Auto checkbox
    local zoneAutoCheck = CreateFrame("CheckButton", "AddressBookZoneAutoFilter", frame, "UICheckButtonTemplate")
    zoneAutoCheck:SetPoint("LEFT", zoneDropdown, "RIGHT", -8, 0)
    zoneAutoCheck:SetSize(20, 20)
    zoneAutoCheck:SetChecked(false)
    _G["AddressBookZoneAutoFilterText"]:SetText("Auto")
    _G["AddressBookZoneAutoFilterText"]:SetFontObject("AddressBookFontSmall")
    frame._zoneAutoCheck = zoneAutoCheck

    local function ZoneDropdown_Init(self, level)
        local info = UIDropDownMenu_CreateInfo()

        info.text = "All Zones"
        info.notCheckable = true
        info.func = function()
            selectedZone = nil
            zoneAutoCheck:SetChecked(false)
            UIDropDownMenu_SetText(zoneDropdown, "All")
            RefreshEntryList()
        end
        UIDropDownMenu_AddButton(info, level)

        -- Resolve the effective continent for zone filtering
        local effectiveContinent = selectedContinent
        if effectiveContinent == "Auto" then
            local rZone = AddressBook:GetCurrentZoneName()
            if rZone then
                effectiveContinent = AddressBook:GetContinentForZone(rZone)
            end
        end

        local zones
        if effectiveContinent then
            zones = AddressBook:GetZonesForContinent(effectiveContinent)
        else
            zones = AddressBook:GetZonesWithEntries()
        end
        for _, name in ipairs(zones) do
            info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.notCheckable = true
            info.func = function()
                selectedZone = name
                zoneAutoCheck:SetChecked(false)
                UIDropDownMenu_SetText(zoneDropdown, name)
                if not selectedContinent or selectedContinent == "Auto" then
                    local cont = AddressBook:GetContinentForZone(name)
                    if cont then
                        selectedContinent = cont
                        contAutoCheck:SetChecked(false)
                        UIDropDownMenu_SetText(continentDropdown, cont)
                    end
                end
                RefreshEntryList()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(zoneDropdown, ZoneDropdown_Init)

    zoneAutoCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            selectedZone = "Auto"
            local rZone = AddressBook:GetCurrentZoneName()
            UIDropDownMenu_SetText(zoneDropdown, rZone or "All")
            -- Also auto the continent if not already
            if not contAutoCheck:GetChecked() then
                contAutoCheck:SetChecked(true)
                selectedContinent = "Auto"
                local rCont = rZone and AddressBook:GetContinentForZone(rZone)
                UIDropDownMenu_SetText(continentDropdown, rCont or "All")
            end
        else
            selectedZone = nil
            UIDropDownMenu_SetText(zoneDropdown, "All")
        end
        RefreshEntryList()
    end)

    -- Right side: Add Entry, Clear WP, Set Waypoint
    local addBtn = AddressBook:CreateButton(frame, "Add Entry", 65, 20)
    addBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -UI.PADDING - 8, row2Y - 2)
    addBtn:SetScript("OnClick", function()
        AddressBook:ShowEditDialog(nil)
    end)

    local clearBtn = AddressBook:CreateButton(frame, "Clear WP", 55, 20)
    clearBtn:SetPoint("RIGHT", addBtn, "LEFT", -4, 0)
    clearBtn:SetScript("OnClick", function()
        AddressBook:ClearWaypoint()
        AddressBook:Print("Waypoint cleared.")
    end)

    local waypointBtn = AddressBook:CreateButton(frame, "Set WP", 50, 20)
    waypointBtn:SetPoint("RIGHT", clearBtn, "LEFT", -4, 0)
    waypointBtn:Disable()
    waypointBtn:SetScript("OnClick", function()
        if selectedEntryData then
            AddressBook:SetWaypoint(selectedEntryData.entry)
        end
    end)
    frame._waypointBtn = waypointBtn

    -------------------------------------------------------------------
    -- CATEGORY PANEL (left side)
    -------------------------------------------------------------------
    local topBarHeight = UI.HEADER_HEIGHT + 58
    local catPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    catPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", UI.PADDING, -topBarHeight)
    catPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", UI.PADDING, UI.PADDING)
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
    catScroll:SetPoint("TOPLEFT", catPanel, "TOPLEFT", 4, -8)
    catScroll:SetPoint("BOTTOMRIGHT", catPanel, "BOTTOMRIGHT", -26, 8)

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
    listPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -UI.PADDING, UI.PADDING)
    listPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    listPanel:SetBackdropColor(0.08, 0.08, 0.08, 0.8)

    -- Column headers
    local headerName = listPanel:CreateFontString(nil, "OVERLAY", "AddressBookFontSmall")
    headerName:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 8, -4)
    headerName:SetText("Name")
    headerName:SetTextColor(UI.COLOR_HEADER.r, UI.COLOR_HEADER.g, UI.COLOR_HEADER.b)

    local headerZone = listPanel:CreateFontString(nil, "OVERLAY", "AddressBookFontSmall")
    headerZone:SetPoint("LEFT", headerName, "LEFT", 164, 0)
    headerZone:SetText("Zone")
    headerZone:SetTextColor(UI.COLOR_HEADER.r, UI.COLOR_HEADER.g, UI.COLOR_HEADER.b)

    local headerNote = listPanel:CreateFontString(nil, "OVERLAY", "AddressBookFontSmall")
    headerNote:SetPoint("LEFT", headerName, "LEFT", 278, 0)
    headerNote:SetText("Note")
    headerNote:SetTextColor(UI.COLOR_HEADER.r, UI.COLOR_HEADER.g, UI.COLOR_HEADER.b)

    -- Nearest button (centered over Zone column, same row as other buttons)
    -- Zone header is at listPanel TOPLEFT + (8 + 164) = catPanel right + 4 + 172
    -- catPanel starts at PADDING(8), width CATEGORY_WIDTH(160), so listPanel left ~= 172
    -- Zone header left ~= 172 + 172 = 344 from frame left; zone col is ~114px wide, center ~= 344+57 = 401
    -- But the frame is 600 wide, so 401 is too far. Let me just place it left of waypointBtn.
    local nearestBtn = AddressBook:CreateButton(frame, "Nearest", 55, 20)
    nearestBtn:SetPoint("RIGHT", waypointBtn, "LEFT", -24, 0)
    nearestBtn:SetScript("OnClick", function()
        AddressBook:FindNearest()
    end)
    frame._nearestBtn = nearestBtn

    -- Entry scroll frame
    local entryScroll = CreateFrame("ScrollFrame", "AddressBookEntryScroll", listPanel, "UIPanelScrollFrameTemplate")
    entryScroll:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 4, -20)
    entryScroll:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -26, 8)

    local entryChild = CreateFrame("Frame", nil, entryScroll)
    entryChild:SetWidth(listPanel:GetWidth() - 26)
    entryScroll:SetScrollChild(entryChild)

    frame._listPanel = listPanel
    frame._entryScroll = entryScroll
    frame._entryChild = entryChild

    -------------------------------------------------------------------
    -- STATIC POPUPS
    -------------------------------------------------------------------
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
        -- Expand first non-flat category
        local cats = self:GetCategories()
        -- Check if Favorites exist and skip them for auto-expand
        local favEntries = AddressBook:GetFavorites()
        local startIdx = (#favEntries > 0) and 2 or 1
        if cats[startIdx] then
            expandedCategories[cats[startIdx].name] = true
            selectedCategory = cats[startIdx].name
            if cats[startIdx].subcategories[1] then
                selectedSubcategory = cats[startIdx].subcategories[1]
            end
        elseif #favEntries > 0 then
            selectedCategory = "Favorites"
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

    -- Favorites always first (if any exist)
    local favEntries = AddressBook:GetFavorites()
    if #favEntries > 0 then
        orderedList[#orderedList + 1] = { name = "Favorites", subcategories = {} }
    end

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
        local isFlatCategory = (cat.name == "Favorites")
        local isExpanded = expandedCategories[cat.name]
        local catBtn = AddressBook:CreateCategoryButton(catChild, cat.name, 1, isExpanded, isFlatCategory)
        catBtn:SetPoint("TOPLEFT", catChild, "TOPLEFT", 0, -yOffset)
        catBtn:SetPoint("RIGHT", catChild, "RIGHT", 0, 0)

        -- Highlight flat categories when selected
        if isFlatCategory and selectedCategory == cat.name then
            catBtn._selectedBg:Show()
        end

        catBtn._categoryName = cat.name
        catBtn._isFlat = isFlatCategory
        catBtn:SetScript("OnClick", function(self)
            if self._isFlat then
                -- Flat category: select directly, no expand/collapse
                selectedCategory = self._categoryName
                selectedSubcategory = nil
            else
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

        if isExpanded and not isFlatCategory then
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
    elseif selectedCategory == "Favorites" then
        entries = AddressBook:GetFavorites()
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

        if AddressBook:IsFavorite(e) then
            row._nameText:SetTextColor(0.2, 0.9, 0.2)
            row._customIcon:SetText("")
        elseif data.isCustom then
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

function AddressBook:SelectCategory(category, subcategory)
    expandedCategories[category] = true
    selectedCategory = category
    selectedSubcategory = subcategory
    -- Clear zone/continent filters so the entry is visible
    selectedContinent = nil
    selectedZone = nil
    if self.mainFrame then
        if self.mainFrame._continentDropdown then
            UIDropDownMenu_SetText(self.mainFrame._continentDropdown, "All")
        end
        if self.mainFrame._zoneDropdown then
            UIDropDownMenu_SetText(self.mainFrame._zoneDropdown, "All")
        end
        -- Uncheck auto checkboxes
        local contAuto = _G["AddressBookContAutoFilter"]
        if contAuto then contAuto:SetChecked(false) end
        if self.mainFrame._zoneAutoCheck then self.mainFrame._zoneAutoCheck:SetChecked(false) end
    end
    if AddressBookCharDB then
        AddressBookCharDB.lastCategory = category
        AddressBookCharDB.lastSubcategory = subcategory
    end
    self:RefreshUI()
end

-------------------------------------------------------------------
-- NEAREST
-------------------------------------------------------------------
function AddressBook:FindNearest()
    if #displayedRows == 0 then
        self:Print("No entries in the current list.")
        return
    end

    local playerMap = C_Map.GetBestMapForUnit("player")
    if not playerMap then
        self:Print("Cannot determine your position.")
        return
    end
    local pos = C_Map.GetPlayerMapPosition(playerMap, "player")
    if not pos then
        self:Print("Cannot determine your position.")
        return
    end
    local px, py = pos:GetXY()

    -- Find the nearest entry that shares the same mapID as the player
    local bestRow, bestDist
    for _, row in ipairs(displayedRows) do
        local e = row._data and row._data.entry
        if e and e.mapID and e.mapID == playerMap then
            -- Same map: simple 2D distance on normalized coords
            local ex, ey = (e.x or 0) / 100, (e.y or 0) / 100
            local dx, dy = px - ex, py - ey
            local dist = dx * dx + dy * dy
            if not bestDist or dist < bestDist then
                bestDist = dist
                bestRow = row
            end
        end
    end

    if not bestRow then
        -- Fallback: try same continent via world coordinates
        for _, row in ipairs(displayedRows) do
            local e = row._data and row._data.entry
            if e and e.mapID then
                -- Use C_Map to check if we can get a vector between the two points
                local ePos = CreateVector2D((e.x or 0) / 100, (e.y or 0) / 100)
                -- Try getting world position for both
                local _, pwPos = C_Map.GetWorldPosFromMapPos(playerMap, pos)
                local eMapPos = CreateVector2D((e.x or 0) / 100, (e.y or 0) / 100)
                local _, ewPos = C_Map.GetWorldPosFromMapPos(e.mapID, eMapPos)
                if pwPos and ewPos then
                    local dx = pwPos.x - ewPos.x
                    local dy = pwPos.y - ewPos.y
                    local dist = dx * dx + dy * dy
                    if not bestDist or dist < bestDist then
                        bestDist = dist
                        bestRow = row
                    end
                end
            end
        end
    end

    if not bestRow then
        self:Print("No nearby entries found.")
        return
    end

    -- Select the nearest row
    for _, r in ipairs(displayedRows) do
        if r._selected then r._selected:Hide() end
    end
    bestRow._selected:Show()
    selectedEntryData = bestRow._data
    self.selectedEntry = bestRow._data
    UpdateWaypointButton()

    -- Scroll to the row
    local scroll = self.mainFrame._entryScroll
    local rowTop = (bestRow._entryIndex - 1) * UI.ROW_HEIGHT
    local visibleHeight = scroll:GetHeight()
    local currentScroll = scroll:GetVerticalScroll()

    if rowTop < currentScroll or rowTop + UI.ROW_HEIGHT > currentScroll + visibleHeight then
        scroll:SetVerticalScroll(math.max(0, rowTop - visibleHeight / 2 + UI.ROW_HEIGHT / 2))
    end

    self:Print(format("Nearest: %s (%.1f, %.1f)",
        bestRow._data.entry.name,
        bestRow._data.entry.x or 0,
        bestRow._data.entry.y or 0))
end

-------------------------------------------------------------------
-- EDIT / ADD ENTRY DIALOG
-------------------------------------------------------------------
local editDialog

local function CreateEditDialog()
    if editDialog then return editDialog end

    local dlg = CreateFrame("Frame", "AddressBookEditDialog", UIParent, "BackdropTemplate")
    dlg:SetSize(320, 260)
    dlg:SetPoint("CENTER")
    dlg:SetFrameStrata("DIALOG")
    dlg:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    dlg:SetMovable(true)
    dlg:EnableMouse(true)
    dlg:RegisterForDrag("LeftButton")
    dlg:SetScript("OnDragStart", dlg.StartMoving)
    dlg:SetScript("OnDragStop", dlg.StopMovingOrSizing)
    dlg:Hide()
    tinsert(UISpecialFrames, "AddressBookEditDialog")

    -- Title
    local title = dlg:CreateFontString(nil, "OVERLAY", "AddressBookFontTitle")
    title:SetPoint("TOP", 0, -16)
    dlg._title = title

    local yPos = -38
    local labelWidth = 55
    local fieldHeight = 20

    -- Helper: create a labeled input
    local function MakeField(parent, labelText, y, editWidth)
        local lbl = parent:CreateFontString(nil, "OVERLAY", "AddressBookFontSmall")
        lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y)
        lbl:SetWidth(labelWidth)
        lbl:SetJustifyH("RIGHT")
        lbl:SetText(labelText)

        local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        eb:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
        eb:SetSize(editWidth or 200, fieldHeight)
        eb:SetAutoFocus(false)
        return eb
    end

    -- Name
    dlg._nameBox = MakeField(dlg, "Name:", yPos)
    dlg._nameBox:SetMaxLetters(30)
    yPos = yPos - 28

    -- Coordinates row (X, Y + Current Location button)
    local coordLabel = dlg:CreateFontString(nil, "OVERLAY", "AddressBookFontSmall")
    coordLabel:SetPoint("TOPLEFT", dlg, "TOPLEFT", 20, yPos)
    coordLabel:SetWidth(labelWidth)
    coordLabel:SetJustifyH("RIGHT")
    coordLabel:SetText("Coords:")

    local xBox = CreateFrame("EditBox", nil, dlg, "InputBoxTemplate")
    xBox:SetPoint("LEFT", coordLabel, "RIGHT", 8, 0)
    xBox:SetSize(50, fieldHeight)
    xBox:SetAutoFocus(false)
    xBox:SetNumeric(false)
    dlg._xBox = xBox

    local commaLabel = dlg:CreateFontString(nil, "OVERLAY", "AddressBookFontSmall")
    commaLabel:SetPoint("LEFT", xBox, "RIGHT", 2, 0)
    commaLabel:SetText(",")

    local yBox = CreateFrame("EditBox", nil, dlg, "InputBoxTemplate")
    yBox:SetPoint("LEFT", commaLabel, "RIGHT", 2, 0)
    yBox:SetSize(50, fieldHeight)
    yBox:SetAutoFocus(false)
    yBox:SetNumeric(false)
    dlg._yBox = yBox

    local locBtn = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
    locBtn:SetSize(90, 20)
    locBtn:SetPoint("LEFT", yBox, "RIGHT", 8, 0)
    locBtn:SetText("Current Loc")
    locBtn:SetScript("OnClick", function()
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
            if pos then
                local px, py = pos:GetXY()
                xBox:SetText(format("%.1f", px * 100))
                yBox:SetText(format("%.1f", py * 100))
                -- Also update zone
                local info = C_Map.GetMapInfo(mapID)
                if info and info.name then
                    dlg._zoneBox:SetText(info.name)
                end
            end
        end
    end)
    yPos = yPos - 28

    -- Zone
    dlg._zoneBox = MakeField(dlg, "Zone:", yPos)
    yPos = yPos - 28

    -- Note
    dlg._noteBox = MakeField(dlg, "Note:", yPos)
    dlg._noteBox:SetMaxLetters(60)
    yPos = yPos - 36

    -- Buttons
    local saveBtn = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
    saveBtn:SetSize(80, 22)
    saveBtn:SetPoint("BOTTOMRIGHT", dlg, "BOTTOM", -4, 14)
    saveBtn:SetText("Save")
    dlg._saveBtn = saveBtn

    local cancelBtn = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
    cancelBtn:SetSize(80, 22)
    cancelBtn:SetPoint("BOTTOMLEFT", dlg, "BOTTOM", 4, 14)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function() dlg:Hide() end)

    dlg:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
            self:SetPropagateKeyboardInput(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    editDialog = dlg
    return dlg
end

function AddressBook:ShowEditDialog(data)
    local dlg = CreateEditDialog()

    if data then
        -- Editing existing
        dlg._title:SetText("Edit Location")
        dlg._nameBox:SetText(data.entry.name or "")
        dlg._xBox:SetText(data.entry.x and format("%.1f", data.entry.x) or "")
        dlg._yBox:SetText(data.entry.y and format("%.1f", data.entry.y) or "")
        dlg._zoneBox:SetText(data.entry.zone or "")
        dlg._noteBox:SetText(data.entry.note or "")

        dlg._saveBtn:SetScript("OnClick", function()
            local name = strtrim(dlg._nameBox:GetText() or "")
            if name == "" then return end
            local updated = {}
            for k, v in pairs(data.entry) do
                updated[k] = v
            end
            updated.name = name
            updated.x = tonumber(dlg._xBox:GetText()) or updated.x
            updated.y = tonumber(dlg._yBox:GetText()) or updated.y
            updated.zone = strtrim(dlg._zoneBox:GetText() or "") or updated.zone
            local noteText = strtrim(dlg._noteBox:GetText() or "")
            updated.note = noteText ~= "" and noteText or nil
            AddressBook:EditCustomEntry(data.category, data.subcategory, data.index, updated)
            dlg:Hide()
        end)
    else
        -- Adding new
        dlg._title:SetText("Add Entry")
        dlg._nameBox:SetText("")
        dlg._xBox:SetText("")
        dlg._yBox:SetText("")
        dlg._zoneBox:SetText("")
        dlg._noteBox:SetText("")

        dlg._saveBtn:SetScript("OnClick", function()
            local name = strtrim(dlg._nameBox:GetText() or "")
            if name == "" then return end
            local zone = strtrim(dlg._zoneBox:GetText() or "")
            local x = tonumber(dlg._xBox:GetText()) or 0
            local y = tonumber(dlg._yBox:GetText()) or 0
            local noteText = strtrim(dlg._noteBox:GetText() or "")
            AddressBook:SaveManualEntry(name, zone, x, y, noteText)
            dlg:Hide()
        end)
    end

    dlg:Show()
    dlg._nameBox:SetFocus()
end
