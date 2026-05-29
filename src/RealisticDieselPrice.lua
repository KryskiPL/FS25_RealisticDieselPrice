--[[

Author:     KryskiPL (https://github.com/KryskiPL)
Version:    v1.0.0.0

Changelog:
    v1.0.0.0  - Publish FS25
]]
RealisticDieselPrice = {}
function RealisticDieselPrice:loadMap(name)
    local dieselType = g_fillTypeManager:getFillTypeByName("DIESEL")
    if dieselType ~= nil then
        -- Default: 6.80
        dieselType.pricePerLiter = 6.80
    end
end
addModEventListener(RealisticDieselPrice)