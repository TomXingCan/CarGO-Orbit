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
    local infoBar = ns:GetModule("InfoBar")
    ns:Print("InfoBar providers: " .. tostring(infoBar:GetProviderCount()))
    ns:Print("InfoBar preset: " .. infoBar:Settings().layout.preset)
    ns:Print("Enhanced Resource Bars: " .. ModuleState("EnhancedResourceBars"))
    ns:Print("Public integration capabilities:")
    ns:Print("- Skinning: " .. YesNo(capabilities.skinAPI))
    ns:Print("- DataBars extension: " .. YesNo(capabilities.dataBarsExtensionAPI))
    ns:Print("- ResourceBars extension: " .. YesNo(capabilities.resourceBarsExtensionAPI))
    ns:Print("- Options registration: " .. YesNo(capabilities.optionsRegistrationAPI))
end

local function InfoBarHelp()
    ns:Print("InfoBar: /orbit infobar [debug | reset | position top/bottom | width 0/240-10000 | height 16-100 | spacing 0-100]")
    ns:Print("InfoBar: visibility always/no_combat/mouseover | time local/server/12/24 | font 8-64 | offset -40..40 | background on/off/0..1")
end

local function NumberInRange(value, minimum, maximum)
    local number = tonumber(value)
    if not number or number ~= number or number < minimum or number > maximum then return nil end
    return number
end

function Diagnostics:HandleInfoBarCommand(message)
    local infoBar = ns:GetModule("InfoBar")
    local command, argument = string.match(string.lower(message or ""), "^%s*(%S*)%s*(.-)%s*$")
    if command == "" then
        if infoBar:IsEnabled() then
            infoBar:Disable()
        elseif ns:IsEnabled() then
            infoBar:Enable()
        else
            ns:Print("Addon disabled; InfoBar is unavailable.")
            return
        end
        ns:Print("InfoBar: " .. infoBar.state)
        return
    elseif command == "debug" and argument == "" then
        infoBar:SetDebug(not infoBar.debugSlots)
        ns:Print("InfoBar slot debug: " .. (infoBar.debugSlots and "enabled" or "disabled"))
        return
    elseif command == "reset" and argument == "" then
        ns.Database:ResetInfoBar()
        infoBar:Apply()
        ns:Print("InfoBar layout and settings reset; enabled state preserved.")
        return
    end

    local settings = ns.Database:RepairInfoBar()
    if command == "position" and (argument == "top" or argument == "bottom") then
        settings.position = string.upper(argument)
    elseif command == "visibility" and (argument == "always" or argument == "no_combat" or argument == "mouseover") then
        settings.visibility = string.upper(argument)
    elseif command == "width" and (argument == "0" or NumberInRange(argument, 240, 10000)) then
        settings.width = tonumber(argument)
    elseif command == "height" and NumberInRange(argument, 16, 100) then
        settings.height = tonumber(argument)
    elseif command == "spacing" and NumberInRange(argument, 0, 100) then
        settings.spacing = tonumber(argument)
    elseif command == "font" and NumberInRange(argument, 8, 64) then
        settings.providers.Time.fontSize = tonumber(argument)
    elseif command == "offset" and NumberInRange(argument, -40, 40) then
        settings.providers.Time.offsetY = tonumber(argument)
    elseif command == "time" and (argument == "local" or argument == "server") then
        settings.providers.Time.localTime = argument == "local"
    elseif command == "time" and (argument == "12" or argument == "24") then
        settings.providers.Time.twentyFour = argument == "24"
    elseif command == "background" and (argument == "on" or argument == "off") then
        settings.background.enabled = argument == "on"
    elseif command == "background" and NumberInRange(argument, 0, 1) then
        settings.background.alpha = tonumber(argument)
    else
        InfoBarHelp()
        return
    end
    infoBar:Apply()
    ns:Print("InfoBar " .. command .. ": " .. argument)
end

function Diagnostics:HandleCommand(message)
    local command, rest = string.match(message or "", "^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
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
    elseif command == "infobar" then
        self:HandleInfoBarCommand(rest)
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
