--------------------------------------------------
-- SAVED VARIABLE DEFAULTS
--------------------------------------------------

-- 8-digit ARGB hex strings (alpha, then red/green/blue) - the format
-- CreateColorFromHexString requires and Settings.CreateColorSwatch's
-- built-in widget round-trips through internally (GenerateHexColor()).
-- A 6-digit RGB string here makes CreateColorFromHexString return nil.
local DEFAULT_HEALTH_COLOR = "FFFFFFFF"
local DEFAULT_SHIELD_COLOR = "FF0099FF"

-- Position is relative to the screen's center, so y = 250 puts the bar
-- roughly above a standing character's head at default UI scale.
-- Kept as constants because several separate paths reset back to them -
-- the settings panel, the quick-edit panel, and /wph reset.
local DEFAULT_X = 0
local DEFAULT_Y = 250
local DEFAULT_WIDTH = 240
local DEFAULT_HEIGHT = 5

-- Also referenced by the settings registrations further down, which
-- declare their own default alongside the saved-variable defaults here.
local DEFAULT_FILL_DIRECTION = "RTL"
local DEFAULT_SHOW_GUIDE = true

WhitePlayerHealthDB = WhitePlayerHealthDB or {}

if WhitePlayerHealthDB.width == nil then
    WhitePlayerHealthDB.width = DEFAULT_WIDTH
end

if WhitePlayerHealthDB.height == nil then
    WhitePlayerHealthDB.height = DEFAULT_HEIGHT
end

if WhitePlayerHealthDB.x == nil then
    WhitePlayerHealthDB.x = DEFAULT_X
end

if WhitePlayerHealthDB.y == nil then
    WhitePlayerHealthDB.y = DEFAULT_Y
end

if WhitePlayerHealthDB.showCenterGuide == nil then
    WhitePlayerHealthDB.showCenterGuide = DEFAULT_SHOW_GUIDE
end

if WhitePlayerHealthDB.editPanelX == nil then
    WhitePlayerHealthDB.editPanelX = 0
end

if WhitePlayerHealthDB.editPanelY == nil then
    WhitePlayerHealthDB.editPanelY = -120
end

if WhitePlayerHealthDB.absorbFillDirection == nil then
    WhitePlayerHealthDB.absorbFillDirection = DEFAULT_FILL_DIRECTION
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
-- themselves here while shown, so the apply functions can push live
-- updates into them as the color picker is dragged, not just refresh
-- them the next time they're shown.
local activeColorPreviews = {}

-- Only ever called from paths where the player actually changed a
-- color or the fill direction - deliberately not from the per-tick
-- health/absorb updates, which would repeat this work on every combat
-- tick for a preview that hadn't changed.
local function RefreshColorPreviews()
    for preview in pairs(activeColorPreviews) do
        preview:RefreshColors()
    end
end

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

    RefreshColorPreviews()
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

local barBorderTop = bar:CreateTexture(nil, "BORDER")
local barBorderBottom = bar:CreateTexture(nil, "BORDER")
local barBorderLeft = bar:CreateTexture(nil, "BORDER")
local barBorderRight = bar:CreateTexture(nil, "BORDER")

barBorderTop:SetColorTexture(0, 0, 0, 1)
barBorderBottom:SetColorTexture(0, 0, 0, 1)
barBorderLeft:SetColorTexture(0, 0, 0, 1)
barBorderRight:SetColorTexture(0, 0, 0, 1)

-- Every anchor here is a fixed offset from one of the bar's own edges,
-- and anchors persist across SetSize, so the border follows the bar on
-- its own once set. Run once at load rather than from ApplySettings(),
-- where it was re-applying identical values on every size or position
-- change.
barBorderTop:SetPoint("TOPLEFT", -1, 1)
barBorderTop:SetPoint("TOPRIGHT", 1, 1)
barBorderTop:SetHeight(1)

barBorderBottom:SetPoint("BOTTOMLEFT", -1, -1)
barBorderBottom:SetPoint("BOTTOMRIGHT", 1, -1)
barBorderBottom:SetHeight(1)

barBorderLeft:SetPoint("TOPLEFT", -1, 1)
barBorderLeft:SetPoint("BOTTOMLEFT", -1, -1)
barBorderLeft:SetWidth(1)

barBorderRight:SetPoint("TOPRIGHT", 1, 1)
barBorderRight:SetPoint("BOTTOMRIGHT", 1, -1)
barBorderRight:SetWidth(1)

--------------------------------------------------
-- APPLY SETTINGS
--------------------------------------------------

local function ApplySettings()
    bar:SetSize(WhitePlayerHealthDB.width, WhitePlayerHealthDB.height)

    bar:ClearAllPoints()
    bar:SetPoint("CENTER", UIParent, "CENTER", WhitePlayerHealthDB.x, WhitePlayerHealthDB.y)
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

-- Set when edit mode is asked for during combat, and honored once
-- combat ends. Mirrors pendingConfigOpen, so /wph and /wph config
-- behave the same way when used mid-fight.
local pendingEditModeOpen = false

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
-- QUICK EDIT PANEL (edit mode only)
--------------------------------------------------

local editPanel = CreateFrame("Frame", "WhitePlayerHealthEditPanel", UIParent)

editPanel:SetSize(190, 208)
editPanel:SetPoint("TOP", UIParent, "TOP", WhitePlayerHealthDB.editPanelX, WhitePlayerHealthDB.editPanelY)
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

-- Re-anchors the bar to exactly centered (x = 0), regardless of what
-- anchor point SetClampedToScreen may have left it on - GetCenter() is
-- used rather than GetPoint()/SetPoint() with the existing point,
-- since a drag pushed against a screen edge can leave the bar anchored
-- from a different point (e.g. "LEFT" instead of "CENTER"), and forcing
-- that offset to 0 would pin the edge to the screen edge instead of
-- centering the bar.
local function SnapBarToCenter()
    local centerX, centerY = bar:GetCenter()
    local parentCenterX, parentCenterY = UIParent:GetCenter()

    if centerX and centerY and parentCenterX and parentCenterY then
        bar:ClearAllPoints()
        bar:SetPoint("CENTER", UIParent, "CENTER", 0, centerY - parentCenterY)
    end
end

-- Toggles WhitePlayerHealthDB.snapToCenter - whether releasing a drag
-- always snaps the bar to exactly centered (x = 0), or leaves it
-- free-floating wherever it was dropped. Checking the box also snaps
-- immediately, rather than waiting for the next drag. OnClick is wired
-- up further down, once ApplySettings-adjacent state exists.
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

-- Escape hatch for when the bar ends up somewhere unusable - dragged
-- off behind another frame, or resized down to something too small to
-- grab. Confirms first, since it discards the current position and
-- size. OnClick is wired up further down, once the reset itself and
-- its confirmation dialog exist.
local resetButton = CreateFrame("Button", nil, editPanel, "UIPanelButtonTemplate")
resetButton:SetSize(130, 22)
resetButton:SetPoint("TOP", editPanel, "TOP", 0, -136)
resetButton:SetText("Reset to Default")

local saveCloseButton = CreateFrame("Button", nil, editPanel, "UIPanelButtonTemplate")
saveCloseButton:SetSize(130, 22)
saveCloseButton:SetPoint("TOP", editPanel, "TOP", 0, -162)
saveCloseButton:SetText("Save & Close")
-- OnClick is wired up further down, once LockBar exists.

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

    if WhitePlayerHealthDB.snapToCenter then
        SnapBarToCenter()
        SavePosition()
    end
end)

-- Shared by the quick-edit panel's Reset to Default button and the
-- settings panel's Reset Position & Size button, so the two can't
-- drift apart.
local function ResetPositionAndSize()
    WhitePlayerHealthDB.x = DEFAULT_X
    WhitePlayerHealthDB.y = DEFAULT_Y
    WhitePlayerHealthDB.width = DEFAULT_WIDTH
    WhitePlayerHealthDB.height = DEFAULT_HEIGHT

    ApplySettings()
    RefreshEditPanelValues()
end

StaticPopupDialogs["WHITEPLAYERHEALTH_RESET_CONFIRM"] = {
    text = "This will reset the bar's position and size to default settings.",
    button1 = "Confirm",
    button2 = "Exit",
    OnAccept = function()
        ResetPositionAndSize()
        print("WhitePlayerHealth: position and size reset to defaults.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- Shared by both reset buttons - the quick-edit panel's and the
-- settings panel's - so neither can reset without confirming first.
local function ConfirmResetPositionAndSize()
    StaticPopup_Show("WHITEPLAYERHEALTH_RESET_CONFIRM")
end

resetButton:SetScript("OnClick", ConfirmResetPositionAndSize)

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

-- Size is set by UpdateGripSize() below, which scales it with the bar.
resizeGrip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
resizeGrip:SetFrameLevel(bar:GetFrameLevel() + 2)
resizeGrip:EnableMouse(true)
resizeGrip:Hide()

-- Two thin lines hugging the bottom-right corner, like crop marks -
-- drawn here as plain rectangles rather than using Blizzard's grabber
-- art, both to match the 1px-line look the rest of this addon already
-- uses and so the contrast is controlled directly. Each line carries
-- its own dark outline, which keeps it legible over a light bar, a
-- dark bar, or whatever's behind it in the world, without needing a
-- heavy filled tile behind the whole grip.
--
-- Arm length tracks the bar's height directly, so the vertical arm
-- spans the bar rather than overhanging past it. The bounds keep a
-- very short bar from leaving nothing to grab, and a very tall one
-- from getting marks that overwhelm it.
local GRIP_MIN_ARM_LENGTH = 8
local GRIP_MAX_ARM_LENGTH = 24
local GRIP_MIN_ARM_THICKNESS = 2
local GRIP_MAX_ARM_THICKNESS = 4

-- Clickable margin around the marks, so the grab target stays
-- comfortable even at the smallest mark size.
local GRIP_PADDING = 6

local function CreateGripArm()
    local outline = resizeGrip:CreateTexture(nil, "OVERLAY", nil, 0)
    outline:SetColorTexture(0, 0, 0, 0.85)

    local line = resizeGrip:CreateTexture(nil, "OVERLAY", nil, 1)
    line:SetColorTexture(1, 1, 1, 1)

    -- Anchored to the line itself, so the outline follows it rather
    -- than needing its own placement kept in sync.
    outline:SetPoint("TOPLEFT", line, "TOPLEFT", -1, 1)
    outline:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", 1, -1)

    return line
end

-- Sizes come from UpdateGripSize() below, not from creation.
local gripArmHorizontal = CreateGripArm()
gripArmHorizontal:SetPoint("BOTTOMRIGHT", resizeGrip, "BOTTOMRIGHT", 0, 0)

local gripArmVertical = CreateGripArm()
gripArmVertical:SetPoint("BOTTOMRIGHT", resizeGrip, "BOTTOMRIGHT", 0, 0)

-- Named to avoid shadowing Blizzard's own global Clamp().
local function ClampToRange(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function UpdateGripSize()
    local barHeight = bar:GetHeight() or 0

    local armLength = ClampToRange(
        RoundToInt(barHeight),
        GRIP_MIN_ARM_LENGTH,
        GRIP_MAX_ARM_LENGTH
    )

    local armThickness = ClampToRange(
        RoundToInt(barHeight / 6),
        GRIP_MIN_ARM_THICKNESS,
        GRIP_MAX_ARM_THICKNESS
    )

    gripArmHorizontal:SetSize(armLength, armThickness)
    gripArmVertical:SetSize(armThickness, armLength)
    resizeGrip:SetSize(armLength + GRIP_PADDING, armLength + GRIP_PADDING)
end

-- OnSizeChanged fires continuously while a native resize drag is in
-- progress, so the marks track the bar live without any polling - the
-- OnUpdate-free approach the rest of this addon sticks to.
bar:SetScript("OnSizeChanged", UpdateGripSize)

UpdateGripSize()

-- Sits slightly dimmed until hovered, so the grip reads as an
-- interactive control without demanding attention the rest of the time.
-- Applied to the grip frame rather than the lines, so the lines and
-- their outlines dim together instead of drifting apart.
local function SetGripHighlighted(highlighted)
    resizeGrip:SetAlpha(highlighted and 1 or 0.75)
end

SetGripHighlighted(false)

resizeGrip:SetScript("OnEnter", function()
    SetGripHighlighted(true)
end)

resizeGrip:SetScript("OnLeave", function()
    SetGripHighlighted(false)
end)

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

    RefreshColorPreviews()
end

ApplyShieldColor()

-- WhitePlayerHealthDB.absorbFillDirection is "RTL" (default, fills
-- from the right edge toward the left) or "LTR" (fills from the left
-- edge toward the right). Reasserted on every update, defensively, in
-- case anything ever resets the flag.
--
-- Deliberately does NOT refresh the settings-panel color previews:
-- UpdateAbsorb() calls this on every health/absorb tick, so doing that
-- here meant rebuilding the preview textures continuously through a
-- fight. The two paths that actually change the fill direction call
-- RefreshColorPreviews() themselves instead.
local function ApplyAbsorbFillDirection()
    absorbBar:SetReverseFill(WhitePlayerHealthDB.absorbFillDirection ~= "LTR")
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
-- unlocked", and UpdateVisibility() only force-shows the bar while
-- it's true - so every unlock path has to set it, which is why it's
-- set here rather than by the callers. When one path skipped it,
-- unlocking while the bar was hidden (out of combat) left it hidden
-- but genuinely unlocked, surfacing later when something else happened
-- to show it and looking like the bar had unlocked itself.
-- The combat guard lives here rather than in the slash handler so it
-- covers both ways in - /wph and the settings panel's Unlock Bar
-- checkbox - instead of just the command. Callers check isEditMode
-- afterwards to tell whether it actually opened, since a deferred
-- request looks the same to them otherwise.
local function UnlockBar()
    if InCombatLockdown() then
        if not pendingEditModeOpen then
            pendingEditModeOpen = true
            print("WhitePlayerHealth: edit mode can't be opened during combat. Opening once you leave combat.")
        end

        return
    end

    isEditMode = true

    SetUnlocked(true)
    bar:Show()
end

local function LockBar()
    isEditMode = false

    -- An explicit lock overrides a request queued during combat, so
    -- edit mode can't reopen later against what was just asked for.
    pendingEditModeOpen = false

    SetUnlocked(false)
    widthBox:ClearFocus()
    heightBox:ClearFocus()
    SavePosition()
    SaveSize()
    UpdateVisibility()
end

saveCloseButton:SetScript("OnClick", function()
    ApplyPanelValues()
    LockBar()
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
    RefreshColorPreviews()
end)

--------------------------------------------------
-- DRAGGING
--------------------------------------------------

bar:EnableMouse(false)

-- When WhitePlayerHealthDB.snapToCenter is enabled (see the Snap to
-- Center checkbox on the quick-edit panel), every release forces x
-- back to 0 (the guide line) regardless of how far off it was
-- dropped - there's no proximity window. Applied once after
-- StopMovingOrSizing() rather than live during the drag - StartMoving()
-- re-tracks the cursor every frame, so a SetPoint override applied
-- mid-drag just gets overwritten by the next frame's native update and
-- never actually shows.
bar:SetScript("OnMouseDown", function(self)
    self:StartMoving()
end)

bar:SetScript("OnMouseUp", function(self)
    self:StopMovingOrSizing()

    if WhitePlayerHealthDB.snapToCenter then
        SnapBarToCenter()
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

-- Fraction of the preview bar the shield overlay covers. Tuned by eye
-- to sit near what a real shield usually looks like on a health bar,
-- rather than the half-and-half split it started at.
local PREVIEW_SHIELD_FRACTION = 0.256

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
    self.Shield:SetWidth(self.barWidth * PREVIEW_SHIELD_FRACTION)
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
        DEFAULT_WIDTH,
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
        DEFAULT_HEIGHT,
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

WPHSettingsLayout:AddInitializer(
    CreateSettingsButtonInitializer(
        "Reset Bar",
        "Reset Position & Size",
        ConfirmResetPositionAndSize,
        "Restores the bar's default position, width, and height. Asks for confirmation first.",
        -- addSearchTags: registers this button's text with the settings
        -- search box. Required, not optional - Blizzard asserts non-nil.
        true
    )
)

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
        DEFAULT_SHOW_GUIDE,
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
        RefreshColorPreviews()
    end

    local fillDirectionSetting = Settings.RegisterProxySetting(
        WPHSettingsCategory,
        "WPH_AbsorbFillDirection",
        "string",
        "Shield Fill Direction",
        DEFAULT_FILL_DIRECTION,
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
            -- addSearchTags - see the Reset Bar button above.
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
        return
    end

    -- Midnight requires the numeric category ID here, not the name.
    Settings.OpenToCategory(WPHSettingsCategory:GetID())
end

SLASH_WHITEPLAYERHEALTH1 = "/wph"

SlashCmdList["WHITEPLAYERHEALTH"] = function(msg)
    local cmd, value = strsplit(" ", msg)
    cmd = (cmd or ""):lower()
    value = tonumber(value)

    if cmd == "" then
        if isEditMode then
            LockBar()
            print("WhitePlayerHealth: edit mode off. Position and size saved.")
        elseif pendingEditModeOpen then
            -- Keeps /wph a real toggle during combat: a second press
            -- takes back the queued request instead of re-queueing it.
            pendingEditModeOpen = false
            print("WhitePlayerHealth: edit mode request cancelled.")
        else
            UnlockBar()

            -- Only announce it if it actually opened - UnlockBar()
            -- refuses during combat and says so itself.
            if isEditMode then
                print("WhitePlayerHealth: edit mode on. Drag to move, drag the corner handle to resize, or type exact values in the panel. Type /wph again to finish.")
            end
        end
    elseif cmd == "lock" then
        LockBar()
        print("WhitePlayerHealth locked.")
    elseif cmd == "reset" then
        -- Same scope as the panel buttons, so "reset" means one thing
        -- everywhere - but with no confirmation dialog, since typing
        -- the command is already deliberate in a way that clicking a
        -- button next to Save & Close isn't.
        ResetPositionAndSize()
        print("WhitePlayerHealth: position and size reset to defaults.")
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
        print("/wph lock")
        print("/wph reset - restore default position and size")
        print("/wph width 240")
        print("/wph height 5")
        print("/wph config")
    end
end

--------------------------------------------------
-- PANELS IN COMBAT
--------------------------------------------------

-- Only true while the settings panel is actually showing this addon's
-- own category. Sitting in Graphics or Keybindings when combat starts
-- is none of this addon's business, so that's left alone.
local function IsOurSettingsCategoryShown()
    if not SettingsPanel or not SettingsPanel:IsShown() then
        return false
    end

    return SettingsPanel:GetCurrentCategory() == WPHSettingsCategory
end

-- Gets this addon's panels out of the way when a fight starts. Nothing
-- reopens afterwards - they stay closed until asked for again, which is
-- why the message says so rather than promising a reopen.
--
-- The settings panel is hidden directly rather than through
-- SettingsPanel:Close(). Close() routes into HideUIPanel(), which goes
-- through WoW's secure panel manager and can be blocked when called
-- from addon code during combat lockdown - and this runs on
-- PLAYER_REGEN_DISABLED, when lockdown is already in effect. Close()
-- also raises a "discard changes?" dialog whenever any setting has
-- unapplied changes, which would be an unwelcome popup at the start of
-- a fight. Hide() avoids both.
local function CloseOurPanelsForCombat()
    local closedAnything = false

    if isEditMode then
        LockBar()
        closedAnything = true
    end

    if IsOurSettingsCategoryShown() then
        SettingsPanel:Hide()
        closedAnything = true
    end

    if closedAnything then
        print("WhitePlayerHealth: closed for combat - reopen with /wph or /wph config.")
    end
end

local combatPanelFrame = CreateFrame("Frame")

combatPanelFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatPanelFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

combatPanelFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        CloseOurPanelsForCombat()
        return
    end

    -- Leaving combat. Only requests made *during* combat are honored
    -- here; panels closed above stay closed. Both route back through
    -- their normal open functions so there's a single call site each -
    -- combat has ended by now, so neither lockdown branch is taken, and
    -- if one somehow were, the request just stays queued for next time.
    if pendingEditModeOpen then
        pendingEditModeOpen = false
        UnlockBar()
    end

    if pendingConfigOpen then
        pendingConfigOpen = false
        OpenConfig()
    end
end)

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
    C_Timer.After(2, ApplyAbsorbSkin)
end)
