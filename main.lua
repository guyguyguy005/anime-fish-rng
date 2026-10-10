-- Fish an Anime RNG — AutoHold v3
-- Hub-style UI: sidebar tabs, collapsible sections, event picker, character picker
-- target: Potassium / mobile executor

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local CoreGui          = game:GetService("CoreGui")
local TweenService     = game:GetService("TweenService")
local LocalPlayer      = Players.LocalPlayer
local Remotes          = ReplicatedStorage:WaitForChild("Remotes")

-- ========== remotes ==========
local R = {
    CharSummaryGet    = Remotes:WaitForChild("BackpackCharSummaryGet"),
    CharSummaryDelta  = Remotes:WaitForChild("BackpackCharSummaryDelta"),
    HoldCharacter     = Remotes:WaitForChild("BackpackHoldCharacter"),
    EquipCharacter    = Remotes:WaitForChild("BackpackEquipCharacter"),
    UnequipCharacter  = Remotes:WaitForChild("BackpackUnequipCharacter"),
    TypeEventState    = Remotes:WaitForChild("TypeEventState"),
    TypeEventStateGet = Remotes:WaitForChild("GetTypeEventState"),
}

-- ========== config state ==========
local S = {
    autoHold         = true,
    autoRefresh      = true,
    selectedChars    = {},  -- [charId] = true
    selectedEvents   = {},  -- [eventName] = true
    rarityFilter     = {},  -- [rarity] = true (empty = all)
    searchText       = "",
    rotateMode       = "cycle", -- "cycle" / "first" / "random"
    holdDelay        = 0.5,
}

local charCache = {}    -- [id] = {name, rarity, count}
local rotateIndex = 1
local activeTab = "main"

-- ========== event catalog (จาก TypeEvents folder) ==========
local EVENT_CATALOG = {
    { name = "A=ForceMutations",      mut = true,  cat = "Mutation" },
    { name = "Supernova",             mut = true,  cat = "Mutation" },
    { name = "Hell's Gates",          mut = true,  cat = "Mutation" },
    { name = "Sad Ending",            mut = true,  cat = "Mutation" },
    { name = "Heaven",                mut = true,  cat = "Mutation" },
    { name = "Eclipse",               mut = true,  cat = "Mutation" },
    { name = "Starfall",              mut = true,  cat = "Mutation" },
    { name = "Lucrative Realization", mut = true,  cat = "Mutation" },
    { name = "Sakura Season",         mut = true,  cat = "Mutation" },
    { name = "S U B  Z E R O",        mut = true,  cat = "Mutation" },
    { name = "Complex Matrix",        mut = true,  cat = "Mutation" },
    { name = "Forgotten Ruins",       mut = true,  cat = "Mutation" },
    { name = "Limerence Complexity",  mut = true,  cat = "Mutation" },
    { name = "Toxic Wasteland",       mut = true,  cat = "Mutation" },
    { name = "Broken Thoughts",       mut = true,  cat = "Mutation" },
    { name = "Blizzard",              mut = true,  cat = "Weather"  },
    { name = "Thunder",               mut = true,  cat = "Weather"  },
    { name = "Solar",                 mut = true,  cat = "Weather"  },
    { name = "Lunar",                 mut = true,  cat = "Weather"  },
    { name = "Night",                 mut = false, cat = "Weather"  },
    { name = "SlimeRain",             mut = false, cat = "Special"  },
    { name = "Halloween",             mut = false, cat = "Special"  },
    { name = "Party",                 mut = false, cat = "Special"  },
    { name = "Cyberspace",            mut = false, cat = "Special"  },
    { name = "Dreamspace",            mut = false, cat = "Special"  },
}

-- ========== rarity palette ==========
local RARITY_COLOR = {
    Common       = Color3.fromRGB(170, 170, 170),
    Uncommon     = Color3.fromRGB(120, 200, 120),
    Rare         = Color3.fromRGB(100, 160, 230),
    Epic         = Color3.fromRGB(170, 100, 220),
    Legendary    = Color3.fromRGB(240, 180, 60),
    Mythical     = Color3.fromRGB(230, 90, 160),
    Divine       = Color3.fromRGB(240, 230, 100),
    God          = Color3.fromRGB(255, 100, 100),
    Secret       = Color3.fromRGB(70, 70, 80),
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

local RARITY_ORDER = {
    "Common","Uncommon","Rare","Epic","Legendary","Mythical","Divine","God",
    "Secret","Rainbow","Omniscient","Celestial","Ascended","Ancient",
    "Exclusive","Transcendent","Apex","Supreme","Cosmic",
}

-- ========== theme ==========
local T = {
    bg       = Color3.fromRGB(18, 18, 24),
    panel    = Color3.fromRGB(26, 26, 34),
    panel2   = Color3.fromRGB(32, 32, 42),
    panel3   = Color3.fromRGB(40, 40, 52),
    accent   = Color3.fromRGB(230, 130, 180),  -- pink
    accentHi = Color3.fromRGB(255, 160, 200),
    text     = Color3.fromRGB(230, 230, 240),
    textDim  = Color3.fromRGB(150, 150, 170),
    stroke   = Color3.fromRGB(55, 55, 72),
    good     = Color3.fromRGB(120, 220, 150),
    bad      = Color3.fromRGB(230, 100, 110),
    warn     = Color3.fromRGB(240, 180, 90),
}

-- ========== helpers ==========
local function newInst(class, props, parent)
    local i = Instance.new(class)
    for k, v in pairs(props or {}) do i[k] = v end
    if parent then i.Parent = parent end
    return i
end

local function corner(parent, radius)
    local c = Instance.new("UICorner", parent)
    c.CornerRadius = UDim.new(0, radius or 6)
    return c
end

local function stroke(parent, color, thick)
    local s = Instance.new("UIStroke", parent)
    s.Color = color or T.stroke
    s.Thickness = thick or 1
    return s
end

local function padding(parent, p)
    local u = Instance.new("UIPadding", parent)
    u.PaddingTop    = UDim.new(0, p)
    u.PaddingBottom = UDim.new(0, p)
    u.PaddingLeft   = UDim.new(0, p)
    u.PaddingRight  = UDim.new(0, p)
    return u
end

-- ========== destroy old ==========
local old = CoreGui:FindFirstChild("FishRngHub")
if old then old:Destroy() end

-- ========== root ==========
local gui = newInst("ScreenGui", {
    Name = "FishRngHub",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = CoreGui,
})

local root = newInst("Frame", {
    Size = UDim2.new(0, 720, 0, 480),
    Position = UDim2.new(0.5, -360, 0.5, -240),
    BackgroundColor3 = T.bg,
    BorderSizePixel = 0,
    Active = true,
    Draggable = true,
    Parent = gui,
})
corner(root, 10)
stroke(root, T.stroke, 1)

-- ========== header ==========
local header = newInst("Frame", {
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = T.panel,
    BorderSizePixel = 0,
    Parent = root,
})
corner(header, 10)

local headerCover = newInst("Frame", {
    Size = UDim2.new(1, 0, 0.5, 0),
    Position = UDim2.new(0, 0, 0.5, 0),
    BackgroundColor3 = T.panel,
    BorderSizePixel = 0,
    Parent = header,
})

local logo = newInst("TextLabel", {
    Size = UDim2.new(0, 44, 1, 0),
    BackgroundTransparency = 1,
    Text = "🐟",
    TextColor3 = T.accent,
    Font = Enum.Font.GothamBold,
    TextSize = 20,
    Parent = header,
})

local titleTxt = newInst("TextLabel", {
    Size = UDim2.new(0, 300, 1, 0),
    Position = UDim2.new(0, 44, 0, 0),
    BackgroundTransparency = 1,
    Text = "Main",
    TextColor3 = T.text,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    Parent = header,
})

-- search
local searchFrame = newInst("Frame", {
    Size = UDim2.new(0, 240, 0, 30),
    Position = UDim2.new(1, -340, 0.5, -15),
    BackgroundColor3 = T.panel2,
    BorderSizePixel = 0,
    Parent = header,
})
corner(searchFrame, 15)

newInst("TextLabel", {
    Size = UDim2.new(0, 24, 1, 0),
    Position = UDim2.new(0, 6, 0, 0),
    BackgroundTransparency = 1,
    Text = "🔍",
    TextColor3 = T.textDim,
    TextSize = 11,
    Parent = searchFrame,
})

local searchBox = newInst("TextBox", {
    Size = UDim2.new(1, -36, 1, 0),
    Position = UDim2.new(0, 32, 0, 0),
    BackgroundTransparency = 1,
    PlaceholderText = "Search...",
    Text = "",
    TextColor3 = T.text,
    PlaceholderColor3 = T.textDim,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    Parent = searchFrame,
})

-- window buttons
local minBtn = newInst("TextButton", {
    Size = UDim2.new(0, 32, 0, 32),
    Position = UDim2.new(1, -72, 0.5, -16),
    BackgroundTransparency = 1,
    Text = "–",
    TextColor3 = T.textDim,
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    Parent = header,
})

local closeBtn = newInst("TextButton", {
    Size = UDim2.new(0, 32, 0, 32),
    Position = UDim2.new(1, -36, 0.5, -16),
    BackgroundTransparency = 1,
    Text = "✕",
    TextColor3 = T.bad,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    Parent = header,
})

-- ========== sidebar ==========
local sidebar = newInst("Frame", {
    Size = UDim2.new(0, 56, 1, -44),
    Position = UDim2.new(0, 0, 0, 44),
    BackgroundColor3 = T.panel,
    BorderSizePixel = 0,
    Parent = root,
})

local sideLayout = newInst("UIListLayout", {
    Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    Parent = sidebar,
})
padding(sidebar, 8).PaddingTop = UDim.new(0, 12)

local TABS = {
    { id = "main",       icon = "🎣", label = "Main"       },
    { id = "characters", icon = "👥", label = "Characters" },
    { id = "events",     icon = "⚡", label = "Events"     },
    { id = "settings",   icon = "⚙",  label = "Settings"   },
}

local tabButtons = {}

local function selectTab(id)
    activeTab = id
    for _, tb in pairs(tabButtons) do
        if tb.id == id then
            tb.btn.BackgroundColor3 = T.accent
            tb.btn.TextColor3 = Color3.new(1, 1, 1)
        else
            tb.btn.BackgroundColor3 = T.panel2
            tb.btn.TextColor3 = T.textDim
        end
    end
    for name, page in pairs(_G.FishHubPages or {}) do
        page.Visible = (name == id)
    end
    for _, tab in ipairs(TABS) do
        if tab.id == id then
            titleTxt.Text = tab.label
            break
        end
    end
end

for i, tab in ipairs(TABS) do
    local btn = newInst("TextButton", {
        Size = UDim2.new(0, 40, 0, 40),
        BackgroundColor3 = T.panel2,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = tab.icon,
        TextColor3 = T.textDim,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        LayoutOrder = i,
        Parent = sidebar,
    })
    corner(btn, 8)
    table.insert(tabButtons, { id = tab.id, btn = btn })
    btn.MouseButton1Click:Connect(function() selectTab(tab.id) end)
end

-- ========== content area ==========
local content = newInst("Frame", {
    Size = UDim2.new(1, -56, 1, -44),
    Position = UDim2.new(0, 56, 0, 44),
    BackgroundTransparency = 1,
    Parent = root,
})
padding(content, 12)

_G.FishHubPages = {}

-- ========== shared widgets ==========
local function makeToggle(parent, text, initial, onChange)
    local row = newInst("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local lbl = newInst("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        Parent = row,
    })
    local track = newInst("TextButton", {
        Size = UDim2.new(0, 44, 0, 22),
        Position = UDim2.new(1, -48, 0.5, -11),
        BackgroundColor3 = initial and T.accent or T.panel3,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Parent = row,
    })
    corner(track, 11)
    local knob = newInst("Frame", {
        Size = UDim2.new(0, 18, 0, 18),
        Position = initial and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(knob, 9)

    local state = initial
    track.MouseButton1Click:Connect(function()
        state = not state
        track.BackgroundColor3 = state and T.accent or T.panel3
        TweenService:Create(knob, TweenInfo.new(0.15),
            { Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9) }
        ):Play()
        if onChange then onChange(state) end
    end)
    return row, function() return state end
end

local function makeSection(parent, title, order)
    local sec = newInst("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = T.panel,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = order or 0,
        Parent = parent,
    })
    corner(sec, 8)

    local head = newInst("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = sec,
    })

    newInst("TextLabel", {
        Size = UDim2.new(1, -40, 1, 0),
        Position = UDim2.new(0, 14, 0, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        Parent = head,
    })

    local chevron = newInst("TextLabel", {
        Size = UDim2.new(0, 24, 1, 0),
        Position = UDim2.new(1, -32, 0, 0),
        BackgroundTransparency = 1,
        Text = "▼",
        TextColor3 = T.textDim,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        Parent = head,
    })

    local body = newInst("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 0, 36),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = sec,
    })
    local bl = newInst("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = body,
    })
    local bp = Instance.new("UIPadding", body)
    bp.PaddingLeft   = UDim.new(0, 14)
    bp.PaddingRight  = UDim.new(0, 14)
    bp.PaddingBottom = UDim.new(0, 10)

    local open = true
    head.MouseButton1Click:Connect(function()
        open = not open
        body.Visible = open
        chevron.Text = open and "▼" or "▶"
    end)

    return body
end

-- ========================================================
-- ========== PAGE: MAIN (dashboard) ==========
-- ========================================================
local pageMain = newInst("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Visible = true,
    Parent = content,
})
_G.FishHubPages.main = pageMain

local mainScroll = newInst("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = T.accent,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Parent = pageMain,
})
local mainList = newInst("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = mainScroll,
})

-- status card
local statusCard = newInst("Frame", {
    Size = UDim2.new(1, -8, 0, 90),
    BackgroundColor3 = T.panel,
    BorderSizePixel = 0,
    LayoutOrder = 1,
    Parent = mainScroll,
})
corner(statusCard, 8)
padding(statusCard, 14)

local statusTitle = newInst("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18),
    BackgroundTransparency = 1,
    Text = "Status",
    TextColor3 = T.accent,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    Parent = statusCard,
})

local statusLine = newInst("TextLabel", {
    Size = UDim2.new(1, 0, 0, 20),
    Position = UDim2.new(0, 0, 0, 22),
    BackgroundTransparency = 1,
    Text = "พร้อม",
    TextColor3 = T.text,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    Parent = statusCard,
})

local statusSub = newInst("TextLabel", {
    Size = UDim2.new(1, 0, 0, 16),
    Position = UDim2.new(0, 0, 0, 46),
    BackgroundTransparency = 1,
    Text = "เลือกตัวละครและ event จากเมนูด้านซ้าย",
    TextColor3 = T.textDim,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    Parent = statusCard,
})

-- automation section (ซ้าย) + info section (ขวา) 2-col
local twoCol = newInst("Frame", {
    Size = UDim2.new(1, -8, 0, 0),
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
    LayoutOrder = 2,
    Parent = mainScroll,
})
local tcLayout = newInst("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = twoCol,
})

local colA = newInst("Frame", {
    Size = UDim2.new(0.5, -4, 0, 0),
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
    LayoutOrder = 1,
    Parent = twoCol,
})
local colAL = newInst("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = colA,
})

local colB = newInst("Frame", {
    Size = UDim2.new(0.5, -4, 0, 0),
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
    LayoutOrder = 2,
    Parent = twoCol,
})
local colBL = newInst("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = colB,
})

-- Automation section
local autoSec = makeSection(colA, "⚙  Automation", 1)
local _, getAutoHold = makeToggle(autoSec, "Auto Hold on Event", S.autoHold, function(v) S.autoHold = v end)
local _, getAutoRefresh = makeToggle(autoSec, "Auto Refresh Characters", S.autoRefresh, function(v) S.autoRefresh = v end)

-- Quick actions
local quickSec = makeSection(colA, "🎯  Quick Actions", 2)

local function makeActionBtn(parent, text, color, cb)
    local btn = newInst("TextButton", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        AutoButtonColor = false,
        Parent = parent,
    })
    corner(btn, 6)
    btn.MouseButton1Click:Connect(cb)
    return btn
end

makeActionBtn(quickSec, "▶  Hold Now (Test)", T.accent, function()
    _G.FishHub_doHold("manual")
end)
makeActionBtn(quickSec, "🔄  Refresh Characters", T.panel3, function()
    _G.FishHub_refreshChars()
end)
makeActionBtn(quickSec, "✖  Clear All Selected", T.bad, function()
    S.selectedChars = {}
    _G.FishHub_renderChars()
    _G.FishHub_setStatus("ล้างรายการตัวละครที่เลือกแล้ว")
end)

-- Info section (ขวา)
local infoSec = makeSection(colB, "📊  Info", 1)

local function makeInfoRow(parent, label, valueGetter)
    local row = newInst("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    newInst("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = T.textDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        Parent = row,
    })
    local val = newInst("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.new(0.5, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "-",
        TextColor3 = T.accent,
        TextXAlignment = Enum.TextXAlignment.Right,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        Parent = row,
    })
    return val
end

local infoChars  = makeInfoRow(infoSec, "Characters Owned", nil)
local infoSelC   = makeInfoRow(infoSec, "Selected to Hold", nil)
local infoSelE   = makeInfoRow(infoSec, "Watching Events", nil)
local infoHold   = makeInfoRow(infoSec, "Last Held", nil)

-- credits
local credSec = makeSection(colB, "ℹ  About", 2)
newInst("TextLabel", {
    Size = UDim2.new(1, 0, 0, 40),
    BackgroundTransparency = 1,
    Text = "AutoHold v3\nFish an Anime RNG\nmade for Sir",
    TextColor3 = T.textDim,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    Parent = credSec,
})

-- ========================================================
-- ========== PAGE: CHARACTERS ==========
-- ========================================================
local pageChars = newInst("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Visible = false,
    Parent = content,
})
_G.FishHubPages.characters = pageChars

-- top bar: search + rarity filter + select-all/none
local charTopBar = newInst("Frame", {
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = T.panel,
    BorderSizePixel = 0,
    Parent = pageChars,
})
corner(charTopBar, 6)

local charSearchBox = newInst("TextBox", {
    Size = UDim2.new(0, 220, 0, 26),
    Position = UDim2.new(0, 8, 0.5, -13),
    BackgroundColor3 = T.panel2,
    BorderSizePixel = 0,
    PlaceholderText = "  🔍  ค้นหาตัวละคร...",
    Text = "",
    TextColor3 = T.text,
    PlaceholderColor3 = T.textDim,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    Parent = charTopBar,
})
corner(charSearchBox, 4)

local selAllBtn = newInst("TextButton", {
    Size = UDim2.new(0, 90, 0, 26),
    Position = UDim2.new(1, -200, 0.5, -13),
    BackgroundColor3 = T.panel3,
    BorderSizePixel = 0,
    Text = "Select Shown",
    TextColor3 = T.text,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    AutoButtonColor = false,
    Parent = charTopBar,
})
corner(selAllBtn, 4)

local selNoneBtn = newInst("TextButton", {
    Size = UDim2.new(0, 90, 0, 26),
    Position = UDim2.new(1, -100, 0.5, -13),
    BackgroundColor3 = T.panel3,
    BorderSizePixel = 0,
    Text = "Clear All",
    TextColor3 = T.text,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    AutoButtonColor = false,
    Parent = charTopBar,
})
corner(selNoneBtn, 4)

-- rarity filter row (chips)
local rarityBar = newInst("ScrollingFrame", {
    Size = UDim2.new(1, 0, 0, 36),
    Position = UDim2.new(0, 0, 0, 42),
    BackgroundColor3 = T.panel,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollingDirection = Enum.ScrollingDirection.X,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.X,
    Parent = pageChars,
})
corner(rarityBar, 6)

local rarityLayout = newInst("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 4),
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Parent = rarityBar,
})
padding(rarityBar, 6)

local rarityChips = {}

local function makeRarityChip(rarity)
    local chip = newInst("TextButton", {
        Size = UDim2.new(0, 76, 0, 22),
        BackgroundColor3 = T.panel2,
        BorderSizePixel = 0,
        Text = rarity,
        TextColor3 = RARITY_COLOR[rarity] or T.text,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        AutoButtonColor = false,
        Parent = rarityBar,
    })
    corner(chip, 11)
    rarityChips[rarity] = chip
    chip.MouseButton1Click:Connect(function()
        S.rarityFilter[rarity] = not S.rarityFilter[rarity] or nil
        if S.rarityFilter[rarity] then
            chip.BackgroundColor3 = RARITY_COLOR[rarity] or T.accent
            chip.TextColor3 = Color3.new(1, 1, 1)
        else
            chip.BackgroundColor3 = T.panel2
            chip.TextColor3 = RARITY_COLOR[rarity] or T.text
        end
        _G.FishHub_renderChars()
    end)
end

makeRarityChip("ALL")
rarityChips["ALL"].MouseButton1Click:Connect(function()
    S.rarityFilter = {}
    for r, c in pairs(rarityChips) do
        c.BackgroundColor3 = T.panel2
        c.TextColor3 = r == "ALL" and T.text or (RARITY_COLOR[r] or T.text)
    end
    _G.FishHub_renderChars()
end)

for _, r in ipairs(RARITY_ORDER) do
    makeRarityChip(r)
end

-- character list
local charScroll = newInst("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -90),
    Position = UDim2.new(0, 0, 0, 84),
    BackgroundColor3 = T.panel,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = T.accent,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Parent = pageChars,
})
corner(charScroll, 6)

local charGrid = newInst("UIGridLayout", {
    CellSize = UDim2.new(0, 196, 0, 56),
    CellPadding = UDim2.new(0, 6, 0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = charScroll,
})
padding(charScroll, 8)

-- character count label
local charCountLbl = newInst("TextLabel", {
    Size = UDim2.new(1, -16, 0, 20),
    Position = UDim2.new(0, 8, 1, -22),
    BackgroundTransparency = 1,
    Text = "โหลด 0 / 0 ตัว",
    TextColor3 = T.textDim,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    Parent = pageChars,
})

-- ========================================================
-- ========== PAGE: EVENTS ==========
-- ========================================================
local pageEvents = newInst("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Visible = false,
    Parent = content,
})
_G.FishHubPages.events = pageEvents

local eventTopBar = newInst("Frame", {
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = T.panel,
    BorderSizePixel = 0,
    Parent = pageEvents,
})
corner(eventTopBar, 6)

newInst("TextLabel", {
    Size = UDim2.new(1, -220, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "เลือก Event ที่อยากให้ตัวละครถือออโต้",
    TextColor3 = T.text,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    Parent = eventTopBar,
})

local evSelMut = newInst("TextButton", {
    Size = UDim2.new(0, 120, 0, 26),
    Position = UDim2.new(1, -210, 0.5, -13),
    BackgroundColor3 = T.accent,
    BorderSizePixel = 0,
    Text = "Mutation Only",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    AutoButtonColor = false,
    Parent = eventTopBar,
})
corner(evSelMut, 4)

local evSelClear = newInst("TextButton", {
    Size = UDim2.new(0, 80, 0, 26),
    Position = UDim2.new(1, -88, 0.5, -13),
    BackgroundColor3 = T.panel3,
    BorderSizePixel = 0,
    Text = "Clear",
    TextColor3 = T.text,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    AutoButtonColor = false,
    Parent = eventTopBar,
})
corner(evSelClear, 4)

local eventScroll = newInst("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -44),
    Position = UDim2.new(0, 0, 0, 44),
    BackgroundColor3 = T.panel,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = T.accent,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Parent = pageEvents,
})
corner(eventScroll, 6)

local eventGrid = newInst("UIGridLayout", {
    CellSize = UDim2.new(0, 196, 0, 52),
    CellPadding = UDim2.new(0, 6, 0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = eventScroll,
})
padding(eventScroll, 8)

local eventRows = {}

local function renderEvents()
    for _, c in ipairs(eventScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    eventRows = {}

    -- sort: mutation first, then category, then name
    local sorted = {}
    for _, e in ipairs(EVENT_CATALOG) do table.insert(sorted, e) end
    table.sort(sorted, function(a, b)
        if a.mut ~= b.mut then return a.mut end
        if a.cat ~= b.cat then return a.cat < b.cat end
        return a.name < b.name
    end)

    for i, ev in ipairs(sorted) do
        local isSelected = S.selectedEvents[ev.name]
        local card = newInst("TextButton", {
            BackgroundColor3 = isSelected and T.accent or T.panel2,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = i,
            Parent = eventScroll,
        })
        corner(card, 6)

        local nameLbl = newInst("TextLabel", {
            Size = UDim2.new(1, -16, 0, 20),
            Position = UDim2.new(0, 8, 0, 6),
            BackgroundTransparency = 1,
            Text = ev.name,
            TextColor3 = isSelected and Color3.new(1,1,1) or T.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            Parent = card,
        })

        local tagColor = ev.mut and T.accent or T.textDim
        local tag = newInst("TextLabel", {
            Size = UDim2.new(0, 60, 0, 14),
            Position = UDim2.new(0, 8, 0, 30),
            BackgroundColor3 = ev.mut and Color3.fromRGB(200, 100, 150) or Color3.fromRGB(70, 70, 85),
            BackgroundTransparency = isSelected and 0.3 or 0,
            BorderSizePixel = 0,
            Text = ev.mut and "MUTATION" or ev.cat,
            TextColor3 = Color3.new(1, 1, 1),
            Font = Enum.Font.GothamBold,
            TextSize = 8,
            Parent = card,
        })
        corner(tag, 3)

        local check = newInst("TextLabel", {
            Size = UDim2.new(0, 22, 0, 22),
            Position = UDim2.new(1, -28, 0.5, -11),
            BackgroundTransparency = 1,
            Text = isSelected and "✓" or "○",
            TextColor3 = isSelected and Color3.new(1, 1, 1) or T.textDim,
            Font = Enum.Font.GothamBold,
            TextSize = 16,
            Parent = card,
        })

        eventRows[ev.name] = { card = card, name = nameLbl, check = check, tag = tag, ev = ev }

        card.MouseButton1Click:Connect(function()
            S.selectedEvents[ev.name] = not S.selectedEvents[ev.name] or nil
            local sel = S.selectedEvents[ev.name]
            card.BackgroundColor3 = sel and T.accent or T.panel2
            nameLbl.TextColor3 = sel and Color3.new(1, 1, 1) or T.text
            check.Text = sel and "✓" or "○"
            check.TextColor3 = sel and Color3.new(1, 1, 1) or T.textDim
            tag.BackgroundTransparency = sel and 0.3 or 0
            _G.FishHub_updateInfo()
        end)
    end
end

evSelMut.MouseButton1Click:Connect(function()
    S.selectedEvents = {}
    for _, ev in ipairs(EVENT_CATALOG) do
        if ev.mut then S.selectedEvents[ev.name] = true end
    end
    renderEvents()
    _G.FishHub_updateInfo()
end)

evSelClear.MouseButton1Click:Connect(function()
    S.selectedEvents = {}
    renderEvents()
    _G.FishHub_updateInfo()
end)

-- ========================================================
-- ========== PAGE: SETTINGS ==========
-- ========================================================
local pageSettings = newInst("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Visible = false,
    Parent = content,
})
_G.FishHubPages.settings = pageSettings

local setScroll = newInst("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = T.accent,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Parent = pageSettings,
})
newInst("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = setScroll,
})

local behaviorSec = makeSection(setScroll, "🎛  Behavior", 1)

-- rotate mode selector
local rotRow = newInst("Frame", {
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundTransparency = 1,
    Parent = behaviorSec,
})
newInst("TextLabel", {
    Size = UDim2.new(0.5, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "Rotation Mode",
    TextColor3 = T.text,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    Parent = rotRow,
})

local rotModes = { "cycle", "first", "random" }
for i, mode in ipairs(rotModes) do
    local btn = newInst("TextButton", {
        Size = UDim2.new(0, 56, 0, 22),
        Position = UDim2.new(1, -186 + (i-1)*60, 0.5, -11),
        BackgroundColor3 = (S.rotateMode == mode) and T.accent or T.panel3,
        BorderSizePixel = 0,
        Text = mode,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        AutoButtonColor = false,
        Parent = rotRow,
    })
    corner(btn, 4)
    btn.MouseButton1Click:Connect(function()
        S.rotateMode = mode
        for _, c in ipairs(rotRow:GetChildren()) do
            if c:IsA("TextButton") then
                c.BackgroundColor3 = (c.Text == S.rotateMode) and T.accent or T.panel3
            end
        end
    end)
end

makeToggle(behaviorSec, "Auto Hold on Event", S.autoHold, function(v) S.autoHold = v end)
makeToggle(behaviorSec, "Auto Refresh Characters", S.autoRefresh, function(v) S.autoRefresh = v end)

local uiSec = makeSection(setScroll, "🎨  UI", 2)
local resetBtn = newInst("TextButton", {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundColor3 = T.panel3,
    BorderSizePixel = 0,
    Text = "Reset Window Position",
    TextColor3 = T.text,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    AutoButtonColor = false,
    Parent = uiSec,
})
corner(resetBtn, 4)
resetBtn.MouseButton1Click:Connect(function()
    root.Position = UDim2.new(0.5, -360, 0.5, -240)
end)

local destroyBtn = newInst("TextButton", {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundColor3 = T.bad,
    BorderSizePixel = 0,
    Text = "Destroy UI (unload)",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    AutoButtonColor = false,
    Parent = uiSec,
})
corner(destroyBtn, 4)
destroyBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- ========================================================
-- ========== LOGIC ==========
-- ========================================================
function _G.FishHub_setStatus(msg, kind)
    statusLine.Text = msg
    local c = T.text
    if kind == "good" then c = T.good
    elseif kind == "bad" then c = T.bad
    elseif kind == "warn" then c = T.warn
    elseif kind == "info" then c = T.accent end
    statusLine.TextColor3 = c
    statusSub.Text = os.date("[%H:%M:%S]")
end

function _G.FishHub_updateInfo()
    local nChars = 0
    for _ in pairs(charCache) do nChars = nChars + 1 end
    local nSelC = 0
    for _ in pairs(S.selectedChars) do nSelC = nSelC + 1 end
    local nSelE = 0
    for _ in pairs(S.selectedEvents) do nSelE = nSelE + 1 end

    infoChars.Text = tostring(nChars)
    infoSelC.Text  = tostring(nSelC)
    infoSelE.Text  = tostring(nSelE)
end

function _G.FishHub_refreshChars()
    local ok, summary = pcall(function()
        return R.CharSummaryGet:InvokeServer()
    end)
    if not ok or type(summary) ~= "table" then
        _G.FishHub_setStatus("โหลดตัวละครไม่สำเร็จ", "bad")
        return
    end
    charCache = {}
    for k, v in pairs(summary) do
        local entry
        if type(v) == "table" then
            entry = {
                id      = v.Id or v.id or k,
                name    = v.Name or v.name or tostring(k),
                rarity  = v.Rarity or v.rarity or "Common",
                count   = v.Count or v.count or 1,
            }
        else
            entry = { id = k, name = tostring(k), rarity = "Common", count = v or 1 }
        end
        charCache[entry.id] = entry
    end
    _G.FishHub_renderChars()
    _G.FishHub_updateInfo()
end

function _G.FishHub_renderChars()
    for _, c in ipairs(charScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end

    local filter = (S.searchText or ""):lower()
    local activeFilters = next(S.rarityFilter) ~= nil

    local list = {}
    for id, e in pairs(charCache) do table.insert(list, e) end
    table.sort(list, function(a, b)
        if a.rarity ~= b.rarity then return (a.rarity or "") < (b.rarity or "") end
        return (a.name or "") < (b.name or "")
    end)

    local shown = 0
    for i, entry in ipairs(list) do
        local matchFilter = (not activeFilters) or S.rarityFilter[entry.rarity]
        local matchSearch = filter == ""
            or (entry.name or ""):lower():find(filter, 1, true)
            or (entry.rarity or ""):lower():find(filter, 1, true)

        if matchFilter and matchSearch then
            shown = shown + 1
            local isSel = S.selectedChars[entry.id]
            local card = newInst("TextButton", {
                BackgroundColor3 = isSel and T.accent or T.panel2,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = i,
                Parent = charScroll,
            })
            corner(card, 6)

            local rColor = RARITY_COLOR[entry.rarity] or T.textDim
            local bar = newInst("Frame", {
                Size = UDim2.new(0, 4, 1, 0),
                BackgroundColor3 = rColor,
                BorderSizePixel = 0,
                Parent = card,
            })

            local name = newInst("TextLabel", {
                Size = UDim2.new(1, -40, 0, 20),
                Position = UDim2.new(0, 12, 0, 6),
                BackgroundTransparency = 1,
                Text = entry.name,
                TextColor3 = isSel and Color3.new(1,1,1) or T.text,
                TextXAlignment = Enum.TextXAlignment.Left,
                Font = Enum.Font.GothamBold,
                TextSize = 11,
                Parent = card,
            })

            local meta = newInst("TextLabel", {
                Size = UDim2.new(1, -40, 0, 14),
                Position = UDim2.new(0, 12, 0, 28),
                BackgroundTransparency = 1,
                Text = string.format("%s  •  x%d", entry.rarity or "?", entry.count or 1),
                TextColor3 = isSel and Color3.fromRGB(240,220,230) or rColor,
                TextXAlignment = Enum.TextXAlignment.Left,
                Font = Enum.Font.Gotham,
                TextSize = 10,
                Parent = card,
            })

            local check = newInst("TextLabel", {
                Size = UDim2.new(0, 22, 0, 22),
                Position = UDim2.new(1, -26, 0.5, -11),
                BackgroundTransparency = 1,
                Text = isSel and "✓" or "○",
                TextColor3 = isSel and Color3.new(1, 1, 1) or T.textDim,
                Font = Enum.Font.GothamBold,
                TextSize = 15,
                Parent = card,
            })

            card.MouseButton1Click:Connect(function()
                S.selectedChars[entry.id] = not S.selectedChars[entry.id] or nil
                local sel = S.selectedChars[entry.id]
                card.BackgroundColor3 = sel and T.accent or T.panel2
                name.TextColor3 = sel and Color3.new(1,1,1) or T.text
                check.Text = sel and "✓" or "○"
                check.TextColor3 = sel and Color3.new(1,1,1) or T.textDim
                meta.TextColor3 = sel and Color3.fromRGB(240,220,230) or rColor
                _G.FishHub_updateInfo()
            end)
        end
    end

    local total = 0
    for _ in pairs(charCache) do total = total + 1 end
    charCountLbl.Text = string.format("โหลด %d / %d ตัว", shown, total)
end

function _G.FishHub_doHold(reason)
    local picks = {}
    for id in pairs(S.selectedChars) do
        if charCache[id] then table.insert(picks, id) end
    end
    if #picks == 0 then
        _G.FishHub_setStatus("event: " .. reason .. " — แต่ไม่ได้เลือกตัวละคร", "warn")
        return
    end
    table.sort(picks, function(a, b)
        return (charCache[a].name or "") < (charCache[b].name or "")
    end)

    local pick
    if S.rotateMode == "first" then
        pick = picks[1]
    elseif S.rotateMode == "random" then
        pick = picks[math.random(1, #picks)]
    else -- cycle
        if rotateIndex > #picks then rotateIndex = 1 end
        pick = picks[rotateIndex]
        rotateIndex = rotateIndex + 1
    end

    local entry = charCache[pick]
    local attempts = {
        function() R.HoldCharacter:FireServer(pick) end,
        function() R.HoldCharacter:FireServer(pick, true) end,
        function() R.EquipCharacter:FireServer(pick) end,
    }
    local success = false
    for _, fn in ipairs(attempts) do
        if pcall(fn) then success = true; break end
    end

    if success then
        _G.FishHub_setStatus(string.format("ถือ: %s  (%s)", entry.name, reason), "good")
        infoHold.Text = entry.name
    else
        _G.FishHub_setStatus(string.format("ถือ %s ไม่สำเร็จ", entry.name), "bad")
    end
end

-- ========== event hook ==========
local function onEvent(eventName, isActive)
    if not S.autoHold then return end
    if not isActive then return end
    if not S.selectedEvents[eventName] then
        _G.FishHub_setStatus(string.format("event: %s (ไม่ได้เลือก — ข้าม)", eventName), nil)
        return
    end
    task.wait(S.holdDelay)
    _G.FishHub_doHold(eventName)
end

R.TypeEventState.OnClientEvent:Connect(function(...)
    local args = {...}
    local eventName, isActive

    if type(args[1]) == "string" then
        eventName = args[1]
        isActive  = args[2]
        if isActive == nil then isActive = true end
    elseif type(args[1]) == "table" then
        local t = args[1]
        eventName = t.Event or t.Name or t.event or t.name
        isActive  = t.Active or t.State or t.active
        if isActive == nil then isActive = true end
    end

    if eventName then onEvent(eventName, isActive ~= false) end
end)

-- query current state
task.spawn(function()
    local ok, state = pcall(function()
        return R.TypeEventStateGet:InvokeServer()
    end)
    if ok and type(state) == "table" then
        for name, active in pairs(state) do
            if active then
                _G.FishHub_setStatus("event ทำงานอยู่: " .. tostring(name), "info")
                onEvent(name, true)
                break
            end
        end
    end
end)

-- auto refresh on delta
R.CharSummaryDelta.OnClientEvent:Connect(function()
    if S.autoRefresh then
        task.wait(0.3)
        _G.FishHub_refreshChars()
    end
end)

-- ========== wiring ==========
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        root.Size = UDim2.new(0, 720, 0, 44)
    else
        root.Size = UDim2.new(0, 720, 0, 480)
    end
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    S.searchText = searchBox.Text
    if activeTab == "characters" then
        _G.FishHub_renderChars()
    end
end)

charSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    S.searchText = charSearchBox.Text
    _G.FishHub_renderChars()
end)

selAllBtn.MouseButton1Click:Connect(function()
    for _, child in ipairs(charScroll:GetChildren()) do
        if child:IsA("TextButton") then
            -- find id matching this card... easier: select all shown
            for id, entry in pairs(charCache) do
                local filter = (S.searchText or ""):lower()
                local af = next(S.rarityFilter) ~= nil
                local mf = (not af) or S.rarityFilter[entry.rarity]
                local ms = filter == ""
                    or entry.name:lower():find(filter, 1, true)
                    or (entry.rarity or ""):lower():find(filter, 1, true)
                if mf and ms then
                    S.selectedChars[id] = true
                end
            end
            break
        end
    end
    _G.FishHub_renderChars()
    _G.FishHub_updateInfo()
end)

selNoneBtn.MouseButton1Click:Connect(function()
    S.selectedChars = {}
    _G.FishHub_renderChars()
    _G.FishHub_updateInfo()
end)

-- ========== init ==========
selectTab("main")
renderEvents()
_G.FishHub_refreshChars()
_G.FishHub_updateInfo()
_G.FishHub_setStatus("พร้อม — hooked TypeEventState", "info")
