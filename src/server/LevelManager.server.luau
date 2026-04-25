local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local LevelData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("LevelData"))
local SlipConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SlipConfig"))

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local slipTransportRequested = ServerScriptService:WaitForChild("SlipTransportRequested") :: BindableEvent

local playerState: { [number]: string } = {}

local function waitForRemoteEvent(folder: Instance, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end

	for _, child in folder:GetChildren() do
		if child.Name == name and child:IsA("RemoteEvent") then
			return child
		end
	end

	while true do
		local child = folder.ChildAdded:Wait()
		if child.Name == name and child:IsA("RemoteEvent") then
			return child
		end
	end
end

local loadBackrooms = waitForRemoteEvent(remoteEvents, "LoadBackrooms")

local function getLevel0SpawnCFrame(): CFrame
	local level0 = LevelData.Level0
	local spawnPosition = level0.SpawnPosition
	local lookAt = spawnPosition + level0.SpawnLookVector
	return CFrame.lookAt(spawnPosition, lookAt)
end

local function transportPlayerToLevel0(player: Player)
	playerState[player.UserId] = "transporting"

	local character = player.Character or player.CharacterAdded:Wait()
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	end

	character:PivotTo(getLevel0SpawnCFrame())
	playerState[player.UserId] = "inBackrooms"

	task.delay(0.15, function()
		loadBackrooms:FireClient(player, SlipConfig.CLIENT_ACTIONS.LOADED)
	end)
end

slipTransportRequested.Event:Connect(function(player: Player)
	if not player or not player:IsDescendantOf(Players) then
		return
	end

	transportPlayerToLevel0(player)
end)

Players.PlayerRemoving:Connect(function(player)
	playerState[player.UserId] = nil
end)
