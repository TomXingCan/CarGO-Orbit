local _, ns = ...

local DebugPanel = {}
ns.DebugPanel = DebugPanel

local function disconnect(panel)
    if panel.unsubscribeReady then panel.unsubscribeReady(); panel.unsubscribeReady = nil end
    if panel.unsubscribeLooks then panel.unsubscribeLooks(); panel.unsubscribeLooks = nil end
    panel.editBox:ClearFocus()
end

local function updateStatus(panel)
    local adapter = ns.EUIAdapter
    if adapter:IsSkinningAvailable() then
        panel.integration:SetText("Skin API v" .. tostring(adapter:GetSkinAPIVersion()))
    else
        panel.integration:SetText("Skin API unavailable / pending / disabled")
    end
end

local function connect(panel)
    disconnect(panel)
    updateStatus(panel)
    panel.unsubscribeReady = ns.EUIAdapter:RegisterReadyCallback(function()
        ns.Skin:Apply(panel)
        updateStatus(panel)
        ns.Skin:RefreshCustom(panel)
    end)
    panel.unsubscribeLooks = ns.EUIAdapter:RegisterLooksChangedCallback(function()
        ns.Skin:RefreshCustom(panel)
    end)
    ns.Skin:RefreshCustom(panel)
end

function DebugPanel:Create()
    if self.panel then return self.panel end
    local panel = { labels = {} }
    self.panel = panel
    local frame = CreateFrame("Frame", nil, UIParent)
    panel.frame = frame
    frame:SetSize(440, 360)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    ns.Skin:Backdrop(frame, 0.08, 0.08, 0.1, 0.98)

    local function label(parent, text, size, x, y)
        local result = ns.Skin:Font(parent, text, size)
        result:SetPoint("TOPLEFT", x, y)
        panel.labels[#panel.labels + 1] = result
        return result
    end
    label(frame, "CarGO Orbit", 20, 20, -18)
    label(frame, ns.version, 12, 20, -44)
    label(frame, "EllesmereUI Integration", 14, 20, -74)
    panel.integration = label(frame, "", 12, 20, -96)

    -- Keep custom art off the shell's own regions, which Shell may fade.
    local accentHost = CreateFrame("Frame", nil, frame)
    accentHost:SetPoint("TOPLEFT", 20, -119)
    accentHost:SetSize(400, 2)
    panel.accent = accentHost:CreateTexture(nil, "ARTWORK")
    panel.accent:SetAllPoints()

    local content = CreateFrame("Frame", nil, frame)
    panel.content = content
    content:SetPoint("TOPLEFT", 20, -137)
    content:SetSize(400, 174)
    ns.Skin:Backdrop(content, 0.12, 0.12, 0.14, 1)

    panel.button = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    panel.button:SetPoint("TOPLEFT", 14, -14)
    panel.button:SetSize(150, 26)
    panel.button:SetText("Test Button")
    panel.button:SetScript("OnClick", function(self)
        self:SetText(self:GetText() == "Test Button" and "Clicked" or "Test Button")
    end)
    panel.labels[#panel.labels + 1] = panel.button:GetFontString()

    panel.checkbox = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    panel.checkbox:SetPoint("TOPLEFT", 14, -52)
    panel.checkbox:SetSize(26, 26)
    panel.checkbox:SetChecked(true)
    label(content, "Test checkbox", 12, 46, -59)

    panel.editBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    panel.editBox:SetPoint("TOPLEFT", 190, -16)
    panel.editBox:SetSize(192, 24)
    panel.editBox:SetAutoFocus(false)
    panel.editBox:SetMaxLetters(64)
    panel.editBox:SetText("Test edit box")
    panel.editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    panel.editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    panel.statusBar = CreateFrame("StatusBar", nil, content)
    panel.statusBar:SetPoint("TOPLEFT", 14, -96)
    panel.statusBar:SetSize(370, 18)
    panel.statusBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    panel.statusBar:SetStatusBarColor(0.25, 0.65, 0.95, 1)
    panel.statusBar:SetMinMaxValues(0, 100)
    panel.statusBar:SetValue(60)
    label(content, "Static sample: 60 / 100 (no resource data)", 12, 14, -134)
    label(frame, "Bootstrap skin test; not an options panel.", 11, 20, -330)

    panel.close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    panel.close:SetPoint("TOPRIGHT", -12, -12)
    panel.close:SetSize(30, 24)
    panel.close:SetText("X")
    panel.close:SetScript("OnClick", function() frame:Hide() end)
    panel.labels[#panel.labels + 1] = panel.close:GetFontString()
    frame:SetScript("OnShow", function() connect(panel) end)
    frame:SetScript("OnHide", function() frame:StopMovingOrSizing(); disconnect(panel) end)
    frame:Hide()
    return panel
end

function DebugPanel:Show()
    if not ns.enabled then return end
    self:Create().frame:Show()
end

function DebugPanel:Hide()
    if self.panel then self.panel.frame:Hide(); disconnect(self.panel) end
end

function DebugPanel:Toggle()
    if not ns.enabled then return end
    local panel = self:Create()
    if panel.frame:IsShown() then self:Hide() else self:Show() end
end

function DebugPanel:Disable()
    self:Hide()
    if self.panel then
        self.panel.checkbox:SetChecked(true)
        self.panel.editBox:SetText("Test edit box")
        self.panel.button:SetText("Test Button")
    end
end
