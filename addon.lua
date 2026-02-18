local myname, ns = ...

-- populated when addon loads:
local DataTypeNames
local LineTypeNames

-- Color helpers

local C = {
    header      = CreateColor(0.9,  0.8,  0.1, 1),
    key         = CreateColor(0.6,  0.9,  1.0, 1),
    value       = CreateColor(1.0,  1.0,  1.0, 1),
    lineType    = CreateColor(0.4,  1.0,  0.5, 1),
    leftText    = CreateColor(1.0,  1.0,  0.82, 1),
    rightText   = CreateColor(0.7,  0.7,  1.0, 1),
    extra       = CreateColor(1.0,  0.6,  0.2, 1),
    dimmed      = CreateColor(0.45, 0.45, 0.45, 1),
    separator   = CreateColor(0.3,  0.3,  0.35, 1),
    bg          = CreateColor(0.05, 0.05, 0.08, 1),
}

local function Col(c, s)
    return WrapTextInColor(s, c)
end

-- Serialise arbitrary values to a readable string
local function Str(v, depth)
    depth = depth or 0
    local t = type(v)
    if t == "nil"     then return Col(C.dimmed, "nil") end
    if t == "boolean" then return Col(C.extra, tostring(v)) end
    if t == "number"  then return Col(C.value, tostring(v)) end
    if t == "string"  then
        if #v == 0 then return Col(C.dimmed, '""') end
        return Col(C.leftText, '"' .. v .. '"')
    end
    if t == "table" and depth < 2 then
        local parts = {}
        for k, val in pairs(v) do
            parts[#parts+1] = Col(C.key, tostring(k)) .. "=" .. Str(val, depth+1)
        end
        if #parts == 0 then return Col(C.dimmed, "{}") end
        return "{ " .. table.concat(parts, ", ") .. " }"
    end
    return Col(C.dimmed, "["..t.."]")
end

-- Known fields
-- There's a bunch more of these, but this is what the wiki documents right now:

local KNOWN_DATA_FIELDS = {
    -- all types
    "type",
    "id", --?
    "dataInstanceID",
    "lines",
    "guid",
    -- items
    "hyperlink",
    "hasDynamicData", --?
    "isAzeriteItem",
    "isAzeriteEmpoweredItem",
    "isCorruptedItem",
    "overrideItemLevel", --?
    "repairCost", --?
    -- units
    "healthGUID",
}

local KNOWN_LINE_FIELDS = {
    -- all types
    "type",
    "leftText",
    "leftColor",
    "rightText",
    "rightColor",
    "wrapText",
    "lineIndex",
    -- 2 unitname
    "unitToken",
    -- 11 sellprice
    "price",
    "maxPrice",
    -- 19 nestedBlock
    "tooltipType",
    "tooltipID",
    -- 20 itemBinding
    "bonding",
}

-- Core rendering

local function TypeName(typeVal, map)
    if not map then return tostring(typeVal) end
    return Col(C.lineType, map[typeVal] or UNKNOWN) .. Col(C.dimmed, " (" .. typeVal .. ")")
end

local function PopulateDataProvider(dataProvider, data)
    local newdata = {}

    -- Top-level fields
    table.insert(newdata, "type = " .. TypeName(data.type, DataTypeNames))

    local knownTop = {lines=true, type=true}
    -- First: known fields in a defined order
    for _, f in ipairs(KNOWN_DATA_FIELDS) do
        if not knownTop[f] then
            local v = data[f]
            if v ~= nil then
                table.insert(newdata, Col(C.key, f) .. " = " .. Str(v))
            end
            knownTop[f] = true
        end
    end
    -- Any we don't have explicitly known
    for k, v in pairs(data) do
        if not knownTop[k] then
            table.insert(newdata, Col(C.extra, "[extra] ") .. Col(C.key, tostring(k)) .. " = " .. Str(v))
        end
    end

    table.insert(newdata, true)

    local lines = data.lines
    if not lines or #lines == 0 then
        table.insert(newdata, Col(C.dimmed, "(no lines)"))
    else
        table.insert(newdata, Col(C.header, "lines  [" .. #lines .. "]"))

        local indent = "   "
        for i, line in ipairs(lines) do
            table.insert(newdata, true)

            -- Line index + type
            table.insert(newdata, Col(C.key, "["..i.."]") .. "  type = " .. TypeName(line.type, LineTypeNames))

            table.insert(newdata, indent .. Col(C.dimmed, "leftText  = ") .. Str(line.leftText))

            if line.rightText and line.rightText ~= "" then
                table.insert(newdata, indent .. Col(C.dimmed, "rightText = ") ..
                    Col(C.rightText, '"' .. line.rightText .. '"'))
            end

            if line.leftColor then
                local lc = line.leftColor
                table.insert(newdata, indent .. Col(C.dimmed, "leftColor = ") ..
                    string.format("%s r=%.3f g=%.3f b=%.3f a=%.3f",
                        WrapTextInColor("▮", lc),
                        lc.r or 0, lc.g or 0, lc.b or 0, lc.a or 1))
            end

            if line.rightColor then
                local rc = line.rightColor
                table.insert(newdata, indent .. Col(C.dimmed, "rightColor= ") ..
                    string.format("%s r=%.3f g=%.3f b=%.3f a=%.3f",
                        WrapTextInColor("▮", rc),
                        rc.r or 0, rc.g or 0, rc.b or 0, rc.a or 1))
            end

            -- All remaining extra/unknown fields
            local knownLine = {
                type=true, leftText=true, rightText=true,
                leftColor=true, rightColor=true,
            }
            -- First pass: known extra fields in a defined order
            for _, f in ipairs(KNOWN_LINE_FIELDS) do
                if not knownLine[f] then
                    local v = line[f]
                    if v ~= nil then
                        knownLine[f] = true
                        table.insert(newdata, indent .. Col(C.extra, f) .. " = " .. Str(v))
                    end
                end
            end
            -- Second pass: anything we haven't seen yet
            for k, v in pairs(line) do
                if not knownLine[k] then
                    table.insert(newdata, indent .. Col(C.extra, "[?] " .. tostring(k)) .. " = " .. Str(v))
                end
            end
        end
    end

    dataProvider:Flush()
    dataProvider:InsertTable(newdata)
end

-- Frame builder

local INSPECTOR_WIDTH = 340
local INSPECTOR_HEIGHT = 500

local function BuildInspectorFrame(dataProvider)
    local f = CreateFrame("Frame", myname.."Frame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(INSPECTOR_WIDTH, INSPECTOR_HEIGHT)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -50)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnSizeChanged", function(self, width, height)
        if not self.ScrollChild then return end
        self.ScrollChild:SetHeight(math.max(CurrentScrollHeight(), self:GetHeight()))
    end)
    f:SetResizable(true)
    f:SetResizeBounds(INSPECTOR_WIDTH, 300, INSPECTOR_WIDTH, 900)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("HIGH")

    -- Title
    f.TitleText:SetText(myname.." |cff888888(hover anything)|r")

    -- Resize grip
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOM") end)
    grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)

    -- Scrolling bits
    local container = CreateFrame("Frame", nil, f)
    container:SetPoint("TOPLEFT", 8, -28)
    container:SetPoint("BOTTOMRIGHT", 0, 8)

    local heightTester = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heightTester:SetPoint("TOPLEFT")
    heightTester:SetPoint("RIGHT", -23, 0)
    heightTester:Hide()

    local scrollBox = CreateFrame("Frame", nil, container, "WowScrollBoxList")
    -- SetPoint handled by manager below
    container.ScrollBox = scrollBox

    local scrollBar = CreateFrame("EventFrame", nil, container, "WowTrimScrollBar")
    scrollBar:SetPoint("TOPRIGHT", -1, 5)
    scrollBar:SetPoint("BOTTOMRIGHT", -1, 14)
    scrollBar:SetHideTrackIfThumbExceedsTrack(true)
    container.ScrollBar = scrollBar

    local pad, spacing = 4, 2
    local scrollView = CreateScrollBoxListLinearView(pad, pad, pad, pad, spacing)
    -- scrollView:SetElementExtent(14)  -- Fixed height for each row; required as we're not using XML.
    scrollView:SetElementExtentCalculator(function(dataIndex, elementData)
        if type(elementData) == "string" then
            heightTester:SetText(elementData)
            return heightTester:GetHeight() or 14
        end
        return elementData and 4 or 0
    end)
    scrollView:SetElementInitializer("Frame", function(element, elementData)
        if not element.text then
            element.text = element:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            element.text:SetJustifyH("LEFT")
            element.text:SetJustifyV("TOP")
            element.text:SetAllPoints(element)
        end
        if type(elementData) == "string" then
            element.text:SetText(elementData)
        else
            element.text:SetText("")
        end
    end)
    scrollView:SetDataProvider(dataProvider, ScrollBoxConstants.RetainScrollPosition)
    container.ScrollView = scrollView

    ScrollUtil.InitScrollBoxWithScrollBar(scrollBox, scrollBar, scrollView)
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, scrollBar,
        {  -- with bar
            CreateAnchor("TOPLEFT", container),
            CreateAnchor("BOTTOMRIGHT", container, "BOTTOMRIGHT", -25, 0),
        },
        { -- without bar
            CreateAnchor("TOPLEFT", container),
            CreateAnchor("BOTTOMRIGHT", container, "BOTTOMRIGHT", -4, 0),
        }
    )
    -- scrollBox:FullUpdate()

    f:Hide()
    return f
end

-- Addon init

local InspectorFrame

EventUtil.ContinueOnAddOnLoaded(myname, function()
    if Enum then
        if Enum.TooltipDataType then
            DataTypeNames = tInvert(Enum.TooltipDataType)
        end
        if Enum.TooltipDataLineType then
            LineTypeNames = tInvert(Enum.TooltipDataLineType)
        end
    end

    local dataProvider = CreateDataProvider()
    InspectorFrame = BuildInspectorFrame(dataProvider)

    TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
        if not (InspectorFrame and InspectorFrame:IsShown()) then return end
        PopulateDataProvider(dataProvider, data)
    end)

    -- print("|cffFFD700".. myname .."|r loaded. |cff888888".. SLASH_TOOLTIPDATAINSPECTOR1 .."|r to toggle")
end)

SLASH_TOOLTIPDATAINSPECTOR1 = "/tdi"
SLASH_TOOLTIPDATAINSPECTOR2 = "/tooltipdatainspector"
SlashCmdList["TOOLTIPDATAINSPECTOR"] = function(msg)
    if not InspectorFrame then return end
    InspectorFrame:SetShown(not InspectorFrame:IsShown())
end

_G.TooltipDataInspector_OnAddonCompartmentClick = function(addon, button, ...)
    -- DevTools_Dump({addon, button, ...})
    if button == "LeftButton" then
        if not InspectorFrame then return end
        InspectorFrame:SetShown(not InspectorFrame:IsShown())
    end
end
