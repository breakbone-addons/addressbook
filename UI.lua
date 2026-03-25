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
        AddressBook:ShowEditDialog(nil)
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

-------------------------------------------------------------------
-- EDIT DIALOG
-------------------------------------------------------------------
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
    local title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -16)
    dlg._title = title

    local yPos = -38
    local labelWidth = 55
    local fieldHeight = 20

    -- Helper: create a labeled input
    local function MakeField(parent, labelText, y, editWidth)
        local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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
    local coordLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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

    local commaLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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
