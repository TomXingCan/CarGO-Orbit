local _, ns = ...

local Diagnostics = {}
ns.Diagnostics = Diagnostics
local debugLineCount = 0
local DEBUG_LINE_LIMIT = 100

function ns:Print(message)
    local text = "|cff33ccffCarGO Orbit|r: " .. tostring(message)
    if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    elseif type(print) == "function" then
        print(text)
    end
end

function ns:Debug(message)
    if self.debug and debugLineCount < DEBUG_LINE_LIMIT then
        -- One fixed session budget, with no retained message history.
        debugLineCount = debugLineCount + 1
        self:Print("[debug] " .. tostring(message))
    elseif self.debug and debugLineCount == DEBUG_LINE_LIMIT then
        debugLineCount = debugLineCount + 1
        self:Print("[debug] Session limit reached; further debug messages suppressed.")
    end
end

local function YesNo(value)
    return value and ns.L.YES or ns.L.NO
end

local function ModuleState(name)
    local module = ns:GetModule(name)
    return module and module.state or ns.L.DISABLED
end

function Diagnostics:Status()
    ns.EUIAdapter:RefreshCapabilities()
    local capabilities = ns.capabilities
    ns:Print(ns.title .. " " .. ns.version)
    ns:Print("EllesmereUI: " .. (capabilities.eui and ns.L.AVAILABLE or ns.L.UNAVAILABLE))
    local skin = ns.L.UNAVAILABLE
    if capabilities.skinAPI then
        skin = "v" .. tostring(capabilities.skinAPIVersion)
    elseif capabilities.skinAPIVersion > 0 then
        skin = "v" .. tostring(capabilities.skinAPIVersion) .. " (disabled / unavailable)"
    end
    ns:Print("Skin API: " .. skin)
    ns:Print("InfoBar: " .. ModuleState("InfoBar"))
    ns:Print("Enhanced Resource Bars: " .. ModuleState("EnhancedResourceBars"))
    ns:Print("Public integration capabilities:")
    ns:Print("- Skinning: " .. YesNo(capabilities.skinAPI))
    ns:Print("- DataBars extension: " .. YesNo(capabilities.dataBarsExtensionAPI))
    ns:Print("- ResourceBars extension: " .. YesNo(capabilities.resourceBarsExtensionAPI))
    ns:Print("- Options registration: " .. YesNo(capabilities.optionsRegistrationAPI))
end

function Diagnostics:HandleCommand(message)
    local command = string.lower(string.match(message or "", "^%s*(%S*)") or "")
    if command == "" or command == "status" then
        self:Status()
    elseif command == "debug" then
        ns.debug = not ns.debug
        ns.db.profile.debug = ns.debug
        ns:Print("Debug: " .. (ns.debug and ns.L.ENABLED or ns.L.DISABLED))
    elseif command == "panel" then
        if ns:IsEnabled() then
            ns.DebugPanel:Toggle()
        else
            ns:Print("Addon disabled; the test panel is unavailable.")
        end
    else
        ns:Print(ns.L.COMMAND_HELP)
    end
end

function Diagnostics:RegisterCommands()
    SLASH_CARGOORBIT1 = "/orbit"
    SLASH_CARGOORBIT2 = "/cgo"
    SlashCmdList.CARGOORBIT = function(message)
        self:HandleCommand(message)
    end
end
