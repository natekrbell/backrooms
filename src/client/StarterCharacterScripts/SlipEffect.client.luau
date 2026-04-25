local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SlipConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SlipConfig"))

local player = Players.LocalPlayer
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

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
local loadBackrooms = waitForRemoteEvent(remoteEvents, "LoadBackrooms")

local playerGui = player:WaitForChild("PlayerGui")
local slipGui = playerGui:FindFirstChild("SlipOverlay")
if not slipGui then
	slipGui = Instance.new("ScreenGui")
	slipGui.Name = "SlipOverlay"
	slipGui.ResetOnSpawn = false
	slipGui.IgnoreGuiInset = true
	slipGui.Parent = playerGui
end

local overlay = slipGui:FindFirstChild("BlackoutFrame")
if not overlay then
	overlay = Instance.new("Frame")
	overlay.Name = "BlackoutFrame"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Parent = slipGui
end

local blur = Lighting:FindFirstChild("SlipBlur")
if not blur then
	blur = Instance.new("BlurEffect")
	blur.Name = "SlipBlur"
	blur.Size = 0
	blur.Parent = Lighting
end

local colorCorrection = Lighting:FindFirstChild("SlipColorCorrection")
if not colorCorrection then
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "SlipColorCorrection"
	colorCorrection.Saturation = 0
	colorCorrection.Brightness = 0
	colorCorrection.Parent = Lighting
end

local function tween(instance: Instance, duration: number, properties: { [string]: any })
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(instance, tweenInfo, properties):Play()
end

local function startSlipEffect(duration: number)
	tween(blur, duration, { Size = 20 })
	tween(colorCorrection, duration, { Saturation = -1, Brightness = -0.3 })
end

local function cancelSlipEffect()
	tween(blur, 0.8, { Size = 0 })
	tween(colorCorrection, 0.8, { Saturation = 0, Brightness = 0 })
	tween(overlay, 0.3, { BackgroundTransparency = 1 })
end

local function transportEffect()
	overlay.BackgroundTransparency = 0
	blur.Size = 0
	colorCorrection.Saturation = 0
	colorCorrection.Brightness = 0
end

local function onBackroomsLoaded()
	tween(overlay, 0.8, { BackgroundTransparency = 1 })
end

triggerSlip.OnClientEvent:Connect(function(action: string, data: number?)
	if action == SlipConfig.CLIENT_ACTIONS.START then
		startSlipEffect(data or SlipConfig.SLIP_DELAY_SECONDS)
	elseif action == SlipConfig.CLIENT_ACTIONS.CANCEL then
		cancelSlipEffect()
	elseif action == SlipConfig.CLIENT_ACTIONS.TRANSPORT then
		transportEffect()
	end
end)

loadBackrooms.OnClientEvent:Connect(function(action: string?)
	if action == SlipConfig.CLIENT_ACTIONS.LOADED then
		onBackroomsLoaded()
	end
end)
