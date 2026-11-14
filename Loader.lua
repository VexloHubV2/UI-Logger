-- =============================================
-- [igc] Remote Finder UI + Webhook
-- search any keyword → finds matching remotes
-- invokes them + shows result on screen
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

if gui:FindFirstChild("RemoteFinderUI") then gui.RemoteFinderUI:Destroy() end

local SG = Instance.new("ScreenGui")
SG.Name="RemoteFinderUI"; SG.ResetOnSpawn=false; SG.Parent=gui

local Main = Instance.new("Frame")
Main.Size=UDim2.new(0,320,0,500)
Main.Position=UDim2.new(0.5,-160,0.5,-250)
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
TL.BackgroundTransparency=1; TL.Text="[igc] Remote Finder + Invoker"
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

-- search label
local SHL=Instance.new("TextLabel")
SHL.Size=UDim2.new(1,-20,0,12); SHL.Position=UDim2.new(0,10,0,83)
SHL.BackgroundTransparency=1; SHL.Text="Search Keyword (searches all remotes)"
SHL.TextColor3=Color3.fromRGB(90,90,140); SHL.TextSize=10
SHL.Font=Enum.Font.Code; SHL.TextXAlignment=Enum.TextXAlignment.Left; SHL.Parent=Main

-- search input
local SHB=Instance.new("TextBox")
SHB.Size=UDim2.new(1,-20,0,24); SHB.Position=UDim2.new(0,10,0,96)
SHB.BackgroundColor3=Color3.fromRGB(11,11,26); SHB.Text=""
SHB.PlaceholderText="e.g. unit, inventory, data, player ..."
SHB.TextColor3=Color3.fromRGB(220,220,255)
SHB.PlaceholderColor3=Color3.fromRGB(60,60,100)
SHB.TextSize=11; SHB.Font=Enum.Font.Code
SHB.ClearTextOnFocus=false; SHB.BorderSizePixel=0; SHB.Parent=Main
Instance.new("UICorner",SHB).CornerRadius=UDim.new(0,4)
local shs=Instance.new("UIStroke",SHB); shs.Color=Color3.fromRGB(50,50,180); shs.Thickness=1

-- status
local statL=Instance.new("TextLabel")
statL.Size=UDim2.new(1,-20,0,20); statL.Position=UDim2.new(0,10,0,128)
statL.BackgroundColor3=Color3.fromRGB(10,10,24); statL.BorderSizePixel=0
statL.Text=" type keyword → SEARCH"
statL.TextColor3=Color3.fromRGB(100,100,160); statL.TextSize=10
statL.Font=Enum.Font.Code; statL.Parent=Main
Instance.new("UICorner",statL).CornerRadius=UDim.new(0,4)

local function setStat(msg, col)
    statL.Text=" "..msg
    statL.TextColor3=col or Color3.fromRGB(55,205,90)
end

-- scroll output
local scrollBg=Instance.new("Frame")
scrollBg.Size=UDim2.new(1,-20,0,255); scrollBg.Position=UDim2.new(0,10,0,156)
scrollBg.BackgroundColor3=Color3.fromRGB(6,6,16); scrollBg.BorderSizePixel=0; scrollBg.Parent=Main
Instance.new("UICorner",scrollBg).CornerRadius=UDim.new(0,6)
Instance.new("UIStroke",scrollBg).Color=Color3.fromRGB(30,30,110)

local scroll=Instance.new("ScrollingFrame")
scroll.Size=UDim2.new(1,-8,1,-8); scroll.Position=UDim2.new(0,4,0,4)
scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0
scroll.ScrollBarThickness=4; scroll.ScrollBarImageColor3=Color3.fromRGB(50,50,180)
scroll.CanvasSize=UDim2.new(0,0,0,0); scroll.Parent=scrollBg

local layout=Instance.new("UIListLayout")
layout.SortOrder=Enum.SortOrder.LayoutOrder
layout.Padding=UDim.new(0,2); layout.Parent=scroll

local lineCount=0
local webhookLines={}

local function addLine(txt, col)
    lineCount=lineCount+1
    table.insert(webhookLines, txt)
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-8,0,0)
    lbl.AutomaticSize=Enum.AutomaticSize.Y
    lbl.BackgroundTransparency=1
    lbl.Text=txt; lbl.TextColor3=col or Color3.fromRGB(180,180,220)
    lbl.TextSize=10; lbl.Font=Enum.Font.Code
    lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.TextWrapped=true; lbl.LayoutOrder=lineCount; lbl.Parent=scroll
    task.defer(function()
        scroll.CanvasSize=UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+8)
        scroll.CanvasPosition=Vector2.new(0,math.huge)
    end)
end

local function clearLines()
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    lineCount=0; webhookLines={}
    scroll.CanvasSize=UDim2.new(0,0,0,0)
end

-- deep dump
local function deepDump(val, prefix, depth)
    depth=depth or 0; prefix=prefix or ""
    if depth>5 then addLine(prefix.."...", Color3.fromRGB(100,100,140)); return end
    if type(val)=="table" then
        local n=0
        for k,v in pairs(val) do
            n=n+1
            if n>40 then addLine(prefix.."...more", Color3.fromRGB(100,100,120)); break end
            local key=prefix.."["..tostring(k).."]"
            if type(v)=="table" then
                addLine(key.." = {", Color3.fromRGB(180,160,255))
                deepDump(v, prefix.."  ", depth+1)
                addLine(prefix.."}", Color3.fromRGB(180,160,255))
            elseif type(v)=="string" then
                local isUUID=v:match("^%x+%-%x+%-%x+%-%x+%-%x+$")
                addLine(key..'="'..v..'"',
                    isUUID and Color3.fromRGB(80,255,160) or Color3.fromRGB(220,220,180))
            elseif type(v)=="number" or type(v)=="boolean" then
                addLine(key.."="..tostring(v), Color3.fromRGB(255,180,80))
            elseif type(v)=="userdata" then
                local ok,nm=pcall(function() return v.Name end)
                addLine(key.."=[Inst:"..(ok and nm or "?").."]", Color3.fromRGB(150,150,200))
            else
                addLine(key.."="..tostring(v), Color3.fromRGB(180,180,180))
            end
        end
        if n==0 then addLine(prefix.."(empty)", Color3.fromRGB(80,80,100)) end
    else
        addLine(prefix..tostring(val), Color3.fromRGB(220,220,180))
    end
end

-- webhook sender
local function sendWH(wh, title)
    if not wh or not wh:find("discord.com/api/webhooks") then
        setStat("invalid webhook", Color3.fromRGB(230,60,60)); return
    end
    local body="**[igc] Remote Finder**\n"
        .."**Player:** "..lp.Name.." (`"..lp.UserId.."`)\n"
        .."**Executor:** "..EXEC.."\n\n"
        .."```\n"..table.concat(webhookLines,"\n"):sub(1,1800).."\n```"
    local chunks={}
    for i=1,#body,1900 do table.insert(chunks,body:sub(i,i+1899)) end
    for idx,chunk in ipairs(chunks) do
        local t2=#chunks>1 and (title.." ["..idx.."/"..#chunks.."]") or title
        pcall(function()
            httpFn({
                Url=wh, Method="POST",
                Headers={["Content-Type"]="application/json"},
                Body=HS:JSONEncode({
                    username="[igc] Remote Finder",
                    embeds={{
                        title=t2, description=chunk, color=0x2255FF,
                        footer={text=EXEC.." · "..lp.Name.." · "..lp.UserId}
                    }}
                })
            })
        end)
        if idx<#chunks then task.wait(1.2) end
    end
    setStat("sent to Discord ✓", Color3.fromRGB(80,255,160))
end

-- buttons
local SearchBtn=Instance.new("TextButton")
SearchBtn.Size=UDim2.new(0,90,0,26); SearchBtn.Position=UDim2.new(0,10,0,420)
SearchBtn.BackgroundColor3=Color3.fromRGB(25,25,150); SearchBtn.Text="[ SEARCH ]"
SearchBtn.TextColor3=Color3.fromRGB(170,170,255); SearchBtn.TextSize=11
SearchBtn.Font=Enum.Font.GothamBold; SearchBtn.BorderSizePixel=0; SearchBtn.Parent=Main
Instance.new("UICorner",SearchBtn).CornerRadius=UDim.new(0,5)

local InvokeBtn=Instance.new("TextButton")
InvokeBtn.Size=UDim2.new(0,100,0,26); InvokeBtn.Position=UDim2.new(0,106,0,420)
InvokeBtn.BackgroundColor3=Color3.fromRGB(100,50,10); InvokeBtn.Text="[ INVOKE ALL ]"
InvokeBtn.TextColor3=Color3.fromRGB(255,180,80); InvokeBtn.TextSize=11
InvokeBtn.Font=Enum.Font.GothamBold; InvokeBtn.BorderSizePixel=0; InvokeBtn.Parent=Main
Instance.new("UICorner",InvokeBtn).CornerRadius=UDim.new(0,5)

local WHSendBtn=Instance.new("TextButton")
WHSendBtn.Size=UDim2.new(0,94,0,26); WHSendBtn.Position=UDim2.new(0,212,0,420)
WHSendBtn.BackgroundColor3=Color3.fromRGB(18,95,38); WHSendBtn.Text="[ WEBHOOK ]"
WHSendBtn.TextColor3=Color3.fromRGB(150,255,150); WHSendBtn.TextSize=11
WHSendBtn.Font=Enum.Font.GothamBold; WHSendBtn.BorderSizePixel=0; WHSendBtn.Parent=Main
Instance.new("UICorner",WHSendBtn).CornerRadius=UDim.new(0,5)

local ClrBtn=Instance.new("TextButton")
ClrBtn.Size=UDim2.new(1,-20,0,22); ClrBtn.Position=UDim2.new(0,10,0,452)
ClrBtn.BackgroundColor3=Color3.fromRGB(50,15,5); ClrBtn.Text="[ CLEAR ]"
ClrBtn.TextColor3=Color3.fromRGB(255,120,60); ClrBtn.TextSize=10
ClrBtn.Font=Enum.Font.GothamBold; ClrBtn.BorderSizePixel=0; ClrBtn.Parent=Main
Instance.new("UICorner",ClrBtn).CornerRadius=UDim.new(0,5)

-- tip
local tipL=Instance.new("TextLabel")
tipL.Size=UDim2.new(1,-20,0,22); tipL.Position=UDim2.new(0,10,0,478)
tipL.BackgroundColor3=Color3.fromRGB(10,10,22); tipL.BorderSizePixel=0
tipL.Text="  SEARCH = list matches  |  INVOKE ALL = call + show return data"
tipL.TextColor3=Color3.fromRGB(60,60,110); tipL.TextSize=9
tipL.Font=Enum.Font.Code; tipL.TextWrapped=true
tipL.TextXAlignment=Enum.TextXAlignment.Left; tipL.Parent=Main
Instance.new("UICorner",tipL).CornerRadius=UDim.new(0,4)

-- found remotes cache for invoke
local foundRemotes={}

-- SEARCH
SearchBtn.MouseButton1Click:Connect(function()
    local kw = SHB.Text:lower():gsub("%s","")
    if kw=="" then setStat("type a keyword first", Color3.fromRGB(230,60,60)); return end
    clearLines(); foundRemotes={}
    SearchBtn.Text="[ ... ]"
    SearchBtn.BackgroundColor3=Color3.fromRGB(10,10,80)
    setStat("searching for '"..kw.."'...", Color3.fromRGB(230,170,30))

    task.spawn(function()
        local count=0
        addLine("keyword: "..kw, Color3.fromRGB(100,180,255))
        addLine("", nil)

        for _, v in ipairs(RS:GetDescendants()) do
            if v.Name:lower():find(kw) then
                if v:IsA("RemoteFunction") or v:IsA("RemoteEvent") or v:IsA("BindableFunction") then
                    count=count+1
                    table.insert(foundRemotes, v)
                    local tag = v:IsA("RemoteFunction") and "RF" or v:IsA("RemoteEvent") and "RE" or "BF"
                    addLine("["..tag.."] "..v:GetFullName(), Color3.fromRGB(80,200,255))
                end
            end
        end

        addLine("", nil)
        addLine("found: "..count.." remotes matching '"..kw.."'", Color3.fromRGB(255,220,50))

        if count==0 then
            addLine("try a different keyword", Color3.fromRGB(230,170,30))
        else
            addLine("hit INVOKE ALL to call them + see data", Color3.fromRGB(150,150,200))
        end

        SearchBtn.Text="[ SEARCH ]"
        SearchBtn.BackgroundColor3=Color3.fromRGB(25,25,150)
        setStat("found "..count.." — hit INVOKE ALL", Color3.fromRGB(55,205,90))

        -- auto webhook if filled
        local wh=WHB.Text
        if wh:find("discord.com/api/webhooks") then
            task.spawn(function() sendWH(wh, "Remote Search: "..kw) end)
        end
    end)
end)

-- INVOKE ALL found remotes
InvokeBtn.MouseButton1Click:Connect(function()
    if #foundRemotes==0 then
        setStat("search first", Color3.fromRGB(230,60,60)); return
    end
    clearLines(); webhookLines={}
    InvokeBtn.Text="[ ... ]"
    InvokeBtn.BackgroundColor3=Color3.fromRGB(50,20,5)
    setStat("invoking "..#foundRemotes.." remotes...", Color3.fromRGB(230,170,30))

    task.spawn(function()
        local hits=0
        local argSets={
            {label="()",     args={}},
            {label="(plr)",  args={lp}},
            {label="(uid)",  args={lp.UserId}},
            {label="(name)", args={lp.Name}},
            {label="(true)", args={true}},
            {label="(1)",    args={1}},
        }

        for _, rf in ipairs(foundRemotes) do
            if rf:IsA("RemoteFunction") then
                local fp=rf:GetFullName()
                addLine("── "..fp, Color3.fromRGB(150,150,200))

                for _, combo in ipairs(argSets) do
                    local ok,res=pcall(function()
                        return rf:InvokeServer(table.unpack(combo.args))
                    end)
                    if ok and res~=nil then
                        hits=hits+1
                        addLine("⚡ args "..combo.label.." GOT DATA:", Color3.fromRGB(80,255,160))
                        deepDump(res, "  ")
                        addLine("", nil)
                        break
                    end
                    task.wait(0.1)
                end
            elseif rf:IsA("RemoteEvent") then
                addLine("RE: "..rf:GetFullName().." (listening...)", Color3.fromRGB(150,150,200))
                local conn
                conn=rf.OnClientEvent:Connect(function(...)
                    addLine("⚡ RE fired: "..rf:GetFullName(), Color3.fromRGB(80,255,160))
                    deepDump({...}, "  ")
                    conn:Disconnect()
                end)
            end
            task.wait(0.1)
        end

        addLine("", nil)
        addLine("⚡ hits with data: "..hits, Color3.fromRGB(255,220,50))

        InvokeBtn.Text="[ INVOKE ALL ]"
        InvokeBtn.BackgroundColor3=Color3.fromRGB(100,50,10)

        if hits>0 then
            setStat("⚡ "..hits.." hits — send webhook", Color3.fromRGB(80,255,160))
            local wh=WHB.Text
            if wh:find("discord.com/api/webhooks") then
                task.spawn(function()
                    sendWH(wh, "Invoke Results: "..SHB.Text)
                end)
            end
        else
            setStat("no data returned — try different keyword", Color3.fromRGB(230,170,30))
        end
    end)
end)

WHSendBtn.MouseButton1Click:Connect(function()
    local wh=WHB.Text
    if not wh:find("discord.com/api/webhooks") then
        setStat("paste webhook first", Color3.fromRGB(230,60,60)); return
    end
    if #webhookLines==0 then
        setStat("search + invoke first", Color3.fromRGB(230,60,60)); return
    end
    setStat("sending...", Color3.fromRGB(230,170,30))
    WHSendBtn.Text="[ SENDING ]"
    task.spawn(function()
        sendWH(wh, "Remote Finder — "..SHB.Text)
        WHSendBtn.Text="[ WEBHOOK ]"
    end)
end)

ClrBtn.MouseButton1Click:Connect(function()
    clearLines(); foundRemotes={}
    setStat("cleared", Color3.fromRGB(100,100,160))
end)

-- enter key fires search
SHB.FocusLost:Connect(function(enterPressed)
    if enterPressed then SearchBtn.MouseButton1Click:Fire() end
end)

print("[igc] Remote Finder loaded on "..EXEC)
