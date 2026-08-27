--------------------------------------------------
-- SAVED VARIABLE DEFAULTS
--------------------------------------------------

-- 8-digit ARGB hex strings (alpha, then red/green/blue) - the format
-- CreateColorFromHexString requires and Settings.CreateColorSwatch's
-- built-in widget round-trips through internally (GenerateHexColor()).
-- A 6-digit RGB string here makes CreateColorFromHexString return nil.
local DEFAULT_HEALTH_COLOR = "FFFFFFFF"
local DEFAULT_SHIELD_COLOR = "FF0099FF"

WhitePlayerHealthDB = WhitePlayerHealthDB or {}

if WhitePlayerHealthDB.width == nil then
    WhitePlayerHealthDB.width = 240
end

if WhitePlayerHealthDB.height == nil then
    WhitePlayerHealthDB.height = 5
end

if WhitePlayerHealthDB.x == nil then
    WhitePlayerHealthDB.x = 0
end

if WhitePlayerHealthDB.y == nil then
    WhitePlayerHealthDB.y = 250
end

if WhitePlayerHealthDB.showCenterGuide == nil then
    WhitePlayerHealthDB.showCenterGuide = true
end

if WhitePlayerHealthDB.editPanelX == nil then
    WhitePlayerHealthDB.editPanelX = 0
end

if WhitePlayerHealthDB.editPanelY == nil then
    WhitePlayerHealthDB.editPanelY = -120
end

if WhitePlayerHealthDB.absorbFillDirection == nil then
    WhitePlayerHealthDB.absorbFillDirection = "RTL"
end

if WhitePlayerHealthDB.snapToCenter == nil then
    WhitePlayerHealthDB.snapToCenter = true
end

-- The length check (rather than a plain == nil check) also repairs
-- saved colors written by an earlier, broken build of this addon that
-- stored 6-digit RGB strings instead of the 8-digit ARGB format
-- CreateColorFromHexString actually requires.
if WhitePlayerHealthDB.healthColor == nil or #WhitePlayerHealthDB.healthColor ~= 8 then
    WhitePlayerHealthDB.healthColor = DEFAULT_HEALTH_COLOR
end

if WhitePlayerHealthDB.shieldColor == nil or #WhitePlayerHealthDB.shieldColor ~= 8 then
    WhitePlayerHealthDB.shieldColor = DEFAULT_SHIELD_COLOR
end

--------------------------------------------------
-- HELPERS
--------------------------------------------------

-- GetWidth/GetHeight/GetPoint/GetCenter can come back a hair off an
-- integer (e.g. 299.99997) due to UI scale rounding. math.floor() on
-- a value like that silently knocks 1 off the real number, so round
-- to the nearest integer instead everywhere we convert a frame
-- measurement back into a saved number.
local function RoundToInt(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    else
        return math.ceil(value - 0.5)
    end
end

-- Falls back to a known-good default whenever a saved color is missing
-- or the wrong length, so CreateColorFromHexString (which errors on
-- anything but an 8-digit ARGB string) never gets handed bad data -
-- regardless of why it ended up that way.
local function GetValidHexColor(hexColor, defaultHex)
    if hexColor and #hexColor == 8 then
        return hexColor
    end

    return defaultHex
end

-- Settings-panel color preview rows (see COLOR PREVIEW below) register
-- themselves here while shown, so ApplyHealthColor/ApplyShieldColor can
-- push live updates into them as the color picker is dragged, not just
-- refresh them the next time they're shown.
local activeColorPreviews = {}

--------------------------------------------------
-- BAR
--------------------------------------------------

local bar = CreateFrame("StatusBar", "WhitePlayerHealthBar", UIParent)

bar:SetMovable(true)
bar:SetClampedToScreen(true)

-- Ultra-minimal flat texture
bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")

local function ApplyHealthColor()
    local hexColor = GetValidHexColor(WhitePlayerHealthDB.healthColor, DEFAULT_HEALTH_COLOR)
    bar:SetStatusBarColor(CreateColorFromHexString(hexColor):GetRGB())

    for preview in pairs(activeColorPreviews) do
        preview:RefreshColors()
    end
end

ApplyHealthColor()

--------------------------------------------------
-- BACKGROUND
--------------------------------------------------

local bg = bar:CreateTexture(nil, "BACKGROUND")

bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 1)

--------------------------------------------------
-- BORDER
--------------------------------------------------

local top = bar:CreateTexture(nil, "BORDER")
local bottom = bar:CreateTexture(nil, "BORDER")
local left = bar:CreateTexture(nil, "BORDER")
local right = bar:CreateTexture(nil, "BORDER")

top:SetColorTexture(0, 0, 0, 1)
bottom:SetColorTexture(0, 0, 0, 1)
left:SetColorTexture(0, 0, 0, 1)
right:SetColorTexture(0, 0, 0, 1)

local function UpdateBorder()
    top:SetPoint("TOPLEFT", -1, 1)
    top:SetPoint("TOPRIGHT", 1, 1)
    top:SetHeight(1)

    bottom:SetPoint("BOTTOMLEFT", -1, -1)
    bottom:SetPoint("BOTTOMRIGHT", 1, -1)
    bottom:SetHeight(1)

    left:SetPoint("TOPLEFT", -1, 1)
    left:SetPoint("BOTTOMLEFT", -1, -1)
    left:SetWidth(1)

    right:SetPoint("TOPRIGHT", 1, 1)
    right:SetPoint("BOTTOMRIGHT", 1, -1)
    right:SetWidth(1)
end

--------------------------------------------------
-- APPLY SETTINGS
--------------------------------------------------

local function ApplySettings()
    bar:SetSize(
        WhitePlayerHealthDB.width,
        WhitePlayerHealthDB.height
    )

    bar:ClearAllPoints()

    bar:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        WhitePlayerHealthDB.x,
        WhitePlayerHealthDB.y
    )

    UpdateBorder()
end

--------------------------------------------------
-- SAVE POSITION
--------------------------------------------------

local function SavePosition()
    local _, _, _, x, y = bar:GetPoint()
    WhitePlayerHealthDB.x = RoundToInt(x)
    WhitePlayerHealthDB.y = RoundToInt(y)
end

--------------------------------------------------
-- SAVE SIZE
--------------------------------------------------

local function SaveSize()
    WhitePlayerHealthDB.width = RoundToInt(bar:GetWidth())
    WhitePlayerHealthDB.height = RoundToInt(bar:GetHeight())

    -- Resizing from a corner shifts the frame's effective center point,
    -- so recompute the CENTER-relative offset before saving it. This
    -- keeps the bar anchored the same way (SetPoint "CENTER") it always
    -- has been, instead of leaving it on whatever anchor the resize
    -- drag left behind.
    local centerX, centerY = bar:GetCenter()
    local parentCenterX, parentCenterY = UIParent:GetCenter()

    if centerX and centerY and parentCenterX and parentCenterY then
        WhitePlayerHealthDB.x = RoundToInt(centerX - parentCenterX)
        WhitePlayerHealthDB.y = RoundToInt(centerY - parentCenterY)
    end

    ApplySettings()
end

--------------------------------------------------
-- EDIT MODE STATE
--------------------------------------------------

local isEditMode = false

--------------------------------------------------
-- CENTER GUIDE LINE (edit mode only)
--------------------------------------------------

-- A thin vertical line down screen x = 0 (UIParent's horizontal
-- center), so the bar can be lined up above the character, who is
-- normally centered on screen. Toggleable from the settings menu.
local guideLine = CreateFrame("Frame", "WhitePlayerHealthGuideLine", UIParent)

guideLine:SetPoint("TOP", UIParent, "TOP", 0, 0)
guideLine:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
guideLine:SetWidth(1)
guideLine:SetFrameStrata("HIGH")
guideLine:EnableMouse(false)
guideLine:Hide()

local guideLineTexture = guideLine:CreateTexture(nil, "OVERLAY")

guideLineTexture:SetAllPoints()
guideLineTexture:SetColorTexture(1, 0.2, 0.2, 0.9)

local function UpdateGuideLineVisibility()
    guideLine:SetShown(bar:IsMouseEnabled() and WhitePlayerHealthDB.showCenterGuide)
end

--------------------------------------------------
-- QUICK EDIT PANEL (Width / Height entry, edit mode only)
--------------------------------------------------

local editPanel = CreateFrame("Frame", "WhitePlayerHealthEditPanel", UIParent)

editPanel:SetSize(190, 182)
editPanel:SetPoint(
    "TOP",
    UIParent,
    "TOP",
    WhitePlayerHealthDB.editPanelX,
    WhitePlayerHealthDB.editPanelY
)
editPanel:SetFrameStrata("HIGH")
editPanel:SetMovable(true)
editPanel:SetClampedToScreen(true)
editPanel:EnableMouse(true)
editPanel:Hide()

local editPanelBg = editPanel:CreateTexture(nil, "BACKGROUND")
editPanelBg:SetAllPoints()
editPanelBg:SetColorTexture(0, 0, 0, 0.9)

local epTop = editPanel:CreateTexture(nil, "BORDER")
local epBottom = editPanel:CreateTexture(nil, "BORDER")
local epLeft = editPanel:CreateTexture(nil, "BORDER")
local epRight = editPanel:CreateTexture(nil, "BORDER")

epTop:SetColorTexture(1, 1, 1, 1)
epBottom:SetColorTexture(1, 1, 1, 1)
epLeft:SetColorTexture(1, 1, 1, 1)
epRight:SetColorTexture(1, 1, 1, 1)

epTop:SetPoint("TOPLEFT", -1, 1)
epTop:SetPoint("TOPRIGHT", 1, 1)
epTop:SetHeight(1)

epBottom:SetPoint("BOTTOMLEFT", -1, -1)
epBottom:SetPoint("BOTTOMRIGHT", 1, -1)
epBottom:SetHeight(1)

epLeft:SetPoint("TOPLEFT", -1, 1)
epLeft:SetPoint("BOTTOMLEFT", -1, -1)
epLeft:SetWidth(1)

epRight:SetPoint("TOPRIGHT", 1, 1)
epRight:SetPoint("BOTTOMRIGHT", 1, -1)
epRight:SetWidth(1)

local editPanelTitle = editPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
editPanelTitle:SetPoint("TOP", editPanel, "TOP", 0, -8)
editPanelTitle:SetText("WhitePlayerHealth")

local function CreateEditPanelRow(labelText, yOffset)
    local label = editPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", editPanel, "TOPLEFT", 14, yOffset)
    label:SetText(labelText)

    local box = CreateFrame("EditBox", nil, editPanel)
    box:SetSize(56, 18)
    box:SetPoint("TOPRIGHT", editPanel, "TOPRIGHT", -14, yOffset + 2)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(4)
    box:SetJustifyH("CENTER")
    box:SetFontObject("GameFontHighlightSmall")
    box:SetTextInsets(2, 2, 0, 0)
    box:EnableMouse(true)

    local boxBg = box:CreateTexture(nil, "BACKGROUND")
    boxBg:SetAllPoints()
    boxBg:SetColorTexture(1, 1, 1, 0.12)

    return box
end

local widthBox = CreateEditPanelRow("Width", -32)
local heightBox = CreateEditPanelRow("Height", -58)

-- Toggles WhitePlayerHealthDB.snapToCenter - whether releasing a drag
-- within CENTER_SNAP_DISTANCE of x = 0 snaps the bar to exactly
-- centered, or leaves it free-floating wherever it was dropped. OnClick
-- is wired up further down, once ApplySettings-adjacent state exists.
local snapToCenterCheckbox = CreateFrame("CheckButton", nil, editPanel, "UICheckButtonTemplate")
snapToCenterCheckbox:SetSize(24, 24)
snapToCenterCheckbox:SetPoint("TOPLEFT", editPanel, "TOPLEFT", 8, -84)

local snapToCenterLabel = editPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
snapToCenterLabel:SetPoint("LEFT", snapToCenterCheckbox, "RIGHT", 0, 1)
snapToCenterLabel:SetText("Snap to Center")

-- The classic dropdown widget (UIDropDownMenuTemplate) was removed
-- entirely in Midnight, and there's no direct replacement for use in
-- a plain custom frame like this panel (Settings.CreateDropdown only
-- works inside the Settings API's own category system). With only
-- two choices, a toggle button is a simpler, equally quick control
-- anyway - one click flips it. OnClick is wired up further down, once
-- ApplyAbsorbFillDirection exists.
local fillDirectionButton = CreateFrame("Button", nil, editPanel, "UIPanelButtonTemplate")
fillDirectionButton:SetSize(160, 20)
fillDirectionButton:SetPoint("TOP", editPanel, "TOP", 0, -110)

local saveCloseButton = CreateFrame("Button", nil, editPanel, "UIPanelButtonTemplate")
saveCloseButton:SetSize(130, 22)
saveCloseButton:SetPoint("TOP", editPanel, "TOP", 0, -136)
saveCloseButton:SetText("Save & Close")
-- OnClick is wired up further down, once ExitEditMode exists.

local editPanelHint = editPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
editPanelHint:SetPoint("BOTTOM", editPanel, "BOTTOM", 0, 8)
editPanelHint:SetText("Enter to apply - drag to move")

local function SaveEditPanelPosition()
    local _, _, _, x, y = editPanel:GetPoint()
    WhitePlayerHealthDB.editPanelX = RoundToInt(x)
    WhitePlayerHealthDB.editPanelY = RoundToInt(y)
end

editPanel:SetScript("OnMouseDown", function(self)
    self:StartMoving()
end)

editPanel:SetScript("OnMouseUp", function(self)
    self:StopMovingOrSizing()
    SaveEditPanelPosition()
end)

local function FillDirectionLabel()
    if WhitePlayerHealthDB.absorbFillDirection == "LTR" then
        return "Shield Fill: Left to Right"
    else
        return "Shield Fill: Right to Left"
    end
end

local function RefreshEditPanelValues()
    widthBox:SetText(tostring(WhitePlayerHealthDB.width))
    heightBox:SetText(tostring(WhitePlayerHealthDB.height))
    fillDirectionButton:SetText(FillDirectionLabel())
    snapToCenterCheckbox:SetChecked(WhitePlayerHealthDB.snapToCenter)
end

snapToCenterCheckbox:SetScript("OnClick", function(self)
    WhitePlayerHealthDB.snapToCenter = self:GetChecked() and true or false
end)

-- Reads whatever is currently typed in BOTH boxes and commits it. Used
-- by Enter in either box, and by the Save & Close button - so clicking
-- that button applies a typed value even if Enter was never pressed.
local function ApplyPanelValues()
    local widthValue = tonumber(widthBox:GetText())
    local heightValue = tonumber(heightBox:GetText())

    if widthValue and widthValue > 0 then
        WhitePlayerHealthDB.width = RoundToInt(widthValue)
    end

    if heightValue and heightValue > 0 then
        WhitePlayerHealthDB.height = RoundToInt(heightValue)
    end

    ApplySettings()
    RefreshEditPanelValues()
end

widthBox:SetScript("OnEnterPressed", function(self)
    ApplyPanelValues()
    self:ClearFocus()
end)

widthBox:SetScript("OnEscapePressed", function(self)
    RefreshEditPanelValues()
    self:ClearFocus()
end)

heightBox:SetScript("OnEnterPressed", function(self)
    ApplyPanelValues()
    self:ClearFocus()
end)

heightBox:SetScript("OnEscapePressed", function(self)
    RefreshEditPanelValues()
    self:ClearFocus()
end)

editPanel:SetScript("OnShow", RefreshEditPanelValues)

--------------------------------------------------
-- RESIZE GRIP (edit mode only)
--------------------------------------------------

-- SetMinResize/SetMaxResize were replaced by SetResizeBounds in 10.0
-- and remain the correct API in Midnight 12.1.
bar:SetResizable(true)
bar:SetResizeBounds(20, 1, 800, 60)

local resizeGrip = CreateFrame("Frame", nil, bar)

resizeGrip:SetSize(10, 10)
resizeGrip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
resizeGrip:SetFrameLevel(bar:GetFrameLevel() + 2)
resizeGrip:EnableMouse(true)
resizeGrip:Hide()

local gripTexture = resizeGrip:CreateTexture(nil, "OVERLAY")

gripTexture:SetAllPoints()
gripTexture:SetColorTexture(1, 1, 1, 0.9)

resizeGrip:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        bar:StartSizing("BOTTOMRIGHT")
    end
end)

resizeGrip:SetScript("OnMouseUp", function()
    bar:StopMovingOrSizing()
    SaveSize()
    RefreshEditPanelValues()
end)

--------------------------------------------------
-- HEALTH
--------------------------------------------------

local function UpdateHealth()
    local maxHealth = UnitHealthMax("player")

    if maxHealth and maxHealth > 0 then
        bar:SetMinMaxValues(0, maxHealth)
        bar:SetValue(UnitHealth("player"))
    end
end

--------------------------------------------------
-- SHIELD / ABSORB OVERLAY
--------------------------------------------------

-- A translucent blue StatusBar laid directly over the health bar,
-- sized and positioned to match it exactly (SetAllPoints), filling
-- right-to-left. It's driven purely by StatusBar:SetValue() /
-- SetMinMaxValues() with the raw values passed straight through, no
-- arithmetic or comparison performed on them - that's the one
-- mechanism confirmed safe to use even when the values are Secret
-- Values during combat (the same mechanism the health bar above
-- already relies on). A StatusBar draws nothing in its own unfilled
-- portion, so the white health bar shows through underneath
-- everywhere except where the shield's own fill actually sits.
local absorbBar = CreateFrame("StatusBar", nil, bar)

absorbBar:SetAllPoints(bar)
absorbBar:SetFrameLevel(bar:GetFrameLevel() + 1)
absorbBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
absorbBar:SetReverseFill(true)

local function ApplyShieldColor()
    local hexColor = GetValidHexColor(WhitePlayerHealthDB.shieldColor, DEFAULT_SHIELD_COLOR)
    local r, g, b = CreateColorFromHexString(hexColor):GetRGB()
    absorbBar:SetStatusBarColor(r, g, b, 0.75)

    for preview in pairs(activeColorPreviews) do
        preview:RefreshColors()
    end
end

ApplyShieldColor()

-- WhitePlayerHealthDB.absorbFillDirection is "RTL" (default, fills
-- from the right edge toward the left) or "LTR" (fills from the left
-- edge toward the right). Reasserted on every update, defensively, in
-- case anything ever resets the flag.
local function ApplyAbsorbFillDirection()
    absorbBar:SetReverseFill(WhitePlayerHealthDB.absorbFillDirection ~= "LTR")

    for preview in pairs(activeColorPreviews) do
        preview:RefreshColors()
    end
end

local function UpdateAbsorb()
    local maxHealth = UnitHealthMax("player")
    local absorb = UnitGetTotalAbsorbs("player")

    ApplyAbsorbFillDirection()

    -- Nil-checks only test whether Lua got a value at all - that's a
    -- truthiness check, not a numeric comparison, so it's fine even
    -- if the value turns out to be secret. Passing it straight into
    -- SetMinMaxValues/SetValue below is the only operation performed
    -- on it.
    if maxHealth then
        absorbBar:SetMinMaxValues(0, maxHealth)
    end

    if absorb then
        absorbBar:SetValue(absorb)
    end
end

--------------------------------------------------
-- VISIBILITY
--------------------------------------------------

local function UpdateVisibility()
    if isEditMode then
        bar:Show()
        return
    end

    if UnitAffectingCombat("player") then
        bar:Show()
    else
        bar:Hide()
    end
end

--------------------------------------------------
-- LOCK / UNLOCK / EDIT MODE
--------------------------------------------------

local function SetUnlocked(unlocked)
    bar:EnableMouse(unlocked)
    resizeGrip:SetShown(unlocked)
    editPanel:SetShown(unlocked)
    UpdateGuideLineVisibility()
end

-- isEditMode is the single source of truth for "is the bar currently
-- unlocked" - UpdateVisibility() only force-shows the bar while it's
-- true. Previously this only got set by the bare /wph toggle
-- (EnterEditMode), not by /wph unlock or the "Unlock Bar" settings
-- checkbox (both went through UnlockBar() directly) - so unlocking via
-- either of those while the bar was hidden (out of combat) left it
-- hidden but genuinely unlocked, with no indication anything had
-- changed, until something else happened to show it again (e.g.
-- entering combat), at which point it would appear already unlocked
-- with no /wph command having just been run. Setting isEditMode here
-- unconditionally makes every unlock path behave identically.
local function UnlockBar()
    isEditMode = true

    SetUnlocked(true)
    bar:Show()
end

local function LockBar()
    isEditMode = false

    SetUnlocked(false)
    widthBox:ClearFocus()
    heightBox:ClearFocus()
    SavePosition()
    SaveSize()
    UpdateVisibility()
end

local function EnterEditMode()
    UnlockBar()
end

local function ExitEditMode()
    LockBar()
end

saveCloseButton:SetScript("OnClick", function()
    ApplyPanelValues()
    ExitEditMode()
    print("WhitePlayerHealth: edit mode off. Position and size saved.")
end)

fillDirectionButton:SetScript("OnClick", function()
    if WhitePlayerHealthDB.absorbFillDirection == "LTR" then
        WhitePlayerHealthDB.absorbFillDirection = "RTL"
    else
        WhitePlayerHealthDB.absorbFillDirection = "LTR"
    end

    ApplyAbsorbFillDirection()
    RefreshEditPanelValues()
end)

--------------------------------------------------
-- DRAGGING
--------------------------------------------------

bar:EnableMouse(false)

-- Pixel distance from center (x = 0, the guide line) within which the
-- bar snaps to it on release, when WhitePlayerHealthDB.snapToCenter is
-- enabled (see the Snap to Center checkbox on the quick-edit panel).
-- Applied once after StopMovingOrSizing() rather than live during the
-- drag - StartMoving() re-tracks the cursor every frame, so a SetPoint
-- override applied mid-drag just gets overwritten by the next frame's
-- native update and never actually shows.
local CENTER_SNAP_DISTANCE = 20

bar:SetScript("OnMouseDown", function(self)
    self:StartMoving()
end)

bar:SetScript("OnMouseUp", function(self)
    self:StopMovingOrSizing()

    if WhitePlayerHealthDB.snapToCenter then
        local point, relativeTo, relativePoint, x, y = self:GetPoint()

        if x and math.abs(x) <= CENTER_SNAP_DISTANCE then
            self:SetPoint(point, relativeTo, relativePoint, 0, y)
        end
    end

    SavePosition()
end)

--------------------------------------------------
-- EVENTS
--------------------------------------------------

local events = CreateFrame("Frame")

-- RegisterUnitEvent (rather than RegisterEvent) filters at the engine
-- level, so this handler only runs for the player's own health/absorb
-- changes instead of firing - and then being ignored - for every
-- visible unit's, which matters in raids/dungeons with many units on
-- screen.
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterUnitEvent("UNIT_HEALTH", "player")
events:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
events:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")

events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        ApplySettings()
        UpdateHealth()
        UpdateAbsorb()
        UpdateVisibility()
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        UpdateAbsorb()
        UpdateVisibility()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        UpdateAbsorb()
        UpdateVisibility()
        return
    end

    if unit == "player" then
        UpdateHealth()
        UpdateAbsorb()
    end
end)

--------------------------------------------------
-- COLOR PREVIEW (settings panel)
--------------------------------------------------

-- Embedded into the Colors section as its own row (see
-- Settings.CreatePanelInitializer below), showing full health with a
-- partial shield overlay so both colors stay visible side by side for
-- comparison. This is the only place the colors can be previewed
-- without being in combat or edit mode, since that's the only two
-- states the real bar is ever shown in. Global (not local) because the
-- XML template's mixin="" attribute resolves it by name.
WhitePlayerHealthColorPreviewMixin = {}

function WhitePlayerHealthColorPreviewMixin:OnLoad()
    local width, height = 200, 14

    self.barWidth = width - 2

    self.Bg = self:CreateTexture(nil, "BACKGROUND")
    self.Bg:SetSize(width, height)
    self.Bg:SetPoint("LEFT", self, "LEFT", 175, 0)
    self.Bg:SetColorTexture(0, 0, 0, 1)

    self.Label = self:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.Label:SetPoint("BOTTOM", self.Bg, "TOP", 0, 4)
    self.Label:SetText("Preview")

    self.Health = self:CreateTexture(nil, "ARTWORK")
    self.Health:SetPoint("TOPLEFT", self.Bg, "TOPLEFT", 1, -1)
    self.Health:SetSize(self.barWidth, height - 2)

    -- Shield overlay only covers part of the bar (rather than the
    -- whole thing) specifically so the health color underneath stays
    -- visible too - the point is comparing the two colors together.
    -- Anchor side is set in RefreshColors(), based on which edge the
    -- real shield bar currently fills from.
    self.Shield = self:CreateTexture(nil, "OVERLAY")
    self.Shield:SetWidth(self.barWidth * 0.256)
end

function WhitePlayerHealthColorPreviewMixin:RefreshColors()
    local healthHex = GetValidHexColor(WhitePlayerHealthDB.healthColor, DEFAULT_HEALTH_COLOR)
    local shieldHex = GetValidHexColor(WhitePlayerHealthDB.shieldColor, DEFAULT_SHIELD_COLOR)

    self.Health:SetColorTexture(CreateColorFromHexString(healthHex):GetRGB())

    local r, g, b = CreateColorFromHexString(shieldHex):GetRGB()
    self.Shield:SetColorTexture(r, g, b, 0.75)

    self.Shield:ClearAllPoints()

    if WhitePlayerHealthDB.absorbFillDirection == "LTR" then
        self.Shield:SetPoint("TOPLEFT", self.Health, "TOPLEFT")
        self.Shield:SetPoint("BOTTOMLEFT", self.Health, "BOTTOMLEFT")
    else
        self.Shield:SetPoint("TOPRIGHT", self.Health, "TOPRIGHT")
        self.Shield:SetPoint("BOTTOMRIGHT", self.Health, "BOTTOMRIGHT")
    end
end

function WhitePlayerHealthColorPreviewMixin:OnShow()
    self:RefreshColors()
    activeColorPreviews[self] = true
end

function WhitePlayerHealthColorPreviewMixin:OnHide()
    activeColorPreviews[self] = nil
end

--------------------------------------------------
-- SETTINGS MENU
--------------------------------------------------

-- Built with the current (post-10.0, post-11.0.2) Settings API. Legacy
-- templates like InterfaceOptionsCheckButtonTemplate were removed in
-- 10.0, so this uses Settings.RegisterVerticalLayoutCategory plus
-- proxy settings bound straight to WhitePlayerHealthDB.
local WPHSettingsCategory, WPHSettingsLayout = Settings.RegisterVerticalLayoutCategory("WhitePlayerHealth")

Settings.RegisterAddOnCategory(WPHSettingsCategory)

WPHSettingsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Size"))

do
    local function GetWidthSetting()
        return WhitePlayerHealthDB.width
    end

    local function SetWidthSetting(value)
        WhitePlayerHealthDB.width = RoundToInt(value)
        ApplySettings()
        RefreshEditPanelValues()
    end

    local widthSetting = Settings.RegisterProxySetting(
        WPHSettingsCategory,
        "WPH_Width",
        "number",
        "Bar Width",
        240,
        GetWidthSetting,
        SetWidthSetting
    )

    local widthOptions = Settings.CreateSliderOptions(20, 600, 1)
    widthOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)

    Settings.CreateSlider(WPHSettingsCategory, widthSetting, widthOptions, "Width of the health bar, in pixels.")
end

do
    local function GetHeightSetting()
        return WhitePlayerHealthDB.height
    end

    local function SetHeightSetting(value)
        WhitePlayerHealthDB.height = RoundToInt(value)
        ApplySettings()
        RefreshEditPanelValues()
    end

    local heightSetting = Settings.RegisterProxySetting(
        WPHSettingsCategory,
        "WPH_Height",
        "number",
        "Bar Height",
        5,
        GetHeightSetting,
        SetHeightSetting
    )

    local heightOptions = Settings.CreateSliderOptions(1, 60, 1)
    heightOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)

    Settings.CreateSlider(WPHSettingsCategory, heightSetting, heightOptions, "Height of the health bar, in pixels.")
end

WPHSettingsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Position & Locking"))

do
    local function GetUnlockedSetting()
        return bar:IsMouseEnabled()
    end

    local function SetUnlockedSetting(value)
        if value then
            UnlockBar()
        else
            LockBar()
        end
    end

    local unlockedSetting = Settings.RegisterProxySetting(
        WPHSettingsCategory,
        "WPH_Unlocked",
        "boolean",
        "Unlock Bar",
        false,
        GetUnlockedSetting,
        SetUnlockedSetting
    )

    Settings.CreateCheckbox(
        WPHSettingsCategory,
        unlockedSetting,
        "Allow the bar to be dragged to move it, and resized using the handle in its bottom-right corner."
    )
end

do
    local function ResetBarPositionAndSize()
        WhitePlayerHealthDB.x = 0
        WhitePlayerHealthDB.y = 250
        WhitePlayerHealthDB.width = 240
        WhitePlayerHealthDB.height = 5
        ApplySettings()
        RefreshEditPanelValues()
    end

    WPHSettingsLayout:AddInitializer(
        CreateSettingsButtonInitializer(
            "Reset Bar",
            "Reset Position & Size",
            ResetBarPositionAndSize,
            "Restores the bar's default position, width, and height.",
            true
        )
    )
end

WPHSettingsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Edit Mode Helpers"))

do
    local function GetShowGuideSetting()
        return WhitePlayerHealthDB.showCenterGuide
    end

    local function SetShowGuideSetting(value)
        WhitePlayerHealthDB.showCenterGuide = value
        UpdateGuideLineVisibility()
    end

    local showGuideSetting = Settings.RegisterProxySetting(
        WPHSettingsCategory,
        "WPH_ShowCenterGuide",
        "boolean",
        "Show Center Guide Line",
        true,
        GetShowGuideSetting,
        SetShowGuideSetting
    )

    Settings.CreateCheckbox(
        WPHSettingsCategory,
        showGuideSetting,
        "While the bar is unlocked, draws a vertical line down the screen's horizontal center (x = 0) to help line the bar up above your character."
    )
end

WPHSettingsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Shield"))

do
    local function GetFillDirectionSetting()
        return WhitePlayerHealthDB.absorbFillDirection
    end

    local function SetFillDirectionSetting(value)
        WhitePlayerHealthDB.absorbFillDirection = value
        ApplyAbsorbFillDirection()
        RefreshEditPanelValues()
    end

    local fillDirectionSetting = Settings.RegisterProxySetting(
        WPHSettingsCategory,
        "WPH_AbsorbFillDirection",
        "string",
        "Shield Fill Direction",
        "RTL",
        GetFillDirectionSetting,
        SetFillDirectionSetting
    )

    local function GetFillDirectionOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("RTL", "Right to Left", "The shield fills from the bar's right edge toward the left.")
        container:Add("LTR", "Left to Right", "The shield fills from the bar's left edge toward the right.")
        return container:GetData()
    end

    Settings.CreateDropdown(
        WPHSettingsCategory,
        fillDirectionSetting,
        GetFillDirectionOptions,
        "Choose which direction the shield overlay fills."
    )
end

WPHSettingsLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Colors"))
WPHSettingsLayout:AddInitializer(Settings.CreatePanelInitializer("WhitePlayerHealthColorPreviewTemplate", {}))

do
    local function GetHealthColorSetting()
        return GetValidHexColor(WhitePlayerHealthDB.healthColor, DEFAULT_HEALTH_COLOR)
    end

    local function SetHealthColorSetting(value)
        WhitePlayerHealthDB.healthColor = value
        ApplyHealthColor()
    end

    local healthColorSetting = Settings.RegisterProxySetting(
        WPHSettingsCategory,
        "WPH_HealthColor",
        "string",
        "Health Bar Color",
        DEFAULT_HEALTH_COLOR,
        GetHealthColorSetting,
        SetHealthColorSetting
    )

    Settings.CreateColorSwatch(WPHSettingsCategory, healthColorSetting, "Color of the health bar fill.")
end

do
    local function GetShieldColorSetting()
        return GetValidHexColor(WhitePlayerHealthDB.shieldColor, DEFAULT_SHIELD_COLOR)
    end

    local function SetShieldColorSetting(value)
        WhitePlayerHealthDB.shieldColor = value
        ApplyShieldColor()
    end

    local shieldColorSetting = Settings.RegisterProxySetting(
        WPHSettingsCategory,
        "WPH_ShieldColor",
        "string",
        "Shield Bar Color",
        DEFAULT_SHIELD_COLOR,
        GetShieldColorSetting,
        SetShieldColorSetting
    )

    Settings.CreateColorSwatch(WPHSettingsCategory, shieldColorSetting, "Color of the shield/absorb overlay.")
end

do
    -- Going through Settings.SetValue() (rather than writing
    -- WhitePlayerHealthDB directly) also runs the setting's normal
    -- change-notification path, so the swatches themselves visually
    -- update immediately - a direct write updates the bar but leaves
    -- the swatch widgets showing the old color until something else
    -- forces them to redraw.
    local function ResetColorsToDefault()
        Settings.SetValue("WPH_HealthColor", DEFAULT_HEALTH_COLOR, true)
        Settings.SetValue("WPH_ShieldColor", DEFAULT_SHIELD_COLOR, true)
    end

    WPHSettingsLayout:AddInitializer(
        CreateSettingsButtonInitializer(
            "Reset Colors",
            "Set to Default Color",
            ResetColorsToDefault,
            "Restores the health bar to white and the shield overlay to blue.",
            true
        )
    )
end

--------------------------------------------------
-- COMMANDS
--------------------------------------------------

-- Settings.OpenToCategory can't run during combat lockdown - it just
-- silently fails. Rather than let that happen with no feedback, this
-- warns the player and opens the panel automatically once combat ends.
local pendingConfigOpen = false

local function OpenConfig()
    if InCombatLockdown() then
        pendingConfigOpen = true
        print("WhitePlayerHealth: settings can't be opened during combat. Opening once you leave combat.")
    else
        -- Midnight requires the numeric category ID here, not the name.
        Settings.OpenToCategory(WPHSettingsCategory:GetID())
    end
end

local configOpenFrame = CreateFrame("Frame")

configOpenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

configOpenFrame:SetScript("OnEvent", function()
    if pendingConfigOpen then
        pendingConfigOpen = false
        Settings.OpenToCategory(WPHSettingsCategory:GetID())
    end
end)

SLASH_WHITEPLAYERHEALTH1 = "/wph"

SlashCmdList["WHITEPLAYERHEALTH"] = function(msg)
    local cmd, value = strsplit(" ", msg)
    cmd = (cmd or ""):lower()
    value = tonumber(value)

    if cmd == "" then
        if isEditMode then
            ExitEditMode()
            print("WhitePlayerHealth: edit mode off. Position and size saved.")
        else
            EnterEditMode()
            print("WhitePlayerHealth: edit mode on. Drag to move, drag the corner handle to resize, or type exact values in the panel. Type /wph again to finish.")
        end
    elseif cmd == "unlock" then
        UnlockBar()
        print("WhitePlayerHealth unlocked.")
    elseif cmd == "lock" then
        LockBar()
        print("WhitePlayerHealth locked.")
    elseif cmd == "reset" then
        WhitePlayerHealthDB.x = 0
        WhitePlayerHealthDB.y = 250

        ApplySettings()
        RefreshEditPanelValues()

        print("WhitePlayerHealth reset.")
    elseif cmd == "width" and value then
        WhitePlayerHealthDB.width = value
        ApplySettings()
        RefreshEditPanelValues()
    elseif cmd == "height" and value then
        WhitePlayerHealthDB.height = value
        ApplySettings()
        RefreshEditPanelValues()
    elseif cmd == "config" or cmd == "options" then
        OpenConfig()
    else
        print("/wph - toggle edit mode (shows the bar, makes it movable/resizable, opens the quick-edit panel)")
        print("/wph unlock")
        print("/wph lock")
        print("/wph reset")
        print("/wph width 240")
        print("/wph height 5")
        print("/wph config")
    end
end

--------------------------------------------------
-- STARTUP
--------------------------------------------------

ApplySettings()
UpdateHealth()
UpdateAbsorb()
UpdateVisibility()

--------------------------------------------------
-- ABSORB SKINNING
--------------------------------------------------

-- Recolors the default Personal Resource Display's absorb overlay to
-- match this addon's own shield color, in case PRD is still shown
-- alongside (or instead of) this addon's bar. Only applied once at
-- login (see the delayed timer below), so a shield color changed
-- mid-session updates this addon's own bar immediately but PRD's
-- overlay only catches up on the next /reload or login.
local function ApplyAbsorbSkin()
    local prd = PersonalResourceDisplayFrame

    if not prd then
        return
    end

    if not prd.HealthBarsContainer then
        return
    end

    local hb = prd.HealthBarsContainer.healthBar

    if not hb then
        return
    end

    local hexColor = GetValidHexColor(WhitePlayerHealthDB.shieldColor, DEFAULT_SHIELD_COLOR)
    local r, g, b = CreateColorFromHexString(hexColor):GetRGB()

    if hb.totalAbsorb then
        hb.totalAbsorb:SetVertexColor(r, g, b, 1)
    end

    -- totalAbsorbOverlay is a highlight drawn on top of totalAbsorb, so
    -- it's blended 40% toward white here rather than reusing the exact
    -- same color - keeps the two visually distinct the way the original
    -- hardcoded (0, 0.6, 1) base / (0.3, 0.8, 1) highlight pair were.
    if hb.totalAbsorbOverlay then
        hb.totalAbsorbOverlay:SetVertexColor(
            r + (1 - r) * 0.4,
            g + (1 - g) * 0.4,
            b + (1 - b) * 0.4,
            1
        )
    end
end

local absorbFrame = CreateFrame("Frame")

absorbFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- PRD's regions aren't guaranteed to exist yet the instant the world
-- finishes loading, so this waits a couple seconds before touching them.
absorbFrame:SetScript("OnEvent", function()
    C_Timer.After(
        2,
        ApplyAbsorbSkin
    )
end)

print("WhitePlayerHealth loaded")
