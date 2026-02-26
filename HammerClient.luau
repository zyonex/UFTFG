-- // PLAYER // --
local player = game.Players.LocalPlayer

-- // MOUSE // --
local mouse = player:GetMouse()

-- // REMOTES // --
local hammerRemotes = script.Parent.Remotes
local remotes = game.ReplicatedStorage.Remotes
local animationRemotes = game.ReplicatedStorage:WaitForChild("AnimationRemotes")
local playAnimationRemote = animationRemotes:WaitForChild("PlayAnimation")
local stopAnimationRemote = animationRemotes:WaitForChild("StopAnimation")

hammerRemotes:WaitForChild("GetMouse").OnClientInvoke = function()
	return player:GetMouse().Hit, player:GetMouse().Target
end

hammerRemotes.StopHammerAnim.OnClientEvent:Connect(function()
	stopAnimationRemote:FireServer("Hammer")
end)

-- Play hammer animation when tool is activated
script.Parent.Parent.Activated:Connect(function()
	playAnimationRemote:FireServer("Hammer")
end)
