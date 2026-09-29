local _, ns = ...

local InfoBar = ns:GetModule("InfoBar")
local Presets = {
    -- Defaults are the canonical mapping. Treat this shared source as read-only.
    toxi = { slots = ns.defaults.profile.infoBar.layout.slots },
}
InfoBar.Presets = Presets

function Presets:Get(name)
    if name == "toxi" then return self.toxi end
end

function Presets:Apply(settings, name)
    local preset = self:Get(name or "toxi")
    if not preset or type(settings) ~= "table" then return false end
    if type(settings.layout) ~= "table" then settings.layout = {} end
    local layout = settings.layout
    layout.preset = name or "toxi"
    if type(layout.slots) ~= "table" then layout.slots = {} end
    for regionName, keys in pairs(preset.slots) do
        if type(layout.slots[regionName]) ~= "table" then layout.slots[regionName] = {} end
        for index = 1, 3 do layout.slots[regionName][index] = keys[index] end
    end
    return true
end
