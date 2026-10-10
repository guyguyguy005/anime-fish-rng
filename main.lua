-- Fish an Anime RNG — AutoHold v2
-- target: Potassium / mobile executor
-- ถือตัวละครที่เลือกเมื่อ event (mutation ฯลฯ) เริ่ม

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local CoreGui          = game:GetService("CoreGui")
local Workspace        = game:GetService("Workspace")
local LocalPlayer      = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- remotes จริงของเกม (จาก scan)
local R = {
    CharSummaryGet    = Remotes:WaitForChild("BackpackCharSummaryGet"),       -- RF
    CharSummaryDelta  = Remotes:WaitForChild("BackpackCharSummaryDelta"),     -- RE
    HoldCharacter     = Remotes:WaitForChild("BackpackHoldCharacter"),        -- RE
    EquipCharacter    = Remotes:WaitForChild("BackpackEquipCharacter"),       -- RE
    UnequipCharacter  = Remotes:WaitForChild("BackpackUnequipCharacter"),     -- RE
    EquippedUpdated   = Remotes:WaitForChild("BackpackEquippedUpdated"),      -- RE
    EquippedStateGet  = Remotes:WaitForChild("BackpackGetEquippedState"),     -- RF
    TypeEventState    = Remotes:WaitForChild("TypeEventState"),               -- RE
    TypeEventStateGet = Remotes:WaitForChild("GetTypeEventState"),            -- RF
}

-- ========== state ==========
local selected       = {}   -- [charId] = true
local charCache      = {}   -- [charId] = {Name, Rarity, ...}
local autoHold       = true
local onlyMutation   = true  -- true = ถือเฉพาะ event ที่มี mutation
local lastHeldId     = nil
local rotateIndex    = 1

-- event ที่บังคับให้ตัวละครได้ mutation (จาก TypeEvents folder)
local MUTATION_EVENTS = {
    ["A=ForceMutations"]       = true,
    ["Hell's Gates"]           = true,
    ["Sad Ending"]             = true,
    ["Heaven"]                 = true,
    ["Eclipse"]                = true,
    ["Starfall"]               = true,
    ["Lucrative Realization"]  = true,
    ["Sakura Season"]          = true,
    ["S U B  Z E R O"]         = true,
    ["Complex Matrix"]         = true,
    ["Forgotten Ruins"]        = true,
    ["Limerence Complexity"]   = true,
    ["Toxic Wasteland"]        = true,
    ["Broken Thoughts"]        = true,
    ["Supernova"]              = true,
    ["Blizzard"]               = true,
    ["Thunder"]                = true,
    ["Solar"]                  = true,
    ["Lunar"]                  = true,
    ["SlimeRain"]              = true,
    ["Halloween"]              = true,
    ["Night"]                  = true,
    ["Party"]                  = true,
    ["Cyberspace"]             = true,
    ["Dreamspace"]             = true,
}

-- ========== character data ==========
local function refreshCharacters()
    local ok, summary = pcall(function()
        return R.CharSummaryGet:InvokeServer()
    end)
    if not ok or type(summary) ~= "table" then
        return {}
    end
    charCache = {}
    local list = {}
    -- summary อาจมาในหลาย format — รองรับทั้งคู่
    for k, v in pairs(summary) do
        local entry
        if type(v) == "table" then
            entry = {
                id      = v.Id or v.id or k,
                name    = v.Name or v.name or tostring(k),
                rarity  = v.Rarity or v.rarity or "?",
                count   = v.Count or v.count or 1,
                mutation= v.Mutation or v.mutation or nil,
            }
        else
            entry = { id = k, name = tostring(k), rarity = "?", count = v or 1 }
        end
        charCache[entry.id] = entry
        table.insert(list, entry)
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function holdCharacter(charId)
    -- ลองหลาย signature ที่เป็นไปได้
    local attempts = {
        function() R.HoldCharacter:FireServer(charId) end,
        function() R.HoldCharacter:FireServer(charId, true) end,
        function() R.EquipCharacter:FireServer(charId) end,
    }
    for _, fn in ipairs(attempts) do
        local ok = pcall(fn)
        if ok then
            lastHeldId = charId
            return true
        end
    end
    return false
end

-- ========== UI ==========
local old = CoreGui:FindFirstChild("FishRngAutoHold")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "FishRngAutoHold"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = CoreGui

local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0, 320, 0, 460)
main.Position = UDim2.new(0, 20, 0.5, -230)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(70, 70, 95)
stroke.Thickness = 1

-- title
local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
title.BorderSizePixel = 0
title.Text = "  🐟  AutoHold  —  Fish RNG"
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(240, 240, 250)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 10)

local closeBtn = Instance.new("TextButton", title)
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -34, 0, 2)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(220, 90, 90)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 15

-- toggle auto-hold
local toggle = Instance.new("TextButton", main)
toggle.Size = UDim2.new(1, -20, 0, 32)
toggle.Position = UDim2.new(0, 10, 0, 46)
toggle.BackgroundColor3 = Color3.fromRGB(40, 120, 75)
toggle.Text = "AUTO-HOLD: ON"
toggle.TextColor3 = Color3.fromRGB(240, 240, 240)
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 13
toggle.BorderSizePixel = 0
Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 6)

-- toggle mutation-only
local mutToggle = Instance.new("TextButton", main)
mutToggle.Size = UDim2.new(1, -20, 0, 28)
mutToggle.Position = UDim2.new(0, 10, 0, 82)
mutToggle.BackgroundColor3 = Color3.fromRGB(90, 60, 120)
mutToggle.Text = "MUTATION EVENTS ONLY: ON"
mutToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
mutToggle.Font = Enum.Font.Gotham
mutToggle.TextSize = 12
mutToggle.BorderSizePixel = 0
Instance.new("UICorner", mutToggle).CornerRadius = UDim.new(0, 6)

-- row of small buttons
local refresh = Instance.new("TextButton", main)
refresh.Size = UDim2.new(0.33, -8, 0, 28)
refresh.Position = UDim2.new(0, 10, 0, 118)
refresh.BackgroundColor3 = Color3.fromRGB(45, 55, 95)
refresh.Text = "Refresh"
refresh.TextColor3 = Color3.fromRGB(230, 230, 240)
refresh.Font = Enum.Font.Gotham
refresh.TextSize = 11
refresh.BorderSizePixel = 0
Instance.new("UICorner", refresh).CornerRadius = UDim.new(0, 6)

local holdNow = Instance.new("TextButton", main)
holdNow.Size = UDim2.new(0.33, -8, 0, 28)
holdNow.Position = UDim2.new(0.33, 2, 0, 118)
holdNow.BackgroundColor3 = Color3.fromRGB(100, 70, 50)
holdNow.Text = "Hold Now"
holdNow.TextColor3 = Color3.fromRGB(230, 230, 240)
holdNow.Font = Enum.Font.Gotham
holdNow.TextSize = 11
holdNow.BorderSizePixel = 0
Instance.new("UICorner", holdNow).CornerRadius = UDim.new(0, 6)

local clearSel = Instance.new("TextButton", main)
clearSel.Size = UDim2.new(0.34, -4, 0, 28)
clearSel.Position = UDim2.new(0.66, 2, 0, 118)
clearSel.BackgroundColor3 = Color3.fromRGB(90, 45, 55)
clearSel.Text = "Clear"
clearSel.TextColor3 = Color3.fromRGB(230, 230, 240)
clearSel.Font = Enum.Font.Gotham
clearSel.TextSize = 11
clearSel.BorderSizePixel = 0
Instance.new("UICorner", clearSel).CornerRadius = UDim.new(0, 6)

-- search
local search = Instance.new("TextBox", main)
search.Size = UDim2.new(1, -20, 0, 28)
search.Position = UDim2.new(0, 10, 0, 154)
search.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
search.PlaceholderText = "  ค้นหาตัวละคร / rarity..."
search.Text = ""
search.TextColor3 = Color3.fromRGB(230, 230, 240)
search.PlaceholderColor3 = Color3.fromRGB(130, 130, 150)
search.Font = Enum.Font.Gotham
search.TextSize = 12
search.TextXAlignment = Enum.TextXAlignment.Left
search.BorderSizePixel = 0
search.ClearTextOnFocus = false
Instance.new("UICorner", search).CornerRadius = UDim.new(0, 6)

-- scroll list
local scroll = Instance.new("ScrollingFrame", main)
scroll.Size = UDim2.new(1, -20, 1, -228)
scroll.Position = UDim2.new(0, 10, 0, 190)
scroll.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 6)

local layout = Instance.new("UIListLayout", scroll)
layout.Padding = UDim.new(0, 2)
layout.SortOrder = Enum.SortOrder.LayoutOrder

local padding = Instance.new("UIPadding", scroll)
padding.PaddingTop    = UDim.new(0, 4)
padding.PaddingBottom = UDim.new(0, 4)
padding.PaddingLeft   = UDim.new(0, 4)
padding.PaddingRight  = UDim.new(0, 4)

-- status
local status = Instance.new("TextLabel", main)
status.Size = UDim2.new(1, -20, 0, 24)
status.Position = UDim2.new(0, 10, 1, -32)
status.BackgroundTransparency = 1
status.Text = "เริ่มต้น..."
status.TextColor3 = Color3.fromRGB(150, 150, 170)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left

-- ========== rarity colors ==========
local RARITY_COLOR = {
    Common       = Color3.fromRGB(170, 170, 170),
    Uncommon     = Color3.fromRGB(120, 200, 120),
    Rare         = Color3.fromRGB(100, 160, 230),
    Epic         = Color3.fromRGB(170, 100, 220),
    Legendary    = Color3.fromRGB(240, 180, 60),
    Mythical     = Color3.fromRGB(230, 90, 160),
    Divine       = Color3.fromRGB(240, 230, 100),
    God          = Color3.fromRGB(255, 100, 100),
    Secret       = Color3.fromRGB(80, 80, 80),
    Rainbow      = Color3.fromRGB(230, 150, 255),
    Omniscient   = Color3.fromRGB(255, 255, 255),
    Celestial    = Color3.fromRGB(180, 230, 255),
    Ascended     = Color3.fromRGB(255, 215, 100),
    Ancient      = Color3.fromRGB(150, 100, 60),
    Exclusive    = Color3.fromRGB(255, 100, 200),
    Transcendent = Color3.fromRGB(200, 100, 255),
    Apex         = Color3.fromRGB(255, 50, 50),
    Supreme      = Color3.fromRGB(255, 180, 230),
    Cosmic       = Color3.fromRGB(100, 100, 255),
}

local function setStatus(msg, color)
    status.Text = os.date("[%H:%M:%S] ") .. msg
    status.TextColor3 = color or Color3.fromRGB(150, 150, 170)
end

-- ========== list render ==========
local rowRefs = {}

local function render(filter)
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    rowRefs = {}
    filter = (filter or ""):lower()

    local list = refreshCharacters()
    local shown = 0

    for _, entry in ipairs(list) do
        local matchName   = entry.name:lower():find(filter, 1, true)
        local matchRarity = tostring(entry.rarity):lower():find(filter, 1, true)
        if filter == "" or matchName or matchRarity then
            shown = shown + 1
            local row = Instance.new("TextButton", scroll)
            row.Size = UDim2.new(1, -4, 0, 30)
            row.BackgroundColor3 = selected[entry.id]
                and Color3.fromRGB(55, 110, 70)
                or  Color3.fromRGB(28, 28, 38)
            row.AutoButtonColor = false
            row.Text = ""
            row.BorderSizePixel = 0
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

            local label = Instance.new("TextLabel", row)
            label.Size = UDim2.new(1, -70, 1, 0)
            label.Position = UDim2.new(0, 8, 0, 0)
            label.BackgroundTransparency = 1
            label.Text = entry.name .. (entry.count > 1 and ("  x" .. entry.count) or "")
            label.TextColor3 = Color3.fromRGB(235, 235, 245)
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Font = Enum.Font.Gotham
            label.TextSize = 12

            local rarityTag = Instance.new("TextLabel", row)
            rarityTag.Size = UDim2.new(0, 62, 1, -8)
            rarityTag.Position = UDim2.new(1, -66, 0, 4)
            rarityTag.BackgroundColor3 = RARITY_COLOR[entry.rarity] or Color3.fromRGB(60, 60, 80)
            rarityTag.BackgroundTransparency = 0.3
            rarityTag.Text = tostring(entry.rarity):sub(1, 7)
            rarityTag.TextColor3 = Color3.fromRGB(255, 255, 255)
            rarityTag.Font = Enum.Font.GothamBold
            rarityTag.TextSize = 9
            Instance.new("UICorner", rarityTag).CornerRadius = UDim.new(0, 3)

            rowRefs[entry.id] = row

            row.MouseButton1Click:Connect(function()
                selected[entry.id] = not selected[entry.id] or nil
                row.BackgroundColor3 = selected[entry.id]
                    and Color3.fromRGB(55, 110, 70)
                    or  Color3.fromRGB(28, 28, 38)
                local n = 0
                for _ in pairs(selected) do n = n + 1 end
                setStatus(("เลือกแล้ว %d ตัว"):format(n))
            end)
        end
    end

    setStatus(("โหลด %d / %d ตัว"):format(shown, #list))
end

-- ========== wiring ==========
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

toggle.MouseButton1Click:Connect(function()
    autoHold = not autoHold
    toggle.Text = autoHold and "AUTO-HOLD: ON" or "AUTO-HOLD: OFF"
    toggle.BackgroundColor3 = autoHold
        and Color3.fromRGB(40, 120, 75)
        or  Color3.fromRGB(120, 55, 55)
end)

mutToggle.MouseButton1Click:Connect(function()
    onlyMutation = not onlyMutation
    mutToggle.Text = "MUTATION EVENTS ONLY: " .. (onlyMutation and "ON" or "OFF")
    mutToggle.BackgroundColor3 = onlyMutation
        and Color3.fromRGB(90, 60, 120)
        or  Color3.fromRGB(60, 60, 75)
end)

refresh.MouseButton1Click:Connect(function()
    render(search.Text)
end)

clearSel.MouseButton1Click:Connect(function()
    selected = {}
    render(search.Text)
    setStatus("ล้างรายการที่เลือกแล้ว")
end)

search:GetPropertyChangedSignal("Text"):Connect(function()
    render(search.Text)
end)

-- ========== hold logic ==========
local function doHold(reason)
    local picks = {}
    for id in pairs(selected) do
        if charCache[id] then
            table.insert(picks, id)
        end
    end
    if #picks == 0 then
        setStatus("event มา — แต่ไม่ได้เลือกตัวละคร", Color3.fromRGB(230, 170, 90))
        return
    end
    table.sort(picks, function(a, b)
        return (charCache[a].name or "") < (charCache[b].name or "")
    end)
    if rotateIndex > #picks then rotateIndex = 1 end
    local pick = picks[rotateIndex]
    rotateIndex = rotateIndex + 1

    local entry = charCache[pick]
    local ok = holdCharacter(pick)
    if ok then
        setStatus(("ถือ: %s  (%s)"):format(entry.name, reason),
            Color3.fromRGB(130, 230, 150))
    else
        setStatus(("ถือ %s ไม่สำเร็จ"):format(entry.name),
            Color3.fromRGB(230, 100, 100))
    end
end

holdNow.MouseButton1Click:Connect(function()
    doHold("manual")
end)

-- ========== event hook ==========
local function evaluateEvent(eventName, isActive)
    if not autoHold then return end
    if not isActive then return end
    if onlyMutation and not MUTATION_EVENTS[eventName] then
        setStatus(("event: %s (ไม่ใช่ mutation — ข้าม)"):format(eventName),
            Color3.fromRGB(150, 150, 170))
        return
    end
    doHold(eventName)
end

R.TypeEventState.OnClientEvent:Connect(function(...)
    local args = {...}
    -- payload shape ของเกมอาจเป็น (eventName, state) หรือ table
    local eventName, isActive

    if type(args[1]) == "string" then
        eventName = args[1]
        isActive  = args[2]
        if isActive == nil then isActive = true end
    elseif type(args[1]) == "table" then
        local t = args[1]
        eventName = t.Event or t.Name or t.event or t.name
        isActive  = t.Active or t.State or t.active or true
    end

    if eventName then
        evaluateEvent(eventName, isActive ~= false)
    end
end)

-- query ปัจจุบันเผื่อ event กำลังทำงาน
task.spawn(function()
    local ok, state = pcall(function()
        return R.TypeEventStateGet:InvokeServer()
    end)
    if ok and type(state) == "table" then
        for name, active in pairs(state) do
            if active then
                setStatus(("event ที่กำลังทำงาน: %s"):format(name),
                    Color3.fromRGB(120, 200, 230))
                evaluateEvent(name, true)
                break
            end
        end
    end
end)

-- sync summary เมื่อ server push delta
R.CharSummaryDelta.OnClientEvent:Connect(function()
    task.wait(0.3)
    render(search.Text)
end)

-- initial render
render("")
setStatus("พร้อม — hooked TypeEventState", Color3.fromRGB(120, 200, 230))
