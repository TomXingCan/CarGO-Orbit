local _, ns = ...

local InfoBar = ns:GetModule("InfoBar")
local Registry = {
    providers = {},
    instances = {},
    assignments = {},
    count = 0,
}
InfoBar.Registry = Registry

local emptySettings = {}

local function Call(record, method, ...)
    local callback = record.instance and record.instance[method]
    if type(callback) ~= "function" then return true end
    local ok, failure = pcall(callback, record.instance, ...)
    if not ok and not record.failures[method] then
        record.failures[method] = true
        ns:Debug("InfoBar " .. record.key .. " " .. method .. " failed: " .. tostring(failure))
    end
    return ok
end

local function ProviderSettings(settings, key)
    local providers = settings and settings.providers
    if type(providers) == "table" and type(providers[key]) == "table" then
        return providers[key]
    end
    return emptySettings
end

function InfoBar:RegisterProvider(key, factory)
    if type(key) ~= "string" or key == "" or type(factory) ~= "table"
        or type(factory.Create) ~= "function" then
        return false, "invalid-provider"
    end
    if Registry.providers[key] then return false, "duplicate-provider" end
    Registry.providers[key] = factory
    Registry.count = Registry.count + 1
    return true
end

function InfoBar:GetProvider(key)
    return Registry.providers[key]
end

function InfoBar:GetProviderCount()
    return Registry.count
end

local function Detach(record)
    if record.slot then record.slot.frame:SetMouseClickEnabled(false) end
    if record.active then
        record.active = false
        Call(record, "Disable")
    end
    if record.instance then ns.Events:Cleanup(record.instance) end
    record.host:Hide()
    record.host:ClearAllPoints()
    record.host:SetParent(UIParent)
    record.slot = nil
end

function Registry:CreateInstance(key, slot)
    local record = self.instances[key]
    if record then return not record.failed and record or nil end
    local host = CreateFrame("Frame", nil, slot.frame)
    host:EnableMouse(false)
    host:SetAllPoints(slot.frame)
    host:Hide()
    record = { key = key, host = host, active = false, failures = {} }
    self.instances[key] = record
    local ok, instance = pcall(self.providers[key].Create, self.providers[key],
        host, ProviderSettings(self.settings, key))
    local alreadyOwned = false
    if ok and type(instance) == "table" then
        for existingKey, existing in pairs(self.instances) do
            if existingKey ~= key and existing.instance == instance then
                alreadyOwned = true
                break
            end
        end
    end
    if not ok or alreadyOwned or type(instance) ~= "table" or type(instance.Enable) ~= "function"
        or type(instance.Disable) ~= "function" or type(instance.Refresh) ~= "function" then
        -- Keep a failed mount cached as well: a broken factory cannot allocate
        -- another frame on every resize. No runtime callbacks are attached.
        record.failed = true
        record.failures.Create = true
        -- A reused table belongs to its first mount. Reject this mount without
        -- cancelling the original instance's active resources.
        if ok and type(instance) == "table" and not alreadyOwned then record.instance = instance end
        local failure = alreadyOwned and "instance already owned" or tostring(instance)
        ns:Debug("InfoBar " .. key .. " Create failed: " .. failure)
        Detach(record)
        return nil
    end
    -- Create builds owned UI only; acquire events/timers in Enable, after the
    -- registry has a returned instance whose resources it can always clean.
    record.instance = instance
    return record
end

function Registry:Apply(slots, settings)
    self.settings = settings
    local mapping = settings and settings.layout and settings.layout.slots
    local wanted = {}
    -- First assignment wins in deterministic layout order. Missing providers
    -- leave an ordinary empty slot, retaining their logical saved key.
    for _, slot in ipairs(slots) do
        local region = type(mapping) == "table" and mapping[slot.region]
        local key = type(region) == "table" and region[slot.index]
        if type(key) == "string" and self.providers[key] and not wanted[key] then
            wanted[key] = slot
        end
    end
    for key, record in pairs(self.instances) do
        if record.active and not wanted[key] then Detach(record) end
    end
    for slot in pairs(self.assignments) do slot.frame:SetMouseClickEnabled(false) end
    self.assignments = {}
    for _, slot in ipairs(slots) do
        local region = type(mapping) == "table" and mapping[slot.region]
        local key = type(region) == "table" and region[slot.index]
        if type(key) == "string" and wanted[key] == slot then
            local record = self:CreateInstance(key, slot)
            if record then
                record.host:SetParent(slot.frame)
                record.host:ClearAllPoints()
                record.host:SetAllPoints(slot.frame)
                record.slot = slot
                record.instance.settings = ProviderSettings(settings, key)
                self.assignments[slot] = record
                if not record.active then
                    record.active = true
                    if not Call(record, "Enable") then
                        Detach(record)
                        self.assignments[slot] = nil
                    end
                end
                if record.active then
                    Call(record, "Refresh")
                    slot.frame:SetMouseClickEnabled(type(record.instance.OnClick) == "function")
                    record.host:Show()
                end
            end
        end
    end
end

function Registry:Refresh()
    for key, record in pairs(self.instances) do
        if record.active then
            record.instance.settings = ProviderSettings(self.settings, key)
            Call(record, "Refresh")
        end
    end
end

function Registry:Dispatch(slot, event, ...)
    if event ~= "OnEnter" and event ~= "OnLeave" and event ~= "OnClick" then return end
    local record = self.assignments[slot]
    if record and record.active then Call(record, event, ...) end
end

function Registry:Disable()
    for _, record in pairs(self.instances) do Detach(record) end
    self.assignments = {}
    self.settings = nil
end
