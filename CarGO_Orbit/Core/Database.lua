local _, ns = ...

local Database = {}
ns.Database = Database

local function ApplyDefaults(target, defaults)
    for key, default in pairs(defaults) do
        if type(default) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ApplyDefaults(target[key], default)
        elseif type(target[key]) ~= type(default) then
            target[key] = default
        end
    end
end

function Database:Initialize()
    if type(CarGOOrbitDB) ~= "table" then
        CarGOOrbitDB = {}
    end
    ApplyDefaults(CarGOOrbitDB, ns.defaults)
    ns.db = CarGOOrbitDB
    ns.debug = ns.db.profile.debug
    return ns.db
end
