-- =============================================
-- [igc] Unit Dump UI + Webhook Sender
-- shows result on screen AND sends to Discord
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

if gui:FindFirstChild("UnitDumpUI") then gui.UnitDumpUI:Destroy() end

local SG = Instance.new("ScreenGui")
SG.Name="UnitDumpUI"; SG.ResetOnSpawn=false; SG.Parent=gui

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
TL.BackgroundTransparency=1; TL.Text="[igc] Unit Dump + Webhook"
TL.TextColor3=Color3.fromRGB(70,70,220); TL.TextSize=10
TL.Font=Enum.Font.Code; TL.TextXAlignment=Enum.TextXAlignment.Left; TL.Parent=TB

local XB=Instance.new("TextButton")
XB.Size=UDim2.new(0,20,0,20); XB.Position=UDim2.new(1,-24,0.5,-10)
XB.BackgroundColor3=Color3.fromRGB(130,20,20); XB.Text="✕"
XB.TextColor3=Color3.fromRGB(255,255,255); XB.TextSize=10
XB.Font=Enum.Font.GothamBold; XB.BorderSizePixel=0; XB.Parent=TB
Instance.new("UICorner",XB).CornerRadius=UDim.new(0,4)
XB.MouseButton1Click:Connect(function() SG:Destroy() end)

-- webhook input
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

-- status
local statL=Instance.new("TextLabel")
statL.Size=UDim2.new(1,-20,0,22); statL.Position=UDim2.new(0,10,0,83)
statL.BackgroundColor3=Color3.fromRGB(10,10,24); statL.BorderSizePixel=0
statL.Text=" press RUN while in trade screen"
statL.TextColor3=Color3.fromRGB(100,100,160); statL.TextSize=11
statL.Font=Enum.Font.Code; statL.Parent=Main
Instance.new("UICorner",statL).CornerRadius=UDim.new(0,4)

local function setStat(msg, col)
    statL.Text=" "..msg
    statL.TextColor3=col or Color3.fromRGB(55,205,90)
end

-- scroll output
local scrollBg=Instance.new("Frame")
scrollBg.Size=UDim2.new(1,-20,0,290); scrollBg.Position=UDim2.new(0,10,0,113)
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

local lineCount = 0
local webhookLines = {} -- raw text for webhook

local function addLine(txt, col)
    lineCount = lineCount + 1
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

-- webhook sender
local function sendToWebhook(wh)
    if not wh or not wh:find("discord.com/api/webhooks") then
        setStat("invalid webhook", Color3.fromRGB(230,60,60)); return
    end

    local body = "**[igc] Unit Dump**\n"
        .."**Player:** "..lp.Name.." (`"..lp.UserId.."`)\n"
        .."**Executor:** "..EXEC.."\n\n"
        .."```\n"
        ..table.concat(webhookLines, "\n"):sub(1,1800)
        .."\n```"

    local chunks = {}
    for i=1,#body,1900 do table.insert(chunks, body:sub(i,i+1899)) end

    for idx, chunk in ipairs(chunks) do
        local t2 = #chunks>1 and ("Unit Dump ["..idx.."/"..#chunks.."]") or "Unit Dump — get_evolve_ready_units"
        pcall(function()
            httpFn({
                Url    = wh,
                Method = "POST",
                Headers= {["Content-Type"]="application/json"},
                Body   = HS:JSONEncode({
                    username = "[igc] Unit Dump",
                    embeds   = {{
                        title       = t2,
                        description = chunk,
                        color       = 0x22FF88,
                        footer      = { text = EXEC.." · "..lp.Name.." · "..lp.UserId }
                    }}
                })
            })
        end)
        if idx < #chunks then task.wait(1.2) end
    end

    setStat("sent to Discord ✓", Color3.fromRGB(80,255,160))
end

-- deep dump
local function deepDump(val, prefix, depth)
    depth = depth or 0
    prefix = prefix or ""
    if depth > 6 then addLine(prefix.."...", Color3.fromRGB(100,100,140)); return end

    if type(val) == "table" then
        local count = 0
        for k, v in pairs(val) do
            count = count + 1
            local key = prefix.."["..tostring(k).."]"
            if type(v) == "table" then
                addLine(key.." = {", Color3.fromRGB(180,160,255))
                deepDump(v, prefix.."  ", depth+1)
                addLine(prefix.."}", Color3.fromRGB(180,160,255))
            elseif type(v) == "string" then
                local isUUID = v:match("^%x+%-%x+%-%x+%-%x+%-%x+$")
                addLine(key..' = "'..v..'"',
                    isUUID and Color3.fromRGB(80,255,160) or Color3.fromRGB(220,220,180))
            elseif type(v) == "number" or type(v) == "boolean" then
                addLine(key.." = "..tostring(v), Color3.fromRGB(255,180,80))
            elseif type(v) == "userdata" then
                local ok, nm = pcall(function() return v.Name end)
                addLine(key.." = [Inst:"..(ok and nm or "?").."]", Color3.fromRGB(150,150,200))
            else
                addLine(key.." = "..tostring(v), Color3.fromRGB(180,180,180))
            end
            if count > 60 then addLine(prefix.."...more", Color3.fromRGB(120,120,140)); break end
        end
        if count == 0 then addLine(prefix.."(empty)", Color3.fromRGB(100,100,120)) end
    else
        addLine(prefix..tostring(val), Color3.fromRGB(220,220,180))
    end
end

-- buttons row
local RunBtn=Instance.new("TextButton")
RunBtn.Size=UDim2.new(0,90,0,26); RunBtn.Position=UDim2.new(0,10,0,412)
RunBtn.BackgroundColor3=Color3.fromRGB(25,25,150); RunBtn.Text="[ RUN ]"
RunBtn.TextColor3=Color3.fromRGB(170,170,255); RunBtn.TextSize=11
RunBtn.Font=Enum.Font.GothamBold; RunBtn.BorderSizePixel=0; RunBtn.Parent=Main
Instance.new("UICorner",RunBtn).CornerRadius=UDim.new(0,5)

local SendWHBtn=Instance.new("TextButton")
SendWHBtn.Size=UDim2.new(0,120,0,26); SendWHBtn.Position=UDim2.new(0,106,0,412)
SendWHBtn.BackgroundColor3=Color3.fromRGB(18,95,38); SendWHBtn.Text="[ SEND WEBHOOK ]"
SendWHBtn.TextColor3=Color3.fromRGB(150,255,150); SendWHBtn.TextSize=11
SendWHBtn.Font=Enum.Font.GothamBold; SendWHBtn.BorderSizePixel=0; SendWHBtn.Parent=Main
Instance.new("UICorner",SendWHBtn).CornerRadius=UDim.new(0,5)

local ClrBtn=Instance.new("TextButton")
ClrBtn.Size=UDim2.new(0,74,0,26); ClrBtn.Position=UDim2.new(0,232,0,412)
ClrBtn.BackgroundColor3=Color3.fromRGB(60,20,8); ClrBtn.Text="[ CLEAR ]"
ClrBtn.TextColor3=Color3.fromRGB(255,160,80); ClrBtn.TextSize=11
ClrBtn.Font=Enum.Font.GothamBold; ClrBtn.BorderSizePixel=0; ClrBtn.Parent=Main
Instance.new("UICorner",ClrBtn).CornerRadius=UDim.new(0,5)

-- note
local noteL=Instance.new("TextLabel")
noteL.Size=UDim2.new(1,-20,0,40); noteL.Position=UDim2.new(0,10,0,446)
noteL.BackgroundColor3=Color3.fromRGB(10,10,22); noteL.BorderSizePixel=0
noteL.Text="  Open trade → RUN → results show on screen + SEND WEBHOOK fires to Discord"
noteL.TextColor3=Color3.fromRGB(70,70,120); noteL.TextSize=9
noteL.Font=Enum.Font.Code; noteL.TextWrapped=true
noteL.TextXAlignment=Enum.TextXAlignment.Left; noteL.TextYAlignment=Enum.TextYAlignment.Center
noteL.Parent=Main
Instance.new("UICorner",noteL).CornerRadius=UDim.new(0,4)

ClrBtn.MouseButton1Click:Connect(function()
    clearLines()
    setStat("cleared", Color3.fromRGB(100,100,160))
end)

SendWHBtn.MouseButton1Click:Connect(function()
    local wh = WHB.Text
    if not wh:find("discord.com/api/webhooks") then
        setStat("paste webhook first", Color3.fromRGB(230,60,60)); return
    end
    if #webhookLines == 0 then
        setStat("run first to get data", Color3.fromRGB(230,60,60)); return
    end
    setStat("sending...", Color3.fromRGB(230,170,30))
    SendWHBtn.Text="[ SENDING... ]"
    task.spawn(function()
        sendToWebhook(wh)
        SendWHBtn.Text="[ SEND WEBHOOK ]"
    end)
end)

-- main run
RunBtn.MouseButton1Click:Connect(function()
    clearLines()
    RunBtn.Text="[ ... ]"
    RunBtn.BackgroundColor3=Color3.fromRGB(10,10,80)
    setStat("searching...", Color3.fromRGB(230,170,30))

    task.spawn(function()
        local rf = RS:FindFirstChild("get_evolve_ready_units", true)

        if not rf then
            setStat("remote not found — scanning...", Color3.fromRGB(230,170,30))
            addLine("get_evolve_ready_units not in RS", Color3.fromRGB(230,60,60))
            addLine("scanning all RFs with unit/evolve/inv...", Color3.fromRGB(150,150,200))
            addLine("", nil)

            local tried = 0
            for _, v in ipairs(RS:GetDescendants()) do
                if v:IsA("RemoteFunction") then
                    local n = v.Name:lower()
                    if n:find("unit") or n:find("evolve") or n:find("inv") or n:find("offer") then
                        tried = tried + 1
                        addLine("trying: "..v:GetFullName(), Color3.fromRGB(150,150,200))
                        local ok, res = pcall(function() return v:InvokeServer() end)
                        if ok and res ~= nil then
                            addLine("⚡ HIT: "..v:GetFullName(), Color3.fromRGB(80,255,160))
                            deepDump(res, "  ")
                            addLine("", nil)
                        else
                            addLine("  → nil", Color3.fromRGB(80,80,100))
                        end
                        task.wait(0.1)
                    end
                end
            end

            if tried == 0 then
                addLine("no matching remotes found", Color3.fromRGB(230,60,60))
            end

            RunBtn.Text="[ RUN ]"
            RunBtn.BackgroundColor3=Color3.fromRGB(25,25,150)
            setStat("done — send webhook to log it", Color3.fromRGB(55,205,90))
            return
        end

        addLine("⚡ remote: "..rf:GetFullName(), Color3.fromRGB(80,180,255))
        addLine("", nil)

        local argSets = {
            {label="no args",  args={}},
            {label="+player",  args={lp}},
            {label="+userId",  args={lp.UserId}},
            {label="+name",    args={lp.Name}},
            {label="+true",    args={true}},
            {label="+1",       args={1}},
        }

        local gotHit = false

        for _, combo in ipairs(argSets) do
            addLine("── trying: "..combo.label, Color3.fromRGB(130,130,180))
            local ok, res = pcall(function()
                return rf:InvokeServer(table.unpack(combo.args))
            end)
            if ok and res ~= nil then
                gotHit = true
                addLine("⚡ GOT DATA:", Color3.fromRGB(80,255,160))
                deepDump(res, "  ")
                addLine("", nil)
                if type(res) == "table" then
                    local cnt = 0
                    for _ in pairs(res) do cnt=cnt+1 end
                    addLine("⚡ total entries: "..cnt, Color3.fromRGB(255,220,50))
                end
                break
            else
                local err = ok and "nil" or tostring(res):sub(1,60)
                addLine("  → "..err, Color3.fromRGB(80,80,100))
            end
            task.wait(0.15)
        end

        addLine("", nil)

        RunBtn.Text="[ RUN ]"
        RunBtn.BackgroundColor3=Color3.fromRGB(25,25,150)

        if gotHit then
            setStat("⚡ got data — hit SEND WEBHOOK", Color3.fromRGB(80,255,160))

            -- auto send if webhook already filled
            local wh = WHB.Text
            if wh:find("discord.com/api/webhooks") then
                setStat("⚡ auto-sending to webhook...", Color3.fromRGB(230,170,30))
                task.spawn(function()
                    sendToWebhook(wh)
                end)
            end
        else
            addLine("all args returned nil", Color3.fromRGB(230,60,60))
            addLine("be in active trade with someone", Color3.fromRGB(230,170,30))
            addLine("then RUN again", Color3.fromRGB(230,170,30))
            setStat("no data — open trade first", Color3.fromRGB(230,170,30))
        end
    end)
end)

print("[igc] Unit Dump UI loaded on "..EXEC)
