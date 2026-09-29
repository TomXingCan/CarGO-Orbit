local _, ns = ...

local Database = {}
ns.Database = Database

local function ApplyDefaults(target, defaults)
    for key, default in pairs(defaults) do
        if defaults == ns.defaults.profile and key == "enhancedResourceBars" and target[key] ~= nil then
            -- This migration is scoped to InfoBar. Preserve existing ERB data verbatim.
        elseif type(default) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ApplyDefaults(target[key], default)
        elseif type(target[key]) ~= type(default) then
            target[key] = default
        end
    end
end

local function Clamp(value, default, minimum, maximum)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return default
    end
    return math.max(minimum, math.min(maximum, value))
end

function Database:RepairInfoBar()
    local settings = ns.db.profile.infoBar
    local defaults = ns.defaults.profile.infoBar
    if type(settings) ~= "table" then
        settings = {}
        ns.db.profile.infoBar = settings
    end
    ApplyDefaults(settings, defaults)
    if settings.position ~= "TOP" and settings.position ~= "BOTTOM" then settings.position = defaults.position end
    if settings.visibility ~= "ALWAYS" and settings.visibility ~= "NO_COMBAT"
        and settings.visibility ~= "MOUSEOVER" then settings.visibility = defaults.visibility end
    if settings.width ~= 0 then settings.width = Clamp(settings.width, 0, 240, 10000) end
    settings.height = Clamp(settings.height, defaults.height, 16, 100)
    settings.spacing = Clamp(settings.spacing, defaults.spacing, 0, 100)
    settings.background.alpha = Clamp(settings.background.alpha, defaults.background.alpha, 0, 1)
    settings.providers.Time.fontSize = Clamp(settings.providers.Time.fontSize, 32, 8, 64)
    settings.providers.Time.offsetY = Clamp(settings.providers.Time.offsetY, 1, -40, 40)
    -- Only this preset is implemented. Unknown slots/fields remain intact.
    settings.layout.preset = "toxi"
    return settings
end

local function ResetKnown(target, defaults)
    for key, default in pairs(defaults) do
        if type(default) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            ResetKnown(target[key], default)
        else
            target[key] = default
        end
    end
end

function Database:ResetInfoBar()
    local settings = self:RepairInfoBar()
    local enabled = settings.enabled
    ResetKnown(settings, ns.defaults.profile.infoBar)
    settings.enabled = enabled
    return settings
end

function Database:Initialize()
    if type(CarGOOrbitDB) ~= "table" then
        CarGOOrbitDB = {}
    end
    ApplyDefaults(CarGOOrbitDB, ns.defaults)
    ns.db = CarGOOrbitDB
    self:RepairInfoBar()
    local version = ns.db.meta.schemaVersion
    if type(version) ~= "number" or version ~= version or version == math.huge or version < 2 then
        ns.db.meta.schemaVersion = 2
    end
    ns.debug = ns.db.profile.debug
    return ns.db
end
