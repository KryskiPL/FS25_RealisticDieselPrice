--[[ RealisticDieselPrice.lua

Author:     KryskiPL (https://github.com/KryskiPL)
Version:    v2.2.0.0

]]--
RealisticDieselPrice = {}
local rdp = RealisticDieselPrice

rdp.modDirectory = g_currentModDirectory or ""
rdp.settingsDirectory = (g_modSettingsDirectory or (getUserProfileAppPath() .. "modSettings")) .. "/FS25_RealisticDieselPrice/"
rdp.settingsFile = rdp.settingsDirectory .. "settings.xml"

rdp.regions = {
    {
        name = "Europe",
        countries = {
            {label = "Poland", price = 1.81},
            {label = "Poland Hard", price = 7.85},
            {label = "Lithuania", price = 1.79},
            {label = "Latvia", price = 1.72},
            {label = "Estonia", price = 1.66},
            {label = "Czechia", price = 1.53},
            {label = "Austria", price = 1.80},
            {label = "Croatia", price = 1.55},
            {label = "Slovakia", price = 1.55},
            {label = "Hungary", price = 1.79},
            {label = "Romania", price = 1.82},
            {label = "Germany", price = 1.90},
            {label = "United Kingdom", price = 1.96},
            {label = "Ireland", price = 1.85},
            {label = "Netherlands", price = 2.15},
            {label = "Belgium", price = 1.95},
            {label = "France", price = 1.95},
            {label = "Italy", price = 2.00},
            {label = "Spain", price = 1.57},
            {label = "Switzerland", price = 2.25},
            {label = "Portugal", price = 1.90},
            {label = "Greece", price = 1.95},
            {label = "Denmark", price = 2.07},
            {label = "Norway", price = 1.61},
            {label = "Sweden", price = 1.65},
            {label = "Finland", price = 2.20},
            {label = "Belarus", price = 0.80},
            {label = "Ukraine", price = 1.53}
        }
    },
    {
        name = "Americas & Australia",
        countries = {
            {label = "Brazil", price = 1.14},
            {label = "Argentina", price = 1.30},
            {label = "USA", price = 1.08},
            {label = "Canada", price = 1.16},
            {label = "Australia", price = 1.09}
        }
    },
    {
        name = "Asia",
        countries = {
            {label = "Russia", price = 0.90},
            {label = "Kazakhstan", price = 0.62},
            {label = "Mongolia", price = 1.52},
            {label = "China", price = 0.98},
            {label = "Japan", price = 0.86}
        }
    }
}

rdp.currentRegion = 1
rdp.currentCountry = 1
rdp.customMode = false
rdp.customPrice = 1.50
rdp.menuInstalled = false
rdp.menuControls = {}

local function getCurrencyData()
    local factor = 1.0
    local symbol = "€"
    if g_i18n ~= nil and g_i18n.getCurrencyFactor ~= nil and g_i18n.getCurrencySymbol ~= nil then
        symbol = string.gsub(g_i18n:getCurrencySymbol(true), "^%s*(.-)%s*$", "%1")
        if (symbol == "$" or symbol == "£") and g_i18n:getCurrencyFactor() > 0 then
            factor = g_i18n:getCurrencyFactor()
        end
    end
    return factor, symbol
end

local function loadSettings()
    createFolder(rdp.settingsDirectory)
    if not fileExists(rdp.settingsFile) then return end
    local xmlFile = XMLFile.loadIfExists("rdpSettingsXML", rdp.settingsFile)
    if xmlFile == nil then return end
    local savedRegion = xmlFile:getInt("settings#regionState")
    local savedCountry = xmlFile:getInt("settings#countryState")
    local savedCustomMode = xmlFile:getBool("settings#customMode")
    local savedCustomPrice = xmlFile:getFloat("settings#customPrice")
    if savedRegion ~= nil and rdp.regions[savedRegion] ~= nil then rdp.currentRegion = savedRegion end
    if savedCountry ~= nil and rdp.regions[rdp.currentRegion].countries[savedCountry] ~= nil then
        rdp.currentCountry = savedCountry
    else
        rdp.currentCountry = 1
    end
    if savedCustomMode ~= nil then rdp.customMode = savedCustomMode end
    if savedCustomPrice ~= nil then rdp.customPrice = savedCustomPrice end
    xmlFile:delete()
end

local function saveSettings()
    createFolder(rdp.settingsDirectory)
    local xmlFile = XMLFile.create("rdpSettingsXML", rdp.settingsFile, "settings")
    if xmlFile == nil then return end
    xmlFile:setInt("settings#regionState", rdp.currentRegion)
    xmlFile:setInt("settings#countryState", rdp.currentCountry)
    xmlFile:setBool("settings#customMode", rdp.customMode)
    xmlFile:setFloat("settings#customPrice", rdp.customPrice)
    xmlFile:save()
    xmlFile:delete()
end

function rdp.applyCurrentPrice()
    local price = 1.0
    if rdp.customMode then
        price = rdp.customPrice
    else
        local regionData = rdp.regions[rdp.currentRegion]
        if regionData ~= nil then
            local countryData = regionData.countries[rdp.currentCountry]
            if countryData ~= nil then
                price = countryData.price
            end
        end
    end
    if g_fillTypeManager ~= nil then
        local dieselType = g_fillTypeManager:getFillTypeByName("DIESEL")
        if dieselType ~= nil then
            dieselType.pricePerLiter = price
        end
    end
end

local function assignFocusIds(element)
    if element == nil then return end
    element.focusId = FocusManager:serveAutoFocusId()
    if element.elements ~= nil then
        for _, child in ipairs(element.elements) do
            assignFocusIds(child)
        end
    end
end

local function getCustomPriceTexts()
    local texts = {}
    local factor, symbol = getCurrencyData()
    for i = 1, 5000 do
        texts[i] = string.format("%.2f %s", i * 0.01, symbol)
    end
    return texts
end

local function getRegionTexts()
    local texts = {}
    for index, region in ipairs(rdp.regions) do
        texts[index] = region.name
    end
    return texts
end

local function getCountryTexts(regionIndex)
    local texts = {}
    local region = rdp.regions[regionIndex]
    if region ~= nil then
        local factor, symbol = getCurrencyData()
        for index, country in ipairs(region.countries) do
            local convertedPrice = country.price * factor
            texts[index] = string.format("%s (%.2f %s/L)", country.label, convertedPrice, symbol)
        end
    end
    return texts
end

local function addMenuOptions(settingsPage, settingsLayout)
    local multiTemplate = settingsPage.multiVolumeVoiceBox or settingsPage.soundVolumeEnvironmentBox
    if multiTemplate == nil or multiTemplate.clone == nil then return false end
    
    local customModeBox = multiTemplate:clone(settingsLayout)
    customModeBox.id = "rdpCustomModeBox"
    local customModeOption = customModeBox.elements[1]
    customModeOption.id = "rdpCustomModeOption"
    customModeOption.target = rdp
    customModeOption:setCallback("onClickCallback", "onCustomModeChanged")
    local textOff = g_i18n:getText("ui_off") or "OFF"
    local textOn = g_i18n:getText("ui_on") or "ON"
    customModeOption:setTexts({textOff, textOn})
    local customModeLabel = customModeBox.elements[2]
    if customModeLabel ~= nil then customModeLabel:setText("Custom Fuel Price") end
    assignFocusIds(customModeBox)
    table.insert(settingsPage.controlsList, customModeBox)
    rdp.menuControls.customModeSelection = customModeOption

    local customPriceBox = multiTemplate:clone(settingsLayout)
    customPriceBox.id = "rdpCustomPriceBox"
    local customPriceOption = customPriceBox.elements[1]
    customPriceOption.id = "rdpCustomPriceOption"
    customPriceOption.target = rdp
    customPriceOption:setCallback("onClickCallback", "onCustomPriceChanged")
    customPriceOption:setTexts(getCustomPriceTexts())
    local customPriceLabel = customPriceBox.elements[2]
    if customPriceLabel ~= nil then customPriceLabel:setText("Set Custom Price") end
    assignFocusIds(customPriceBox)
    table.insert(settingsPage.controlsList, customPriceBox)
    rdp.menuControls.customPriceSelection = customPriceOption

    local regionBox = multiTemplate:clone(settingsLayout)
    regionBox.id = "rdpRegionSelectionBox"
    local regionOption = regionBox.elements[1]
    regionOption.id = "rdpRegionSelection"
    regionOption.target = rdp
    regionOption:setCallback("onClickCallback", "onRegionChanged")
    regionOption:setTexts(getRegionTexts())
    local regionLabel = regionBox.elements[2]
    if regionLabel ~= nil then regionLabel:setText("Diesel Region") end
    assignFocusIds(regionBox)
    table.insert(settingsPage.controlsList, regionBox)
    rdp.menuControls.regionSelection = regionOption
    
    local countryBox = multiTemplate:clone(settingsLayout)
    countryBox.id = "rdpCountrySelectionBox"
    local countryOption = countryBox.elements[1]
    countryOption.id = "rdpCountrySelection"
    countryOption.target = rdp
    countryOption:setCallback("onClickCallback", "onCountryChanged")
    local countryLabel = countryBox.elements[2]
    if countryLabel ~= nil then countryLabel:setText("Diesel Country") end
    assignFocusIds(countryBox)
    table.insert(settingsPage.controlsList, countryBox)
    rdp.menuControls.countrySelection = countryOption
    
    return true
end

function rdp:onCustomModeChanged(state)
    rdp.customMode = (state == 2)
    saveSettings()
    rdp.applyCurrentPrice()
    rdp.refreshMenuStates()
end

function rdp:onCustomPriceChanged(state)
    local factor, symbol = getCurrencyData()
    local localPrice = state * 0.01
    rdp.customPrice = localPrice / factor
    saveSettings()
    rdp.applyCurrentPrice()
end

function rdp:onRegionChanged(state)
    if rdp.regions[state] == nil then return end
    rdp.currentRegion = state
    rdp.currentCountry = 1
    saveSettings()
    rdp.applyCurrentPrice()
    rdp.refreshMenuStates()
end

function rdp:onCountryChanged(state)
    if rdp.regions[rdp.currentRegion].countries[state] == nil then return end
    rdp.currentCountry = state
    saveSettings()
    rdp.applyCurrentPrice()
end

function rdp.refreshMenuStates()
    local isCustom = rdp.customMode
    
    if rdp.menuControls.customModeSelection ~= nil then
        rdp.menuControls.customModeSelection:setState(isCustom and 2 or 1, nil, true)
    end
    
    if rdp.menuControls.customPriceSelection ~= nil then
        local factor, symbol = getCurrencyData()
        local localPrice = rdp.customPrice * factor
        local state = math.floor((localPrice / 0.01) + 0.5)
        if state < 1 then state = 1 end
        if state > 5000 then state = 5000 end
        
        rdp.menuControls.customPriceSelection:setDisabled(not isCustom)
        rdp.menuControls.customPriceSelection:setTexts(getCustomPriceTexts())
        rdp.menuControls.customPriceSelection:setState(state, nil, true)
    end
    
    if rdp.menuControls.regionSelection ~= nil then
        rdp.menuControls.regionSelection:setDisabled(isCustom)
        rdp.menuControls.regionSelection:setState(rdp.currentRegion, nil, true)
    end
    
    if rdp.menuControls.countrySelection ~= nil then
        rdp.menuControls.countrySelection:setDisabled(isCustom)
        rdp.menuControls.countrySelection:setTexts(getCountryTexts(rdp.currentRegion))
        rdp.menuControls.countrySelection:setState(rdp.currentCountry, nil, true)
    end
end

function rdp.installMenuIfPossible()
    if rdp.menuInstalled then return end
    local inGameMenu = g_gui and g_gui.screenControllers and g_gui.screenControllers[InGameMenu]
    if inGameMenu == nil or inGameMenu.pageSettings == nil then return end
    local settingsPage = inGameMenu.pageSettings
    local settingsLayout = settingsPage.generalSettingsLayout
    if settingsLayout == nil then return end
    if settingsPage.controlsList == nil then
        settingsPage.controlsList = {}
    end
    local sectionTitle = nil
    for _, element in ipairs(settingsLayout.elements) do
        if element.name == "sectionHeader" and element.clone ~= nil then
            sectionTitle = element:clone(settingsLayout)
            break
        end
    end
    if sectionTitle ~= nil then
        sectionTitle:setText("Realistic Diesel Price")
        assignFocusIds(sectionTitle)
        table.insert(settingsPage.controlsList, sectionTitle)
        rdp.menuControls.sectionTitle = sectionTitle
    end
    if not addMenuOptions(settingsPage, settingsLayout) then return end
    settingsLayout:invalidateLayout()
    if InGameMenuSettingsFrame ~= nil and InGameMenuSettingsFrame.onFrameOpen ~= nil and InGameMenuSettingsFrame._rdpMenuHook ~= true then
        InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
            rdp.refreshMenuStates()
        end)
        InGameMenuSettingsFrame._rdpMenuHook = true
    end
    rdp.menuInstalled = true
    rdp.refreshMenuStates()
end

function rdp.onMissionFinishedLoading()
    loadSettings()
    rdp.applyCurrentPrice()
    rdp.installMenuIfPossible()
end

if FSBaseMission ~= nil and FSBaseMission.onFinishedLoading ~= nil then
    FSBaseMission.onFinishedLoading = Utils.appendedFunction(FSBaseMission.onFinishedLoading, rdp.onMissionFinishedLoading)
end

if InGameMenuSettingsFrame ~= nil and InGameMenuSettingsFrame.onFrameOpen ~= nil and InGameMenuSettingsFrame._rdpInstallHook ~= true then
    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
        rdp.installMenuIfPossible()
        rdp.refreshMenuStates()
    end)
    InGameMenuSettingsFrame._rdpInstallHook = true
end