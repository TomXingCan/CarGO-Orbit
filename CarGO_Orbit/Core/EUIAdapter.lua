local _, ns = ...

-- Contract: https://github.com/EllesmereGaming/EllesmereUI/blob/main/SKINNING_API.md
-- This file is the only integration boundary. All S functions use dot calls.
local Adapter = { active = false }
ns.EUIAdapter = Adapter

local skin
local registrationAttempted = false
local looksRegistered = false
local readyListeners = {}
local looksListeners = {}
local reportedErrors = {}

local function report(operation)
    if reportedErrors[operation] then return end
    reportedErrors[operation] = true
    if ns.Debug then ns:Debug("Skin API call unavailable: " .. operation) end
end

local function dispatch(listeners, once)
    local pending = {}
    for fn in pairs(listeners) do pending[#pending + 1] = fn end
    for _, fn in ipairs(pending) do
        if not Adapter.active or (listeners ~= readyListeners and listeners ~= looksListeners) then return end
        if listeners[fn] ~= nil and (not once or not listeners[fn]) then
            listeners[fn] = true
            if not pcall(fn) then report("Orbit listener") end
        end
    end
end

function Adapter:IsAvailable()
    return type(_G.EllesmereUI) == "table"
end

function Adapter:GetSkinAPIVersion()
    local version = skin and skin.apiVersion
    if type(version) ~= "number" or version < 1 or version ~= version or version == math.huge then return 0 end
    return version
end

function Adapter:IsSkinningAvailable()
    if not self.active or not self:IsAvailable() or self:GetSkinAPIVersion() < 1 then
        return false
    end
    if type(skin.IsEnabled) ~= "function" then return false end
    local ok, enabled = pcall(skin.IsEnabled)
    return ok and enabled == true
end

function Adapter:RefreshCapabilities()
    ns.capabilities.eui = self:IsAvailable()
    ns.capabilities.skinAPI = self:IsSkinningAvailable()
    ns.capabilities.skinAPIVersion = self:GetSkinAPIVersion()
    -- No documented extension/registration contracts have been adopted.
    ns.capabilities.dataBarsExtensionAPI = false
    ns.capabilities.resourceBarsExtensionAPI = false
    ns.capabilities.optionsRegistrationAPI = false
end

local function looksChanged()
    Adapter:RefreshCapabilities()
    if Adapter:IsSkinningAvailable() then
        -- A panel opened while skinning was disabled still needs its first skin.
        dispatch(readyListeners, true)
        dispatch(looksListeners)
    end
end

local function receiveSkin(publicAPI)
    if type(publicAPI) ~= "table" then return end
    skin = publicAPI
    Adapter:RefreshCapabilities()
    if Adapter:GetSkinAPIVersion() < 1 then return end
    if not looksRegistered and type(skin.OnLooksChanged) == "function" then
        -- No public unregister exists. One session bridge owns no UI closures.
        looksRegistered = true
        if not pcall(skin.OnLooksChanged, looksChanged) then report("OnLooksChanged") end
    end
    if Adapter:IsSkinningAvailable() then dispatch(readyListeners, true) end
end

function Adapter:Enable()
    self.active = true
    self:RefreshCapabilities()
    if not registrationAttempted and self:IsAvailable()
        and type(_G.EllesmereUI.RegisterSkin) == "function" then
        registrationAttempted = true
        if not pcall(_G.EllesmereUI.RegisterSkin, "CarGO_Orbit", receiveSkin) then
            report("RegisterSkin")
        end
    elseif self:IsSkinningAvailable() then
        dispatch(readyListeners, true)
    end
    self:RefreshCapabilities()
end

function Adapter:Disable()
    self.active = false
    readyListeners = {}
    looksListeners = {}
    reportedErrors = {}
    -- Retain the documented borrowed S handle: RegisterSkin is once per session.
    -- No widget, timer or module callback is retained by these bridges.
    self:RefreshCapabilities()
end

local function subscribe(listeners, fn)
    if type(fn) ~= "function" then return nil end
    listeners[fn] = false
    return function() listeners[fn] = nil end
end

function Adapter:RegisterReadyCallback(fn)
    if not self.active then return nil end
    local unsubscribe = subscribe(readyListeners, fn)
    if unsubscribe and self:IsSkinningAvailable() then
        readyListeners[fn] = true
        if not pcall(fn) then report("Orbit listener") end
    end
    return unsubscribe
end

function Adapter:RegisterLooksChangedCallback(fn)
    if not self.active then return nil end
    return subscribe(looksListeners, fn)
end

local function apply(operation, target, ...)
    if target == nil then return false, "missing-target" end
    if not Adapter:IsSkinningAvailable() then return false, "skinning-unavailable" end
    if type(skin[operation]) ~= "function" then return false, "unsupported-primitive" end
    if not pcall(skin[operation], target, ...) then
        report(operation)
        return false, "skin-call-failed"
    end
    return true
end

function Adapter:SkinShell(frame, opts) return apply("Shell", frame, opts) end
function Adapter:SkinPanel(frame, opts) return apply("Panel", frame, opts) end
function Adapter:SkinButton(frame) return apply("Button", frame) end
function Adapter:SkinCheckbox(frame) return apply("Checkbox", frame) end
function Adapter:SkinDropdown(frame) return apply("Dropdown", frame) end
function Adapter:SkinEditBox(frame) return apply("EditBox", frame) end
function Adapter:SkinScrollBar(frame) return apply("ScrollBar", frame) end
function Adapter:SkinTab(frame) return apply("Tab", frame) end
function Adapter:SkinFont(fontString) return apply("Font", fontString) end
function Adapter:SkinStatusBar(statusBar) return apply("ApplyBarFill", statusBar) end

local function query(operation)
    if not Adapter:IsSkinningAvailable() or type(skin[operation]) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(skin[operation])
    if not ok then report(operation); return nil end
    return a, b, c, d
end

function Adapter:GetAccentColor() return query("GetAccentColor") end
function Adapter:GetPanelColor() return query("GetPanelColor") end
function Adapter:GetFont() return query("GetFont") end
