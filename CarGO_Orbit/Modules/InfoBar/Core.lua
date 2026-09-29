local _, ns = ...

local InfoBar = {
    settingsKey = "infoBar",
    enabled = false,
    state = "disabled",
    debugSlots = false,
}
ns:RegisterModule("InfoBar", InfoBar)

function InfoBar:IsEnabled() return self.enabled end

function InfoBar:Settings()
    if not ns.db then ns.Database:Initialize() end
    return ns.db.profile.infoBar
end

function InfoBar:UpdateVisibility()
    local frame = self.Layout.frame
    if not frame then return end
    if not self.enabled then frame:Hide(); return end
    local visibility = self:Settings().visibility
    if visibility == "NO_COMBAT" and self.inCombat then
        frame:Hide()
        return
    end
    frame:Show()
    -- Keep the mouse hit area live at alpha zero; entry/leave events reveal it.
    -- No timer or per-frame cursor polling is needed for this policy.
    local hovered = visibility ~= "MOUSEOVER" or frame:IsMouseOver()
    frame:SetAlpha(hovered and 1 or 0)
end

function InfoBar:RefreshTheme()
    if not self.enabled then return end
    self.Layout:RefreshTheme(self:Settings())
    self.Registry:Refresh()
end

function InfoBar:Apply()
    if not self.enabled then return end
    local settings = ns.Database:RepairInfoBar()
    self.Layout:Apply(settings, self.debugSlots)
    self.Registry:Apply(self.Layout.slots, settings)
    self:UpdateVisibility()
end

function InfoBar:SetDebug(enabled)
    self.debugSlots = enabled == true
    self.Layout:SetDebug(self.enabled and self.debugSlots)
end

function InfoBar:OnSlotEnter(slot)
    if not self.enabled then return end
    self.Layout:SetHovered(slot, true)
    self:UpdateVisibility()
    self.Registry:Dispatch(slot, "OnEnter")
end

function InfoBar:OnSlotLeave(slot)
    self.Layout:SetHovered(slot, false)
    if not self.enabled then return end
    self:UpdateVisibility()
    self.Registry:Dispatch(slot, "OnLeave")
end

local function OnRuntimeEvent(event)
    if not InfoBar.enabled then return end
    if event == "PLAYER_REGEN_DISABLED" then
        InfoBar.inCombat = true
        InfoBar:UpdateVisibility()
    elseif event == "PLAYER_REGEN_ENABLED" then
        InfoBar.inCombat = false
        InfoBar:UpdateVisibility()
    else
        InfoBar:Apply()
    end
end

function InfoBar:Enable()
    local settings = self:Settings()
    settings.enabled = true
    if self.enabled or not ns:IsEnabled() then return end
    self.enabled = true
    self.state = "enabled"
    self.inCombat = not not InCombatLockdown()
    ns.Events:Register(self, "PLAYER_REGEN_DISABLED", OnRuntimeEvent)
    ns.Events:Register(self, "PLAYER_REGEN_ENABLED", OnRuntimeEvent)
    ns.Events:Register(self, "DISPLAY_SIZE_CHANGED", OnRuntimeEvent)
    ns.Events:Register(self, "UI_SCALE_CHANGED", OnRuntimeEvent)
    self:Apply()
    self.unsubscribeReady = ns.EUIAdapter:RegisterReadyCallback(function() self:RefreshTheme() end)
    self.unsubscribeLooks = ns.EUIAdapter:RegisterLooksChangedCallback(function() self:RefreshTheme() end)
    ns:Debug("InfoBar enabled")
end

function InfoBar:Disable(preservePreference)
    if ns.db and not preservePreference then ns.db.profile.infoBar.enabled = false end
    local wasEnabled = self.enabled
    self.enabled = false
    self.state = "disabled"
    self.inCombat = nil
    if self.unsubscribeReady then self.unsubscribeReady(); self.unsubscribeReady = nil end
    if self.unsubscribeLooks then self.unsubscribeLooks(); self.unsubscribeLooks = nil end
    self.Registry:Disable()
    ns.Events:Cleanup(self)
    self.Layout:SetDebug(false)
    self.Layout:Hide()
    if wasEnabled then ns:Debug("InfoBar disabled") end
end
