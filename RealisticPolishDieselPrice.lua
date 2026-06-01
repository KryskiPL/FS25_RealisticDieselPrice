--[[ RealisticDieselPrice.lua

Author:     KryskiPL (https://github.com/KryskiPL)
Version:    v1.0.0.0

]]--

RealisticDieselPrice = {}
function RealisticDieselPrice:loadMap(name)
    local dieselType = g_fillTypeManager:getFillTypeByName("DIESEL")
    if dieselType ~= nil then
        -- Default: 6.30
        dieselType.pricePerLiter = 6.30
    end
end
addModEventListener(RealisticDieselPrice)