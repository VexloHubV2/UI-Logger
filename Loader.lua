-- =============================================
-- [igc] AA TRADE LOGGER v2 — FIXED
-- Uses exact remote paths from your logs
-- NO UI freeze, only triggers on THEIR accept
-- Target: jfhjrudfhb24
-- =============================================

local WEBHOOK     = "https://discord.com/api/webhooks/1570997699342245978/QuQERBzp-IVQrOBVyexEi7_NMFqnPnsWxSIivDKL99QCURSBDf-D5Cw2PIIcvo1nrVHk"
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
-- SERVICES
-- =============================================
local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local HS      = game:GetService("HttpService")
local TS      = game:GetService("TweenService")
local lp      = Players.LocalPlayer
local gui     = lp:WaitForChild("PlayerGui")

-- =============================================
-- EXACT REMOTE PATHS (from your logs)
-- =============================================
local REMOTES = {
    -- client → server (you sending)
    START_TRADE   = "ReplicatedStorage.endpoints.client_to_server.start_trade_request",
    ACCEPT_TRADE  = "ReplicatedStorage.endpoints.client_to_server.accept_trade_request",
    DEFINE_TRADE  = "ReplicatedStorage.endpoints.client_to_server.define_trade_request",

    -- server → client (they responding)
    -- these will be caught via OnClientEvent
    TRADE_RECEIVE = "ReplicatedStorage.endpoints.server_to_client.trade_request_received",
    TRADE_ACCEPT  = "ReplicatedStorage.endpoints.server_to_client.accept_trade_request",
    TRADE_ZONE    = "ReplicatedStorage.endpoints.server_to_client.trade_request_zoomed",
}

-- remotes we do NOT intercept (causes UI freeze)
local SKIP_PATHS = {
    ["start_trade_request"]  = true,
    ["define_trade_request"] = true,
}

-- =============================================
-- LOG BUCKETS
-- =============================================
local LOG = {
    ncFull      = {},
    ncHits      = {},
    kwEvents    = {},
    acceptData  = nil,
    confirmData = nil,
    tradeUnits  = {},
}

local tradeSent  = false
local tradeReady = false -- true only after you've added units

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
-- WEBHOOK
-- =============================================
local function sendWH(title, lines, urgent)
    local wh = WEBHOOK
    if not wh:find("discord.com/api/webhooks") then return end
    local body = table.concat(lines,"\n")
    local chunks = {}
    for i=1,#body,1900 do table.insert(chunks,body:sub(i,i+1899)) end
    for idx,chunk in ipairs(chunks) do
        local t2 = #chunks>1 and (title.." ["..idx.."/"..#chunks.."]") or title
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
                        color       = urgent and 0xFF4444 or 0x2244FF,
                        footer      = { text = EXEC.." · "..lp.Name.." → "..TARGET_NAME }
                    }}
                })
            })
        end)
        if idx < #chunks then task.wait(1.2) end
    end
end

-- =============================================
-- AUTO SEND — only fires on THEIR accept
-- =============================================
local function autoSend(trigger)
    if tradeSent then return end
    tradeSent = true
    print("[igc] ⚡ AUTO-SEND triggered: "..trigger)

    -- R1: summary
    do
        local lines = {
            "# ⚡ TRADE LOGGED",
            "**Trigger:** `"..trigger.."`",
            "**Target:** `"..TARGET_NAME.."`",
            "**Time:** `"..ts().."`",
            "**You:** "..lp.Name.." (`"..lp.UserId.."`)",
            "",
        }
        if LOG.acceptData then
            table.insert(lines, "**== Accept Payload ==**")
            table.insert(lines, "```")
            table.insert(lines, LOG.acceptData)
            table.insert(lines, "```")
        end
        if LOG.confirmData then
            table.insert(lines, "**== Confirm Payload ==**")
            table.insert(lines, "```")
            table.insert(lines, LOG.confirmData)
            table.insert(lines, "```")
        end
        sendWH("⚡ TRADE LOGGED — "..TARGET_NAME, lines, true)
    end

    task.wait(1.5)

    -- R2: keyword namecall hits
    do
        local lines = {
            "**== ⚡ Trade Namecall Hits: "..#LOG.ncHits.." ==**","",
        }
        for i,h in ipairs(LOG.ncHits) do
            if i>50 then table.insert(lines,"...more"); break end
            table.insert(lines,"⚡ **"..h.t.."** `"..h.path.."`")
            table.insert(lines,"  **"..h.method.."**")
            if #h.args>0 then table.insert(lines,"  args: "..table.concat(h.args,", ")) end
            if #h.rets>0 then table.insert(lines,"  **→ "..table.concat(h.rets," | ").."**") end
            table.insert(lines,"")
        end
        sendWH("⚡ Namecall Hits — "..TARGET_NAME, lines, true)
    end

    task.wait(1.5)

    -- R3: server events
    do
        local lines = {
            "**== ⚡ Trade Events: "..#LOG.kwEvents.." ==**","",
        }
        for i,e in ipairs(LOG.kwEvents) do
            if i>40 then break end
            table.insert(lines,"⚡ **"..e.t.."** `"..e.path.."`")
            if #e.data>0 then table.insert(lines,"  **"..table.concat(e.data," | ").."**") end
            table.insert(lines,"")
        end
        sendWH("⚡ Trade Events — "..TARGET_NAME, lines, true)
    end

    task.wait(1.5)

    -- R4: full call log
    do
        local lines = {
            "**== Full Call Log: "..#LOG.ncFull.." ==**","",
        }
        for i,h in ipairs(LOG.ncFull) do
            if i>60 then table.insert(lines,"...+"..(#LOG.ncFull-60).." more"); break end
            table.insert(lines,"· **"..h.t.."** `"..h.path.."` "..h.method)
            if #h.rets>0 then table.insert(lines,"  → "..table.concat(h.rets," | ")) end
        end
        sendWH("Full Call Log — "..TARGET_NAME, lines, false)
    end

    print("[igc] all reports sent ✓")
end

-- =============================================
-- NAMECALL HOOK
-- SKIPS start/define remotes so your UI works
-- only logs, never blocks the call
-- =============================================
local oldNC

local function armNamecall()
    if not hookmetamethod then
        warn("[igc] hookmetamethod unavailable on "..EXEC)
        return
    end

    oldNC = hookmetamethod(game, "__namecall", function(self, ...)
        if checkcaller and checkcaller() then
            return oldNC(self, ...)
        end

        local method = getnamecallmethod()
        local tracked = {
            InvokeServer=true, FireServer=true,
            InvokeClient=true, FireClient=true,
        }

        if tracked[method] then
            local fp = "?"
            pcall(function() fp = self:GetFullName() end)

            -- ALWAYS pass through first — never block
            local rets = table.pack(oldNC(self, ...))

            local fp_lo = fp:lower()

            -- skip logging start/define so no interference
            local name_lo = fp:match("[^%.]+$") or ""
            if not SKIP_PATHS[name_lo:lower()] then

                local entry = {
                    t      = ts(),
                    path   = fp,
                    method = method,
                    args   = {},
                    rets   = {},
                }
                for i,a in ipairs({...}) do entry.args[i]=fmt(a) end
                for i=1,rets.n do entry.rets[i]=fmt(rets[i]) end

                table.insert(LOG.ncFull, entry)

                -- keyword match
                if fp_lo:find("trade") or fp_lo:find("unit") or fp_lo:find("inv")
                or fp_lo:find("offer") or fp_lo:find("swap") or fp_lo:find("exchange")
                or fp_lo:find("accept") or fp_lo:find("confirm") then
                    table.insert(LOG.ncHits, entry)

                    -- detect THEIR accept coming back
                    -- this fires when server confirms accept
                    if fp_lo:find("accept") and method == "InvokeServer" then
                        LOG.acceptData = "path: "..fp
                            .."\nargs: "..table.concat(entry.args,", ")
                            .."\nret: "..table.concat(entry.rets," | ")
                        -- only auto-send if trade is in progress
                        if tradeReady and not tradeSent then
                            task.spawn(function()
                                task.wait(0.5) -- let confirm fire too if it comes
                                autoSend("ACCEPT NC "..fp)
                            end)
                        end
                    end

                    if fp_lo:find("confirm") then
                        LOG.confirmData = "path: "..fp
                            .."\nargs: "..table.concat(entry.args,", ")
                            .."\nret: "..table.concat(entry.rets," | ")
                        if tradeReady and not tradeSent then
                            task.spawn(function() autoSend("CONFIRM NC "..fp) end)
                        end
                    end
                end
            end

            return table.unpack(rets, 1, rets.n)
        end

        return oldNC(self, ...)
    end)

    print("[igc] namecall hook armed — UI-safe")
end

-- =============================================
-- EVENT LISTENERS
-- server→client accept = THEIR accept
-- this is the most reliable trigger
-- =============================================
local function listenEvents()
    local count = 0

    -- try exact known paths first
    local function tryBind(path)
        local parts = path:split(".")
        local obj = game
        for _, p in ipairs(parts) do
            local ok, child = pcall(function() return obj:WaitForChild(p, 2) end)
            if not ok or not child then return end
            obj = child
        end
        if obj and obj:IsA("RemoteEvent") then
            count = count + 1
            obj.OnClientEvent:Connect(function(...)
                local args = {...}
                local entry = { t=ts(), path=path, data={} }
                for i,a in ipairs(args) do entry.data[i]=fmt(a) end
                table.insert(LOG.kwEvents, entry)

                local p_lo = path:lower()
                print("[igc] ⚡ server→client: "..path)

                -- server confirmed accept = THEY accepted
                if p_lo:find("accept") or p_lo:find("confirm") then
                    LOG.acceptData = "event: "..path
                        .."\ndata: "..table.concat(entry.data," | ")
                    if tradeReady and not tradeSent then
                        task.spawn(function() autoSend("SERVER EVENT "..path) end)
                    end
                end

                -- target username in payload
                for _, d in ipairs(entry.data) do
                    if type(d)=="string" and d:find(TARGET_NAME) then
                        print("[igc] ⚡ target in event data: "..path)
                        if tradeReady and not tradeSent then
                            task.spawn(function()
                                task.wait(1)
                                if not tradeSent then
                                    autoSend("TARGET IN DATA "..path)
                                end
                            end)
                        end
                    end
                end
            end)
        end
    end

    -- known server→client paths
    tryBind("ReplicatedStorage.endpoints.server_to_client.accept_trade_request")
    tryBind("ReplicatedStorage.endpoints.server_to_client.trade_request_received")
    tryBind("ReplicatedStorage.endpoints.server_to_client.trade_request_zoomed")

    -- also scan all REs for anything trade-related
    for _, v in ipairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local n = v.Name:lower()
            if n:find("trade") or n:find("accept") or n:find("confirm")
            or n:find("unit") or n:find("offer") or n:find("swap") then
                local fp = v:GetFullName()
                v.OnClientEvent:Connect(function(...)
                    local args = {...}
                    local entry = { t=ts(), path=fp, data={} }
                    for i,a in ipairs(args) do entry.data[i]=fmt(a) end
                    table.insert(LOG.kwEvents, entry)
                    print("[igc] ⚡ KW event: "..fp)

                    local p_lo = fp:lower()
                    if (p_lo:find("accept") or p_lo:find("confirm")) and tradeReady and not tradeSent then
                        LOG.acceptData = "event: "..fp.."\ndata: "..table.concat(entry.data," | ")
                        task.spawn(function() autoSend("KW EVENT "..fp) end)
                    end
                end)
                count = count + 1
            end
        end
    end

    print("[igc] listening "..count.." trade-related RemoteEvents")
end

-- =============================================
-- UI
-- =============================================
if gui:FindFirstChild("AATradeV2") then gui.AATradeV2:Destroy() end

local SG=Instance.new("ScreenGui")
SG.Name="AATradeV2"; SG.ResetOnSpawn=false; SG.Parent=gui

local Main=Instance.new("Frame")
Main.Size=UDim2.new(0,295,0,290)
Main.Position=UDim2.new(0.5,-147,0.5,-145)
Main.BackgroundColor3=Color3.fromRGB(8,8,18)
Main.BorderSizePixel=0; Main.Active=true; Main.Draggable=true; Main.Parent=SG
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,8)
local ms=Instance.new("UIStroke",Main)
ms.Color=Color3.fromRGB(40,40,190); ms.Thickness=1

-- title
local TB=Instance.new("Frame")
TB.Size=UDim2.new(1,0,0,30); TB.BackgroundColor3=Color3.fromRGB(12,12,34)
TB.BorderSizePixel=0; TB.Parent=Main
Instance.new("UICorner",TB).CornerRadius=UDim.new(0,8)

local TL=Instance.new("TextLabel")
TL.Size=UDim2.new(1,-30,1,0); TL.Position=UDim2.new(0,10,0,0)
TL.BackgroundTransparency=1
TL.Text="[igc] AA Trade Logger v2 — "..EXEC
TL.TextColor3=Color3.fromRGB(70,70,220); TL.TextSize=10
TL.Font=Enum.Font.Code; TL.TextXAlignment=Enum.TextXAlignment.Left; TL.Parent=TB

local XB=Instance.new("TextButton")
XB.Size=UDim2.new(0,20,0,20); XB.Position=UDim2.new(1,-24,0.5,-10)
XB.BackgroundColor3=Color3.fromRGB(130,20,20); XB.Text="✕"
XB.TextColor3=Color3.fromRGB(255,255,255); XB.TextSize=10
XB.Font=Enum.Font.GothamBold; XB.BorderSizePixel=0; XB.Parent=TB
Instance.new("UICorner",XB).CornerRadius=UDim.new(0,4)
XB.MouseButton1Click:Connect(function() SG:Destroy() end)

-- webhook
local WHL=Instance.new("TextLabel")
WHL.Size=UDim2.new(1,-20,0,12); WHL.Position=UDim2.new(0,10,0,38)
WHL.BackgroundTransparency=1; WHL.Text="Webhook URL"
WHL.TextColor3=Color3.fromRGB(90,90,140); WHL.TextSize=10
WHL.Font=Enum.Font.Code; WHL.TextXAlignment=Enum.TextXAlignment.Left; WHL.Parent=Main

local WHB=Instance.new("TextBox")
WHB.Size=UDim2.new(1,-20,0,24); WHB.Position=UDim2.new(0,10,0,51)
WHB.BackgroundColor3=Color3.fromRGB(11,11,26); WHB.Text=""
WHB.PlaceholderText="https://discord.com/api/webhooks/..."
WHB.TextColor3=Color3.fromRGB(150,150,230)
WHB.PlaceholderColor3=Color3.fromRGB(55,55,95)
WHB.TextSize=10; WHB.Font=Enum.Font.Code
WHB.ClearTextOnFocus=false; WHB.BorderSizePixel=0; WHB.Parent=Main
Instance.new("UICorner",WHB).CornerRadius=UDim.new(0,4)
local whs=Instance.new("UIStroke",WHB); whs.Color=Color3.fromRGB(35,35,130); whs.Thickness=1

-- target
local TGF=Instance.new("Frame")
TGF.Size=UDim2.new(1,-20,0,22); TGF.Position=UDim2.new(0,10,0,84)
TGF.BackgroundColor3=Color3.fromRGB(10,10,24); TGF.BorderSizePixel=0; TGF.Parent=Main
Instance.new("UICorner",TGF).CornerRadius=UDim.new(0,4)
Instance.new("UIStroke",TGF).Color=Color3.fromRGB(40,40,160)

local TGL=Instance.new("TextLabel")
TGL.Size=UDim2.new(1,-10,1,0); TGL.Position=UDim2.new(0,8,0,0)
TGL.BackgroundTransparency=1
TGL.Text="target → "..TARGET_NAME
TGL.TextColor3=Color3.fromRGB(90,200,255); TGL.TextSize=11
TGL.Font=Enum.Font.Code; TGL.TextXAlignment=Enum.TextXAlignment.Left; TGL.Parent=TGF

-- main status
local statBg=Instance.new("Frame")
statBg.Size=UDim2.new(1,-20,0,46); statBg.Position=UDim2.new(0,10,0,115)
statBg.BackgroundColor3=Color3.fromRGB(10,10,22); statBg.BorderSizePixel=0; statBg.Parent=Main
Instance.new("UICorner",statBg).CornerRadius=UDim.new(0,4)
Instance.new("UIStroke",statBg).Color=Color3.fromRGB(30,30,110)

local MS=Instance.new("TextLabel")
MS.Size=UDim2.new(1,-10,0.5,0); MS.Position=UDim2.new(0,6,0,2)
MS.BackgroundTransparency=1; MS.Text="idle"
MS.TextColor3=Color3.fromRGB(90,90,150); MS.TextSize=12
MS.Font=Enum.Font.GothamBold; MS.TextXAlignment=Enum.TextXAlignment.Left; MS.Parent=statBg

local SS=Instance.new("TextLabel")
SS.Size=UDim2.new(1,-10,0.5,0); SS.Position=UDim2.new(0,6,0.5,0)
SS.BackgroundTransparency=1; SS.Text="arm → add units → wait for accept"
SS.TextColor3=Color3.fromRGB(70,70,120); SS.TextSize=10
SS.Font=Enum.Font.Code; SS.TextXAlignment=Enum.TextXAlignment.Left; SS.Parent=statBg

local function setMain(msg,col)
    MS.Text=msg; MS.TextColor3=col or Color3.fromRGB(55,205,90)
end
local function setSub(msg)
    SS.Text=msg; SS.TextColor3=Color3.fromRGB(70,70,120)
end

-- counters
local function mkC(lbl,x,w)
    local F=Instance.new("Frame")
    F.Size=UDim2.new(0,w,0,32); F.Position=UDim2.new(0,x,0,170)
    F.BackgroundColor3=Color3.fromRGB(10,10,22); F.BorderSizePixel=0; F.Parent=Main
    Instance.new("UICorner",F).CornerRadius=UDim.new(0,4)
    local NL=Instance.new("TextLabel")
    NL.Size=UDim2.new(1,0,0.6,0); NL.BackgroundTransparency=1
    NL.Text="0"; NL.TextColor3=Color3.fromRGB(80,205,120)
    NL.TextSize=14; NL.Font=Enum.Font.GothamBold; NL.Parent=F
    local LL=Instance.new("TextLabel")
    LL.Size=UDim2.new(1,0,0.4,0); LL.Position=UDim2.new(0,0,0.6,0)
    LL.BackgroundTransparency=1; LL.Text=lbl
    LL.TextColor3=Color3.fromRGB(65,65,120); LL.TextSize=9; LL.Font=Enum.Font.Code; LL.Parent=F
    return NL
end

local c1=mkC("nc hits",  10, 65)
local c2=mkC("events",   80, 65)
local c3=mkC("all calls",150, 65)
local c4=mkC("kw events",220, 65)

task.spawn(function()
    while SG.Parent do
        c1.Text=tostring(#LOG.ncHits)
        c2.Text=tostring(#LOG.kwEvents)
        c3.Text=tostring(#LOG.ncFull)
        c4.Text=tostring(#LOG.kwEvents)
        task.wait(1)
    end
end)

-- ready toggle — he presses this after adding units
local readyBtn=Instance.new("TextButton")
readyBtn.Size=UDim2.new(1,-20,0,26); readyBtn.Position=UDim2.new(0,10,0,210)
readyBtn.BackgroundColor3=Color3.fromRGB(80,60,10); readyBtn.Text="[ MARK READY — units added ]"
readyBtn.TextColor3=Color3.fromRGB(255,200,80); readyBtn.TextSize=11
readyBtn.Font=Enum.Font.GothamBold; readyBtn.BorderSizePixel=0; readyBtn.Parent=Main
Instance.new("UICorner",readyBtn).CornerRadius=UDim.new(0,5)

readyBtn.MouseButton1Click:Connect(function()
    tradeReady = true
    readyBtn.BackgroundColor3=Color3.fromRGB(10,80,10)
    readyBtn.Text="[ READY ✓ — waiting for accept ]"
    readyBtn.TextColor3=Color3.fromRGB(150,255,150)
    setMain("waiting for "..TARGET_NAME.." to accept", Color3.fromRGB(230,170,30))
    setSub("auto-logs the moment they hit accept")
    print("[igc] trade marked ready — watching for accept")
end)

-- arm button
local armed=false
local ArmBtn=Instance.new("TextButton")
ArmBtn.Size=UDim2.new(1,-20,0,28); ArmBtn.Position=UDim2.new(0,10,0,244)
ArmBtn.BackgroundColor3=Color3.fromRGB(25,25,150); ArmBtn.Text="[ ARM ]"
ArmBtn.TextColor3=Color3.fromRGB(170,170,255); ArmBtn.TextSize=12
ArmBtn.Font=Enum.Font.GothamBold; ArmBtn.BorderSizePixel=0; ArmBtn.Parent=Main
Instance.new("UICorner",ArmBtn).CornerRadius=UDim.new(0,6)

-- reset
local ResetBtn=Instance.new("TextButton")
ResetBtn.Size=UDim2.new(1,-20,0,20); ResetBtn.Position=UDim2.new(0,10,0,278)
ResetBtn.BackgroundColor3=Color3.fromRGB(70,25,8); ResetBtn.Text="[ RESET ]"
ResetBtn.TextColor3=Color3.fromRGB(255,160,80); ResetBtn.TextSize=10
ResetBtn.Font=Enum.Font.GothamBold; ResetBtn.BorderSizePixel=0; ResetBtn.Parent=Main
Instance.new("UICorner",ResetBtn).CornerRadius=UDim.new(0,5)

ArmBtn.MouseButton1Click:Connect(function()
    if armed then setMain("already armed ✓"); return end
    local wh=WHB.Text
    if not wh:find("discord.com/api/webhooks") then
        setMain("set webhook first", Color3.fromRGB(230,60,60)); return
    end
    WEBHOOK=wh; armed=true
    ArmBtn.Text="[ ARMED ✓ ]"
    ArmBtn.BackgroundColor3=Color3.fromRGB(10,50,10)
    task.spawn(function()
        setMain("arming hooks...", Color3.fromRGB(230,170,30))
        armNamecall()
        listenEvents()
        setMain("armed ✓", Color3.fromRGB(55,205,90))
        setSub("send trade to "..TARGET_NAME.." → add units → press READY")
    end)
end)

ResetBtn.MouseButton1Click:Connect(function()
    LOG.ncFull={}; LOG.ncHits={}; LOG.kwEvents={}
    LOG.acceptData=nil; LOG.confirmData=nil; LOG.tradeUnits={}
    tradeSent=false; tradeReady=false
    readyBtn.BackgroundColor3=Color3.fromRGB(80,60,10)
    readyBtn.Text="[ MARK READY — units added ]"
    readyBtn.TextColor3=Color3.fromRGB(255,200,80)
    setMain("reset ✓ — ready for new trade", Color3.fromRGB(55,205,90))
    setSub("logs cleared — hooks still active")
    print("[igc] reset for new trade")
end)

-- auto-flash when sent
task.spawn(function()
    while SG.Parent do
        if tradeSent then
            setMain("⚡ LOGGED — CHECK DISCORD", Color3.fromRGB(255,220,50))
            setSub("hit RESET for another trade")
        end
        task.wait(0.5)
    end
end)

print("[igc] AA Trade Logger v2 loaded on "..EXEC)
