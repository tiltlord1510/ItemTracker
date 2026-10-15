local addonName, ns = ...

-- Helper function to safely trim strings in standard Lua
local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Helper function to extract Item/Currency ID or Link
-- Returns: id (number or string "cID"), isCurrency (boolean)
local function GetTargetFromInput(text)
    if not text or text == "" then return nil, false end
    
    -- Check for explicit currency prefix "c" (e.g., "c1792" or "c0" for gold)
    local currID = string.match(text, "^c(%d+)$")
    if currID then
        return "c" .. currID, true
    end

    -- Check for gold keyword
    if text == "gold" or text == "money" then
        return "c0", true
    end

    -- Check if input is a raw item ID number
    local id = tonumber(text)
    if id then return id, false end

    -- Parse standard WoW Item Link pattern (|Hitem:172040:...)
    id = string.match(text, "item:(%d+)")
    if id then return tonumber(id), false end

    -- Parse WoW Currency Link pattern (|Hcurrency:1792:...)
    id = string.match(text, "currency:(%d+)")
    if id then return "c" .. id, true end

    return nil, false
end

-- Default SavedVariables (Character Specific)
local function InitDB()
    ItemTrackerDB = ItemTrackerDB or {}
    ItemTrackerDB.targetID = ItemTrackerDB.targetID or ItemTrackerDB.targetItemID or 172040 -- Default: Protoplasmic Core
    ItemTrackerDB.shown = (ItemTrackerDB.shown == nil) and true or ItemTrackerDB.shown
    ItemTrackerDB.savedItems = ItemTrackerDB.savedItems or {
        172040,   -- Protoplasmic Core (Item)
        178786,   -- Heavy Callous Hide (Item)
        "c0",     -- Gold (Currency)
        "c1792",  -- Honor (Currency)
    }
    ItemTrackerDB.minimapPos = ItemTrackerDB.minimapPos or 45
end

local trackingTargetID = nil
local isTrackingCurrency = false
local initialCount = nil
local startTime = nil

----------------------------------------------------
-- SESSION RESET LOGIC
----------------------------------------------------
local function ResetSessionData()
    initialCount = nil
    startTime = nil
end

----------------------------------------------------
-- VALUE & FORMATTING HELPERS
----------------------------------------------------
local function GetCurrentTotal(targetID, isCurrency)
    if isCurrency then
        local currNum = tonumber(string.sub(targetID, 2))
        if currNum == 0 then
            -- Tracking Gold (in Copper)
            return GetMoney() or 0
        else
            local info = C_CurrencyInfo.GetCurrencyInfo(currNum)
            return info and info.quantity or 0
        end
    else
        return GetItemCount(targetID, true) or 0
    end
end

local function GetTargetDetails(targetID, isCurrency)
    if isCurrency then
        local currNum = tonumber(string.sub(targetID, 2))
        if currNum == 0 then
            return "Gold", "Interface\\Icons\\INV_Misc_Coin_01"
        else
            local info = C_CurrencyInfo.GetCurrencyInfo(currNum)
            if info then
                return info.name, info.iconFileID
            else
                return "Currency: " .. currNum, "Interface\\Icons\\INV_Misc_QuestionMark"
            end
        end
    else
        local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(targetID)
        return itemName or ("Item ID: " .. targetID), itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark"
    end
end

local function FormatValue(val, isCurrency)
    if isCurrency and tonumber(string.sub(trackingTargetID, 2)) == 0 then
        -- Gold formatting
        return GetCoinTextureString(val)
    end
    return tostring(val)
end

----------------------------------------------------
-- CUSTOM STANDALONE OPTIONS FRAME
----------------------------------------------------
local customOptionsFrame = CreateFrame("Frame", "ItemTrackerCustomOptionsFrame", UIParent, "BackdropTemplate")
customOptionsFrame:SetSize(420, 360)
customOptionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
customOptionsFrame:SetMovable(true)
customOptionsFrame:EnableMouse(true)
customOptionsFrame:RegisterForDrag("LeftButton")
customOptionsFrame:SetScript("OnDragStart", customOptionsFrame.StartMoving)
customOptionsFrame:SetScript("OnDragStop", customOptionsFrame.StopMovingOrSizing)
customOptionsFrame:SetFrameStrata("DIALOG")
customOptionsFrame:Hide()

customOptionsFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})

-- Header / Title
local optTitle = customOptionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
optTitle:SetPoint("TOPLEFT", 20, -20)
optTitle:SetText("Item & Currency Tracker Options")

-- Close Button
local optCloseBtn = CreateFrame("Button", nil, customOptionsFrame, "UIPanelCloseButton")
optCloseBtn:SetPoint("TOPRIGHT", customOptionsFrame, "TOPRIGHT", -5, -5)

-- Reset Session Button
local optResetBtn = CreateFrame("Button", nil, customOptionsFrame, "UIPanelButtonTemplate")
optResetBtn:SetSize(130, 22)
optResetBtn:SetPoint("TOPRIGHT", customOptionsFrame, "TOPRIGHT", -40, -18)
optResetBtn:SetText("Reset Session")
optResetBtn:SetScript("OnClick", function()
    ResetSessionData()
    print("|cff00ff00[ItemTracker]|r Session tracking reset.")
end)

-- Input Box to Add New Item/Currency
local addInput = CreateFrame("EditBox", "ItemTrackerAddInput", customOptionsFrame, "InputBoxTemplate")
addInput:SetSize(160, 22)
addInput:SetPoint("TOPLEFT", optTitle, "BOTTOMLEFT", 0, -20)
addInput:SetAutoFocus(false)

local addBtn = CreateFrame("Button", nil, customOptionsFrame, "UIPanelButtonTemplate")
addBtn:SetSize(100, 22)
addBtn:SetPoint("LEFT", addInput, "RIGHT", 10, 0)
addBtn:SetText("Add Target")

local scrollFrame, contentFrame

local function RefreshOptionsList()
    if not contentFrame then return end
    
    for _, child in ipairs({contentFrame:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local yOffset = 0
    if ItemTrackerDB and ItemTrackerDB.savedItems then
        for idx, savedID in ipairs(ItemTrackerDB.savedItems) do
            local isCurr = type(savedID) == "string" and string.sub(savedID, 1, 1) == "c"
            local row = CreateFrame("Frame", nil, contentFrame)
            row:SetSize(350, 26)
            row:SetPoint("TOPLEFT", 0, -yOffset)

            local iconTex = row:CreateTexture(nil, "ARTWORK")
            iconTex:SetSize(20, 20)
            iconTex:SetPoint("LEFT", 0, 0)

            local name, texture = GetTargetDetails(savedID, isCurr)
            iconTex:SetTexture(texture)

            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameText:SetPoint("LEFT", iconTex, "RIGHT", 8, 0)
            nameText:SetPoint("RIGHT", row, "RIGHT", -120, 0)
            nameText:SetJustifyH("LEFT")
            nameText:SetText(name .. (isCurr and " |cff808080(Currency)|r" or ""))

            local trackBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            trackBtn:SetSize(55, 20)
            trackBtn:SetPoint("RIGHT", row, "RIGHT", -55, 0)
            trackBtn:SetText("Track")
            trackBtn:SetScript("OnClick", function()
                trackingTargetID = savedID
                isTrackingCurrency = isCurr
                ItemTrackerDB.targetID = savedID
                ResetSessionData()
                print("|cff00ff00[ItemTracker]|r Now tracking: " .. name)
            end)

            local delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            delBtn:SetSize(50, 20)
            delBtn:SetPoint("LEFT", trackBtn, "RIGHT", 4, 0)
            delBtn:SetText("Delete")
            delBtn:SetScript("OnClick", function()
                table.remove(ItemTrackerDB.savedItems, idx)
                RefreshOptionsList()
            end)

            yOffset = yOffset + 28
        end
    end
    contentFrame:SetHeight(math.max(yOffset, 100))
end

-- Helper to add target to saved table safely
local function AddTargetFromInput()
    local text = addInput:GetText()
    local targetID, isCurr = GetTargetFromInput(text)
    if targetID then
        for _, existingID in ipairs(ItemTrackerDB.savedItems) do
            if existingID == targetID then
                print("|cffff0000[ItemTracker]|r Target is already in your list.")
                addInput:SetText("")
                addInput:ClearFocus()
                return
            end
        end
        
        table.insert(ItemTrackerDB.savedItems, targetID)
        addInput:SetText("")
        addInput:ClearFocus()
        RefreshOptionsList()
        local name = GetTargetDetails(targetID, isCurr)
        print("|cff00ff00[ItemTracker]|r Added " .. name)
    else
        print("|cffff0000[ItemTracker]|r Invalid Item/Currency ID, Link, or Keyword.")
    end
end

addBtn:SetScript("OnClick", AddTargetFromInput)
addInput:SetScript("OnEnterPressed", AddTargetFromInput)

-- Support dragging items onto the input box
local function HandleItemDrop()
    local infoType, itemID = GetCursorInfo()
    if infoType == "item" and itemID then
        addInput:SetText(tostring(itemID))
        AddTargetFromInput()
        ClearCursor()
    end
end

addInput:SetScript("OnReceiveDrag", HandleItemDrop)
addInput:SetScript("OnMouseDown", HandleItemDrop)
addBtn:SetScript("OnReceiveDrag", HandleItemDrop)

hooksecurefunc("ChatEdit_InsertLink", function(text)
    if addInput and addInput:HasFocus() then
        addInput:Insert(text)
    end
end)

scrollFrame = CreateFrame("ScrollFrame", "ItemTrackerScrollFrame", customOptionsFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetSize(360, 220)
scrollFrame:SetPoint("TOPLEFT", addInput, "BOTTOMLEFT", 0, -20)

contentFrame = CreateFrame("Frame", nil, scrollFrame)
contentFrame:SetSize(340, 220)
scrollFrame:SetScrollChild(contentFrame)

customOptionsFrame:SetScript("OnShow", RefreshOptionsList)

local function ToggleOptionsMenu()
    if customOptionsFrame:IsShown() then
        customOptionsFrame:Hide()
    else
        customOptionsFrame:Show()
    end
end

----------------------------------------------------
-- MAIN TRACKER FRAME SETUP
----------------------------------------------------
local frame = CreateFrame("Button", "ItemTrackerFrame", UIParent, "BackdropTemplate")
frame:SetSize(220, 95)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\PVPFrame\\UI-Character-PVP-Highlight",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
frame:SetBackdropColor(0, 0, 0, 0.8)

frame:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
        ToggleOptionsMenu()
    end
end)

local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
closeButton:SetScript("OnClick", function()
    frame:Hide()
    ItemTrackerDB.shown = false
end)

local uiResetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
uiResetBtn:SetSize(18, 18)
uiResetBtn:SetPoint("RIGHT", closeButton, "LEFT", 2, 0)
uiResetBtn:SetText("R")
uiResetBtn:SetScript("OnClick", function()
    ResetSessionData()
    print("|cff00ff00[ItemTracker]|r Session tracking reset.")
end)
uiResetBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Reset Session Data", 1, 1, 1)
    GameTooltip:AddLine("Resets baseline count and hourly rate timer.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
uiResetBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetSize(32, 32)
icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
titleText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 0)
titleText:SetPoint("RIGHT", uiResetBtn, "LEFT", -4, 0)
titleText:SetText("No Target Selected")
titleText:SetJustifyH("LEFT")

local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
countText:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -6)
countText:SetText("Total: 0")

local rateText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
rateText:SetPoint("TOPLEFT", countText, "BOTTOMLEFT", 0, -4)
rateText:SetText("Session: +0 (0/hr)")

----------------------------------------------------
-- DISPLAY UPDATE LOGIC
----------------------------------------------------
local function UpdateDisplay()
    if not trackingTargetID then return end

    local currentTotal = GetCurrentTotal(trackingTargetID, isTrackingCurrency)
    local name, texture = GetTargetDetails(trackingTargetID, isTrackingCurrency)

    titleText:SetText(name)
    if texture then icon:SetTexture(texture) end

    if not initialCount then
        initialCount = currentTotal
        startTime = GetTime()
    end

    local gained = currentTotal - initialCount
    local elapsedSeconds = GetTime() - startTime
    local itemsPerHour = (elapsedSeconds > 0) and math.floor((gained / elapsedSeconds) * 3600) or 0

    countText:SetText("Total: " .. FormatValue(currentTotal, isTrackingCurrency))
    local gainColor = gained >= 0 and "|cff00ff00+" or "|cffff0000"
    rateText:SetText(string.format("Session: %s%s|r (%s/hr)", gainColor, FormatValue(gained, isTrackingCurrency), FormatValue(itemsPerHour, isTrackingCurrency)))
end

----------------------------------------------------
-- MINIMAP BUTTON SETUP
----------------------------------------------------
local minimapBtn = CreateFrame("Button", "ItemTrackerMinimapButton", Minimap)
minimapBtn:SetSize(31, 31)
minimapBtn:SetFrameLevel(8)
minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local mIcon = minimapBtn:CreateTexture(nil, "BACKGROUND")
mIcon:SetSize(20, 20)
mIcon:SetPoint("CENTER")
mIcon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10.blp")

local mBorder = minimapBtn:CreateTexture(nil, "OVERLAY")
mBorder:SetSize(53, 53)
mBorder:SetPoint("TOPLEFT")
mBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function UpdateMinimapPos()
    local angle = math.rad(ItemTrackerDB.minimapPos or 45)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

minimapBtn:RegisterForDrag("LeftButton")
minimapBtn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local xpos, ypos = GetCursorPosition()
        local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
        local scale = Minimap:GetEffectiveScale()
        xpos = xpos / scale - xmin - 70
        ypos = ypos / scale - ymin - 70
        ItemTrackerDB.minimapPos = math.deg(math.atan2(ypos, xpos))
        UpdateMinimapPos()
    end)
end)

minimapBtn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

minimapBtn:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
        ToggleOptionsMenu()
    else
        if frame:IsShown() then
            frame:Hide()
            ItemTrackerDB.shown = false
        else
            frame:Show()
            ItemTrackerDB.shown = true
        end
    end
end)

minimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Item & Currency Tracker")
    GameTooltip:AddLine("|cffffffffLeft-Click:|r Toggle Display Frame", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cffffffffRight-Click:|r Open Options Menu", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cffffffffDrag:|r Move Minimap Button", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)

minimapBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

----------------------------------------------------
-- TIMER & EVENTS
----------------------------------------------------
local timerGroup = frame:CreateAnimationGroup()
local timerAnim = timerGroup:CreateAnimation()
timerAnim:SetDuration(1.0)
timerGroup:SetLooping("REPEAT")
timerGroup:SetScript("OnLoop", UpdateDisplay)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
frame:RegisterEvent("PLAYER_MONEY")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitDB()
        trackingTargetID = ItemTrackerDB.targetID
        isTrackingCurrency = type(trackingTargetID) == "string" and string.sub(trackingTargetID, 1, 1) == "c"
        
        if ItemTrackerDB.shown then
            frame:Show()
        else
            frame:Hide()
        end
        
        UpdateMinimapPos()
        timerGroup:Play()
    elseif event == "PLAYER_LOGIN" then
        ResetSessionData()
        UpdateDisplay()
    elseif event == "BAG_UPDATE" or event == "CURRENCY_DISPLAY_UPDATE" or event == "PLAYER_MONEY" then
        UpdateDisplay()
    end
end)

----------------------------------------------------
-- SLASH COMMANDS
----------------------------------------------------
SLASH_ITEMTRACKER1 = "/it"
SLASH_ITEMTRACKER2 = "/itemtracker"
SlashCmdList["ITEMTRACKER"] = function(msg)
    msg = string.lower(trim(msg or ""))
    
    if msg == "options" or msg == "opt" then
        ToggleOptionsMenu()
    elseif msg == "toggle" then
        if frame:IsShown() then frame:Hide() ItemTrackerDB.shown = false else frame:Show() ItemTrackerDB.shown = true end
    elseif msg == "show" then
        frame:Show() ItemTrackerDB.shown = true
    elseif msg == "hide" then
        frame:Hide() ItemTrackerDB.shown = false
    elseif msg == "reset" then
        ResetSessionData()
        UpdateDisplay()
        print("|cff00ff00[ItemTracker]|r Session counter reset.")
    else
        local targetID, isCurr = GetTargetFromInput(msg)
        if targetID then
            trackingTargetID = targetID
            isTrackingCurrency = isCurr
            ItemTrackerDB.targetID = trackingTargetID
            ResetSessionData()
            UpdateDisplay()
            local name = GetTargetDetails(targetID, isCurr)
            print("|cff00ff00[ItemTracker]|r Now tracking: " .. name)
        else
            print("|cff00ff00[ItemTracker] Commands:|r")
            print("  /it opt - Open Options Window")
            print("  /it reset - Reset session gains and rate timer")
            print("  /it gold - Track character gold rate")
            print("  /it c<CurrencyID> - Track a currency (e.g., /it c1792 for Honor)")
            print("  /it <ItemID or ItemLink> - Track an item")
        end
    end
end