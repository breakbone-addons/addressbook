AddressBook = AddressBook or {}

function AddressBook:InitMinimapButton()
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)

    if not LDB or not LDBIcon then return end

    local dataObj = LDB:NewDataObject("AddressBook", {
        type = "launcher",
        text = "AddressBook",
        icon = "Interface\\Icons\\INV_Misc_Map_01",
        OnClick = function(_, button)
            if button == "LeftButton" then
                AddressBook:ToggleUI()
            elseif button == "RightButton" then
                AddressBook:SaveHere("Quick Save " .. date("%H:%M:%S"), "Custom", nil)
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cff33bbffAddressBook|r v" .. AddressBook.VERSION)
            tooltip:AddLine(" ")
            tooltip:AddLine("|cffeda55fLeft-click|r to open address book")
            tooltip:AddLine("|cffeda55fRight-click|r to save current location")
            if AddressBook:HasTomTom() then
                tooltip:AddLine("|cff00ff00TomTom detected|r")
            else
                tooltip:AddLine("|cffff0000TomTom not installed|r")
            end
        end,
    })

    LDBIcon:Register("AddressBook", dataObj, AddressBookDB.minimap)
end
