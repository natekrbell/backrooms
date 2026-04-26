local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SlipConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SlipConfig"))

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local slipTransportRequested = ServerScriptService:WaitForChild("SlipTransportRequested") :: BindableEvent

local activeSlipTokenByUserId: { [number]: number } = {}
local tokenCounter = 0

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

local triggerSlip = waitForRemoteEvent(remoteEvents, "TriggerSlip")

local function getPlayerFromTouchedPart(part: BasePart): Player?
	local character = part.Parent
	if not character then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function onSlipZoneTouched(part: BasePart)
	local player = getPlayerFromTouchedPart(part)
	if not player then
		return
	end

	local userId = player.UserId
	if activeSlipTokenByUserId[userId] then
		return
	end

	tokenCounter += 1
	local token = tokenCounter
	activeSlipTokenByUserId[userId] = token

	triggerSlip:FireClient(player, SlipConfig.CLIENT_ACTIONS.START, SlipConfig.SLIP_DELAY_SECONDS)

	task.delay(SlipConfig.SLIP_DELAY_SECONDS, function()
		if activeSlipTokenByUserId[userId] ~= token then
			return
		end

		activeSlipTokenByUserId[userId] = nil
		triggerSlip:FireClient(player, SlipConfig.CLIENT_ACTIONS.TRANSPORT)

		task.delay(SlipConfig.TRANSPORT_BUFFER_SECONDS, function()
			slipTransportRequested:Fire(player)
		end)
	end)
end

local function registerSlipZone(slipZone: Instance)
	if not slipZone:IsA("BasePart") then
		return
	end

	slipZone.Touched:Connect(function(part: BasePart)
		onSlipZoneTouched(part)
	end)
end

for _, slipZone in CollectionService:GetTagged(SlipConfig.SLIP_ZONE_TAG) do
	registerSlipZone(slipZone)
end

CollectionService:GetInstanceAddedSignal(SlipConfig.SLIP_ZONE_TAG):Connect(registerSlipZone)
