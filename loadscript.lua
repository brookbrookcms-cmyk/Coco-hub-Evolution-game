-- Evolution game (place 74931828101115)
-- Run in an executor that supports queue_on_teleport and game:HttpGet.
local PLACE_ID = 74931828101115
local SCRIPT_URL = "https://raw.githubusercontent.com/brookbrookcms-cmyk/Coco-hub-Evolution-game/main/loadscript.lua"
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

if game.PlaceId ~= PLACE_ID then
    error("Coco Evolution: run this in Evolution game (place " .. PLACE_ID .. ")")
end

local env = getgenv()
if env.CocoEvolutionRunningJob == game.JobId then return end
env.CocoEvolutionRunningJob = game.JobId

local state = env.CocoEvolutionState or {phase = "scan", index = 1, bestHeight = -1}
env.CocoEvolutionState = nil

local function status(message)
    print("[Coco Evolution] " .. message)
end

local function feetAndInches(text)
    text = tostring(text)
    local feet, inches = text:match("(%d+)%s*['′]%s*(%d+)")
    if not feet then
        feet, inches = text:match("(%d+)%s*[Ff][Tt]%s*(%d+)%s*[Ii][Nn]")
    end
    if feet and inches and tonumber(inches) < 12 then
        return tonumber(feet) * 12 + tonumber(inches)
    end
    local number = tonumber(text:match("^%s*([%d%.]+)%s*$"))
    if number and number >= 1 and number <= 30 then
        return math.floor(number * 12 + 0.5) -- numeric height in feet
    end
    if number and number >= 36 and number <= 300 then
        return math.floor(number + 0.5) -- numeric height in inches
    end
end

local function ageFrom(value)
    local number = tonumber(value)
    if not number then
        number = tonumber(tostring(value):match("[Aa]ge%s*:?%s*(%d+)"))
    end
    if number and number >= 0 and number <= 200 then return number end
end

local function readNamed(root, wanted, parser)
    if not root then return nil end
    for _, object in ipairs(root:GetDescendants()) do
        if object.Name:lower() == wanted then
            if object:IsA("ValueBase") then
                local result = parser(object.Value)
                if result then return result end
            elseif object:IsA("TextLabel") or object:IsA("TextButton") then
                local result = parser(object.Text)
                if result then return result end
            end
        end
        for name, value in pairs(object:GetAttributes()) do
            if name:lower() == wanted then
                local result = parser(value)
                if result then return result end
            end
        end
    end
    for name, value in pairs(root:GetAttributes()) do
        if name:lower() == wanted then
            local result = parser(value)
            if result then return result end
        end
    end
end

local function readDisplayed(root, parser)
    if not root then return nil end
    for _, object in ipairs(root:GetDescendants()) do
        if object:IsA("TextLabel") or object:IsA("TextButton") then
            local result = parser(object.Text)
            if result then return result end
        end
    end
end

local function heightOf(player)
    local result = readNamed(player, "height", feetAndInches)
        or readNamed(player.Character, "height", feetAndInches)
        or readDisplayed(player.Character, feetAndInches)
    if player == LocalPlayer then
        result = result or readNamed(player:FindFirstChild("PlayerGui"), "height", feetAndInches)
            or readDisplayed(player:FindFirstChild("PlayerGui"), feetAndInches)
    end
    return result
end

local function ageOf(player)
    local result = readNamed(player, "age", ageFrom)
        or readNamed(player.Character, "age", ageFrom)
        or readDisplayed(player.Character, ageFrom)
    if player == LocalPlayer then
        result = result or readNamed(player:FindFirstChild("PlayerGui"), "age", ageFrom)
            or readDisplayed(player:FindFirstChild("PlayerGui"), ageFrom)
    end
    return result
end

local function queueNext()
    local queue = queue_on_teleport or (syn and syn.queue_on_teleport)
    if type(queue) ~= "function" then
        error("Coco Evolution: executor must support queue_on_teleport for server scanning")
    end
    local encoded = HttpService:JSONEncode(state)
    queue("getgenv().CocoEvolutionState = game:GetService('HttpService'):JSONDecode(" .. string.format("%q", encoded) .. "); loadstring(game:HttpGet(" .. string.format("%q", SCRIPT_URL) .. "))()")
end

local function teleport(jobId)
    queueNext()
    status("Joining server " .. jobId)
    TeleportService:TeleportToPlaceInstance(PLACE_ID, jobId, LocalPlayer)
end

local function listServers()
    local servers, seen = {game.JobId}, {[game.JobId] = true}
    local cursor
    repeat
        local url = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"
        if cursor then url = url .. "&cursor=" .. HttpService:UrlEncode(cursor) end
        local response = HttpService:JSONDecode(game:HttpGet(url))
        for _, server in ipairs(response.data or {}) do
            if server.id and not seen[server.id] and server.playing < server.maxPlayers then
                seen[server.id] = true
                table.insert(servers, server.id)
            end
        end
        cursor = response.nextPageCursor
    until not cursor
    return servers
end

if state.phase == "scan" then
    state.servers = state.servers or listServers()
    while state.index <= #state.servers do
        local jobId = state.servers[state.index]
        if game.JobId ~= jobId then
            teleport(jobId)
            return
        end

        status("Checking server " .. state.index .. "/" .. #state.servers)
        local foundAny = false
        for _ = 1, 12 do
            for _, player in ipairs(Players:GetPlayers()) do
                local height = heightOf(player)
                if height then
                    foundAny = true
                    if height > state.bestHeight then
                        state.bestHeight = height
                        state.bestJob = game.JobId
                        state.bestPlayer = player.Name
                    end
                end
            end
            task.wait(1)
        end
        if not foundAny then status("No readable heights found in this server") end
        state.index = state.index + 1
    end

    if not state.bestJob then
        env.CocoEvolutionRunningJob = nil
        error("Coco Evolution: no replicated height values found; the game's stat path needs inspection")
    end
    status("Tallest observed: " .. state.bestPlayer .. " (" .. state.bestHeight .. " inches)")
    state.phase = "reroll"
    if game.JobId ~= state.bestJob then
        teleport(state.bestJob)
        return
    end
end

if state.phase ~= "reroll" then error("Coco Evolution: invalid saved state") end
status("Rerolling in the selected server. Targets: 8'4 at age 1 or 20'0 at age 18")

local attempts = 0
while true do
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid", 20)
    if not humanoid then error("Coco Evolution: character has no Humanoid") end
    local sawStats = false
    local startedAt = os.clock()
    local adultSince

    while LocalPlayer.Character == character and humanoid.Health > 0 do
        local age, height = ageOf(LocalPlayer), heightOf(LocalPlayer)
        if age and height then
            sawStats = true
            if (age == 1 and height == 100) or (age == 18 and height == 240) then
                status("Target reached at age " .. age .. " and height " .. height .. " inches after " .. attempts .. " resets")
                env.CocoEvolutionRunningJob = nil
                return
            end
            if age >= 18 then
                adultSince = adultSince or os.clock()
                if os.clock() - adultSince >= 5 then
                    attempts = attempts + 1
                    status("Reset " .. attempts .. ": age " .. age .. ", height " .. height .. " inches")
                    humanoid.Health = 0
                    break
                end
            else
                adultSince = nil
            end
        end
        if not sawStats and os.clock() - startedAt >= 30 then
            env.CocoEvolutionRunningJob = nil
            error("Coco Evolution: age or height was not readable; the game's stat path needs inspection")
        end
        task.wait(1)
    end

    if not sawStats then
        env.CocoEvolutionRunningJob = nil
        error("Coco Evolution: age or height was not readable on this character")
    end
    if LocalPlayer.Character == character then
        LocalPlayer.CharacterAdded:Wait()
    end
end
