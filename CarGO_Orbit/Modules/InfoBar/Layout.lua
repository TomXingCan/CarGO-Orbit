local _, ns = ...

local InfoBar = ns:GetModule("InfoBar")
local Layout = { defaultFontSize = 16, slots = {}, regions = {} }
InfoBar.Layout = Layout

local regionNames = { "left", "center", "right" }

local function number(value, fallback, minimum)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return fallback
    end
    return math.max(minimum, value)
end

-- Geometry has no dependency on provider content or the frame API.
function Layout:Calculate(width, height, spacing)
    width = number(width, 1, 1)
    height = number(height, 30, 1)
    spacing = number(spacing, 20, 0)
    local padding = math.min(12, width / 20)
    local innerWidth = width - padding * 2
    -- Keep hosts positive and distinct even on unusually narrow displays.
    spacing = math.min(spacing, innerWidth / 16)
    local slotWidth = (innerWidth - spacing * 8) / 9
    local regionWidth = slotWidth * 3 + spacing * 2
    local result = {
        width = width, height = height, spacing = spacing, padding = padding,
        slotWidth = slotWidth, regionWidth = regionWidth, slots = {}, regions = {},
    }
    for _, regionName in ipairs(regionNames) do
        local x
        if regionName == "left" then
            x = padding
        elseif regionName == "center" then
            x = (width - regionWidth) / 2
        else
            x = width - padding - regionWidth
        end
        result.regions[regionName] = {
            x = x, width = regionWidth, height = height, centerX = x + regionWidth / 2,
        }
        for index = 1, 3 do
            local slotX = x + (index - 1) * (slotWidth + spacing)
            local centerX = slotX + slotWidth / 2
            if regionName == "center" and index == 2 then centerX = width / 2 end
            result.slots[#result.slots + 1] = {
                id = regionName .. index, region = regionName, index = index,
                x = slotX, width = slotWidth, height = height, centerX = centerX,
            }
        end
    end
    return result
end

local function makeDebug(slot)
    local frame = CreateFrame("Frame", nil, slot.frame)
    frame:SetAllPoints()
    frame:EnableMouse(false)
    slot.debugFrame = frame
    slot.debugBackground = frame:CreateTexture(nil, "BACKGROUND")
    slot.debugBackground:SetAllPoints()
    slot.debugEdges = {}
    local anchors = {
        { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
        { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false },
    }
    for _, anchorsForEdge in ipairs(anchors) do
        local edge = frame:CreateTexture(nil, "BORDER")
        edge:SetPoint(anchorsForEdge[1], frame, anchorsForEdge[1], 0, 0)
        edge:SetPoint(anchorsForEdge[2], frame, anchorsForEdge[2], 0, 0)
        if anchorsForEdge[3] then edge:SetHeight(1) else edge:SetWidth(1) end
        slot.debugEdges[#slot.debugEdges + 1] = edge
    end
    slot.debugLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    slot.debugLabel:SetPoint("TOPLEFT", 3, -2)
    slot.debugLabel:SetText(string.upper(slot.region) .. " " .. slot.index)
    frame:Hide()
end

function Layout:Ensure()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", nil, UIParent)
    self.frame = frame
    frame:SetFrameStrata("LOW")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMouseClickEnabled(false)
    self.background = frame:CreateTexture(nil, "BACKGROUND")
    self.background:SetAllPoints()
    frame:SetScript("OnEnter", function() InfoBar:UpdateVisibility() end)
    frame:SetScript("OnLeave", function() InfoBar:UpdateVisibility() end)
    for _, regionName in ipairs(regionNames) do
        local region = CreateFrame("Frame", nil, frame)
        self.regions[regionName] = region
        for index = 1, 3 do
            local slot = { id = regionName .. index, region = regionName, index = index }
            local host = CreateFrame("Button", nil, region)
            slot.frame = host
            host:EnableMouse(true)
            host:SetMouseClickEnabled(false)
            host:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            host:SetScript("OnEnter", function() InfoBar:OnSlotEnter(slot) end)
            host:SetScript("OnLeave", function() InfoBar:OnSlotLeave(slot) end)
            host:SetScript("OnClick", function(_, button)
                if InfoBar.Registry then InfoBar.Registry:Dispatch(slot, "OnClick", button) end
            end)
            slot.highlight = host:CreateTexture(nil, "BACKGROUND")
            slot.highlight:SetAllPoints()
            slot.highlight:SetAlpha(0)
            makeDebug(slot)
            self.slots[#self.slots + 1] = slot
        end
    end
    frame:Hide()
    return frame
end

function Layout:SetHovered(slot, hovered)
    if slot and slot.highlight then slot.highlight:SetAlpha(hovered and 0.045 or 0) end
end

function Layout:SetDebug(enabled)
    self.debugSlots = enabled == true
    for _, slot in ipairs(self.slots) do
        if self.debugSlots then slot.debugFrame:Show() else slot.debugFrame:Hide() end
    end
end

function Layout:RefreshTheme(settings)
    if not self.frame then return end
    settings = settings or self.settings or {}
    local adapter = ns.EUIAdapter
    local r, g, b = adapter:GetPanelColor()
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        r, g, b = 0.06, 0.07, 0.09
    end
    local background = settings.background or {}
    local alpha = math.min(1, number(background.alpha, 0.25, 0))
    self.background:SetColorTexture(r, g, b, background.enabled == false and 0 or alpha)
    local accentR, accentG, accentB = adapter:GetAccentColor()
    if type(accentR) ~= "number" or type(accentG) ~= "number" or type(accentB) ~= "number" then
        accentR, accentG, accentB = 0.25, 0.65, 0.95
    end
    local font, flags = adapter:GetFont()
    local fallback, _, fallbackFlags = self.slots[1].debugLabel:GetFont()
    self.font = type(font) == "string" and font or fallback
    self.fontFlags = type(flags) == "string" and flags or fallbackFlags
    for _, slot in ipairs(self.slots) do
        slot.highlight:SetColorTexture(accentR, accentG, accentB, 1)
        slot.debugBackground:SetColorTexture(accentR, accentG, accentB, 0.025)
        for _, edge in ipairs(slot.debugEdges) do
            edge:SetColorTexture(accentR, accentG, accentB, 0.22)
        end
        slot.debugLabel:SetFont(self.font, 9, self.fontFlags)
        slot.debugLabel:SetTextColor(accentR, accentG, accentB, 0.8)
    end
end

function Layout:Apply(settings, debugSlots)
    self:Ensure()
    self.settings = settings
    local width = number(settings.width, 0, 0)
    local availableWidth = math.max(1, (UIParent:GetWidth() or 1920) - 24)
    if width == 0 then width = availableWidth else width = math.min(width, availableWidth) end
    local geometry = self:Calculate(width, settings.height, settings.spacing)
    self.geometry = geometry
    local frame = self.frame
    frame:ClearAllPoints()
    frame:SetSize(geometry.width, geometry.height)
    local position = settings.position == "TOP" and "TOP" or "BOTTOM"
    frame:SetPoint(position, UIParent, position, 0, 0)
    for _, regionName in ipairs(regionNames) do
        local region = self.regions[regionName]
        region:ClearAllPoints()
        region:SetSize(geometry.regionWidth, geometry.height)
        if regionName == "center" then
            region:SetPoint("CENTER", frame, "CENTER", 0, 0)
        elseif regionName == "left" then
            region:SetPoint("LEFT", frame, "LEFT", geometry.padding, 0)
        else
            region:SetPoint("RIGHT", frame, "RIGHT", -geometry.padding, 0)
        end
    end
    for _, slot in ipairs(self.slots) do
        local host = slot.frame
        host:ClearAllPoints()
        host:SetSize(geometry.slotWidth, geometry.height)
        -- Independent centers ensure that provider text cannot displace Time.
        host:SetPoint("CENTER", self.regions[slot.region], "CENTER",
            (slot.index - 2) * (geometry.slotWidth + geometry.spacing), 0)
    end
    self:RefreshTheme(settings)
    self:SetDebug(debugSlots)
    return frame
end

function Layout:Hide()
    if self.frame then self.frame:Hide() end
    self.settings = nil
    for _, slot in ipairs(self.slots) do self:SetHovered(slot, false) end
end
