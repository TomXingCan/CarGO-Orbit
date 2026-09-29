local _, ns = ...

local InfoBar = ns:GetModule("InfoBar")
local Time = {}
local Clock = {}
Clock.__index = Clock

local function FiniteNumber(value, fallback)
    if type(value) ~= "number" or value ~= value or value == math.huge
        or value == -math.huge then return fallback end
    return value
end

function Time:Format(hour, minute, twentyFour)
    hour = math.floor(FiniteNumber(hour, 0)) % 24
    minute = math.floor(FiniteNumber(minute, 0)) % 60
    if twentyFour == false then
        hour = hour % 12
        if hour == 0 then hour = 12 end
    end
    return string.format("%02d", hour), string.format("%02d", minute)
end

function Time:ReadTime(settings)
    if settings and settings.localTime == false then
        return GetGameTime()
    end
    -- A single read cannot mix the old hour with a new minute at rollover.
    local hour, minute = date("%H:%M"):match("^(%d%d):(%d%d)$")
    return tonumber(hour), tonumber(minute)
end

function Clock:Update()
    if not self.enabled then return end
    local hour, minute = Time:ReadTime(self.settings)
    local twentyFour = self.settings.twentyFour ~= false
    if hour == self.lastHour and minute == self.lastMinute
        and twentyFour == self.lastTwentyFour then return end
    self.lastHour, self.lastMinute, self.lastTwentyFour = hour, minute, twentyFour
    local hourText, minuteText = Time:Format(hour, minute, twentyFour)
    if hourText ~= self.hourText then
        self.hour:SetText(hourText)
        self.hourText = hourText
    end
    if minuteText ~= self.minuteText then
        self.minute:SetText(minuteText)
        self.minuteText = minuteText
    end
end

function Clock:Refresh()
    local path, flags = ns.EUIAdapter:GetFont()
    if type(path) ~= "string" or path == "" then
        local fallbackSize
        if GameFontNormal then path, fallbackSize, flags = GameFontNormal:GetFont() end
        path = path or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    end
    flags = type(flags) == "string" and flags or ""
    local size = math.max(1, FiniteNumber(self.settings.fontSize, 32))
    local hostWidth = self.host:GetWidth()
    -- Fixed symmetric cells, independent of current digits. Fit narrow layouts
    -- by reducing the rendered font, never by changing global slot geometry.
    if type(hostWidth) == "number" and hostWidth > 0 then
        size = math.min(size, hostWidth / 3.1)
    end
    local pairWidth, colonWidth, height = size * 1.35, size * 0.4, size * 1.5
    local sideOffset = (pairWidth + colonWidth) / 2
    self.group:ClearAllPoints()
    self.group:SetPoint("CENTER", self.host, "CENTER", 0,
        FiniteNumber(self.settings.offsetY, 1))
    self.group:SetSize(pairWidth * 2 + colonWidth, height)
    self.hour:SetSize(pairWidth, height)
    self.colon:SetSize(colonWidth, height)
    self.minute:SetSize(pairWidth, height)
    self.hour:ClearAllPoints()
    self.colon:ClearAllPoints()
    self.minute:ClearAllPoints()
    self.hour:SetPoint("CENTER", self.group, "CENTER", -sideOffset, 0)
    self.colon:SetPoint("CENTER", self.group, "CENTER", 0, 0)
    self.minute:SetPoint("CENTER", self.group, "CENTER", sideOffset, 0)
    self.hour:SetFont(path, size, flags)
    self.colon:SetFont(path, size, flags)
    self.minute:SetFont(path, size, flags)
    self.hour:SetTextColor(1, 1, 1, 1)
    self.minute:SetTextColor(1, 1, 1, 1)
    local r, g, b, a = ns.EUIAdapter:GetAccentColor()
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        r, g, b, a = 0.3, 0.8, 1, 1
    end
    self.colon:SetTextColor(r, g, b, type(a) == "number" and a or 1)
    self:Update()
end

function Clock:Enable()
    if self.enabled then return end
    self.enabled = true
    self:Refresh()
    self.ticker = ns.Events:Every(self, 1, self.tick)
end

function Clock:Disable()
    self.enabled = false
    ns.Events:Cleanup(self)
    self.ticker = nil
end

function Time:Create(host, settings)
    local instance = setmetatable({ host = host, settings = settings or {}, enabled = false }, Clock)
    instance.group = CreateFrame("Frame", nil, host)
    instance.group:EnableMouse(false)
    instance.hour = instance.group:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instance.colon = instance.group:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instance.minute = instance.group:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    for _, text in ipairs({ instance.hour, instance.colon, instance.minute }) do
        text:SetJustifyH("CENTER")
        text:SetJustifyV("MIDDLE")
    end
    instance.colon:SetText(":")
    instance.tick = function() instance:Update() end
    return instance
end

InfoBar:RegisterProvider("Time", Time)
