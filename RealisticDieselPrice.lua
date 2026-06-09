--[[ RealisticDieselPrice.lua

Author:     KryskiPL (https://github.com/KryskiPL)
Version:    v1.0.0.0

]]--
RealisticDieselPrice = {}
local rdp = RealisticDieselPrice

rdp.modDirectory = g_currentModDirectory or ""
rdp.settingsDirectory = (g_modSettingsDirectory or (getUserProfileAppPath() .. "modSettings")) .. "/FS25_RealisticDieselPrice/"
rdp.settingsFile = rdp.settingsDirectory .. "settings.xml"

rdp.priceOptions = {
    {label = "Poland (1.60 Euro)", price = 1.60},
    {label = "Poland Hard (6.30 Euro)", price = 6.30},
    {label = "Germany (1.80 Euro)", price = 1.80},
    {label = "France (1.59 Euro)", price = 1.59}
}
rdp.currentState = 2 
rdp.menuInstalled = false
rdp.menuControls = {}

local function loadSettings()
    createFolder(rdp.settingsDirectory)
    if not fileExists(rdp.settingsFile) then return end
    local xmlFile = XMLFile.loadIfExists("rdpSettingsXML", rdp.settingsFile)
    if xmlFile == nil then return end
    local state = xmlFile:getInt("settings#priceState")
    if state ~= nil and rdp.priceOptions[state] ~= nil then
        rdp.currentState = state
    end
    xmlFile:delete()
end

local function saveSettings()
    createFolder(rdp.settingsDirectory)
    local xmlFile = XMLFile.create("rdpSettingsXML", rdp.settingsFile, "settings")
    if xmlFile == nil then return end
    xmlFile:setInt("settings#priceState", rdp.currentState)
    xmlFile:save()
    xmlFile:delete()
end

function rdp.applyCurrentPrice()
    local currentOption = rdp.priceOptions[rdp.currentState]
    if currentOption == nil then return end
    if g_fillTypeManager ~= nil then
        local dieselType = g_fillTypeManager:getFillTypeByName("DIESEL")
        if dieselType ~= nil then
            dieselType.pricePerLiter = currentOption.price
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

local function getOptionTexts()
    local texts = {}
    for index, option in ipairs(rdp.priceOptions) do
        texts[index] = option.label
    end
    return texts
end

local function addMenuOption(settingsPage, settingsLayout)
    local multiTemplate = settingsPage.multiVolumeVoiceBox or settingsPage.soundVolumeEnvironmentBox
    if multiTemplate == nil or multiTemplate.clone == nil then return false end
    local optionBox = multiTemplate:clone(settingsLayout)
    optionBox.id = "rdpPriceSelectionBox"
    local option = optionBox.elements[1]
    option.id = "rdpPriceSelection"
    option.target = rdp
    option:setCallback("onClickCallback", "onPriceChanged")
    option:setDisabled(false)
    option:setTexts(getOptionTexts())
    option:setState(rdp.currentState)
    local tooltip = option.elements[1]
    if tooltip ~= nil then
        tooltip:setText("Choose the country fuel pricing you want to play with. Changes apply immediately.")
    end
    local label = optionBox.elements[2]
    if label ~= nil then
        label:setText("Realistic Diesel Price Region")
    end
    assignFocusIds(optionBox)
    table.insert(settingsPage.controlsList, optionBox)
    rdp.menuControls.rdpPriceSelection = option
    return true
end

function rdp:onPriceChanged(state)
    if rdp.priceOptions[state] == nil then return end
    rdp.currentState = state
    saveSettings()
    rdp.applyCurrentPrice()
end

function rdp.refreshMenuStates()
    local control = rdp.menuControls.rdpPriceSelection
    if control ~= nil then
        control:setState(rdp.currentState, nil, true)
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
    if not addMenuOption(settingsPage, settingsLayout) then return end
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