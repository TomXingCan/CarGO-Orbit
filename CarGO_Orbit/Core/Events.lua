local _, ns = ...

local Events = {
    handlers = {},
    timers = {},
}
ns.Events = Events

local function ReportFailure(kind, failure)
    ns:Debug(kind .. " callback failed: " .. tostring(failure))
end

local function Dispatch(_, event, ...)
    local handlers = Events.handlers[event]
    if not handlers then
        return
    end
    -- A callback may unregister itself or another owner while dispatching.
    local pending = {}
    for owner, callback in pairs(handlers) do
        pending[#pending + 1] = { owner = owner, callback = callback }
    end
    for _, entry in ipairs(pending) do
        if Events.handlers[event] == handlers and handlers[entry.owner] == entry.callback then
            local ok, failure = pcall(entry.callback, event, ...)
            if not ok then
                ReportFailure("Event", failure)
            end
        end
    end
end

function Events:Register(owner, event, callback)
    if owner == nil or type(event) ~= "string" or event == ""
        or type(callback) ~= "function" then
        return false
    end
    if not self.frame then
        self.frame = CreateFrame("Frame")
    end
    self.frame:SetScript("OnEvent", Dispatch)
    if not self.handlers[event] then
        self.handlers[event] = {}
        self.frame:RegisterEvent(event)
    end
    self.handlers[event][owner] = callback
    return true
end

function Events:Unregister(owner, event)
    local handlers = self.handlers[event]
    if not handlers then
        return
    end
    handlers[owner] = nil
    if next(handlers) == nil then
        self.handlers[event] = nil
        self.frame:UnregisterEvent(event)
    end
end

function Events:After(owner, seconds, callback)
    if owner == nil or type(seconds) ~= "number" or seconds < 0
        or seconds ~= seconds or seconds == math.huge
        or type(callback) ~= "function" or not C_Timer
        or type(C_Timer.NewTimer) ~= "function" then
        return nil
    end
    local records = self.timers[owner]
    if not records then
        records = {}
        self.timers[owner] = records
    end
    local record = { callback = callback }
    records[record] = true
    local ok, timer = pcall(C_Timer.NewTimer, seconds, function()
        local run = record.callback
        record.callback = nil
        record.timer = nil
        records[record] = nil
        if next(records) == nil and self.timers[owner] == records then
            self.timers[owner] = nil
        end
        if run then
            local ok, failure = pcall(run)
            if not ok then
                ReportFailure("Timer", failure)
            end
        end
    end)
    if not ok or timer == nil then
        record.callback = nil
        records[record] = nil
        if next(records) == nil then
            self.timers[owner] = nil
        end
        if not ok then
            ReportFailure("Timer creation", timer)
        end
        return nil
    end
    record.timer = timer
    return timer
end

function Events:Cleanup(owner)
    local events = {}
    for event, handlers in pairs(self.handlers) do
        if handlers[owner] then
            events[#events + 1] = event
        end
    end
    for _, event in ipairs(events) do
        self:Unregister(owner, event)
    end

    local records = self.timers[owner]
    if records then
        for record in pairs(records) do
            record.callback = nil
            if record.timer and type(record.timer.Cancel) == "function" then
                record.timer:Cancel()
            end
            record.timer = nil
            records[record] = nil
        end
        self.timers[owner] = nil
    end
end

function Events:Disable()
    if self.frame then
        self.frame:UnregisterAllEvents()
        self.frame:SetScript("OnEvent", nil)
        self.frame:Hide()
    end
    self.handlers = {}
    local owners = {}
    for owner in pairs(self.timers) do
        owners[#owners + 1] = owner
    end
    for _, owner in ipairs(owners) do
        self:Cleanup(owner)
    end
end

-- Loaded last by the TOC so every service is ready before initialization.
Events:Register(ns, "ADDON_LOADED", function(_, loadedAddon)
    if loadedAddon == ns.name then
        Events:Unregister(ns, "ADDON_LOADED")
        ns:Initialize()
    end
end)
