local addonName, ns = ...

ns.name = addonName or "CarGO_Orbit"
ns.title = "CarGO Orbit"
ns.version = "0.1.0"
ns.debug = false
ns.modules = {}
ns.moduleOrder = {}
ns.capabilities = {
    eui = false,
    skinAPI = false,
    skinAPIVersion = 0,
    dataBarsExtensionAPI = false,
    resourceBarsExtensionAPI = false,
    optionsRegistrationAPI = false,
}

function ns:RegisterModule(name, module)
    if type(name) ~= "string" or name == "" or type(module) ~= "table" then
        return false
    end
    if self.modules[name] then
        return false
    end
    module.name = name
    self.modules[name] = module
    self.moduleOrder[#self.moduleOrder + 1] = name
    return true
end

function ns:GetModule(name)
    return self.modules[name]
end

function ns:IsEnabled()
    return self.enabled == true
end

function ns:Enable()
    if self.enabled then
        return
    end
    if not self.db then
        self.Database:Initialize()
    end
    self.debug = self.db.profile.debug
    self.enabled = true
    self.EUIAdapter:Enable()

    for _, name in ipairs(self.moduleOrder) do
        local module = self.modules[name]
        local settings = self.db.profile[module.settingsKey]
        if type(settings) == "table" and settings.enabled == true and type(module.Enable) == "function" then
            module:Enable()
        end
    end
end

function ns:Disable()
    self.enabled = false
    for _, name in ipairs(self.moduleOrder) do
        -- Shutdown releases resources without changing the user's preference.
        local module = self.modules[name]
        if type(module.Disable) == "function" then
            module:Disable(true)
        end
    end
    if self.DebugPanel then
        self.DebugPanel:Disable()
    end
    if self.EUIAdapter then
        self.EUIAdapter:Disable()
    end
    if self.Events then
        self.Events:Disable()
    end
end

function ns:Initialize()
    if self.initialized then
        return
    end
    self.Database:Initialize()
    self.initialized = true
    self.Diagnostics:RegisterCommands()
    self:Enable()
    self:Debug("Initialized " .. self.version)
end
