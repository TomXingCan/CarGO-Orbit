-- Isolated behavioral tests. The mock implements only public WoW UI behavior
-- needed by this bootstrap; it does not reproduce any third-party addon code.
assert(_VERSION == "Lua 5.1", "Run these checks with Lua 5.1")
ADDON_ROOT = ADDON_ROOT or "CarGO_Orbit"
if not TOC_ENTRIES then
    TOC_ENTRIES = {}
    local toc = assert(io.open(ADDON_ROOT .. "/CarGO_Orbit.toc", "r"), "Run tests from the repository root")
    for line in toc:lines() do
        local entry = line:match("^%s*(.-)%s*$")
        if entry ~= "" and entry:sub(1, 1) ~= "#" then
            TOC_ENTRIES[#TOC_ENTRIES + 1] = entry:gsub("\\", "/")
        end
    end
    toc:close()
end
local passed, failed = 0, 0

local function equal(actual, expected, message)
    if actual ~= expected then
        error((message or "Unexpected value") .. ": expected " .. tostring(expected)
            .. ", got " .. tostring(actual), 2)
    end
end

local function test(name, callback)
    local ok, failure = pcall(callback)
    if ok then
        passed = passed + 1
        print("PASS " .. name)
    else
        failed = failed + 1
        print("FAIL " .. name .. ": " .. tostring(failure))
    end
end

local function sandbox(options)
    options = options or {}
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.frames, env.timers, env.messages = {}, {}, {}
    env.SlashCmdList = {}
    env.EllesmereUI = options.eui
    env.CarGOOrbitDB = options.db
    env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, message)
        env.messages[#env.messages + 1] = message
    end }

    local methods = {}
    local function object(kind)
        return setmetatable({ kind = kind, scripts = {}, events = {}, shown = true,
            regions = {}, colorChanges = 0, font = { "Fonts\\FRIZQT__.TTF", 12, "" } }, { __index = methods })
    end
    function methods:SetScript(name, fn) self.scripts[name] = fn end
    function methods:GetScript(name) return self.scripts[name] end
    function methods:RegisterEvent(event) self.events[event] = true end
    function methods:UnregisterEvent(event) self.events[event] = nil end
    function methods:UnregisterAllEvents() self.events = {} end
    function methods:SetSize(width, height) self.width, self.height = width, height end
    function methods:GetWidth() return self.width end
    function methods:GetHeight() return self.height end
    function methods:SetPoint(...) self.point = { ... } end
    function methods:SetAllPoints() end
    function methods:SetFrameStrata(value) self.strata = value end
    function methods:SetClampedToScreen() end
    function methods:EnableMouse() end
    function methods:SetMovable() end
    function methods:RegisterForDrag() end
    function methods:StartMoving() self.moving = true end
    function methods:StopMovingOrSizing() self.moving = false end
    function methods:SetAutoFocus(value) self.autoFocus = value end
    function methods:SetMaxLetters(value) self.maxLetters = value end
    function methods:ClearFocus() self.focused = false end
    function methods:SetText(value) self.text = value end
    function methods:GetText() return self.text end
    function methods:SetChecked(value) self.checked = value end
    function methods:GetChecked() return self.checked end
    function methods:SetFont(...) self.font = { ... } end
    function methods:GetFont() return unpack(self.font) end
    function methods:SetTextColor(...) self.textColor = { ... } end
    function methods:SetColorTexture(...)
        self.color = { ... }
        self.colorChanges = self.colorChanges + 1
    end
    function methods:SetStatusBarTexture(value) self.fillTexture = value end
    function methods:SetStatusBarColor(...) self.fillColor = { ... } end
    function methods:SetMinMaxValues(low, high) self.minimum, self.maximum = low, high end
    function methods:SetValue(value) self.value = value end
    function methods:CreateTexture()
        local result = object("Texture")
        self.regions[#self.regions + 1] = result
        return result
    end
    function methods:CreateFontString()
        local result = object("FontString")
        self.regions[#self.regions + 1] = result
        return result
    end
    function methods:GetFontString()
        if not self.label then self.label = self:CreateFontString() end
        return self.label
    end
    function methods:Show()
        local changed = not self.shown
        self.shown = true
        if changed and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function methods:Hide()
        local changed = self.shown
        self.shown = false
        if changed and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function methods:IsShown() return self.shown end
    env.UIParent = object("Frame")
    env.CreateFrame = function(kind, name, parent, template)
        local frame = object(kind)
        frame.parent, frame.template = parent, template
        env.frames[#env.frames + 1] = frame
        if name then env[name] = frame end
        return frame
    end
    env.C_Timer = { NewTimer = function(seconds, callback)
        local timer = { seconds = seconds, callback = callback, cancelled = false }
        function timer:Cancel() self.cancelled = true end
        function timer:Fire() self.callback() end
        env.timers[#env.timers + 1] = timer
        return timer
    end }
    function env:Fire(event, ...)
        for _, frame in ipairs(self.frames) do
            if frame.events[event] and frame.scripts.OnEvent then
                frame.scripts.OnEvent(frame, event, ...)
            end
        end
    end
    local ns = {}
    for _, entry in ipairs(TOC_ENTRIES) do
        local chunk = assert(loadfile(ADDON_ROOT .. "/" .. entry))
        setfenv(chunk, env)("CarGO_Orbit", ns)
    end
    env.ns = ns
    if options.initialize ~= false then env:Fire("ADDON_LOADED", "CarGO_Orbit") end
    return env, ns
end

local primitives = {
    SkinShell = "Shell", SkinPanel = "Panel", SkinButton = "Button", SkinCheckbox = "Checkbox",
    SkinDropdown = "Dropdown", SkinEditBox = "EditBox", SkinScrollBar = "ScrollBar", SkinTab = "Tab",
    SkinFont = "Font", SkinStatusBar = "ApplyBarFill",
}

local function public_api(version, delayed)
    local probe = { registrations = 0, lookRegistrations = 0, calls = {}, accent = { 0.1, 0.2, 0.3 } }
    local api = { apiVersion = version, IsEnabled = function() return true end }
    for _, primitive in pairs(primitives) do
        local name = primitive
        api[name] = function(...)
            probe.calls[#probe.calls + 1] = { name = name, args = { ... } }
        end
    end
    api.GetAccentColor = function() return unpack(probe.accent) end
    api.GetPanelColor = function() return 0.11, 0.12, 0.13, 0.8 end
    api.GetFont = function() return "test-font", "OUTLINE" end
    api.OnLooksChanged = function(callback)
        equal(type(callback), "function", "OnLooksChanged must receive a function without self")
        probe.lookRegistrations = probe.lookRegistrations + 1
        probe.looks = callback
    end
    local eui = { RegisterSkin = function(name, callback)
        equal(name, "CarGO_Orbit", "RegisterSkin must use addon folder name and dot signature")
        equal(type(callback), "function")
        probe.registrations = probe.registrations + 1
        probe.receive = callback
        if not delayed then callback(api) end
    end }
    return eui, api, probe
end

test("TOC loads safely and initializes only for its own addon", function()
    local env, ns = sandbox({ initialize = false })
    env:Fire("ADDON_LOADED", "UnrelatedAddon")
    equal(ns.initialized, nil)
    env:Fire("ADDON_LOADED", "CarGO_Orbit")
    equal(ns:IsEnabled(), true)
    equal(ns.name, "CarGO_Orbit")
    equal(ns.version, "0.0.1-dev")
    equal(ns.capabilities.eui, false)
    equal(ns.capabilities.skinAPI, false)
    equal(ns.capabilities.dataBarsExtensionAPI, false)
    equal(ns.capabilities.resourceBarsExtensionAPI, false)
    equal(ns.capabilities.optionsRegistrationAPI, false)
    equal(#env.frames, 1, "Bootstrap must not create feature UI")
    equal(#env.messages, 0, "Normal startup must be quiet")
end)

test("database repairs malformed known fields and preserves unknown data", function()
    local original = { profile = { debug = "wrong", infoBar = { enabled = "wrong", future = 37 },
        enhancedResourceBars = false, custom = { keep = true } }, meta = { schemaVersion = "wrong", future = 8 }, future = 9 }
    local env, ns = sandbox({ db = original })
    equal(ns.db, original)
    equal(env.CarGOOrbitDB, original)
    equal(ns.db.profile.debug, false)
    equal(ns.db.profile.infoBar.enabled, false)
    equal(ns.db.profile.infoBar.future, 37)
    equal(ns.db.profile.enhancedResourceBars.enabled, false)
    equal(ns.db.profile.custom.keep, true)
    equal(ns.db.meta.schemaVersion, 1)
    equal(ns.db.meta.future, 8)
    equal(ns.db.future, 9)
    ns.db.profile.debug = true
    ns.Database:Initialize()
    equal(ns.db.profile.debug, true, "Defaults must not overwrite valid settings")
    for _, malformed in ipairs({ false, 12, "broken" }) do
        local _, repaired = sandbox({ db = malformed })
        equal(repaired.db.meta.schemaVersion, 1)
        equal(repaired.db.profile.infoBar.enabled, false)
    end
end)

test("module stubs persist explicit toggles and preserve preferences on shutdown", function()
    local env, ns = sandbox()
    local info, resources = ns:GetModule("InfoBar"), ns:GetModule("EnhancedResourceBars")
    equal(info:IsEnabled(), false)
    equal(resources:IsEnabled(), false)
    local frameCount = #env.frames
    info:Enable(); resources:Enable()
    equal(info:IsEnabled(), true)
    equal(resources.state, "enabled-but-no-host")
    equal(ns.db.profile.infoBar.enabled, true)
    equal(ns.db.profile.enhancedResourceBars.enabled, true)
    equal(#env.frames, frameCount, "Stubs must not create feature frames")
    ns:Disable()
    equal(info:IsEnabled(), false)
    equal(resources:IsEnabled(), false)
    equal(ns.db.profile.infoBar.enabled, true)
    ns:Enable()
    equal(info:IsEnabled(), true)
    equal(resources.state, "enabled-but-no-host")
    info:Disable(); resources:Disable()
    equal(ns.db.profile.infoBar.enabled, false)
    equal(ns.db.profile.enhancedResourceBars.enabled, false)
end)

test("owned events and timers are isolated and released on Disable", function()
    local env, ns = sandbox()
    local first, second = ns:GetModule("InfoBar"), ns:GetModule("EnhancedResourceBars")
    local firstCalls, secondCalls, timerCalls = 0, 0, 0
    ns.Events:Register(first, "TEST_EVENT", function(event, value)
        equal(event, "TEST_EVENT"); equal(value, 17); firstCalls = firstCalls + 1
    end)
    ns.Events:Register(second, "TEST_EVENT", function() secondCalls = secondCalls + 1 end)
    local timer = ns.Events:After(first, 1, function() timerCalls = timerCalls + 1 end)
    env:Fire("TEST_EVENT", 17)
    equal(firstCalls, 1); equal(secondCalls, 1)
    first:Disable()
    equal(timer.cancelled, true)
    timer:Fire() -- A late queued timer callback must remain harmless.
    equal(timerCalls, 0)
    env:Fire("TEST_EVENT", 17)
    equal(firstCalls, 1); equal(secondCalls, 2)
    local activeTimer = ns.Events:After(second, 1, function() timerCalls = timerCalls + 1 end)
    ns:Disable()
    equal(activeTimer.cancelled, true)
    activeTimer:Fire(); env:Fire("TEST_EVENT", 17)
    equal(secondCalls, 2); equal(timerCalls, 0)
    equal(next(ns.Events.handlers), nil); equal(next(ns.Events.timers), nil)
    for _, frame in ipairs(env.frames) do
        equal(next(frame.events), nil)
        equal(frame.scripts.OnUpdate, nil)
    end
    ns:Enable()
    ns.Events:Register(first, "TEST_EVENT", function() firstCalls = firstCalls + 1 end)
    env:Fire("TEST_EVENT", 17)
    equal(firstCalls, 2, "Event service must be usable again after enabling")
end)

test("missing or malformed EUI fails open", function()
    for _, host in ipairs({ false, "wrong", {}, { RegisterSkin = 1 } }) do
        local _, ns = sandbox({ eui = host })
        equal(ns.EUIAdapter:IsSkinningAvailable(), false)
        equal(ns.EUIAdapter:GetSkinAPIVersion(), 0)
        for wrapper in pairs(primitives) do equal(ns.EUIAdapter[wrapper](ns.EUIAdapter, {}), false) end
        equal(ns.EUIAdapter:GetAccentColor(), nil)
        equal(ns.EUIAdapter:GetPanelColor(), nil)
        equal(ns.EUIAdapter:GetFont(), nil)
        equal(ns:GetModule("InfoBar"):IsEnabled(), false)
    end
end)

test("versions and optional primitives are detected independently", function()
    for _, version in ipairs({ 0, -1, "2", false, math.huge, 0 / 0 }) do
        local eui = public_api(version)
        local _, ns = sandbox({ eui = eui })
        equal(ns.EUIAdapter:IsSkinningAvailable(), false)
        equal(ns.EUIAdapter:SkinButton({}), false)
    end
    local eui, api = public_api(1)
    api.ApplyBarFill = nil
    local _, ns = sandbox({ eui = eui })
    equal(ns.EUIAdapter:GetSkinAPIVersion(), 1)
    equal(ns.EUIAdapter:IsSkinningAvailable(), true)
    equal(ns.EUIAdapter:SkinButton({}), true)
    equal(ns.EUIAdapter:SkinStatusBar({}), false)
    api.IsEnabled = nil
    equal(ns.EUIAdapter:IsSkinningAvailable(), false)
    api.IsEnabled = function() return false end
    equal(ns.EUIAdapter:SkinButton({}), false)
    local missingVersion, missingAPI = public_api(2)
    missingAPI.apiVersion = nil
    local _, unknown = sandbox({ eui = missingVersion })
    equal(unknown.EUIAdapter:IsSkinningAvailable(), false)
end)

test("adapter preserves documented dot-call arguments and getter returns", function()
    local eui, _, probe = public_api(2)
    local _, ns = sandbox({ eui = eui })
    local target, opts = {}, { noBorder = true }
    for wrapper, primitive in pairs(primitives) do
        equal(ns.EUIAdapter[wrapper](ns.EUIAdapter, target, opts), true)
        local call = probe.calls[#probe.calls]
        equal(call.name, primitive)
        equal(call.args[1], target, "Public primitive must receive target without self")
        if wrapper == "SkinShell" or wrapper == "SkinPanel" then equal(call.args[2], opts) end
    end
    local r, g, b = ns.EUIAdapter:GetAccentColor()
    equal(r, 0.1); equal(g, 0.2); equal(b, 0.3)
    local pr, pg, pb, pa = ns.EUIAdapter:GetPanelColor()
    equal(pr, 0.11); equal(pg, 0.12); equal(pb, 0.13); equal(pa, 0.8)
    local path, outline = ns.EUIAdapter:GetFont()
    equal(path, "test-font"); equal(outline, "OUTLINE")
    equal(ns.EUIAdapter:SkinButton(nil), false)
end)

test("throwing public calls do not break addon or unrelated primitives", function()
    local eui, api = public_api(2)
    api.Button = function() error("simulated public API failure") end
    api.GetAccentColor = function() error("simulated getter failure") end
    local _, ns = sandbox({ eui = eui })
    equal(ns.EUIAdapter:SkinButton({}), false)
    equal(ns.EUIAdapter:GetAccentColor(), nil)
    equal(ns.EUIAdapter:SkinPanel({}), true)
    api.IsEnabled = function() error("simulated state query failure") end
    equal(ns.EUIAdapter:SkinPanel({}), false)
    local _, failedRegistration = sandbox({ eui = { RegisterSkin = function() error("registration failed") end } })
    equal(failedRegistration:IsEnabled(), true)
    equal(failedRegistration.EUIAdapter:IsSkinningAvailable(), false)
end)

test("delayed and malformed skin callbacks are safe", function()
    local eui, api, probe = public_api(2, true)
    local _, ns = sandbox({ eui = eui })
    local ready = 0
    ns.EUIAdapter:RegisterReadyCallback(function() ready = ready + 1 end)
    equal(ns.EUIAdapter:IsSkinningAvailable(), false)
    probe.receive(nil); probe.receive(false); probe.receive("wrong")
    equal(ready, 0)
    probe.receive(api)
    equal(ready, 1)
    equal(ns.EUIAdapter:IsSkinningAvailable(), true)
    local immediate = 0
    local unsubscribe = ns.EUIAdapter:RegisterReadyCallback(function() immediate = immediate + 1 end)
    equal(immediate, 1)
    unsubscribe()
    ns.EUIAdapter:Disable(); probe.receive(api)
    equal(ready, 1)
    equal(immediate, 1)
    equal(ns.EUIAdapter:IsSkinningAvailable(), false)
end)

test("looks subscriptions unsubscribe, isolate failures and stay inactive after Disable", function()
    local eui, _, probe = public_api(2)
    local _, ns = sandbox({ eui = eui })
    local first, second = 0, 0
    local unsubscribe = ns.EUIAdapter:RegisterLooksChangedCallback(function() first = first + 1 end)
    ns.EUIAdapter:RegisterLooksChangedCallback(function() error("listener failure") end)
    ns.EUIAdapter:RegisterLooksChangedCallback(function() second = second + 1 end)
    probe.looks(); equal(first, 1); equal(second, 1)
    unsubscribe(); probe.looks(); equal(first, 1); equal(second, 2)
    ns.EUIAdapter:Disable(); probe.looks(); equal(second, 2)
    ns.EUIAdapter:Enable()
    local fresh = 0
    ns.EUIAdapter:RegisterLooksChangedCallback(function() fresh = fresh + 1 end)
    probe.looks(); equal(second, 2); equal(fresh, 1)
    equal(probe.registrations, 1); equal(probe.lookRegistrations, 1)
end)

test("Disable and unsubscribe during callbacks prevent further delivery", function()
    local eui, _, probe = public_api(2)
    local _, ns = sandbox({ eui = eui })
    local calls = 0
    -- Either callback can run first; it must stop the other immediately.
    for _ = 1, 2 do
        ns.EUIAdapter:RegisterLooksChangedCallback(function()
            calls = calls + 1
            ns.EUIAdapter:Disable()
        end)
    end
    probe.looks(); equal(calls, 1)
    ns.EUIAdapter:Enable()
    local unsubscribeA, unsubscribeB
    local function unsubscribeBoth()
        calls = calls + 1
        unsubscribeA(); unsubscribeB()
    end
    unsubscribeA = ns.EUIAdapter:RegisterLooksChangedCallback(function() unsubscribeBoth() end)
    unsubscribeB = ns.EUIAdapter:RegisterLooksChangedCallback(function() unsubscribeBoth() end)
    probe.looks(); equal(calls, 2)
    probe.looks(); equal(calls, 2)
    local events = 0
    for _, owner in ipairs({ {}, {} }) do
        ns.Events:Register(owner, "STOP_EVENT", function()
            events = events + 1
            ns.Events:Disable()
        end)
    end
    ns.Events.frame:GetScript("OnEvent")(ns.Events.frame, "STOP_EVENT")
    equal(events, 1)
end)

test("a panel opened during disabled skinning gets one first skin when enabled", function()
    local eui, api, probe = public_api(2)
    local enabled = false
    api.IsEnabled = function() return enabled end
    local _, ns = sandbox({ eui = eui })
    ns.DebugPanel:Show()
    equal(#probe.calls, 0)
    enabled = true
    probe.looks()
    assert(#probe.calls > 0)
    local firstSkinCalls = #probe.calls
    equal(ns.DebugPanel.panel.integration:GetText(), "Skin API v2")
    probe.looks(); probe.looks()
    equal(#probe.calls, firstSkinCalls, "Readiness must be delivered once per subscription")
    enabled = false
    ns.Diagnostics:Status()
    equal(ns.capabilities.skinAPI, false, "Status must refresh live capabilities")
end)

test("invalid and failed timers leave no owned records", function()
    local env, ns = sandbox()
    local owner = {}
    for _, delay in ipairs({ -1, math.huge, -math.huge, 0 / 0, "1" }) do
        equal(ns.Events:After(owner, delay, function() end), nil)
    end
    equal(next(ns.Events.timers), nil)
    env.C_Timer.NewTimer = function() error("timer creation failure") end
    equal(ns.Events:After(owner, 1, function() end), nil)
    equal(next(ns.Events.timers), nil)
end)

test("lazy debug panel skins after delayed readiness and recolors without rebuilding", function()
    local eui, api, probe = public_api(2, true)
    local env, ns = sandbox({ eui = eui })
    equal(ns.DebugPanel.panel, nil)
    ns.DebugPanel:Show()
    local panel = ns.DebugPanel.panel
    equal(panel.frame:IsShown(), true)
    equal(panel.statusBar.value, 60)
    equal(#probe.calls, 0)
    probe.receive(api)
    local seen = {}
    for _, call in ipairs(probe.calls) do seen[call.name] = true end
    for _, required in ipairs({ "Shell", "Panel", "Button", "Checkbox", "EditBox", "ApplyBarFill", "Font" }) do
        equal(seen[required], true, "Debug panel must skin " .. required)
    end
    equal(panel.integration:GetText(), "Skin API v2")
    local frameCount, primitiveCalls = #env.frames, #probe.calls
    probe.accent = { 0.6, 0.7, 0.8 }
    probe.looks()
    equal(panel.accent.color[1], 0.6)
    equal(panel.accent.color[2], 0.7)
    equal(panel.accent.color[3], 0.8)
    equal(#env.frames, frameCount)
    equal(#probe.calls, primitiveCalls, "Looks callback must only update custom colors")
    ns.DebugPanel:Hide()
    local changes = panel.accent.colorChanges
    probe.looks(); equal(panel.accent.colorChanges, changes)
    for _ = 1, 10 do ns.DebugPanel:Toggle(); ns.DebugPanel:Toggle() end
    equal(#env.frames, frameCount)
    ns.DebugPanel:Show()
    panel.editBox.focused = true
    ns:Disable()
    equal(panel.frame:IsShown(), false)
    equal(panel.editBox.focused, false)
    changes = panel.accent.colorChanges
    probe.looks(); equal(panel.accent.colorChanges, changes)
    ns:Enable(); ns.DebugPanel:Show()
    equal(ns.DebugPanel.panel, panel)
    equal(#env.frames, frameCount)
    equal(probe.registrations, 1); equal(probe.lookRegistrations, 1)
    local before = panel.accent.colorChanges
    probe.looks(); equal(panel.accent.colorChanges, before + 1, "No duplicate panel looks listeners")
    for _, frame in ipairs(env.frames) do equal(frame.scripts.OnUpdate, nil) end
end)

test("slash aliases report status, persist debug and reuse panel", function()
    local env, ns = sandbox()
    equal(env.SLASH_CARGOORBIT1, "/orbit")
    equal(env.SLASH_CARGOORBIT2, "/cgo")
    local command = env.SlashCmdList.CARGOORBIT
    equal(type(command), "function")
    command("status")
    equal(#env.messages, 10)
    local status = table.concat(env.messages, "\n")
    assert(status:find("InfoBar: disabled", 1, true))
    assert(status:find("ResourceBars extension: no", 1, true))
    command("debug"); equal(ns.db.profile.debug, true)
    command("debug"); equal(ns.db.profile.debug, false)
    command("panel"); equal(ns.DebugPanel.panel.frame:IsShown(), true)
    command("panel"); equal(ns.DebugPanel.panel.frame:IsShown(), false)
end)

test("debug logging remains bounded across toggles", function()
    local env, ns = sandbox()
    ns.debug = true
    for _ = 1, 1000 do ns:Debug("repeated event") end
    equal(#env.messages, 101)
    ns.debug = false; ns:Debug("hidden"); ns.debug = true
    ns:Debug("budget already spent")
    equal(#env.messages, 101)
end)

print(string.format("Behavioral tests: %d passed, %d failed (Lua 5.1; mocked WoW runtime)", passed, failed))
if failed > 0 then error(tostring(failed) .. " behavioral test(s) failed") end
