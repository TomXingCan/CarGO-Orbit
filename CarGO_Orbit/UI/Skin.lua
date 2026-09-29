local _, ns = ...

local Skin = {}
ns.Skin = Skin

-- Standard client font; no EUI resources are addressed or bundled.
function Skin:Font(parent, text, size)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local path, _, flags = label:GetFont()
    label:SetFont(path, size or 12, flags)
    label:SetTextColor(0.9, 0.9, 0.9)
    label:SetText(text)
    ns.EUIAdapter:SkinFont(label)
    return label
end

function Skin:Backdrop(frame, r, g, b, a)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(r, g, b, a)
    return background
end

function Skin:Apply(panel)
    local adapter = ns.EUIAdapter
    adapter:SkinShell(panel.frame)
    adapter:SkinPanel(panel.content)
    adapter:SkinButton(panel.button)
    adapter:SkinButton(panel.close)
    adapter:SkinCheckbox(panel.checkbox)
    adapter:SkinEditBox(panel.editBox)
    adapter:SkinStatusBar(panel.statusBar)
    for _, label in ipairs(panel.labels) do adapter:SkinFont(label) end
end

function Skin:RefreshCustom(panel)
    -- Only this Orbit-owned accent strip needs manual theme colors.
    local r, g, b = ns.EUIAdapter:GetAccentColor()
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        r, g, b = 0.25, 0.65, 0.95
    end
    panel.accent:SetColorTexture(r, g, b, 1)
end
