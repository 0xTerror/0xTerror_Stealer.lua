--[[ 0xTerror Stealer — Keyless Standalone
     Delta Executor | Luau | WindUI | Auto Steal (one-shot, not loop) ]]

---------- SERVICES ----------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")  local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")            local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")    local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")              
local LocalPlayer = Players.LocalPlayer                         local Camera = Workspace.CurrentCamera
                                                                ---------- WINDUI ----------                                    local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/main.lua"))()

---------- CONFIG ----------
local CFG = {
    AutoSteal = false, AutoHatch = false, AutoPlace = false,
    StealDelay = 0.5, ReturnSpeed = 50, Movement = "Tween",
    MinRarity = "Common", MinSize = 0, MinValue = 0,
    BiomeTarget = "All", TargetMutations = {},
    KillAura = false, AntiStun = true, AntiAFK = true,              HitRange = 10, ESPColor = Color3.fromRGB(255, 85, 85),
    ShowDistance = true, ShowHealth = true,
    NotifyRare = true, ToggleKey = "RightControl",
}

---------- CONSTANTS ----------
local RARITIES = {"Common","Uncommon","Rare","Epic","Legendary","Mythic","Cosmic","Secret","Eternal","Divine"}
local RARITY_WEIGHTS = {Common=1,Uncommon=2,Rare=3,Epic=4,Legendary=5,Mythic=6,Cosmic=7,Secret=8,Eternal=9,Divine=10}
local RARITY_COLORS = {
    Common = Color3.fromRGB(180,180,180), Uncommon = Color3.fromRGB(80,200,80),
    Rare = Color3.fromRGB(80,130,255), Epic = Color3.fromRGB(160,80,255),
    Legendary = Color3.fromRGB(255,170,0), Mythic = Color3.fromRGB(255,85,85),
    Cosmic = Color3.fromRGB(255,0,255), Secret = Color3.fromRGB(0,255,255),
    Eternal = Color3.fromRGB(163,53,238), Divine = Color3.fromRGB(255,215,0),
}
local BIOMES = {"All","Forest","Lake","Desert","Jungle","Snow","Volcano","Abyss Ocean","Prehistoric","Cosmic","Cherry Blossom","Titan Temple"}
local MUTATIONS = {"None","Rainbow","Shadow","Golden","Crystal","Galactic","Infernal","Frozen","Toxic","Ethereal"}
local PlaceId = game.PlaceId

---------- SESSION STATS ----------
local STATS = {
    eggsStolen = 0, eggsHatched = 0, rareStolen = 0, totalValue = 0,
    startTime = os.time(), currentTarget = "None", statusText = "Idle",
    lastStolenRarity = "None", lastStolenSize = 0, lootLog = {},
}

---------- UTILITIES ----------
local function getRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function getEggsFolder()
    return Workspace:FindFirstChild("Eggs")
end
local function getPlayerBase()
    local c = LocalPlayer.Character
    if not c then return nil end
    local root = c:FindFirstChild("HumanoidRootPart")
    return root and root.Position
end
local function getRemotes()
    local sae = ReplicatedStorage:FindFirstChild("StealAnEgg") or ReplicatedStorage:FindFirstChild("SAE") or ReplicatedStorage:FindFirstChild("Game")
    if sae then return sae:FindFirstChild("Remotes") or sae:FindFirstChild("Events") or sae end
    return ReplicatedStorage
end
local function getEggRarity(egg)
    return egg:GetAttribute("Rarity") or (egg:FindFirstChild("Rarity") and egg.Rarity.Value) or "Common"
end
local function getEggSize(egg)
    return egg:GetAttribute("Size") or (egg:FindFirstChild("Size") and egg.Size.Value) or 1
end
local function getEggValue(egg)
    local r = getEggRarity(egg)
    local s = getEggSize(egg)
    return (RARITY_WEIGHTS[r] or 1) * (type(s) == "number" and s or 1)
end
local function getEggPosition(egg)
    if egg:IsA("BasePart") then return egg.Position end
    local p = egg:FindFirstChildOfClass("Part") or egg:FindFirstChildOfClass("MeshPart")
    return p and p.Position or egg:GetPivot().Position
end
local function formatTime(sec)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end
local function showToast(text, color, duration)
    task.spawn(function()
        pcall(function()
            StarterGui:SetCore("SendNotification", {Title = "0xTerror", Text = text, Duration = duration or 3})
        end)
    end)
end

---------- MOVEMENT ----------
local function tweenMove(root, target, speed)
    local dist = (target - root.Position).Magnitude
    local dur = dist / math.max(speed, 1)
    local tween = TweenService:Create(root, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target)})
    tween:Play(); tween.Completed:Wait()
end
local function cframeMove(root, target)
    root.CFrame = CFrame.new(target)
end
local function walkMove(root, target)
    local hum = getHumanoid()
    if hum then hum:MoveTo(target); hum.MoveToFinished:Wait() end
end
local function moveToPosition(target)
    local root = getRoot()
    if not root then return end
    if CFG.Movement == "CFrame" then cframeMove(root, target)
    elseif CFG.Movement == "Tween" then tweenMove(root, target, CFG.ReturnSpeed)
    else walkMove(root, target) end
end

---------- FILTERING ----------
local function passesFilters(egg)
    local rarity = getEggRarity(egg)
    local size = getEggSize(egg)
    local value = getEggValue(egg)
    local rarityIdx = table.find(RARITIES, rarity) or 1
    local minIdx = table.find(RARITIES, CFG.MinRarity) or 1
    if rarityIdx < minIdx then return false end
    if size < CFG.MinSize then return false end
    if value < CFG.MinValue then return false end
    if #CFG.TargetMutations > 0 then
        local found = false
        for _, m in ipairs(CFG.TargetMutations) do
            if m == (egg:GetAttribute("Mutation") or "None") then found = true; break end
        end
        if not found then return false end
    end
    if CFG.BiomeTarget ~= "All" then
        local area = egg:GetAttribute("Area") or egg:GetAttribute("Biome") or ""
        if area ~= CFG.BiomeTarget then return false end
    end
    return true
end

---------- EGG SCANNER ----------
local function findAllEggs()
    local eggs = {}
    local folder = getEggsFolder()
    if not folder then return eggs end
    local function scan(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if (child:IsA("Model") or child:IsA("BasePart"))
                and (child:GetAttribute("Rarity") or child:GetAttribute("Collected") ~= nil
                or child:FindFirstChild("Rarity") or child:FindFirstChild("EggType")) then
                table.insert(eggs, child)
            end
            if child:IsA("Folder") or child:IsA("Model") then scan(child) end
        end
    end
    scan(folder)
    return eggs
end
local function getBestEgg()
    local eggs = findAllEggs()
    local best, bestVal = nil, -math.huge
    for _, egg in ipairs(eggs) do
        if not egg:GetAttribute("Collected") and passesFilters(egg) then
            local val = getEggValue(egg)
            if val > bestVal then bestVal = val; best = egg end
        end
    end
    return best
end
local function getTop4Eggs()
    local eggs = findAllEggs()
    local candidates = {}
    for _, egg in ipairs(eggs) do
        if not egg:GetAttribute("Collected") and passesFilters(egg) then
            table.insert(candidates, {egg = egg, value = getEggValue(egg), rarity = getEggRarity(egg)})
        end
    end
    table.sort(candidates, function(a, b) return a.value > b.value end)
    local top4 = {}
    for i = 1, math.min(4, #candidates) do top4[i] = candidates[i] end
    return top4
end

---------- COLLECTION ----------
local function firePickup(egg)
    local remotes = getRemotes()
    local names = {"Pickup","Steal","Collect","GrabEgg","TakeEgg","PickUpEgg","StealEgg","CollectEgg","EggPickup","EggSteal"}
    for _, n in ipairs(names) do
        local r = remotes:FindFirstChild(n)
        if r and r:IsA("RemoteEvent") then r:FireServer(egg); return true end
    end
    for _, r in ipairs(remotes:GetChildren()) do
        if r:IsA("RemoteEvent") and r.Name:lower():find("egg") then r:FireServer(egg); return true end
    end
    return false
end

---------- ANTI-AFK ----------
local function setupAntiAFK()
    if not CFG.AntiAFK then return end
    task.spawn(function()
        while CFG.AntiAFK do
            local hum = getHumanoid()
            if hum and LocalPlayer.Character then
                pcall(function()
                    hum:Move(Vector3.new(0, 0, 0.05))
                end)
            end
            task.wait(4)
        end
    end)
end

---------- ANTI-STUN ----------
local function setupAntiStun()
    if not CFG.AntiStun then return end
    local hum = getHumanoid()
    if not hum then return end
    local mt = getrawmetatable(hum)
    local old = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if m == "Kick" or m == "kick" then return nil end
        return old(self, ...)
    end)
    setreadonly(mt, true)
    task.spawn(function()
        while CFG.AntiStun do
            local c = LocalPlayer.Character
            if c then
                local h = c:FindFirstChildOfClass("Humanoid")
                if h then
                    pcall(function()
                        h.PlatformStand = false
                        h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                        h:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
                        h:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
                    end)
                end
            end
            task.wait(0.5)
        end
    end)
end

---------- KILL AURA ----------
local function doKillAura()
    if not CFG.KillAura then return end
    local root = getRoot()
    if not root then return end
    local remotes = getRemotes()
    local names = {"Hit","Attack","Punch","HitPlayer","Damage","AttackPlayer"}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local tr = player.Character:FindFirstChild("HumanoidRootPart")
            local th = player.Character:FindFirstChildOfClass("Humanoid")
            if tr and th and th.Health > 0 then
                if (tr.Position - root.Position).Magnitude <= CFG.HitRange then
                    for _, n in ipairs(names) do
                        local r = remotes:FindFirstChild(n)
                        if r and r:IsA("RemoteEvent") then r:FireServer(player); break end
                    end
                end
            end
        end
    end
end

---------- ESP ----------
local espPool = {}
local function destroyAllESP()
    for _, e in ipairs(espPool) do
        if e and e.Remove then pcall(function() e:Remove() end) end
    end
    espPool = {}
end
local function makeESP(part, text, color, size)
    local ok, esp = pcall(function()
        local e = Drawing.new("Text")
        e.Text = text; e.Position = Vector2.new(0, 0); e.Color = color or Color3.new(1, 1, 1)
        e.Size = size or 14; e.Center = true; e.Outline = true; e.OutlineColor = Color3.new(0, 0, 0)
        e.Visible = false
        return e
    end)
    if not ok then return nil end
    table.insert(espPool, esp)
    return esp
end
local function updateEggESP()
    destroyAllESP()
    if not CFG.EggESP then return end
    task.spawn(function()
        while CFG.EggESP do
            local eggs = findAllEggs()
            for _, egg in ipairs(eggs) do
                if not egg:GetAttribute("Collected") then
                    local part = egg:IsA("BasePart") and egg or egg:FindFirstChildOfClass("Part") or egg:FindFirstChildOfClass("MeshPart")
                    if part then
                        local rarity = getEggRarity(egg)
                        local size = getEggSize(egg)
                        local dist = ""
                        local root = getRoot()
                        if root and CFG.ShowDistance then dist = string.format(" [%dm]", math.floor((getEggPosition(egg) - root.Position).Magnitude)) end
                        local label = string.format("%s | %skg%s", rarity, tostring(size), dist)
                        local color = RARITY_COLORS[rarity] or CFG.ESPColor
                        local esp = makeESP(part, label, color)
                        if esp then
                            task.spawn(function()
                                while true do
                                    if not esp or not esp.Remove then break end
                                    if part and part.Parent then
                                        local pos, on = Camera:WorldToViewportPoint(part.Position)
                                        if on then esp.Position = Vector2.new(pos.X, pos.Y - 20); esp.Visible = true
                                        else esp.Visible = false end
                                    else esp.Visible = false; break end
                                    RunService.RenderStepped:Wait()
                                end
                                pcall(function() esp:Remove() end)
                            end)
                        end
                    end
                end
            end
            task.wait(2)
        end
    end)
end

---------- AUTO STEAL (ONE-SHOT, NOT LOOP) ----------
local function autoSteal()
    local root = getRoot()
    if not root then showToast("No character", Color3.fromRGB(255, 85, 85)); return end
    local bestEgg = getBestEgg()
    if not bestEgg then showToast("No eggs found", Color3.fromRGB(255, 85, 85)); return end

    local eggPos = getEggPosition(bestEgg)
    local rarity = getEggRarity(bestEgg)
    local size = getEggSize(bestEgg)
    local value = getEggValue(bestEgg)

    STATS.currentTarget = rarity .. " " .. tostring(size) .. "kg"
    STATS.statusText = "Stealing"
    showToast("Targeting " .. rarity .. " egg", RARITY_COLORS[rarity] or Color3.fromRGB(255, 85, 85), 2)

    moveToPosition(eggPos)
    task.wait(CFG.StealDelay + math.random() * 0.3)

    local success = firePickup(bestEgg)
    if success then
        STATS.eggsStolen = STATS.eggsStolen + 1
        STATS.totalValue = STATS.totalValue + value
        STATS.lastStolenRarity = rarity
        STATS.lastStolenSize = size
        local rarityIdx = RARITY_WEIGHTS[rarity] or 1
        if rarityIdx >= 5 then
            STATS.rareStolen = STATS.rareStolen + 1
            if CFG.NotifyRare then
                showToast("Rare! " .. rarity .. " " .. tostring(size) .. "kg", Color3.fromRGB(255, 170, 0), 4)
            end
        else
            showToast(rarity .. " stolen", RARITY_COLORS[rarity], 2)
        end
        if CFG.AutoPlace then
            task.wait(0.2)
            local remotes = getRemotes()
            for _, n in ipairs({"Place","PlaceEgg","PutEgg","Deploy","PutDown"}) do
                local r = remotes:FindFirstChild(n)
                if r and r:IsA("RemoteEvent") then r:FireServer(bestEgg); break end
            end
        end
        local basePos = getPlayerBase()
        if basePos then
            STATS.statusText = "Returning"
            moveToPosition(basePos)
        end
    end
    STATS.currentTarget = "None"
    STATS.statusText = "Idle"
end

---------- GUI ----------
local Window, guiOk = nil, false
pcall(function()
    local ok, err = pcall(function()
        local parent = (syn and syn.protect_gui) and syn.protect_gui(game:GetService("CoreGui")) or game:GetService("CoreGui")
        if gethui then parent = gethui() end
        Window = WindUI:CreateWindow({Title = "0xTerror Stealer", Size = UDim2.new(0,400,0,500)})
        Window:SetParent(parent)
    end)
    guiOk = ok
    if not ok then warn("[0xTerror] GUI create failed: " .. tostring(err)) end
end)

if guiOk then
---------- DASHBOARD ----------
local DashTab = Window:AddTab("Dashboard")
local dashLabels = {}
local DashInfo = DashTab:AddLeftGroupbox("Live Stats")
dashLabels.status = DashInfo:AddLabel("Status: Idle")
dashLabels.target = DashInfo:AddLabel("Target: None")
dashLabels.stolen = DashInfo:AddLabel("Stolen: 0")
dashLabels.rare = DashInfo:AddLabel("Rare: 0")
dashLabels.value = DashInfo:AddLabel("Value: 0")
dashLabels.last = DashInfo:AddLabel("Last: None")
DashInfo:AddDivider()
DashInfo:AddButton({Text = "Steal Best Egg", Func = function() autoSteal() end})
DashInfo:AddButton({Text = "Return to Base", Func = function()
    local base = getPlayerBase()
    if base then moveToPosition(base); showToast("At base", Color3.fromRGB(85, 170, 255)) end
end})
DashInfo:AddButton({Text = "Hatch All", Func = function()
    local remotes = getRemotes()
    for _, n in ipairs({"Hatch","HatchEgg","HatchAll","DoHatch"}) do
        local r = remotes:FindFirstChild(n)
        if r and r:IsA("RemoteEvent") then r:FireServer(); break end
    end
end})

---------- AUTO STEAL ----------
local FarmTab = Window:AddTab("Auto Steal")
local FarmLeft = FarmTab:AddLeftGroupbox("Settings")
FarmLeft:AddButton({Text = "Steal Best Egg Now", Func = function() autoSteal() end})
FarmLeft:AddSlider("StealDelay", {Text = "Steal Delay (s)", Default = 0.5, Min = 0, Max = 3, Rounding = 0, Callback = function(v) CFG.StealDelay = v end})
FarmLeft:AddSlider("ReturnSpeed", {Text = "Move Speed (studs/s)", Default = 50, Min = 10, Max = 300, Rounding = 0, Callback = function(v) CFG.ReturnSpeed = v end})
FarmLeft:AddDropdown("MovementMode", {Text = "Movement", Options = {"Safe","Tween","CFrame"}, Default = "Tween", Callback = function(v) CFG.Movement = v end})

local FarmRight = FarmTab:AddRightGroupbox("Filters")
FarmRight:AddDropdown("MinRarity", {Text = "Min Rarity", Options = RARITIES, Default = "Common", Callback = function(v) CFG.MinRarity = v end})
FarmRight:AddSlider("MinSize", {Text = "Min Size (kg)", Default = 0, Min = 0, Max = 1000, Rounding = 0, Callback = function(v) CFG.MinSize = v end})
FarmRight:AddSlider("MinValue", {Text = "Min Value", Default = 0, Min = 0, Max = 100, Rounding = 0, Callback = function(v) CFG.MinValue = v end})
FarmRight:AddDropdown("BiomeTarget", {Text = "Biome", Options = BIOMES, Default = "All", Callback = function(v) CFG.BiomeTarget = v end})

---------- TOP 4 LEADERBOARD ----------
local Top4Tab = Window:AddTab("Top 4 Eggs")
local Top4Group = Top4Tab:AddLeftGroupbox("Top 4 Eggs by Value")
local top4Labels = {}
for i = 1, 4 do
    top4Labels[i] = Top4Group:AddLabel("Slot " .. i .. ": Empty")
end
task.spawn(function()
    while true do
        local top4 = getTop4Eggs()
        for i = 1, 4 do
            if top4[i] then
                local e = top4[i]
                local txt = string.format("Slot %d: %s | %skg | $%s | %dm", i, e.rarity, tostring(e.egg and getEggSize(e.egg) or 0), tostring(e.value), math.floor((getEggPosition(e.egg) - (getRoot() and getRoot().Position or Vector3.new())).Magnitude))
                pcall(function() top4Labels[i]:SetText(txt) end)
            else
                pcall(function() top4Labels[i]:SetText("Slot " .. i .. ": Empty") end)
            end
        end
        task.wait(2)
    end
end)

---------- ESP ----------
local ESPTab = Window:AddTab("ESP")
local ESPLeft = ESPTab:AddLeftGroupbox("Overlays")
ESPLeft:AddToggle("EggESP", {Text = "Egg ESP", Default = false, Callback = function(v)
    CFG.EggESP = v
    if v then task.spawn(updateEggESP) end
end})
ESPLeft:AddToggle("AntiStun", {Text = "Anti-Stun", Default = CFG.AntiStun, Callback = function(v)
    CFG.AntiStun = v; setupAntiStun()
end})
ESPLeft:AddToggle("AntiAFK", {Text = "Anti-AFK", Default = CFG.AntiAFK, Callback = function(v)
    CFG.AntiAFK = v; setupAntiAFK()
end})
local ESPRight = ESPTab:AddRightGroupbox("Options")
ESPRight:AddToggle("ShowDistance", {Text = "Show Distance", Default = true, Callback = function(v) CFG.ShowDistance = v end})
pcall(function() ESPRight:AddColorPicker("ESPColor", {Text = "ESP Color", Default = Color3.fromRGB(255, 85, 85), Callback = function(v) CFG.ESPColor = v end}) end)
pcall(function() ESPRight:AddKeybind("ToggleAutoSteal", {Text = "Toggle (RightControl)", Default = "RightControl", Callback = function(state) if state then autoSteal() end end}) end)

---------- SETTINGS ----------
local SettingsTab = Window:AddTab("Settings")
local SettingsLeft = SettingsTab:AddLeftGroupbox("UI")
SettingsLeft:AddToggle("AntiStun", {Text = "Anti-Stun", Default = CFG.AntiStun, Callback = function(v)
    CFG.AntiStun = v; setupAntiStun()
end})
SettingsLeft:AddToggle("AntiAFK", {Text = "Anti-AFK", Default = CFG.AntiAFK, Callback = function(v)
    CFG.AntiAFK = v; setupAntiAFK()
end})
SettingsLeft:AddDivider()
SettingsLeft:AddButton({Text = "Destroy ESP", Func = destroyAllESP})
SettingsLeft:AddButton({Text = "Destroy GUI", Func = function()
    destroyAllESP(); pcall(function() WindUI:Destroy() end)
end})

---------- KEYBIND ----------
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightControl then autoSteal() end
end)

---------- DASHBOARD UPDATER ----------
task.spawn(function()
    while true do
        pcall(function() dashLabels.status:SetText("Status: " .. STATS.statusText) end)
        pcall(function() dashLabels.target:SetText("Target: " .. STATS.currentTarget) end)
        pcall(function() dashLabels.stolen:SetText("Stolen: " .. STATS.eggsStolen) end)
        pcall(function() dashLabels.rare:SetText("Rare: " .. STATS.rareStolen) end)
        pcall(function() dashLabels.value:SetText("Value: " .. STATS.totalValue) end)
        pcall(function() dashLabels.last:SetText("Last: " .. STATS.lastStolenRarity .. " " .. tostring(STATS.lastStolenSize) .. "kg") end)
        task.wait(1)
    end
end)
end

---------- INIT ----------
setupAntiAFK()
setupAntiStun()
pcall(function() if guiOk then WindUI:Notify("0xTerror Stealer loaded", 5) end end)