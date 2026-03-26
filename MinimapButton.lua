AddressBook = AddressBook or {}

-- Persistent context menu frame for favorites
local favMenuFrame = CreateFrame("Frame", "AddressBookFavMinimapMenu", UIParent, "UIDropDownMenuTemplate")

local function ShowFavoritesMenu()
    local favorites = AddressBook:GetFavorites()

    local function InitMenu(self, level)
        if not level then return end

        local info = UIDropDownMenu_CreateInfo()

        -- Title
        info.text = "|cff33bbffFavorites|r"
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        if #favorites == 0 then
            info = UIDropDownMenu_CreateInfo()
            info.text = "No favorites yet"
            info.disabled = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
        else
            for _, fav in ipairs(favorites) do
                info = UIDropDownMenu_CreateInfo()
                info.text = fav.entry.name
                info.notCheckable = true
                info.func = function()
                    AddressBook:SetWaypoint(fav.entry)
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end

        -- Separator + cancel
        info = UIDropDownMenu_CreateInfo()
        info.text = ""
        info.disabled = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        info = UIDropDownMenu_CreateInfo()
        info.text = "Cancel"
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
    end

    UIDropDownMenu_Initialize(favMenuFrame, InitMenu, "MENU")
    ToggleDropDownMenu(1, nil, favMenuFrame, "cursor", 0, 0)
end

function AddressBook:InitMinimapButton()
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)

    if not LDB or not LDBIcon then return end

    local dataObj = LDB:NewDataObject("AddressBook", {
        type = "launcher",
        text = "AddressBook",
        icon = "Interface\\AddOns\\AddressBook\\minimap-icon",
        OnClick = function(_, button)
            if button == "LeftButton" then
                AddressBook:ToggleUI()
            elseif button == "RightButton" then
                ShowFavoritesMenu()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cff33bbffAddressBook|r v" .. AddressBook.VERSION)
            tooltip:AddLine(" ")
            tooltip:AddLine("|cffeda55fLeft-click|r to open address book")
            tooltip:AddLine("|cffeda55fRight-click|r for favorites")
            if AddressBook:HasTomTom() then
                tooltip:AddLine("|cff00ff00TomTom detected|r")
            else
                tooltip:AddLine("|cffff0000TomTom not installed|r")
            end
        end,
    })

    LDBIcon:Register("AddressBook", dataObj, AddressBookDB.minimap)
end
