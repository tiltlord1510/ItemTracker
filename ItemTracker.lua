local addonName, ns = ...

local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function GetTargetFromInput(text)
    if not text or text == "" then return nil, false end
    
    local currID = string.match(text, "^c(%d+)$")
    if currID then return "c" .. currID, true end

    if text == "gold" or text == "money" then return "c0", true end

    local id = tonumber(text)
    if id then return id, false end

    id = string.match(text, "item:(%d+)")
    if id then return tonumber(id), false end

    id = string.match(text, "currency:(%d+)")
    if id then return "c" .. id, true end

    return nil, false
end

-- Default SavedVariables (Includes Migration Logic for Old DB Format)
local function InitDB()
    ItemTrackerDB = ItemTrackerDB or {}
    ItemTrackerDB.savedItems = ItemTrackerDB.savedItems or {
        { id = 172040, tracking = true },  -- Protoplasmic Core
        { id = 178786, tracking = false }, -- Heavy Callous Hide
        { id = "c0",   tracking = false }, -- Gold
        { id = "c1792", tracking = false },-- Honor
    }
    
    -- Automatic Data Migration: Converts raw number IDs into table entries
    for idx, item in ipairs(ItemTrackerDB.savedItems) do
        if type(item) == "number" or type(item) == "string" then
            ItemTrackerDB.savedItems[idx] = { id = item, tracking = false }
        end
    end

    ItemTrackerDB.minimapPos = ItemTrackerDB.minimapPos or 45
end

local activeTrackers = {} -- Runtime tracker frame instances
local customOptionsFrame = nil
local RebuildAllTrackers -- Forward declaration

----------------------------------------------------
-- VALUE & FORMATTING HELPERS
----------------------------------------------------
local function GetCurrentTotal(targetID, isCurrency)
    if not targetID then return 0 end
    if isCurrency then
        local currNum = tonumber(string.sub(targetID, 2))
        if currNum == 0 then
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
    if not targetID then
        return "No Target Selected", "Interface\\Icons\\INV_Misc_QuestionMark"
    end
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

local function FormatValue(val, targetID, isCurrency)
    if isCurrency and targetID and tonumber(string.sub(targetID, 2)) == 0 then
        return GetCoinTextureString(val)
    end
    return tostring(val)
end

----------------------------------------------------
-- DYNAMIC TRACKER FRAME CREATOR
----------------------------------------------------
local function CreateTrackerInstance(itemEntry, index)
    local instance = {
        itemEntry = itemEntry,
        index = index,
    }

    -- Main Container Frame
    local f = CreateFrame("Button", "ItemTrackerFrame_" .. index, UIParent, "BackdropTemplate")
    f:SetSize(220, 95)

    if itemEntry.pos then
        f:SetPoint(itemEntry.pos[1], UIParent, itemEntry.pos[3], itemEntry.pos[4], itemEntry.pos[5])
    else
        f:SetPoint("CENTER", UIParent, "CENTER", (index - 1) * 30, (index - 1) * -30)
    end

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        itemEntry.pos = { point, nil, relPoint, x, y }
    end)

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\PVPFrame\\UI-Character-PVP-Highlight",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    f:SetBackdropColor(0, 0, 0, 0.8)

    -- Right-Click Any Frame to Open Options
    f:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if customOptionsFrame then customOptionsFrame:Show() end
        end
    end)

    -- Header Buttons
    local closeButton = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    closeButton:SetScript("OnClick", function()
        itemEntry.tracking = false
        RebuildAllTrackers()
    end)

    local uiResetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    uiResetBtn:SetSize(18, 18)
    uiResetBtn:SetPoint("RIGHT", closeButton, "LEFT", 2, 0)
    uiResetBtn:SetText("R")
    uiResetBtn:SetScript("OnClick", function()
        itemEntry.initialCount = nil
        itemEntry.startTime = nil
        instance:UpdateDisplay()
        print("|cff00ff00[ItemTracker]|r Reset session baseline.")
    end)

    -- Text & Icon components inside `f`
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)

    local titleText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    titleText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 0)
    titleText:SetPoint("RIGHT", uiResetBtn, "LEFT", -4, 0)
    titleText:SetJustifyH("LEFT")

    local countText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    countText:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -6)

    local rateText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rateText:SetPoint("TOPLEFT", countText, "BOTTOMLEFT", 0, -4)

    function instance:UpdateDisplay()
        if not itemEntry.tracking then
            f:Hide()
            return
        else
            f:Show()
        end

        local targetID = itemEntry.id
        local isCurrency = type(targetID) == "string" and string.sub(targetID, 1, 1) == "c"

        local name, texture = GetTargetDetails(targetID, isCurrency)
        titleText:SetText(name)
        if texture then icon:SetTexture(texture) end

        if not targetID then
            countText:SetText("Total: 0")
            rateText:SetText("Session: +0 (0/hr)")
            return
        end

        local currentTotal = GetCurrentTotal(targetID, isCurrency)

        -- Retain existing session baseline on itemEntry across frame rebuilds
        if not itemEntry.initialCount then
            itemEntry.initialCount = currentTotal
            itemEntry.startTime = GetTime()
        end

        local gained = currentTotal - itemEntry.initialCount
        local elapsedSeconds = GetTime() - (itemEntry.startTime or GetTime())
        local itemsPerHour = (elapsedSeconds > 0) and math.floor((gained / elapsedSeconds) * 3600) or 0

        countText:SetText("Total: " .. FormatValue(currentTotal, targetID, isCurrency))
        local gainColor = gained >= 0 and "|cff00ff00+" or "|cffff0000"
        rateText:SetText(string.format("Session: %s%s|r (%s/hr)", 
            gainColor, 
            FormatValue(gained, targetID, isCurrency), 
            FormatValue(itemsPerHour, targetID, isCurrency)
        ))
    end

    instance.frame = f
    table.insert(activeTrackers, instance)
    
    instance:UpdateDisplay()
    return instance
end

RebuildAllTrackers = function()
    for _, tracker in ipairs(activeTrackers) do
        if tracker.frame then
            tracker.frame:Hide()
            tracker.frame:SetParent(nil)
        end
    end
    activeTrackers = {}

    local activeIndex = 1
    for _, itemEntry in ipairs(ItemTrackerDB.savedItems) do
        if type(itemEntry) == "table" and itemEntry.tracking then
            CreateTrackerInstance(itemEntry, activeIndex)
            activeIndex = activeIndex + 1
        end
    end
    if customOptionsFrame and customOptionsFrame:IsShown() then
        if customOptionsFrame.RefreshList then customOptionsFrame:RefreshList() end
    end
end

----------------------------------------------------
-- CUSTOM OPTIONS FRAME
----------------------------------------------------
customOptionsFrame = CreateFrame("Frame", "ItemTrackerCustomOptionsFrame", UIParent, "BackdropTemplate")
customOptionsFrame:SetSize(460, 380)
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

local optTitle = customOptionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
optTitle:SetPoint("TOPLEFT", 20, -20)
optTitle:SetText("Item & Currency Tracker Options")

local optCloseBtn = CreateFrame("Button", nil, customOptionsFrame, "UIPanelCloseButton")
optCloseBtn:SetPoint("TOPRIGHT", customOptionsFrame, "TOPRIGHT", -5, -5)

local addInput = CreateFrame("EditBox", "ItemTrackerAddInput", customOptionsFrame, "InputBoxTemplate")
addInput:SetSize(160, 22)
addInput:SetPoint("TOPLEFT", optTitle, "BOTTOMLEFT", 0, -20)
addInput:SetAutoFocus(false)

local addSavedBtn = CreateFrame("Button", nil, customOptionsFrame, "UIPanelButtonTemplate")
addSavedBtn:SetSize(140, 22)
addSavedBtn:SetPoint("LEFT", addInput, "RIGHT", 10, 0)
addSavedBtn:SetText("+ Add to Saved Items")

local scrollFrame, contentFrame

local function RefreshOptionsList()
    if not contentFrame then return end
    
    for _, child in ipairs({contentFrame:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local yOffset = 0
    if ItemTrackerDB and ItemTrackerDB.savedItems then
        for idx, itemEntry in ipairs(ItemTrackerDB.savedItems) do
            local targetID = (type(itemEntry) == "table") and itemEntry.id or itemEntry
            local isTracking = (type(itemEntry) == "table") and itemEntry.tracking or false
            local isCurr = type(targetID) == "string" and string.sub(targetID, 1, 1) == "c"

            local row = CreateFrame("Frame", nil, contentFrame)
            row:SetSize(390, 26)
            row:SetPoint("TOPLEFT", 0, -yOffset)

            local iconTex = row:CreateTexture(nil, "ARTWORK")
            iconTex:SetSize(20, 20)
            iconTex:SetPoint("LEFT", 0, 0)

            local name, texture = GetTargetDetails(targetID, isCurr)
            iconTex:SetTexture(texture)

            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameText:SetPoint("LEFT", iconTex, "RIGHT", 6, 0)
            nameText:SetPoint("RIGHT", row, "RIGHT", -190, 0)
            nameText:SetJustifyH("LEFT")
            nameText:SetText(name)

            -- Button: Toggle Tracking On / Off
            local toggleBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            toggleBtn:SetSize(100, 20)
            toggleBtn:SetPoint("RIGHT", row, "RIGHT", -60, 0)
            toggleBtn:SetText(isTracking and "|cff00ff00Tracking ON|r" or "|cffff0000Tracking OFF|r")
            toggleBtn:SetScript("OnClick", function()
                if type(itemEntry) ~= "table" then
                    ItemTrackerDB.savedItems[idx] = { id = itemEntry, tracking = true }
                else
                    itemEntry.tracking = not itemEntry.tracking
                end
                RebuildAllTrackers()
                RefreshOptionsList()
            end)

            -- Button: Remove item from saved list
            local delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            delBtn:SetSize(50, 20)
            delBtn:SetPoint("LEFT", toggleBtn, "RIGHT", 4, 0)
            delBtn:SetText("Delete")
            delBtn:SetScript("OnClick", function()
                table.remove(ItemTrackerDB.savedItems, idx)
                RebuildAllTrackers()
                RefreshOptionsList()
            end)

            yOffset = yOffset + 28
        end
    end
    contentFrame:SetHeight(math.max(yOffset, 100))
end

customOptionsFrame.RefreshList = RefreshOptionsList

local function AddItemToSavedList()
    local text = addInput:GetText()
    local targetID, _ = GetTargetFromInput(text)
    if targetID then
        for _, entry in ipairs(ItemTrackerDB.savedItems) do
            local existingID = (type(entry) == "table") and entry.id or entry
            if existingID == targetID then
                print("|cffff0000[ItemTracker]|r Item is already in your saved list.")
                addInput:SetText("")
                addInput:ClearFocus()
                return
            end
        end
        
        table.insert(ItemTrackerDB.savedItems, { id = targetID, tracking = false })
        addInput:SetText("")
        addInput:ClearFocus()
        RefreshOptionsList()
        local name, _ = GetTargetDetails(targetID, type(targetID) == "string" and string.sub(targetID, 1, 1) == "c")
        print("|cff00ff00[ItemTracker]|r Added to saved list: " .. name)
    else
        print("|cffff0000[ItemTracker]|r Invalid Item/Currency ID, Link, or Keyword.")
    end
end

addSavedBtn:SetScript("OnClick", AddItemToSavedList)
addInput:SetScript("OnEnterPressed", AddItemToSavedList)

local function HandleItemDrop()
    local infoType, itemID = GetCursorInfo()
    if infoType == "item" and itemID then
        addInput:SetText(tostring(itemID))
        AddItemToSavedList()
        ClearCursor()
    end
end

addInput:SetScript("OnReceiveDrag", HandleItemDrop)
addInput:SetScript("OnMouseDown", HandleItemDrop)
addSavedBtn:SetScript("OnReceiveDrag", HandleItemDrop)

hooksecurefunc("ChatEdit_InsertLink", function(text)
    if addInput and addInput:HasFocus() then
        addInput:Insert(text)
    end
end)

scrollFrame = CreateFrame("ScrollFrame", "ItemTrackerScrollFrame", customOptionsFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetSize(400, 240)
scrollFrame:SetPoint("TOPLEFT", addInput, "BOTTOMLEFT", 0, -20)

contentFrame = CreateFrame("Frame", nil, scrollFrame)
contentFrame:SetSize(380, 240)
scrollFrame:SetScrollChild(contentFrame)

customOptionsFrame:SetScript("OnShow", RefreshOptionsList)

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
    customOptionsFrame:Show()
end)

minimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Multi-Item & Currency Tracker")
    GameTooltip:AddLine("|cffffffffClick:|r Open Options Menu", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cffffffffDrag:|r Move Minimap Button", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)

minimapBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

----------------------------------------------------
-- TIMER & EVENTS
----------------------------------------------------
local eventDriver = CreateFrame("Frame")

local function UpdateAllDisplays()
    for _, tracker in ipairs(activeTrackers) do
        tracker:UpdateDisplay()
    end
end

local timerGroup = eventDriver:CreateAnimationGroup()
local timerAnim = timerGroup:CreateAnimation()
timerAnim:SetDuration(1.0)
timerGroup:SetLooping("REPEAT")
timerGroup:SetScript("OnLoop", UpdateAllDisplays)

eventDriver:RegisterEvent("ADDON_LOADED")
eventDriver:RegisterEvent("PLAYER_LOGIN")
eventDriver:RegisterEvent("BAG_UPDATE")
eventDriver:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
eventDriver:RegisterEvent("PLAYER_MONEY")

eventDriver:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitDB()
        UpdateMinimapPos()
        RebuildAllTrackers()
        timerGroup:Play()
    elseif event == "PLAYER_LOGIN" then
        InitDB()
        RebuildAllTrackers()
    elseif event == "BAG_UPDATE" or event == "CURRENCY_DISPLAY_UPDATE" or event == "PLAYER_MONEY" then
        UpdateAllDisplays()
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
        customOptionsFrame:Show()
    elseif msg == "reset" then
        for _, entry in ipairs(ItemTrackerDB.savedItems) do
            if type(entry) == "table" then
                entry.initialCount = nil
                entry.startTime = nil
            end
        end
        UpdateAllDisplays()
        print("|cff00ff00[ItemTracker]|r Reset session counters for all items.")
    else
        local targetID, _ = GetTargetFromInput(msg)
        if targetID then
            local found = false
            for _, entry in ipairs(ItemTrackerDB.savedItems) do
                local existingID = (type(entry) == "table") and entry.id or entry
                if existingID == targetID then
                    if type(entry) == "table" then
                        entry.tracking = true
                    end
                    found = true
                    break
                end
            end
            if not found then
                table.insert(ItemTrackerDB.savedItems, { id = targetID, tracking = true })
            end
            RebuildAllTrackers()
            local name, _ = GetTargetDetails(targetID, type(targetID) == "string" and string.sub(targetID, 1, 1) == "c")
            print("|cff00ff00[ItemTracker]|r Enabled tracking for: " .. name)
        else
            print("|cff00ff00[ItemTracker] Commands:|r")
            print("  /it opt - Open Options Window")
            print("  /it reset - Reset session counters on all active frames")
            print("  /it <ItemID, Link, or gold> - Enable tracking for item")
        end
    end
end