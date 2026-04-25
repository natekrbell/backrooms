local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SlipConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SlipConfig"))

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local triggerSlip = remoteEvents:WaitForChild("TriggerSlip") :: RemoteEvent
local slipTransportRequested = ServerScriptService:WaitForChild("SlipTransportRequested") :: BindableEvent

local activeSlipTokenByUserId: { [number]: number } = {}
local touchCountByZone: { [Instance]: { [number]: number } } = {}
local tokenCounter = 0

local function getPlayerFromTouchedPart(part: BasePart): Player?
	local character = part.Parent
	if not character then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function cancelSlip(player: Player)
	local userId = player.UserId
	if not activeSlipTokenByUserId[userId] then
		return
	end

	activeSlipTokenByUserId[userId] = nil
	triggerSlip:FireClient(player, SlipConfig.CLIENT_ACTIONS.CANCEL)
end

local function onSlipZoneTouched(part: BasePart, slipZone: Instance)
	local player = getPlayerFromTouchedPart(part)
	if not player then
		return
	end

	local perZone = touchCountByZone[slipZone]
	if not perZone then
		perZone = {}
		touchCountByZone[slipZone] = perZone
	end

	local userId = player.UserId
	perZone[userId] = (perZone[userId] or 0) + 1
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

local function onSlipZoneTouchEnded(part: BasePart, slipZone: Instance)
	local player = getPlayerFromTouchedPart(part)
	if not player then
		return
	end

	local perZone = touchCountByZone[slipZone]
	if not perZone then
		return
	end

	local userId = player.UserId
	local currentCount = perZone[userId] or 0
	if currentCount <= 1 then
		perZone[userId] = nil
		cancelSlip(player)
	else
		perZone[userId] = currentCount - 1
	end
end

local function registerSlipZone(slipZone: Instance)
	if not slipZone:IsA("BasePart") then
		return
	end

	touchCountByZone[slipZone] = touchCountByZone[slipZone] or {}

	slipZone.Touched:Connect(function(part: BasePart)
		onSlipZoneTouched(part, slipZone)
	end)

	slipZone.TouchEnded:Connect(function(part: BasePart)
		onSlipZoneTouchEnded(part, slipZone)
	end)
end

for _, slipZone in CollectionService:GetTagged(SlipConfig.SLIP_ZONE_TAG) do
	registerSlipZone(slipZone)
end

CollectionService:GetInstanceAddedSignal(SlipConfig.SLIP_ZONE_TAG):Connect(registerSlipZone)
