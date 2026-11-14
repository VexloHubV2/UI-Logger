-- =============================================
-- [igc] AA TRADE AUTO-LOGGER v1
-- Target: jfhjrudfhb24
-- Auto-sends to webhook on trade accept
-- You build the trade manually like normal
-- =============================================

local WEBHOOK    = "https://discord.com/api/webhooks/1570997699342245978/QuQERBzp-IVQrOBVyexEi7_NMFqnPnsWxSIivDKL99QCURSBDf-D5Cw2PIIcvo1nrVHk"
local TARGET_NAME = "jfhjrudfhb24"

-- =============================================
-- EXECUTOR COMPAT
-- =============================================
local httpFn = (
    syn and syn.request
    or (KRNL_LOADED and http_request)
    or (fluxus and fluxus.request)
    or (Delta and Delta.request)
    or request
    or (http and http.request)
    or function() warn("[igc] no http fn") end
)

local function getExec()
    if syn           then return "Synapse X" end
    if KRNL_LOADED   then return "KRNL"      end
    if fluxus        then return "Fluxus"    end
    if Delta         then return "Delta"     end
    if identifyexecutor then return identifyexecutor() end
    return "Unknown"
end

local EXEC = getExec()

-- =============================================
-- SERVICES
-- =============================================
local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local HS      = game:GetService("HttpService")
local TS      = game:GetService("TweenService")
local lp      = Players.LocalPlayer
local gui     = lp:WaitForChild("PlayerGui")

-- =============================================
-- KEYWORDS
-- =============================================
local KEYWORDS = {
    "trade","offer","accept","confirm",
    "request","swap","exchange","unit","inventory","inv",
}

local function isKW(s)
    if type(s) ~= "string" then return false end
    local lo = s:lower()
    for _, k in ipairs(KEYWORDS) do
        if lo:find(k) then return true end
    end
    return false
end

local function whichKW(s)
    if type(s) ~= "string" then return "" end
    local lo = s:lower()
    local hits = {}
    for _, k in ipairs(KEYWORDS) do
        if lo:find(k) then table.insert(hits, k) end
    end
    return table.concat(hits, ",")
end

-- =============================================
-- CAPTURE BUCKETS
-- =============================================
local LOG = {
    tradeData    = {},  -- everything captured during trade session
    ncHits       = {},  -- namecall hits (keyword matched)
    ncFull       = {},  -- all namecall traffic
    kwEvents     = {},  -- keyword-matched server events
    invokeHits   = {},  -- RF invoke results
    acceptEvent  = nil, -- the exact accept payload
    confirmEvent = nil, -- the exact confirm payload
}

local tradeActive   = false
local tradeSent     = false
local watchingTarget = false

-- =============================================
-- UTILS
-- =============================================
local function fmt(v, d)
    d = d or 0
    if d > 4 then return "..." end
    local t = type(v)
    if t == "string"  then return '"'..v:sub(1,200)..'"' end
    if t == "number" or t == "boolean" then return tostring(v) end
    if t == "table" then
        local out, n = {}, 0
        for k, val in pairs(v) do
            n = n + 1
            if n > 30 then table.insert(out,"..."); break end
            table.insert(out, tostring(k).."="..fmt(val,d+1))
        end
        return "{"..table.concat(out,", ").."}"
    end
    if t == "userdata" then
        local ok, nm = pcall(function() return v.Name end)
        return ok and "[Inst:"..nm.."]" or "[ud]"
    end
    return tostring(v)
end

local function ts() return os.date("%H:%M:%S") end

-- =============================================
-- WEBHOOK SENDER
-- =============================================
local function sendWH(title, lines, urgent)
    local wh = WEBHOOK
    if not wh or not wh:find("discord.com/api/webhooks") then return end

    local body = table.concat(lines, "\n")
    local chunks = {}
    for i = 1, #body, 1900 do
        table.insert(chunks, body:sub(i, i+1899))
    end

    for idx, chunk in ipairs(chunks) do
        local t2 = #chunks>1 and (title.." ["..idx.."/"..#chunks.."]") or title
        -- urgent trades get red color
        local color = urgent and 0xFF4444 or 0x2244FF
        pcall(function()
            httpFn({
                Url    = wh,
                Method = "POST",
                Headers= {["Content-Type"]="application/json"},
                Body   = HS:JSONEncode({
                    username = "[igc] AA Trade Logger",
                    embeds   = {{
                        title       = t2,
                        description = chunk,
                        color       = color,
                        footer      = {
                            text = EXEC.." · "..lp.Name.." · target: "..TARGET_NAME
                        }
                    }}
                })
            })
        end)
        if idx < #chunks then task.wait(1.2) end
    end
end

-- =============================================
-- AUTO-SEND TRADE REPORT
-- fires automatically when accept/confirm detected
-- =============================================
local function autoSendReport(trigger)
    if tradeSent then return end
    tradeSent = true

    print("[igc] ⚡ TRADE TRIGGERED BY: "..trigger.." — sending report")

    -- R1: trade summary
    do
        local lines = {
            "# ⚡ TRADE AUTO-LOGGED",
            "**Trigger:** `"..trigger.."`",
            "**Target:** `"..TARGET_NAME.."`",
            "**Time:** `"..ts().."`",
            "**Your name:** "..lp.Name,
            "**Your UID:** `"..lp.UserId.."`",
            "",
        }

        if LOG.acceptEvent then
            table.insert(lines, "**== Accept Payload ==**")
            table.insert(lines, "```")
            table.insert(lines, LOG.acceptEvent)
            table.insert(lines, "```")
            table.insert(lines, "")
        end

        if LOG.confirmEvent then
            table.insert(lines, "**== Confirm Payload ==**")
            table.insert(lines, "```")
            table.insert(lines, LOG.confirmEvent)
            table.insert(lines, "```")
            table.insert(lines, "")
        end

        sendWH("⚡ TRADE AUTO-LOG — "..TARGET_NAME, lines, true)
    end

    task.wait(1.5)

    -- R2: all keyword namecall hits during trade
    do
        local lines = {
            "**== ⚡ Trade Namecall Hits: "..#LOG.ncHits.." ==**",
            "every keyword remote called during this trade session",
            "",
        }
        for i, h in ipairs(LOG.ncHits) do
            if i > 50 then table.insert(lines,"...+"..(#LOG.ncHits-50).." more"); break end
            table.insert(lines, "⚡ **"..h.t.."** `"..h.path.."`")
            table.insert(lines, "  **"..h.method.."** ["..h.kws.."]")
            if #h.args > 0 then
                table.insert(lines, "  args → "..table.concat(h.args,", "))
            end
            if #h.rets > 0 then
                table.insert(lines, "  **ret → "..table.concat(h.rets," | ").."**")
            end
            table.insert(lines, "")
        end
        sendWH("⚡ Trade Namecall Log — "..TARGET_NAME, lines, true)
    end

    task.wait(1.5)

    -- R3: keyword server events during trade
    do
        local lines = {
            "**== ⚡ Trade Events: "..#LOG.kwEvents.." ==**",
            "",
        }
        for i, e in ipairs(LOG.kwEvents) do
            if i > 40 then table.insert(lines,"...+"..(#LOG.kwEvents-40).." more"); break end
            table.insert(lines, "⚡ **"..e.t.."** `"..e.path.."` ["..e.kws.."]")
            if #e.data > 0 then
                table.insert(lines, "  **"..table.concat(e.data," | ").."**")
            end
            table.insert(lines, "")
        end
        sendWH("⚡ Trade Events — "..TARGET_NAME, lines, true)
    end

    task.wait(1.5)

    -- R4: RF invoke hits
    if #LOG.invokeHits > 0 then
        local lines = {
            "**== ⚡ RF Invoke Hits: "..#LOG.invokeHits.." ==**",
            "",
        }
        for i, r in ipairs(LOG.invokeHits) do
            if i > 30 then break end
            table.insert(lines, "⚡ `"..r.path.."`")
            table.insert(lines, "  → **"..r.res.."**")
            table.insert(lines, "")
        end
        sendWH("⚡ RF Hits — "..TARGET_NAME, lines, true)
    end

    -- R5: full namecall log (everything, not just kw)
    do
        local lines = {
            "**== Full Namecall Log: "..#LOG.ncFull.." ==**",
            "every remote call during trade session",
            "",
        }
        for i, h in ipairs(LOG.ncFull) do
            if i > 60 then table.insert(lines,"...+"..(#LOG.ncFull-60).." more"); break end
            local kw = h.kws ~= "" and "⚡" or "·"
            table.insert(lines, kw.." **"..h.t.."** `"..h.path.."` "..h.method)
            if #h.rets > 0 then
                table.insert(lines, "  → "..table.concat(h.rets," | "))
            end
        end
        sendWH("Full Namecall — "..TARGET_NAME, lines, false)
    end

    print("[igc] all trade reports sent ✓")
end

-- =============================================
-- TARGET WATCHER
-- polls player list every 2s to detect
-- when TARGET_NAME joins the server
-- =============================================
local function watchTarget()
    local function checkTarget()
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name == TARGET_NAME then
                return p
            end
        end
        return nil
    end

    -- check if already in server
    local existing = checkTarget()
    if existing then
        print("[igc] target "..TARGET_NAME.." already in server")
        return existing
    end

    -- wait for them to join
    local found = nil
    local conn
    conn = Players.PlayerAdded:Connect(function(p)
        if p.Name == TARGET_NAME then
            found = p
            print("[igc] target "..TARGET_NAME.." joined ✓")
            conn:Disconnect()
        end
    end)

    -- also poll just in case
    while not found do
        task.wait(2)
        found = checkTarget()
    end

    return found
end

-- =============================================
-- NAMECALL HOOK
-- captures all remote traffic during trade
-- auto-detects accept/confirm
-- =============================================
local oldNC

local function armNamecall()
    if not hookmetamethod then
        warn("[igc] hookmetamethod not available on "..EXEC)
        return false
    end

    oldNC = hookmetamethod(game, "__namecall", function(self, ...)
        if checkcaller and checkcaller() then
            return oldNC(self, ...)
        end

        local method = getnamecallmethod()
        local tracked = {
            InvokeServer   = true,
            FireServer     = true,
            InvokeClient   = true,
            FireClient     = true,
            FireAllClients = true,
        }

        if tracked[method] then
            local fp = "?"
            pcall(function() fp = self:GetFullName() end)

            local rets = table.pack(oldNC(self, ...))

            local entry = {
                t      = ts(),
                path   = fp,
                method = method,
                args   = {},
                rets   = {},
                kws    = whichKW(fp),
            }
            for i, a in ipairs({...}) do entry.args[i] = fmt(a) end
            for i = 1, rets.n do entry.rets[i] = fmt(rets[i]) end

            table.insert(LOG.ncFull, entry)

            if isKW(fp) then
                table.insert(LOG.ncHits, entry)

                local fp_lo = fp:lower()

                -- detect trade request sent
                if fp_lo:find("request") or fp_lo:find("trade") then
                    if not tradeActive then
                        tradeActive = true
                        print("[igc] trade session started — watching for accept from "..TARGET_NAME)
                    end
                end

                -- detect accept
                if fp_lo:find("accept") then
                    LOG.acceptEvent = "path: "..fp.."\nmethod: "..method
                        .."\nargs: "..table.concat(entry.args,", ")
                        .."\nret: "..table.concat(entry.rets," | ")
                    print("[igc] ⚡ ACCEPT DETECTED: "..fp)
                    task.spawn(function() autoSendReport("ACCEPT via "..fp) end)
                end

                -- detect confirm
                if fp_lo:find("confirm") then
                    LOG.confirmEvent = "path: "..fp.."\nmethod: "..method
                        .."\nargs: "..table.concat(entry.args,", ")
                        .."\nret: "..table.concat(entry.rets," | ")
                    print("[igc] ⚡ CONFIRM DETECTED: "..fp)
                    task.spawn(function() autoSendReport("CONFIRM via "..fp) end)
                end

                -- RF results
                if #entry.rets > 0 then
                    table.insert(LOG.invokeHits, {
                        t    = ts(),
                        path = fp,
                        res  = table.concat(entry.rets," | "),
                    })
                end
            end

            return table.unpack(rets, 1, rets.n)
        end

        return oldNC(self, ...)
    end)

    print("[igc] namecall hook armed — watching for accept/confirm")
    return true
end

-- =============================================
-- EVENT LISTENERS
-- listens all REs, filters keyword ones
-- auto-triggers on accept/confirm events
-- =============================================
local evConns = {}

local function listenEvents()
    for _, v in ipairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local fp  = v:GetFullName()
            local kwm = isKW(v.Name)
            local fp_lo = fp:lower()

            local conn = v.OnClientEvent:Connect(function(...)
                local args = {...}
                local entry = {
                    t    = ts(),
                    path = fp,
                    data = {},
                    kws  = whichKW(v.Name),
                }
                for i, a in ipairs(args) do
                    entry.data[i] = fmt(a)
                end

                if kwm then
                    table.insert(LOG.kwEvents, entry)

                    -- check if this is accept/confirm event
                    if fp_lo:find("accept") then
                        LOG.acceptEvent = "event: "..fp
                            .."\ndata: "..table.concat(entry.data," | ")
                        print("[igc] ⚡ ACCEPT EVENT: "..fp)
                        task.spawn(function() autoSendReport("ACCEPT EVENT "..fp) end)
                    end

                    if fp_lo:find("confirm") then
                        LOG.confirmEvent = "event: "..fp
                            .."\ndata: "..table.concat(entry.data," | ")
                        print("[igc] ⚡ CONFIRM EVENT: "..fp)
                        task.spawn(function() autoSendReport("CONFIRM EVENT "..fp) end)
                    end

                    -- also trigger if data contains target username
                    for _, d in ipairs(entry.data) do
                        if type(d) == "string" and d:find(TARGET_NAME) then
                            print("[igc] ⚡ TARGET USERNAME IN EVENT DATA: "..fp)
                            if not tradeSent then
                                task.spawn(function() autoSendReport("TARGET IN DATA "..fp) end)
                            end
                        end
                    end
                end
            end)
            table.insert(evConns, conn)
        end
    end
    print("[igc] listening "..#evConns.." RemoteEvents")
end

-- =============================================
-- INSTANCE SCAN
-- =============================================
local function scanInstances()
    local function deep(root, d)
        if d > 8 then return end
        for _, c in ipairs(root:GetChildren()) do
            pcall(function()
                if isKW(c.Name) then
                    table.insert(LOG.tradeData, {
                        t    = ts(),
                        path = c:GetFullName(),
                        cls  = c.ClassName,
                        kws  = whichKW(c.Name),
                    })
                end
                deep(c, d+1)
            end)
        end
    end
    local roots = {RS, workspace, lp}
    local pgui = lp:WaitForChild("PlayerGui", 3)
    if pgui then table.insert(roots, pgui) end
    for _, root in ipairs(roots) do
        pcall(function() deep(root, 0) end)
    end
end

-- =============================================
-- UI
-- =============================================
if gui:FindFirstChild("AATradeLogger") then
    gui.AATradeLogger:Destroy()
end

local SG = Instance.new("ScreenGui")
SG.Name="AATradeLogger"; SG.ResetOnSpawn=false; SG.Parent=gui

local Main = Instance.new("Frame")
Main.Size=UDim2.new(0,300,0,330)
Main.Position=UDim2.new(0.5,-150,0.5,-165)
Main.BackgroundColor3=Color3.fromRGB(8,8,18)
Main.BorderSizePixel=0; Main.Active=true; Main.Draggable=true; Main.Parent=SG
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,8)
local ms=Instance.new("UIStroke",Main)
ms.Color=Color3.fromRGB(40,40,190); ms.Thickness=1

-- title
local TB=Instance.new("Frame")
TB.Size=UDim2.new(1,0,0,32); TB.BackgroundColor3=Color3.fromRGB(12,12,34)
TB.BorderSizePixel=0; TB.Parent=Main
Instance.new("UICorner",TB).CornerRadius=UDim.new(0,8)

local TL=Instance.new("TextLabel")
TL.Size=UDim2.new(1,-34,1,0); TL.Position=UDim2.new(0,10,0,0)
TL.BackgroundTransparency=1
TL.Text="[igc] AA Trade Logger — "..EXEC
TL.TextColor3=Color3.fromRGB(70,70,220); TL.TextSize=10
TL.Font=Enum.Font.Code; TL.TextXAlignment=Enum.TextXAlignment.Left; TL.Parent=TB

local XB=Instance.new("TextButton")
XB.Size=UDim2.new(0,20,0,20); XB.Position=UDim2.new(1,-26,0.5,-10)
XB.BackgroundColor3=Color3.fromRGB(130,20,20); XB.Text="✕"
XB.TextColor3=Color3.fromRGB(255,255,255); XB.TextSize=10
XB.Font=Enum.Font.GothamBold; XB.BorderSizePixel=0; XB.Parent=TB
Instance.new("UICorner",XB).CornerRadius=UDim.new(0,4)
XB.MouseButton1Click:Connect(function() SG:Destroy() end)

-- webhook input
local function mklbl(txt, y)
    local l=Instance.new("TextLabel")
    l.Size=UDim2.new(1,-20,0,12); l.Position=UDim2.new(0,10,0,y)
    l.BackgroundTransparency=1; l.Text=txt
    l.TextColor3=Color3.fromRGB(100,100,155); l.TextSize=10
    l.Font=Enum.Font.Code; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=Main
    return l
end

mklbl("Webhook URL", 40)
local WHB=Instance.new("TextBox")
WHB.Size=UDim2.new(1,-20,0,24); WHB.Position=UDim2.new(0,10,0,53)
WHB.BackgroundColor3=Color3.fromRGB(11,11,26); WHB.Text=""
WHB.PlaceholderText="https://discord.com/api/webhooks/..."
WHB.TextColor3=Color3.fromRGB(150,150,230)
WHB.PlaceholderColor3=Color3.fromRGB(55,55,95)
WHB.TextSize=10; WHB.Font=Enum.Font.Code
WHB.ClearTextOnFocus=false; WHB.BorderSizePixel=0; WHB.Parent=Main
Instance.new("UICorner",WHB).CornerRadius=UDim.new(0,4)
local whs=Instance.new("UIStroke",WHB); whs.Color=Color3.fromRGB(35,35,130); whs.Thickness=1

-- target display
local TGF=Instance.new("Frame")
TGF.Size=UDim2.new(1,-20,0,24); TGF.Position=UDim2.new(0,10,0,86)
TGF.BackgroundColor3=Color3.fromRGB(10,10,24); TGF.BorderSizePixel=0; TGF.Parent=Main
Instance.new("UICorner",TGF).CornerRadius=UDim.new(0,4)
Instance.new("UIStroke",TGF).Color=Color3.fromRGB(50,50,180)

local TGL=Instance.new("TextLabel")
TGL.Size=UDim2.new(1,-10,1,0); TGL.Position=UDim2.new(0,8,0,0)
TGL.BackgroundTransparency=1
TGL.Text="target: "..TARGET_NAME
TGL.TextColor3=Color3.fromRGB(100,210,255); TGL.TextSize=11
TGL.Font=Enum.Font.Code; TGL.TextXAlignment=Enum.TextXAlignment.Left; TGL.Parent=TGF

-- status box
local statBg=Instance.new("Frame")
statBg.Size=UDim2.new(1,-20,0,54); statBg.Position=UDim2.new(0,10,0,120)
statBg.BackgroundColor3=Color3.fromRGB(10,10,22); statBg.BorderSizePixel=0; statBg.Parent=Main
Instance.new("UICorner",statBg).CornerRadius=UDim.new(0,4)
Instance.new("UIStroke",statBg).Color=Color3.fromRGB(35,35,120)

local mainStatus=Instance.new("TextLabel")
mainStatus.Size=UDim2.new(1,-10,0.5,0); mainStatus.Position=UDim2.new(0,6,0,2)
mainStatus.BackgroundTransparency=1; mainStatus.Text="idle"
mainStatus.TextColor3=Color3.fromRGB(100,100,160); mainStatus.TextSize=12
mainStatus.Font=Enum.Font.GothamBold; mainStatus.TextXAlignment=Enum.TextXAlignment.Left
mainStatus.Parent=statBg

local subStatus=Instance.new("TextLabel")
subStatus.Size=UDim2.new(1,-10,0.5,0); subStatus.Position=UDim2.new(0,6,0.5,0)
subStatus.BackgroundTransparency=1; subStatus.Text="arm → trade manually → auto-logs on accept"
subStatus.TextColor3=Color3.fromRGB(80,80,130); subStatus.TextSize=10
subStatus.Font=Enum.Font.Code; subStatus.TextXAlignment=Enum.TextXAlignment.Left
subStatus.Parent=statBg

local function setMain(msg, col)
    mainStatus.Text=msg
    mainStatus.TextColor3=col or Color3.fromRGB(80,205,100)
end

local function setSub(msg)
    subStatus.Text=msg
    subStatus.TextColor3=Color3.fromRGB(80,80,130)
end

-- counters
local function mkCnt(lbl, x, y, w)
    local F=Instance.new("Frame")
    F.Size=UDim2.new(0,w,0,34); F.Position=UDim2.new(0,x,0,y)
    F.BackgroundColor3=Color3.fromRGB(10,10,24); F.BorderSizePixel=0; F.Parent=Main
    Instance.new("UICorner",F).CornerRadius=UDim.new(0,4)
    local NL=Instance.new("TextLabel")
    NL.Size=UDim2.new(1,0,0.55,0); NL.BackgroundTransparency=1
    NL.Text="0"; NL.TextColor3=Color3.fromRGB(80,205,120)
    NL.TextSize=14; NL.Font=Enum.Font.GothamBold; NL.Parent=F
    local LL=Instance.new("TextLabel")
    LL.Size=UDim2.new(1,0,0.45,0); LL.Position=UDim2.new(0,0,0.55,0)
    LL.BackgroundTransparency=1; LL.Text=lbl
    LL.TextColor3=Color3.fromRGB(70,70,125); LL.TextSize=9; LL.Font=Enum.Font.Code; LL.Parent=F
    return NL
end

local c1=mkCnt("⚡ nc hits",  10, 183, 65)
local c2=mkCnt("⚡ events",   80, 183, 65)
local c3=mkCnt("rf hits",    150, 183, 65)
local c4=mkCnt("all calls",  220, 183, 65)

task.spawn(function()
    while SG.Parent do
        c1.Text=tostring(#LOG.ncHits)
        c2.Text=tostring(#LOG.kwEvents)
        c3.Text=tostring(#LOG.invokeHits)
        c4.Text=tostring(#LOG.ncFull)
        task.wait(1)
    end
end)

-- trade sent indicator
local sentInd=Instance.new("Frame")
sentInd.Size=UDim2.new(1,-20,0,20); sentInd.Position=UDim2.new(0,10,0,225)
sentInd.BackgroundColor3=Color3.fromRGB(10,10,22); sentInd.BorderSizePixel=0
sentInd.Visible=false; sentInd.Parent=Main
Instance.new("UICorner",sentInd).CornerRadius=UDim.new(0,4)

local sentLbl=Instance.new("TextLabel")
sentLbl.Size=UDim2.new(1,0,1,0); sentLbl.BackgroundTransparency=1
sentLbl.Text="⚡ TRADE AUTO-LOGGED — CHECK DISCORD"
sentLbl.TextColor3=Color3.fromRGB(255,220,50); sentLbl.TextSize=11
sentLbl.Font=Enum.Font.GothamBold; sentLbl.Parent=sentInd

-- arm button
local armed = false

local ArmBtn=Instance.new("TextButton")
ArmBtn.Size=UDim2.new(1,-20,0,32); ArmBtn.Position=UDim2.new(0,10,0,254)
ArmBtn.BackgroundColor3=Color3.fromRGB(25,25,150); ArmBtn.Text="[ ARM — WATCH FOR TRADE ]"
ArmBtn.TextColor3=Color3.fromRGB(170,170,255); ArmBtn.TextSize=12
ArmBtn.Font=Enum.Font.GothamBold; ArmBtn.BorderSizePixel=0; ArmBtn.Parent=Main
Instance.new("UICorner",ArmBtn).CornerRadius=UDim.new(0,6)

-- reset button (in case you want to do another trade)
local ResetBtn=Instance.new("TextButton")
ResetBtn.Size=UDim2.new(1,-20,0,22); ResetBtn.Position=UDim2.new(0,10,0,292)
ResetBtn.BackgroundColor3=Color3.fromRGB(80,30,10); ResetBtn.Text="[ RESET FOR NEW TRADE ]"
ResetBtn.TextColor3=Color3.fromRGB(255,180,100); ResetBtn.TextSize=10
ResetBtn.Font=Enum.Font.GothamBold; ResetBtn.BorderSizePixel=0; ResetBtn.Parent=Main
Instance.new("UICorner",ResetBtn).CornerRadius=UDim.new(0,5)

ArmBtn.MouseButton1Click:Connect(function()
    if armed then setMain("already armed ✓"); return end

    local wh = WHB.Text
    if not wh:find("discord.com/api/webhooks") then
        setMain("set webhook first", Color3.fromRGB(230,60,60)); return
    end
    WEBHOOK = wh
    armed = true
    ArmBtn.Text="[ ARMED — WAITING FOR TRADE ]"
    ArmBtn.BackgroundColor3=Color3.fromRGB(10,55,10)

    task.spawn(function()
        setMain("scanning...", Color3.fromRGB(230,170,30))
        setSub("mapping remotes + arming hooks")
        scanInstances()
        armNamecall()
        listenEvents()

        setMain("armed ✓", Color3.fromRGB(50,210,90))
        setSub("build your trade manually → it auto-logs when "..TARGET_NAME.." accepts")

        -- watch for target in server
        task.spawn(function()
            local targetPlayer = watchTarget()
            if targetPlayer then
                setMain("target online ✓", Color3.fromRGB(50,210,90))
                setSub(TARGET_NAME.." is in server — ready")
            end
        end)
    end)
end)

ResetBtn.MouseButton1Click:Connect(function()
    -- clear logs for new trade
    LOG.tradeData    = {}
    LOG.ncHits       = {}
    LOG.ncFull       = {}
    LOG.kwEvents     = {}
    LOG.invokeHits   = {}
    LOG.acceptEvent  = nil
    LOG.confirmEvent = nil
    tradeSent        = false
    tradeActive      = false
    sentInd.Visible  = false
    setMain("reset ✓ — ready for new trade", Color3.fromRGB(50,210,90))
    setSub("logs cleared — arm hooks still active")
    print("[igc] logs reset for new trade session")
end)

-- hook auto-show sent indicator
task.spawn(function()
    while SG.Parent do
        if tradeSent and not sentInd.Visible then
            sentInd.Visible = true
            setMain("⚡ LOGGED — CHECK DISCORD", Color3.fromRGB(255,220,50))
            setSub("reset for another trade if needed")
        end
        task.wait(0.5)
    end
end)

print("[igc] AA Trade Logger loaded — target: "..TARGET_NAME.." — arm and trade manually")
