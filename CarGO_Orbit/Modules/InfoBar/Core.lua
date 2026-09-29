local _, ns = ...

local InfoBar = {
    settingsKey = "infoBar",
    enabled = false,
    state = "disabled",
}

function InfoBar:IsEnabled()
    return self.enabled
end

function InfoBar:Enable()
    if not ns.db then
        ns.Database:Initialize()
    end
    ns.db.profile.infoBar.enabled = true
    if self.enabled then
        return
    end
    self.enabled = true
    self.state = "enabled"
    ns:Debug("InfoBar enabled (lifecycle stub)")
end

function InfoBar:Disable(preservePreference)
    if ns.db and not preservePreference then
        ns.db.profile.infoBar.enabled = false
    end
    local wasEnabled = self.enabled
    self.enabled = false
    self.state = "disabled"
    if ns.Events then
        ns.Events:Cleanup(self)
    end
    if wasEnabled then
        ns:Debug("InfoBar disabled")
    end
end

ns:RegisterModule("InfoBar", InfoBar)
