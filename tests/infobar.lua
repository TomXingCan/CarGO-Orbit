-- InfoBar integration checks share the isolated public-WoW mock in run.lua.
return function(test, equal, sandbox, public_api)
    local function near(actual, expected, message)
        assert(type(actual) == "number" and math.abs(actual - expected) < 0.000001,
            (message or "Geometry differs") .. ": " .. tostring(actual) .. " vs " .. tostring(expected))
    end

    local function liveTimers(env)
        local count = 0
        for _, timer in ipairs(env.timers) do
            if not timer.cancelled then count = count + 1 end
        end
        return count
    end

    local function clock(info)
        local record = info.Registry.instances.Time
        assert(record and record.active, "Time must have one active registry instance")
        return record.instance
    end

    test("InfoBar defaults migrate old schema without replacing existing tables", function()
        local resource = { enabled = false, future = { value = 42 } }
        local settings = { enabled = false, future = { value = 17 } }
        local original = { profile = { infoBar = settings, enhancedResourceBars = resource },
            meta = { schemaVersion = 1, future = "keep" } }
        local _, ns = sandbox({ db = original })
        equal(ns.db, original)
        equal(ns.db.profile.infoBar, settings)
        equal(ns.db.profile.enhancedResourceBars, resource)
        equal(resource.future.value, 42)
        equal(settings.future.value, 17)
        equal(ns.db.meta.schemaVersion, 2)
        equal(ns.db.meta.future, "keep")
        equal(settings.enabled, false)
        equal(settings.position, "BOTTOM")
        equal(settings.width, 0)
        equal(settings.height, 30)
        equal(settings.spacing, 20)
        equal(settings.visibility, "ALWAYS")
        equal(settings.background.enabled, true)
        equal(settings.background.alpha, 0.25)
        equal(settings.layout.preset, "toxi")
        equal(settings.providers.Time.localTime, true)
        equal(settings.providers.Time.twentyFour, true)
        equal(settings.providers.Time.fontSize, 32)
        equal(settings.providers.Time.offsetY, 1)
        local layout, background, providers = settings.layout, settings.background, settings.providers
        settings.position, settings.width = "TOP", 1200
        settings.providers.Time.localTime, settings.providers.Time.twentyFour = false, false
        ns.Database:Initialize(); ns.Database:Initialize()
        equal(ns.db.profile.infoBar, settings)
        equal(settings.layout, layout); equal(settings.background, background)
        equal(settings.providers, providers)
        equal(settings.position, "TOP"); equal(settings.width, 1200)
        equal(settings.providers.Time.localTime, false)
        equal(settings.providers.Time.twentyFour, false)
    end)

    test("InfoBar migration leaves all existing Resource Bars data untouched", function()
        for _, original in ipairs({ false, true, "future-data", 7, {}, { custom = { keep = true } } }) do
            local _, ns = sandbox({ db = { profile = { enhancedResourceBars = original } } })
            equal(ns.db.profile.enhancedResourceBars, original)
            ns.Database:Initialize(); ns.Database:ResetInfoBar()
            equal(ns.db.profile.enhancedResourceBars, original)
            if type(original) == "table" then equal(original.enabled, nil) end
        end
        local _, fresh = sandbox()
        equal(fresh.db.profile.enhancedResourceBars.enabled, false)
    end)

    test("InfoBar repair validates ranges and keeps unknown nested settings", function()
        local settings = { enabled = "yes", position = "SIDE", width = math.huge,
            height = 1, spacing = -2, visibility = "unsupported",
            background = { enabled = "yes", alpha = 3, extra = 8 },
            layout = { preset = "toxi", slots = { left = { false, 8, "" }, extra = { "Future" } } },
            providers = { Time = { localTime = "yes", twentyFour = false,
                fontSize = 90, offsetY = -200, extra = 9 }, Future = { x = 1 } } }
        local _, ns = sandbox({ db = { profile = { infoBar = settings } } })
        equal(settings.enabled, false); equal(settings.position, "BOTTOM")
        equal(settings.width, 0); equal(settings.height, 16); equal(settings.spacing, 0)
        equal(settings.visibility, "ALWAYS")
        equal(settings.background.enabled, true); equal(settings.background.alpha, 1)
        equal(settings.background.extra, 8)
        equal(settings.layout.slots.left[1], "MicroMenu")
        equal(settings.layout.slots.left[2], "")
        equal(settings.layout.slots.left[3], "", "Explicit empty assignment must survive")
        equal(settings.layout.slots.extra[1], "Future")
        equal(settings.providers.Time.localTime, true)
        equal(settings.providers.Time.twentyFour, false)
        equal(settings.providers.Time.fontSize, 64); equal(settings.providers.Time.offsetY, -40)
        equal(settings.providers.Time.extra, 9); equal(settings.providers.Future.x, 1)
        for _, invalid in ipairs({ false, "invalid", math.huge, -math.huge, 0 / 0 }) do
            settings.width, settings.height, settings.spacing = invalid, invalid, invalid
            settings.background.alpha = invalid
            settings.providers.Time.fontSize, settings.providers.Time.offsetY = invalid, invalid
            ns.Database:RepairInfoBar()
            equal(settings.width, 0); equal(settings.height, 30); equal(settings.spacing, 20)
            equal(settings.background.alpha, 0.25)
            equal(settings.providers.Time.fontSize, 32); equal(settings.providers.Time.offsetY, 1)
        end
        settings.width, settings.height, settings.spacing = 1, 999, 999
        ns.Database:RepairInfoBar()
        equal(settings.width, 240); equal(settings.height, 100); equal(settings.spacing, 100)
    end)

    test("Toxi preset preserves the frozen nine logical provider assignments", function()
        local _, ns = sandbox()
        local slots = ns.db.profile.infoBar.layout.slots
        equal(table.concat(slots.left, "|"), "MicroMenu||Durability")
        equal(table.concat(slots.center, "|"), "Travel|Time|Spec")
        equal(table.concat(slots.right, "|"), "XPRep|Currency|System")
        local other = select(2, sandbox())
        slots.left[1] = "Future"
        equal(other.db.profile.infoBar.layout.slots.left[1], "MicroMenu", "Defaults must not share mutable arrays")
    end)

    test("nine-slot geometry has unique cells and an invariant center", function()
        local _, ns = sandbox()
        local layout = ns:GetModule("InfoBar").Layout
        for _, dimensions in ipairs({ { 1920, 30, 20 }, { 1200, 48, 10 }, { 240, 16, 100 }, { 12, 30, 20 } }) do
            local data = layout:Calculate(unpack(dimensions))
            equal(#data.slots, 9)
            local ids, previousRight = {}, nil
            for index, slot in ipairs(data.slots) do
                equal(ids[slot.id], nil, "Slot IDs must be unique")
                ids[slot.id] = true
                equal(slot.index, ((index - 1) % 3) + 1)
                assert(slot.width >= 0 and slot.height > 0, "Geometry must remain nonnegative")
                near(slot.centerX, slot.x + slot.width / 2)
                assert(slot.x >= -0.000001 and slot.x + slot.width <= data.width + 0.000001)
                if previousRight then assert(slot.x >= previousRight - 0.000001, "Slots overlap") end
                previousRight = slot.x + slot.width
            end
            near(data.slots[5].centerX, data.width / 2, "Time slot must stay geometrically centered")
            near(data.regions.center.centerX, data.width / 2)
            near(data.slots[1].centerX + data.slots[9].centerX, data.width)
            near(data.slots[4].centerX + data.slots[6].centerX, data.width)
        end
    end)

    test("InfoBar creates nine reusable slots and applies top bottom and width settings", function()
        local env, ns = sandbox()
        local info = ns:GetModule("InfoBar")
        info:Enable()
        local frame, slots = info.Layout.frame, info.Layout.slots
        equal(#slots, 9); equal(frame:IsShown(), true)
        equal(frame.mouseClickEnabled, false, "Backdrop must let game clicks pass through")
        local seen = {}
        for _, slot in ipairs(slots) do
            equal(seen[slot.frame], nil); seen[slot.frame] = true
            equal(slot.debugFrame:IsShown(), false)
            equal(slot.frame.mouseClickEnabled, false, "Time and missing providers must let clicks pass through")
        end
        local frames, timers, instance = #env.frames, #env.timers, clock(info)
        local settings = info:Settings()
        settings.position, settings.width, settings.height, settings.spacing = "TOP", 1200, 40, 12
        info:Apply()
        equal(info.Layout.frame, frame); equal(info.Layout.slots, slots)
        equal(frame.point[1], "TOP"); equal(frame:GetWidth(), 1200); equal(frame:GetHeight(), 40)
        equal(clock(info), instance)
        equal(#env.frames, frames); equal(#env.timers, timers)
        near(info.Layout.regions.center.point[4], 0)
        equal(info.Layout.regions.center.point[1], "CENTER")
        equal(slots[5].frame.point[2], info.Layout.regions.center)
        near(slots[5].frame.point[4], 0, "Clock host must anchor directly to region center")
        settings.position, settings.width = "BOTTOM", 0
        env.UIParent:SetSize(1600, 900)
        info:Apply()
        equal(frame.point[1], "BOTTOM")
        assert(frame:GetWidth() >= 1500 and frame:GetWidth() <= 1600, "Auto width must track UIParent")
        equal(#env.frames, frames); equal(#env.timers, timers)
        settings.width = 10000
        info:Apply()
        assert(frame:GetWidth() <= 1600, "Configured bar must fit within the viewport")
        settings.width = 240
        info:Apply()
        assert(instance.group:GetWidth() <= slots[5].frame:GetWidth() + 0.000001,
            "Rendered clock must fit a narrow slot without changing slot geometry")
        equal(settings.providers.Time.fontSize, 32, "Responsive rendering must preserve saved font size")
        info:SetDebug(true)
        for _, slot in ipairs(slots) do equal(slot.debugFrame:IsShown(), true) end
        info:SetDebug(false)
        for _, slot in ipairs(slots) do equal(slot.debugFrame:IsShown(), false) end
        equal(#env.frames, frames, "Debug toggles must reuse overlays")
    end)

    test("provider registration rejects duplicate keys and missing providers stay empty", function()
        local _, ns = sandbox()
        local info = ns:GetModule("InfoBar")
        local original = info:GetProvider("Time")
        equal(info:GetProviderCount(), 1)
        equal(type(original), "table")
        equal(info:RegisterProvider("Time", { Create = function() error("must not replace Time") end }), false)
        equal(info:GetProvider("Time"), original); equal(info:GetProviderCount(), 1)
        equal(info:GetProvider("Currency"), nil)
        info:Enable()
        local active = 0
        for _, record in pairs(info.Registry.instances) do
            if record.active then active = active + 1 end
        end
        equal(active, 1)
        equal(info.Registry.instances.Currency, nil)
        equal(info.Registry.instances.MicroMenu, nil)
    end)

    test("provider lifecycle keeps one instance for duplicate assignments and reassignments", function()
        local env, ns = sandbox()
        local info, count = ns:GetModule("InfoBar"), { create = 0, enable = 0, disable = 0, refresh = 0, click = 0 }
        local factory = {}
        function factory:Create(host, settings)
            count.create = count.create + 1
            local instance = { host = host, settings = settings }
            function instance:Enable() count.enable = count.enable + 1 end
            function instance:Disable() count.disable = count.disable + 1 end
            function instance:Refresh() count.refresh = count.refresh + 1 end
            function instance:OnClick(button) equal(button, "LeftButton"); count.click = count.click + 1 end
            return instance
        end
        equal(info:RegisterProvider("Probe", factory), true)
        local settings = info:Settings()
        settings.layout.slots.left = { "Probe", "Probe", "Unknown" }
        info:Enable()
        equal(count.create, 1); equal(count.enable, 1)
        equal(info.Layout.slots[1].frame.mouseClickEnabled, true)
        equal(info.Layout.slots[2].frame.mouseClickEnabled, false)
        local instance = info.Registry.instances.Probe.instance
        local frames, timers = #env.frames, #env.timers
        info:Apply(); info:Enable(); info:Apply()
        equal(count.create, 1); equal(count.enable, 1)
        equal(info.Registry.instances.Probe.instance, instance)
        equal(#env.frames, frames); equal(#env.timers, timers)
        info.Registry:Dispatch(info.Layout.slots[1], "OnClick", "LeftButton")
        info.Registry:Dispatch(info.Layout.slots[2], "OnClick", "LeftButton")
        equal(count.click, 1, "Only the assigned slot may deliver provider input")
        settings.layout.slots.left[1], settings.layout.slots.left[2] = "", ""
        info:Apply()
        equal(count.disable, 1)
        equal(info.Layout.slots[1].frame.mouseClickEnabled, false)
        settings.layout.slots.right[1] = "Probe"
        info:Apply()
        equal(count.create, 1, "A provider must be reused when moved")
        equal(count.enable, 2)
        info:Disable(); info:Disable()
        equal(count.disable, 2, "Disable should be idempotent")
    end)

    test("failed providers release owned runtime and do not break the working clock", function()
        local env, ns = sandbox()
        local info, creates, failedInstance = ns:GetModule("InfoBar"), 0, nil
        info:RegisterProvider("BrokenCreate", { Create = function()
            creates = creates + 1
            error("simulated creation failure")
        end })
        info:RegisterProvider("BrokenEnable", { Create = function()
            local instance = {}
            failedInstance = instance
            function instance:Enable()
                ns.Events:Register(self, "BROKEN_PROVIDER_EVENT", function() error("must be cleaned") end)
                ns.Events:Every(self, 1, function() error("must be cleaned") end)
                error("simulated enable failure")
            end
            function instance:Disable() error("cleanup must survive provider failure") end
            function instance:Refresh() end
            return instance
        end })
        info:RegisterProvider("Incomplete", { Create = function() return {} end })
        info:Settings().layout.slots.left = { "BrokenCreate", "BrokenEnable", "Incomplete" }
        info:Enable()
        equal(clock(info).hour:GetText(), "23")
        equal(liveTimers(env), 1, "Failed enable must cancel any timer it acquired")
        equal(ns.Events.timers[failedInstance], nil)
        equal(ns.Events.handlers.BROKEN_PROVIDER_EVENT, nil)
        equal(info.Registry.instances.BrokenEnable.active, false)
        equal(info.Registry.instances.Incomplete.active, false, "Incomplete provider contract must not activate")
        local frameCount = #env.frames
        info:Apply(); info:Apply()
        equal(creates, 1, "Failed factory must not allocate again on resize")
        equal(#env.frames, frameCount); equal(liveTimers(env), 1)
        info:Disable()
        equal(liveTimers(env), 0)
    end)

    test("two provider keys cannot activate the same singleton or cancel its original ticker", function()
        local env, ns = sandbox()
        local info = ns:GetModule("InfoBar")
        local creates, enables, disables, ticks = 0, 0, 0, 0
        local instance = {}
        function instance:Enable()
            enables = enables + 1
            self.ticker = ns.Events:Every(self, 1, function() ticks = ticks + 1 end)
        end
        function instance:Disable() disables = disables + 1; ns.Events:Cleanup(self) end
        function instance:Refresh() end
        local factory = { Create = function() creates = creates + 1; return instance end }
        equal(info:RegisterProvider("First", factory), true)
        equal(info:RegisterProvider("Second", factory), true)
        info:Settings().layout.slots.left = { "First", "Second", "" }
        info:Settings().providers.First = { owner = "first" }
        info:Settings().providers.Second = { owner = "second" }
        info:Enable()
        local originalTicker, frameCount = instance.ticker, #env.frames
        equal(creates, 2); equal(enables, 1); equal(disables, 0)
        equal(info.Registry.instances.First.active, true)
        equal(info.Registry.instances.Second.active, false)
        equal(info.Registry.instances.Second.failed, true)
        equal(instance.settings.owner, "first", "Rejected mount must not change the active instance settings")
        equal(originalTicker.cancelled, false); equal(liveTimers(env), 2)
        originalTicker:Fire(); equal(ticks, 1)
        for _ = 1, 5 do info:Apply() end
        equal(creates, 2, "Rejected duplicate mount must remain cached")
        equal(enables, 1); equal(disables, 0); equal(#env.frames, frameCount)
        equal(instance.ticker, originalTicker); equal(originalTicker.cancelled, false)
        info:Disable()
        equal(disables, 1); equal(originalTicker.cancelled, true); equal(liveTimers(env), 0)
        originalTicker:Fire(); equal(ticks, 1)
        info:Enable()
        equal(creates, 2); equal(enables, 2); equal(liveTimers(env), 2)
        equal(info.Registry.instances.Second.active, false)
    end)

    test("repeating timer service rejects invalid intervals and clears failed allocations", function()
        local env, ns = sandbox()
        local owner = {}
        for _, interval in ipairs({ 0, -1, math.huge, -math.huge, 0 / 0, "1" }) do
            equal(ns.Events:Every(owner, interval, function() end), nil)
        end
        equal(next(ns.Events.timers), nil)
        env.C_Timer.NewTicker = function() error("ticker creation failed") end
        equal(ns.Events:Every(owner, 1, function() end), nil)
        equal(next(ns.Events.timers), nil)
        env.C_Timer.NewTicker = function() return nil end
        equal(ns.Events:Every(owner, 1, function() end), nil)
        equal(next(ns.Events.timers), nil)
    end)

    test("Time formats both clocks without secondary AM PM text", function()
        local _, ns = sandbox()
        local provider = ns:GetModule("InfoBar"):GetProvider("Time")
        for _, case in ipairs({
            { 0, 0, true, "00", "00" }, { 0, 7, false, "12", "07" },
            { 12, 30, false, "12", "30" }, { 23, 59, false, "11", "59" },
            { 9, 4, true, "09", "04" }, { 13, 5, true, "13", "05" },
        }) do
            local hour, minute = provider:Format(case[1], case[2], case[3])
            equal(hour, case[4]); equal(minute, case[5])
        end
    end)

    test("Time selects local or server data and updates through one cancellable ticker", function()
        local env, ns = sandbox()
        local info = ns:GetModule("InfoBar")
        info:Enable()
        local instance = clock(info)
        equal(instance.hour:GetText(), "23"); equal(instance.colon:GetText(), ":")
        equal(instance.minute:GetText(), "07")
        assert(instance.hour ~= instance.colon and instance.colon ~= instance.minute)
        equal(instance.colon.template, "GameFontNormal", "Colon must have a font before its initial SetText")
        equal(instance.ticker.seconds, 1); equal(instance.ticker.repeating, true)
        equal(liveTimers(env), 1)
        for _ = 1, 8 do info:Enable(); info:Apply() end
        equal(clock(info), instance); equal(#env.timers, 1)
        env.localMinute = 8
        instance.ticker:Fire()
        equal(instance.minute:GetText(), "08")
        info:Settings().providers.Time.localTime = false
        info:Apply()
        equal(instance.hour:GetText(), "06"); equal(instance.minute:GetText(), "45")
        env.serverHour = 18
        info:Settings().providers.Time.twentyFour = false
        instance.ticker:Fire()
        equal(instance.hour:GetText(), "06")
        local ticker, text = instance.ticker, instance.minute:GetText()
        info:Disable()
        equal(ticker.cancelled, true); equal(liveTimers(env), 0)
        env.serverMinute = 59
        ticker:Fire()
        equal(instance.minute:GetText(), text, "Late cancelled callbacks must be harmless")
        equal(next(ns.Events.timers), nil)
        info:Enable()
        equal(clock(info), instance); equal(liveTimers(env), 1)
        equal(#env.timers, 2)
    end)

    test("saved enabled InfoBar starts without EUI and shutdown releases its runtime", function()
        local env, ns = sandbox({ eui = false, db = { profile = { infoBar = { enabled = true } } } })
        local info = ns:GetModule("InfoBar")
        equal(info:IsEnabled(), true); equal(info.Layout.frame:IsShown(), true)
        equal(clock(info).hour:GetText(), "23")
        equal(ns.EUIAdapter:IsSkinningAvailable(), false)
        local frameCount = #env.frames
        ns:Disable()
        equal(info.Layout.frame:IsShown(), false); equal(liveTimers(env), 0)
        equal(next(ns.Events.handlers), nil); equal(next(ns.Events.timers), nil)
        equal(info:Settings().enabled, true)
        for _, frame in ipairs(env.frames) do
            equal(frame.scripts.OnUpdate, nil); equal(next(frame.events), nil)
        end
        ns:Enable()
        equal(info:IsEnabled(), true); equal(#env.frames, frameCount); equal(liveTimers(env), 1)
    end)

    test("visibility supports always combat events and mouse hit zones without polling", function()
        local env, ns = sandbox({ combat = true })
        local info = ns:GetModule("InfoBar")
        info:Settings().visibility = "NO_COMBAT"
        info:Enable()
        local frame = info.Layout.frame
        equal(frame:IsShown(), false, "NO_COMBAT must respect initial combat state")
        env.combat = false; env:Fire("PLAYER_REGEN_ENABLED")
        equal(frame:IsShown(), true)
        env.combat = true; env:Fire("PLAYER_REGEN_DISABLED")
        equal(frame:IsShown(), false)
        info:Settings().visibility = "ALWAYS"; info:Apply()
        equal(frame:IsShown(), true); equal(frame:GetAlpha(), 1)
        info:Settings().visibility = "MOUSEOVER"; info:Apply()
        equal(frame:IsShown(), true, "Hidden mouseover bar must retain an active hit zone")
        equal(frame:GetAlpha(), 0)
        frame.hovered = true
        frame:GetScript("OnEnter")(frame)
        equal(frame:GetAlpha(), 1)
        frame.hovered = false
        frame:GetScript("OnLeave")(frame)
        equal(frame:GetAlpha(), 0)
        local slot = info.Layout.slots[5]
        frame.hovered, slot.frame.hovered = true, true
        slot.frame:GetScript("OnEnter")(slot.frame)
        equal(frame:GetAlpha(), 1)
        frame.hovered, slot.frame.hovered = false, false
        slot.frame:GetScript("OnLeave")(slot.frame)
        equal(frame:GetAlpha(), 0)
        for _, candidate in ipairs(env.frames) do equal(candidate.scripts.OnUpdate, nil) end
        info:Disable()
        equal(frame:IsShown(), false); equal(liveTimers(env), 0)
        for _, handlers in pairs(ns.Events.handlers) do equal(handlers[info], nil) end
    end)

    test("InfoBar follows public font and accent changes without rebuilding providers", function()
        local eui, api, probe = public_api(2)
        local env, ns = sandbox({ eui = eui })
        local info = ns:GetModule("InfoBar")
        info:Enable()
        local instance, frames, timers = clock(info), #env.frames, #env.timers
        equal(instance.hour.font[1], "test-font")
        probe.accent = { 0.8, 0.3, 0.4 }
        api.GetFont = function() return "updated-font", "OUTLINE" end
        probe.looks()
        equal(instance.hour.font[1], "updated-font")
        near(instance.colon.textColor[1], 0.8)
        near(instance.colon.textColor[2], 0.3)
        near(instance.colon.textColor[3], 0.4)
        equal(clock(info), instance); equal(#env.frames, frames); equal(#env.timers, timers)
        info:Disable()
        api.GetFont = function() return "inactive-font", "" end
        probe.looks()
        equal(instance.hour.font[1], "updated-font", "Disabled modules must unsubscribe from theme changes")
        equal(probe.lookRegistrations, 1)
    end)

    test("InfoBar commands toggle runtime and overlays and reset known settings in place", function()
        local env, ns = sandbox()
        local command, info = env.SlashCmdList.CARGOORBIT, ns:GetModule("InfoBar")
        local settings, resources = info:Settings(), ns.db.profile.enhancedResourceBars
        command("infobar")
        equal(info:IsEnabled(), true); equal(settings.enabled, true)
        command("infobar debug")
        equal(info.debugSlots, true)
        for _, slot in ipairs(info.Layout.slots) do equal(slot.debugFrame:IsShown(), true) end
        command("infobar debug")
        equal(info.debugSlots, false)
        settings.width, settings.position, settings.visibility = 800, "TOP", "MOUSEOVER"
        settings.layout.slots.left[1] = "Custom"
        settings.providers.Time.twentyFour = false
        settings.future, settings.background.future = 21, 22
        settings.providers.Time.future = 23
        local layout, slots, background, time = settings.layout, settings.layout.slots,
            settings.background, settings.providers.Time
        command("infobar reset")
        equal(info:Settings(), settings); equal(settings.layout, layout)
        equal(settings.layout.slots, slots); equal(settings.background, background)
        equal(settings.providers.Time, time)
        equal(settings.enabled, true); equal(settings.width, 0); equal(settings.position, "BOTTOM")
        equal(settings.visibility, "ALWAYS"); equal(settings.providers.Time.twentyFour, true)
        equal(settings.layout.slots.left[1], "MicroMenu")
        equal(settings.future, 21); equal(settings.background.future, 22)
        equal(settings.providers.Time.future, 23); equal(ns.db.profile.enhancedResourceBars, resources)
        equal(liveTimers(env), 1)
        command("infobar")
        equal(info:IsEnabled(), false); equal(settings.enabled, false); equal(liveTimers(env), 0)
        command("infobar reset")
        equal(info:IsEnabled(), false); equal(settings.enabled, false)
    end)

    test("InfoBar setting commands apply validated values without restarting runtime", function()
        local env, ns = sandbox()
        local command, info = env.SlashCmdList.CARGOORBIT, ns:GetModule("InfoBar")
        command("infobar")
        local settings, frameCount, tickerCount = info:Settings(), #env.frames, #env.timers
        local instance = clock(info)
        command("infobar position top"); equal(settings.position, "TOP")
        equal(info.Layout.frame.point[1], "TOP")
        command("infobar position bottom"); equal(settings.position, "BOTTOM")
        command("infobar width 0"); equal(settings.width, 0)
        command("infobar width 1200"); equal(settings.width, 1200)
        equal(info.Layout.frame:GetWidth(), 1200)
        command("infobar height 44"); equal(settings.height, 44)
        equal(info.Layout.frame:GetHeight(), 44)
        command("infobar spacing 12"); equal(settings.spacing, 12)
        command("infobar visibility no_combat"); equal(settings.visibility, "NO_COMBAT")
        command("infobar visibility mouseover"); equal(settings.visibility, "MOUSEOVER")
        equal(info.Layout.frame:GetAlpha(), 0)
        command("infobar visibility always"); equal(settings.visibility, "ALWAYS")
        equal(info.Layout.frame:GetAlpha(), 1)
        command("infobar time server"); equal(settings.providers.Time.localTime, false)
        equal(instance.hour:GetText(), "06"); equal(instance.minute:GetText(), "45")
        command("infobar time local"); equal(settings.providers.Time.localTime, true)
        equal(instance.hour:GetText(), "23")
        command("infobar time 12"); equal(settings.providers.Time.twentyFour, false)
        equal(instance.hour:GetText(), "11")
        command("infobar time 24"); equal(settings.providers.Time.twentyFour, true)
        equal(instance.hour:GetText(), "23")
        command("infobar font 40"); equal(settings.providers.Time.fontSize, 40)
        command("infobar offset -4"); equal(settings.providers.Time.offsetY, -4)
        equal(instance.group.point[5], -4)
        command("infobar background 0.4"); equal(settings.background.alpha, 0.4)
        command("infobar background off"); equal(settings.background.enabled, false)
        equal(info.Layout.background.color[4], 0)
        command("infobar background on"); equal(settings.background.enabled, true)
        equal(info.Layout.background.color[4], 0.4)
        for _, invalid in ipairs({ "position side", "width -1", "width 239", "width 10001", "width text",
            "height 15", "height 101", "spacing -1", "spacing 101", "visibility resting",
            "time utc", "time 25", "font 7", "font 65", "offset -41", "offset 41",
            "background -0.1", "background 1.1", "background maybe", "debug extra", "reset extra" }) do
            command("infobar " .. invalid)
        end
        equal(settings.position, "BOTTOM"); equal(settings.width, 1200); equal(settings.height, 44)
        equal(settings.spacing, 12); equal(settings.visibility, "ALWAYS")
        equal(settings.providers.Time.localTime, true); equal(settings.providers.Time.twentyFour, true)
        equal(settings.providers.Time.fontSize, 40); equal(settings.providers.Time.offsetY, -4)
        equal(settings.background.enabled, true); equal(settings.background.alpha, 0.4)
        equal(info.debugSlots, false)
        equal(clock(info), instance); equal(#env.frames, frameCount); equal(#env.timers, tickerCount)
        equal(liveTimers(env), 1)
    end)
end
