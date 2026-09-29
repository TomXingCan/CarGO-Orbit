local _, ns = ...

local EnhancedResourceBars = {
    settingsKey = "enhancedResourceBars",
    enabled = false,
    state = "disabled",
}

function EnhancedResourceBars:IsEnabled()
    return self.enabled
end

function EnhancedResourceBars:Enable()
    if not ns.db then
        ns.Database:Initialize()
    end
    ns.db.profile.enhancedResourceBars.enabled = true
    if self.enabled then
        return
    end
    self.enabled = true
    -- No host contract is implemented at this stage, even if capabilities evolve.
    self.state = "enabled-but-no-host"
    ns:Debug("Enhanced Resource Bars enabled-but-no-host (public host API unsupported)")
end

function EnhancedResourceBars:Disable(preservePreference)
    if ns.db and not preservePreference then
        ns.db.profile.enhancedResourceBars.enabled = false
    end
    local wasEnabled = self.enabled
    self.enabled = false
    self.state = "disabled"
    if ns.Events then
        ns.Events:Cleanup(self)
    end
    if wasEnabled then
        ns:Debug("Enhanced Resource Bars disabled")
    end
end

ns:RegisterModule("EnhancedResourceBars", EnhancedResourceBars)
