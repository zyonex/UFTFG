-- // REMOTES // --
local hammerRemotes = script.Parent.Remotes
local remotes = game.ReplicatedStorage.Remotes

local hammer = script.Parent.Parent

local physicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

physicsService:RegisterCollisionGroup("HammerMesh")
physicsService:RegisterCollisionGroup("HammerHit")

--[[
hammer.Handle.CollisionGroup = "HammerMesh"
hammer.Handle.HITBOX.CollisionGroup = "HammerHit"
]]

-- Store active ropes per player
local playerRopes = {}

local roping: Model | nil
local rope_attach

local function stopRoping(p)
	local currentPlayer = game.Players:GetPlayerFromCharacter(hammer.Parent)

	p.Character.IsRagdoll.Value = false
	p.Character.Humanoid.WalkSpeed = 18

	p.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)

	if rope_attach and Players:GetPlayerFromCharacter(rope_attach) == p then
		roping = nil
		rope_attach:Destroy()
	end

	remotes.Beast.Rope:FireClient(currentPlayer, nil)

	for _, v in p.Character:GetChildren() do
		if v:IsA("BasePart") and v.Anchored == false then
			v.Massless = false
			v:SetNetworkOwnershipAuto()
		end
	end
end

remotes.Survivor.StopFlop.OnServerEvent:Connect(stopRoping)

hammer.Activated:Connect(function()
	print("ACTIVATED")
	local currentPlayer = game.Players:GetPlayerFromCharacter(hammer.Parent)
	local hit, target = hammerRemotes.GetMouse:InvokeClient(currentPlayer)

	if target then
		print("TARGET")
		if target.Parent then
			print("PARENT")
			if target.Parent:FindFirstChildOfClass("Humanoid") then
				print("HUMANOID")
				if target.Parent:FindFirstChild("IsRagdoll") then
					print("RAGDOLL")
					local ragdoll = target.Parent:FindFirstChild("IsRagdoll")
					if ragdoll.Value == true then
						roping = target.Parent
						print("RAGDOLLED")
						remotes.Beast.Rope:FireClient(Players:GetPlayerFromCharacter(target.Parent), target)

						if not rope_attach then
							rope_attach = Instance.new("Attachment")
							rope_attach.Name = "PLAYER_ROPED_ATTACHMENT"
						end

						pcall(function()
							rope_attach.Parent = target
						end)

						rope_attach.WorldCFrame = hit

						local hammerRope_attach = hammer.Handle.RopeAttach

						local rope = Instance.new("RopeConstraint")

						rope.Visible = true

						rope.Name = "ROPING_PLAYER_ROPE"

						rope.Parent = currentPlayer.Character.HumanoidRootPart

						rope.Attachment0 = hammerRope_attach
						rope.Attachment1 = rope_attach

						rope.Length = 10

						local function getOut()
							rope:Destroy()
						end

						local connSomething
						local connSomthing
						local tpConnection

						local function disconnect()
							connSomething:Disconnect()
							connSomthing:Disconnect()
							task.cancel(tpConnection)

							stopRoping(Players:GetPlayerFromCharacter(target.Parent))
						end

						tpConnection = task.spawn(function()
							local currentRoping = roping
							local params = RaycastParams.new()

							params.RespectCanCollide = true

							while currentRoping == roping do
								local cast = workspace:Raycast(currentPlayer.Character.HumanoidRootPart.Position, (currentRoping.HumanoidRootPart.Position - currentPlayer.Character.HumanoidRootPart.Position), params)

								if cast then
									if (currentRoping.HumanoidRootPart.Position - currentPlayer.Character.HumanoidRootPart.Position).Magnitude > 8 or cast.Instance:FindFirstAncestor(currentRoping.Name) then
										currentRoping.HumanoidRootPart.Position = currentPlayer.Character.HumanoidRootPart.Position
									end
								else
									print("stupid cast")
								end
								
								wait(0.5)
							end
						end)

						connSomething = remotes.Survivor.StopFlop.OnServerEvent:Connect(function(p)
							if p == game.Players:GetPlayerFromCharacter(ragdoll.Parent) then
								getOut()
								disconnect()
							end
						end)

						connSomthing = rope_attach.Destroying:Connect(function()
							rope:Destroy()
							disconnect()
						end)

						for _, v in target.Parent:GetChildren() do
							if v:IsA("BasePart") then
								v.Massless = true
								if v.Anchored == false then
									v:SetNetworkOwner(currentPlayer)
								end
							end
						end

						return
					end
				end
			else
				if rope_attach then
					rope_attach:Destroy()
				end
			end
		end
	end

	local gracePeriod = .5
	local t = tick()
	local hitting

	local function disconnect()
		hitting:Disconnect()
	end

	local function hit(body, hitTime)
		print("try hit")
		if hitTime - t <= gracePeriod then
			print("Hit something")
			local humanoid: Humanoid = body.Parent:FindFirstChildWhichIsA("Humanoid")

			if humanoid then
				local ragdoll = body.Parent:FindFirstChild("IsRagdoll")

				humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
				print("Hit player")
				remotes.Survivor.Flop:FireClient(game.Players:GetPlayerFromCharacter(humanoid.Parent))
				ragdoll.Value = true
				humanoid.WalkSpeed = 0

				game.ReplicatedStorage.Remotes.Misc.SpawnAudio:Fire(game.SoundService.Hammer.Hit.SoundId, hammer.Handle.HITBOX, {["Volume"] = 2, RollOffMaxDistance = 50})
			else
				print("hit object")
				game.ReplicatedStorage.AnimationRemotes.StopAnimation:FireClient(currentPlayer, "Hammer")

				game.ReplicatedStorage.Remotes.Misc.SpawnAudio:Fire(game.SoundService.Hammer.Miss.SoundId, hammer.Handle.HITBOX, {["Volume"] = 2, RollOffMaxDistance = 50})
			end
		end
	end

	hitting = hammer.Handle.HITBOX.Touched:Connect(function(a)
		if not a:IsA("Accessory") and a.CanCollide == true then
			hit(a, tick())
			disconnect()
		end
	end)
	task.delay(gracePeriod, function()
		disconnect()
	end)
end)

	--[[
]]
