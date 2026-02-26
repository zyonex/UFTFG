
local module = {}

local replicatedstorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local startergui = game:GetService("StarterGui")
local serverstorage = game:GetService("ServerStorage")
local soundService = game:GetService("SoundService")
local runservice = game:GetService("RunService")
local ts = game:GetService("TweenService")
local ui = require(script.Parent.UI)

module.riggedBeast = nil

function module.run(currMap: Model)
	print("Game Started")

	local killswitch = false

	local g = {}

	local ExitDoorID = "rbxassetid://78428533587717"
	local CapturedPlayerID = "rbxassetid://130965487928107"
	local PodID = "rbxassetid://90814323457151"

	local connections = {}

	local function Conn(c: RBXScriptSignal, callback:(()->()))
		table.insert(connections, c:Connect(callback))
	end
	local captured = 0

	local Main: Folder = currMap.Main
	local Freezers: Folder = Main.Freezers
	local Doors: Folder = Main.Doors
	local Computers: Folder = Main.Computers
	local Exits: Folder = Main.Exits

	local PCs = currMap.Main:WaitForChild("Computers"):GetChildren()

	local ingame = {}
	local beast: Player = module.riggedBeast or players:GetPlayers()[math.random(1, #players:GetPlayers())]
	module.riggedBeast = nil

	replicatedstorage.Remotes.Misc.Message:FireAllClients("The beast is ".. beast.Name)

	local ambiance = soundService.Ambiance_FTF
	local lobbymusic = soundService.FTF_Menu

	ambiance.Looped = true
	ambiance.Volume = 0.1

	lobbymusic.Volume = 0

	ambiance:Play()

	local hammer = serverstorage.Storage.Items.Beast.Hammer:Clone()

	--/ Beast Light INIT /--
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 0, 0)
	light.Range = 12
	light.Brightness = 6
	light.Parent = beast.Character.HumanoidRootPart

	local timer = 900
	local TIMER_CONNECTION = task.spawn(function()

		while true do
			wait(1)
			timer-=1
		end
	end)

	--/ Ingame Init /--
	for _, p in players:GetPlayers() do
		if p ~= beast then table.insert(ingame, p) end

		p.Character:FindFirstChildOfClass("Humanoid"):GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			if beast == p then
				if beast:GetAttribute("Sprint") == false then
					p.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = 19
				end
			else
				p.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = 18
			end
		end)
	end

	_G.ingame = ingame

	local pcCount = #game.Players:GetPlayers()

	print(pcCount)

	repeat if pcCount >= #PCs then pcCount -= 1 end until pcCount < #PCs

	startergui.Main_Local.Remotes.Round.PC.UpdatePCCount:FireAllClients(pcCount)

	local clone = serverstorage.Storage.UI.Player:Clone()

	clone.Parent = replicatedstorage.Temp

	startergui.Main_Local.Remotes.Round.StartRound:FireAllClients(clone, ingame)

	-- Notify all players they are entering the game
	for _, player in ingame do
		replicatedstorage.Remotes.Game.SetGameState:FireClient(player, "ingame")
	end

	local function setPropertyOfDescendants(base:BasePart|Model, prop:{[string]: any}, skip:(BasePart)->(boolean))
		if base:IsA("BasePart") then
			for i, v in prop do
				base[i] = v
			end
		end

		for _, d in base:GetDescendants() do
			if d:IsA("BasePart") then
				for i, v in prop do
					d[i] = v
				end
			end
		end
	end

	local roped = nil

	local function initDoor(door:Model)
		local doorP:BasePart = door.Door
		local proxHitbox = door.Hitbox.Prox

		door:SetAttribute("State", "closed")

		local prox = Instance.new("ProximityPrompt")
		prox.Parent = proxHitbox
		prox.RequiresLineOfSight = false
		prox.MaxActivationDistance = 7
		prox.HoldDuration = 1

		prox.Triggered:Connect(function(p)
			if door:GetAttribute("State") == "closed" and p.Character.IsRagdoll.Value == false then
				-- opening
				local tween = ts:Create(doorP, TweenInfo.new(.2),
					{
						CFrame = 
							(
								(
									CFrame.new(doorP.Hinge.WorldCFrame.Position)
									*CFrame.Angles(0,math.rad(100),0)
								)*CFrame.new(doorP.Hinge.WorldCFrame.Position):ToObjectSpace(doorP.CFrame)
							)
					}
				)

				setPropertyOfDescendants(door, {["CanCollide"] = false}, function(o)
					return o:FindFirstAncestor("Frame") or o:FindFirstAncestor("Hitbox") or o.Name == "Hitbox"
				end)

				tween:Play()
				prox.Enabled = false

				replicatedstorage.Remotes.Misc.SpawnAudio:Fire(soundService.Door.OPEN.SoundId, doorP, {["Volume"] = 2, RollOffMaxDistance = 50})

				tween.Completed:Wait()

				prox.HoldDuration = 0
				prox.Enabled = true
				door:SetAttribute("State", "open")
			elseif p.Character.IsRagdoll.Value == false then
				-- open
				local tween = ts:Create(doorP, TweenInfo.new(.2),
					{
						CFrame = 
							(
								(
									CFrame.new(doorP.Hinge.WorldCFrame.Position)
									*CFrame.Angles(0,math.rad(-100),0)
								)*CFrame.new(doorP.Hinge.WorldCFrame.Position):ToObjectSpace(doorP.CFrame)
							)
					}
				)

				tween:Play()
				prox.Enabled = false
				replicatedstorage.Remotes.Misc.SpawnAudio:Fire(soundService.Door.CLOSE.SoundId, doorP, {["Volume"] = 2, RollOffMaxDistance = 50})

				tween.Completed:Wait()
				setPropertyOfDescendants(doorP, {["CanCollide"] = true}, function(o)
					return o:FindFirstAncestor("Frame") or o:FindFirstAncestor("Hitbox") or o.Name == "Hitbox"
				end)



				prox.Enabled = true
				prox.HoldDuration = 1
				door:SetAttribute("State", "closed")
			end
		end)
	end

	local function registerExitedPlayer(p)
		g.playerGone(p)
	end

	local function openExits()
		soundService.Door.Exit.Exits_Unlocked:Play()
		for _, exit in Exits:GetChildren() do
			local prox = Instance.new("ProximityPrompt")
			local doorP:BasePart = exit.Door

			prox.ActionText = ""
			prox.ObjectText = ""
			prox.MaxActivationDistance = 7
			prox.HoldDuration = 10
			prox.Enabled = true

			prox.Parent = exit.Hitbox
			prox.RequiresLineOfSight = false

			local opening: Sound = soundService.Door.Exit.ExitDoor_OPENING:Clone()
			opening.Parent = exit.Door

			local currentPlayerOpeningExit = nil

			prox.PromptButtonHoldBegan:Connect(function(p)
				if currentPlayerOpeningExit and currentPlayerOpeningExit.Character.IsRagdoll.Value == true then
					currentPlayerOpeningExit = nil
				end

				if beast ~= p and not currentPlayerOpeningExit and p.Character.IsRagdoll.Value == false then
					currentPlayerOpeningExit = p
					opening:Play()
				end
			end)

			prox.PromptButtonHoldEnded:Connect(function(p)
				if p == currentPlayerOpeningExit and p.Character.IsRagdoll.Value == false and currentPlayerOpeningExit then
					currentPlayerOpeningExit = nil
					opening:Stop()
				end
			end)

			prox.Triggered:Connect(function(p)
				if beast ~= p then
					currentPlayerOpeningExit = nil
					opening:Stop()
					doorP.CanCollide = false
					local tween = ts:Create(doorP, TweenInfo.new(3),
						{
							CFrame = 
								(
									(
										CFrame.new(doorP.Hinge.WorldCFrame.Position)
										*CFrame.Angles(0,math.rad(100),0)
									)*CFrame.new(doorP.Hinge.WorldCFrame.Position):ToObjectSpace(doorP.CFrame)
								)
						}
					)

					spawn(function()
						local temp: Sound = soundService.Door.Exit.ExitDoor_Open:Clone()
						temp.Parent = beast.Character.HumanoidRootPart
						temp:Play()
						temp.Ended:Wait()
						temp:Destroy()
					end)

					prox:Destroy()
				end
			end)

			exit.ExitHitbox.Touched:Connect(function(c)
				if c.Parent:FindFirstChildOfClass("Humanoid") then
					registerExitedPlayer(players:GetPlayerFromCharacter(c.Parent))
				end
			end)

			local billboard = serverstorage.Storage.UI.Bill:Clone()
			billboard.Parent = workspace.Bills

			billboard.Adornee = exit.Door
			billboard.AlwaysOnTop = true
			billboard.ImageLabel.Image = ExitDoorID
		end
	end

	local function kickOutPlayerFromHacking(compoter, plr2: Player?)
		local vals: {ObjectValue} = {
			compoter.LeftPlayer,
			compoter.FrontPlayer,
			compoter.RightPlayer
		}

		local plrs = {}
		for _, val in vals do
			if plr2 then
				if val.Value == plr2 then
					table.insert(plrs, plr2)
					replicatedstorage.Remotes.Game.PC.UpdateHackingAnimation:FireClient(plr2, false)
				end
			else
				if val.Value ~= nil then
					table.insert(plrs, val.Value)
					replicatedstorage.Remotes.Game.PC.UpdateHackingAnimation:FireClient(val.Value, false)
				end
			end
		end

		for _, playerHacking: Player in plrs do
			local char = playerHacking.Character
			local hrp = char.HumanoidRootPart

			hrp.Anchored = false

			compoter:SetAttribute("PersonCount", compoter:GetAttribute("PersonCount") - 1)
		end
	end

	local function pcFinished(pc: Model)
		if pc:FindFirstChild("LeftPos") and pc:FindFirstChild("FrontPos") and pc:FindFirstChild("RightPos") then
			pc:SetAttribute("Finished", true)

			pc.Computer.Essential.Light.Color = Color3.fromRGB(0, 255, 0)

			kickOutPlayerFromHacking(pc)

			local lPos = pc.LeftPos
			local fPos = pc.FrontPos
			local rPos = pc.RightPos

			lPos:Destroy()
			fPos:Destroy()
			rPos:Destroy()

			pcCount -= 1
			startergui.Main_Local.Remotes.Round.PC.UpdatePCCount:FireAllClients(pcCount)



			if pcCount == 0 then
				openExits()
			end
		end
	end

	local function findCurrentPcHackedBy(plr)
		for _, compoter in currMap.Main.Computers:GetChildren() do
			local vals: {Player} = {
				compoter.LeftPlayer,
				compoter.FrontPlayer,
				compoter.RightPlayer
			}

			for _, val in vals do
				if val.Value == plr then
					return compoter
				end
			end
		end
	end

	local function initPC(pc: Model)
		local lPos = pc.LeftPos
		local fPos = pc.FrontPos
		local rPos = pc.RightPos

		local lPlayer = Instance.new("ObjectValue")
		lPlayer.Parent = pc
		lPlayer.Name = "LeftPlayer"

		local fPlayer = Instance.new("ObjectValue")
		fPlayer.Parent = pc
		fPlayer.Name = "FrontPlayer"

		local rPlayer = Instance.new("ObjectValue")
		rPlayer.Parent = pc
		rPlayer.Name = "RightPlayer"

		local lProx = Instance.new("ProximityPrompt")

		lProx.Name = "LeftProx"
		lProx.Parent = lPos
		lProx.HoldDuration = .1
		lProx.RequiresLineOfSight = false
		lProx.MaxActivationDistance = 5
		lProx.ActionText = ""
		lProx.ObjectText = ""

		local rProx = Instance.new("ProximityPrompt")

		rProx.Name = "RightProx"
		rProx.Parent = rPos
		rProx.HoldDuration = .1
		rProx.RequiresLineOfSight = false
		rProx.MaxActivationDistance = 5
		rProx.ActionText = ""
		rProx.ObjectText = ""

		local fProx = Instance.new("ProximityPrompt")

		fProx.Name = "FrontProx"
		fProx.Parent = fPos
		fProx.HoldDuration = .1
		fProx.RequiresLineOfSight = false
		fProx.MaxActivationDistance = 5
		fProx.ActionText = ""
		fProx.ObjectText = ""

		pc:SetAttribute("PersonCount", 0)
		pc:SetAttribute("Progress", 0)
		pc:SetAttribute("Finished", false)

		lProx.Triggered:Connect(function(plrWhoTriggered)
			if pc:GetAttribute("Finished") then return end

			if table.find(ingame, plrWhoTriggered) and plrWhoTriggered.Character.IsRagdoll.Value == false then
				if lPlayer ~= nil and lPlayer.Value == plrWhoTriggered then
					plrWhoTriggered.PlayerGui.Main_Local.Remotes.Round.PC.UpdatePCProgressVisible:FireClient(plrWhoTriggered, false)
					lPlayer.Value = nil 

					pc:SetAttribute("PersonCount", pc:GetAttribute("PersonCount") - 1)

					local char = plrWhoTriggered.Character

					local hrp = char:WaitForChild("HumanoidRootPart")

					hrp.Anchored = false

					-- Stop hacking animation
					replicatedstorage.Remotes.Game.PC.UpdateHackingAnimation:FireClient(plrWhoTriggered, false)
				elseif plrWhoTriggered.Character.IsRagdoll.Value == false then
					lPlayer.Value = plrWhoTriggered

					pc:SetAttribute("PersonCount", pc:GetAttribute("PersonCount") + 1)

					local char = plrWhoTriggered.Character

					local hum = char:FindFirstChildOfClass("Humanoid")

					local hrp = char:WaitForChild("HumanoidRootPart")

					hrp.Anchored = true

					char:PivotTo(CFrame.new(lPos.CFrame.Position + Vector3.new(0, 1.5)) --[[ * CFrame.new(0, -1.5, 0)]])

					replicatedstorage.Remotes.Game.PC.UpdateHackingAnimation:FireClient(plrWhoTriggered, true)
				end
			end
		end)

		fProx.Triggered:Connect(function(plrWhoTriggered)
			if pc:GetAttribute("Finished") then return end

			if table.find(ingame, plrWhoTriggered) and plrWhoTriggered.Character.IsRagdoll.Value == false then
				if fPlayer ~= nil and fPlayer.Value == plrWhoTriggered then
					plrWhoTriggered.PlayerGui.Main_Local.Remotes.Round.PC.UpdatePCProgressVisible:FireClient(plrWhoTriggered, false)
					fPlayer.Value = nil 

					pc:SetAttribute("PersonCount", pc:GetAttribute("PersonCount") - 1)

					local char = plrWhoTriggered.Character

					local hrp = char:WaitForChild("HumanoidRootPart")

					hrp.Anchored = false

					-- Stop hacking animation
					replicatedstorage.Remotes.Game.PC.UpdateHackingAnimation:FireClient(plrWhoTriggered, false)
				elseif plrWhoTriggered.Character.IsRagdoll.Value == false then
					fPlayer.Value = plrWhoTriggered

					pc:SetAttribute("PersonCount", pc:GetAttribute("PersonCount") + 1)

					local char = plrWhoTriggered.Character

					local hum = char:FindFirstChildOfClass("Humanoid")

					local hrp = char:WaitForChild("HumanoidRootPart")

					hrp.Anchored = true

					char:PivotTo(CFrame.new(fPos.CFrame.Position + Vector3.new(0, 1.5)) --[[ * CFrame.new(0, -1.5, 0)]])

					replicatedstorage.Remotes.Game.PC.UpdateHackingAnimation:FireClient(plrWhoTriggered, true)
				end
			end
		end)

		rProx.Triggered:Connect(function(plrWhoTriggered)
			if pc:GetAttribute("Finished") then return end

			if table.find(ingame, plrWhoTriggered) and plrWhoTriggered.Character.IsRagdoll.Value == false then
				if rPlayer ~= nil and rPlayer.Value == plrWhoTriggered then
					plrWhoTriggered.PlayerGui.Main_Local.Remotes.Round.PC.UpdatePCProgressVisible:FireClient(plrWhoTriggered, false)
					rPlayer.Value = nil 

					pc:SetAttribute("PersonCount", pc:GetAttribute("PersonCount") - 1)

					local char = plrWhoTriggered.Character

					local hrp = char:WaitForChild("HumanoidRootPart")

					hrp.Anchored = false

					-- Stop hacking animation
					replicatedstorage.Remotes.Game.PC.UpdateHackingAnimation:FireClient(plrWhoTriggered, false)
				elseif plrWhoTriggered.Character.IsRagdoll.Value == false then
					rPlayer.Value = plrWhoTriggered

					pc:SetAttribute("PersonCount", pc:GetAttribute("PersonCount") + 1)

					local char = plrWhoTriggered.Character

					local hum = char:FindFirstChildOfClass("Humanoid")

					local hrp = char:WaitForChild("HumanoidRootPart")

					hrp.Anchored = true

					char:PivotTo(CFrame.new(rPos.CFrame.Position + Vector3.new(0, 1.5)) --[[ * CFrame.new(0, -1.5, 0)]])

					replicatedstorage.Remotes.Game.PC.UpdateHackingAnimation:FireClient(plrWhoTriggered, true)
				end
			end
		end)

		local connection
		local conn2
		-- what the hellllll oo my gad no way!!!
		-- devadelso 3/20/25 3:24 pm est


		conn2 = pc:GetAttributeChangedSignal("PersonCount"):Connect(function()
			local count = pc:GetAttribute("PersonCount")

			local goal = 30 -- dev balls

			if count > 0 then
				if not pc.Computer.Essential.Light:FindFirstChild("Hacking") then
					local hackingMusic = soundService.Computer.Hacking:Clone()

					hackingMusic.Parent = pc.Computer.Essential.Light
					hackingMusic:Play()
				end

				connection = runservice.Heartbeat:Connect(function(delta)
					if pc:GetAttribute("Progress") >= goal then
						kickOutPlayerFromHacking(pc)
						pcFinished(pc)

						if pc.Computer.Essential.Light:FindFirstChild("Hacking") then
							local hackingMusic = pc.Computer.Essential.Light:FindFirstChild("Hacking")

							hackingMusic:Stop()
							hackingMusic:Destroy()
						end

						connection:Disconnect()
						conn2:Disconnect()
					end

					if lPlayer.Value then
						startergui.Main_Local.Remotes.Round.PC.UpdatePCProgress:FireClient(lPlayer.Value, pc:GetAttribute("Progress")/goal)
						if lPlayer.Value.Character.IsRagdoll.Value == true then
							kickOutPlayerFromHacking(pc, lPlayer.Value)
						end
					end
					if fPlayer.Value then
						startergui.Main_Local.Remotes.Round.PC.UpdatePCProgress:FireClient(fPlayer.Value, pc:GetAttribute("Progress")/goal)
						if fPlayer.Value.Character.IsRagdoll.Value == true then
							kickOutPlayerFromHacking(pc, fPlayer.Value)
						end
					end
					if rPlayer.Value then
						startergui.Main_Local.Remotes.Round.PC.UpdatePCProgress:FireClient(rPlayer.Value, pc:GetAttribute("Progress")/goal)
						if rPlayer.Value.Character.IsRagdoll.Value == true then
							kickOutPlayerFromHacking(pc, rPlayer.Value)
						end
					end

					pc:SetAttribute("Progress", pc:GetAttribute("Progress") + (delta * count))
				end)
			else
				if pc.Computer.Essential.Light:FindFirstChild("Hacking") then
					pc.Computer.Essential.Light:FindFirstChild("Hacking"):Stop()
					pc.Computer.Essential.Light:FindFirstChild("Hacking"):Destroy()
				end
				connection:Disconnect()
			end
		end)

        --[[
        fProx.Triggered:Connect(function(plrWhoTriggered)
            if table.find(ingame, plrWhoTriggered) then
                if pc.FrontPos ~= nil and fPlayer.Value == plrWhoTriggered then
                    fPlayer.Value = plrWhoTriggered

                    pc:SetAttribute("PersonCount", pc:GetAttribute("PersonCount") + 1)
                    
                    local char = plrWhoTriggered.Character

                    local hrp = char:WaitForChild("HumanoidRootPart")

                    hrp.Anchored = true

                    char:PivotTo((hrp.CFrame + CFrame.new(0, 1.5 + char:WaitForChild("Humanoid").HipHeight, 0)) * fPos.CFrame)
                else
                    fPlayer.Value = nil 

                    pc:SetAttribute("PersonCount", pc:GetAttribute("PersonCount") - 1)
                    
                    local char = plrWhoTriggered.Character

                    local hrp = char:WaitForChild("HumanoidRootPart")

                    hrp.Anchored = false
                end
            end
        end)

        rProx.Triggered:Connect(function(plrWhoTriggered)
            if table.find(ingame, plrWhoTriggered) then
                if pc.RightPos ~= nil and rPlayer.Value == plrWhoTriggered then
                    rPlayer.Value = plrWhoTriggered

                    pc:SetAttribute("PersonCount", pc:GetAttribute("PersonCount") + 1)
                    
                    local char = plrWhoTriggered.Character

                    local hrp = char:WaitForChild("HumanoidRootPart")

                    hrp.Anchored = true

                    char:PivotTo((hrp.CFrame + CFrame.new(0, 1.5 + char:WaitForChild("Humanoid").HipHeight, 0)) * rPos.CFrame)
                else
                    rPlayer.Value = nil 

                    pc:SetAttribute("PersonCount", pc:GetAttribute("PersonCount") - 1)
                    
                    local char = plrWhoTriggered.Character

                    local hrp = char:WaitForChild("HumanoidRootPart")

                    hrp.Anchored = false
                end
            end
        end)
        ]]

		pc:SetAttribute("Active", true)
	end

	local function sendPlayerToLobby(player)
		if not player then return end

		-- Remove from ingame if still there
		if table.find(ingame, player) then
			table.remove(ingame, table.find(ingame, player))
		end

		startergui.Main_Local.Remotes.Round.HideAllGUI:FireClient(player)

		-- Reset character and gameHealth
		if player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = 0
			end
		end

		-- Reset gameHealth to 100
		player:SetAttribute("Health", 100)

		-- Teleport to lobby
		local lobbySpawns = workspace.Lobby:FindFirstChild("SpawnLocation")
		if lobbySpawns then
			if player.Character then
				player.Character.IsRagdoll.Value = false
				player.Character:PivotTo(lobbySpawns.CFrame * CFrame.new(0, 10, 0))
			end
		end

		-- Update game state
		replicatedstorage.Remotes.Game.SetGameState:FireClient(player, "lobby")
		replicatedstorage.Remotes.Game.ResetLighting:FireClient(player)

		-- Show message
		replicatedstorage.Remotes.Misc.Message:FireClient(player, "You are now in lobby.")
	end

	local function initPod(pod: Model)
		pod:SetAttribute("Available", true)
		pod:SetAttribute("Occupied", false)
		pod:SetAttribute("CaptureTime", 30) -- Time until player dies in pod

		-- Create proximity prompt for beast to capture
		local beastPrompt = Instance.new("ProximityPrompt")
		beastPrompt.Name = "BeastPrompt"
		beastPrompt.Parent = pod.Glass
		beastPrompt.ActionText = "Capture"
		beastPrompt.ObjectText = "Pod"
		beastPrompt.RequiresLineOfSight = false
		beastPrompt.MaxActivationDistance = 5
		beastPrompt.HoldDuration = 0
		beastPrompt.Enabled = true

		-- Create proximity prompt for survivors to rescue
		local rescuePrompt = Instance.new("ProximityPrompt")
		rescuePrompt.Name = "RescuePrompt"
		rescuePrompt.Parent = pod.Glass
		rescuePrompt.ActionText = "Rescue"
		rescuePrompt.ObjectText = "Rescue Player"
		rescuePrompt.RequiresLineOfSight = false
		rescuePrompt.MaxActivationDistance = 5
		rescuePrompt.HoldDuration = 0
		rescuePrompt.Enabled = false

		-- Store captured player
		local capturedPlayer = Instance.new("ObjectValue")
		capturedPlayer.Name = "CapturedPlayer"
		capturedPlayer.Parent = pod

		-- Store health connection
		local healthConnection
		local captureTimer

		local function cleanupPod(podToClean)
			podToClean:SetAttribute("Occupied", false)
			podToClean:SetAttribute("Available", false) -- Pod becomes unusable
			podToClean:SetAttribute("PodHealth", 0)

			if podToClean:FindFirstChild("CapturedPlayer") then
				podToClean.CapturedPlayer.Value = nil
			end

			-- Disable both prompts
			if podToClean:FindFirstChild("BeastPrompt") then
				podToClean.BeastPrompt.Enabled = false
			end
			if podToClean:FindFirstChild("RescuePrompt") then
				podToClean.RescuePrompt.Enabled = false
			end

			-- Update UI
			replicatedstorage.Remotes.Pod.UpdateHealth:FireAllClients(podToClean, 0, 100)
		end  

		local function createBlueClone(character)
			if not character then return nil end

			local clone = character:Clone()
			clone.Name = "BlueClone"
			clone.IsRagdoll = false

			-- Make all parts blue and transparent
			for _, part in clone:GetDescendants() do
				if part:IsA("BasePart") then
					part.BrickColor = BrickColor.new("Bright blue")
					part.Transparency = 0.3
					part.CanCollide = false
				end
			end

			-- Remove tools and scripts
			for _, child in clone:GetChildren() do
				if child:IsA("Tool") or child:IsA("Script") or child:IsA("LocalScript") then
					child:Destroy()
				end
			end

			return clone
		end

		-- Beast captures player
		beastPrompt.Triggered:Connect(function(playerWhoTriggered)
			if playerWhoTriggered ~= beast then return end
			if not roped then return end
			if pod:GetAttribute("Occupied") or not pod:GetAttribute("Available") then return end
			if not capturedPlayer.Value then
				local rchar = roped.Character
				if not rchar then return end

				for _, d in rchar:GetDescendants() do
					if d.Name == "PLAYER_ROPED_ATTACHMENT" then
						d:Destroy()
					end
				end

				captured += 1

				-- Capture the player
				capturedPlayer.Value = roped
				pod:SetAttribute("Occupied", true)
				pod:SetAttribute("Available", false)

				-- Disable beast prompt, enable rescue prompt
				beastPrompt.Enabled = false
				rescuePrompt.Enabled = true

				-- Set player attributes
				rchar:SetAttribute("Freezing", true)
				rchar:SetAttribute("InPod", true)
				if rchar:FindFirstChild("IsRagdoll") then
					rchar.IsRagdoll.Value = false
				end

				-- Clear roped
				roped = nil

				-- Position player in pod
				local hrp = rchar:WaitForChild("HumanoidRootPart")
				local cf = pod.Glass.CFrame * CFrame.fromOrientation(0,0,90)
				hrp.CFrame = cf
				hrp.Anchored = true

				-- Start pod health drain
				local captureTime = pod:GetAttribute("CaptureTime")
				local healthDrainRate = 100 / captureTime

				captureTimer = runservice.Heartbeat:Connect(function(deltaTime)
					if not pod or not pod.Parent then
						if captureTimer then captureTimer:Disconnect() end
						return
					end

					local currentHealth = capturedPlayer.Value:GetAttribute("Health") or 100
					local newHealth = math.max(0, currentHealth - (healthDrainRate * deltaTime))
					capturedPlayer.Value:SetAttribute("Health", newHealth)

					-- Update UI for all players (show player health instead of pod health)
					local capturedPlr = capturedPlayer.Value
					if capturedPlr and capturedPlr.Character then
						local humanoid = capturedPlr.Character:FindFirstChildOfClass("Humanoid")
						if humanoid then
							replicatedstorage.Remotes.Pod.UpdateHealth:FireAllClients(capturedPlr, newHealth, 100)
						end
					end

					-- Check if player died in pod
					if newHealth <= 0 then
						-- Player died, send to lobby and create blue clone
						local capturedPlr = capturedPlayer.Value
						if capturedPlr then
							-- Create blue clone
							local blueClone = createBlueClone(capturedPlr.Character)
							blueClone.Parent = pod
							blueClone:PivotTo(pod.Glass.CFrame * CFrame.new(0, 0, 0))

							local weld = Instance.new("WeldConstraint")
							weld.Part1 = pod.Glass
							weld.Part0 = blueClone.HumanoidRootPart

							-- Send player to lobby
							sendPlayerToLobby(capturedPlr)

							-- Remove from ingame
							if table.find(ingame, capturedPlr) then
								table.remove(ingame, table.find(ingame, capturedPlr)) 
							end

							-- Increment captured count
							ingame -= 1
							captured -= 1
							captureTimer:Disconnect()
							-- Clean up pod
							cleanupPod(pod)
						end

						if captureTimer then captureTimer:Disconnect() end
					end
				end)

				if captured == #ingame then
					g.ending()
				end
			end

			-- Check win condition

		end)


		-- Survivor rescues player
		rescuePrompt.Triggered:Connect(function(playerWhoTriggered)
			if playerWhoTriggered == beast then return end
			if not pod:GetAttribute("Occupied") then return end
			if not table.find(ingame, playerWhoTriggered) then return end
			if playerWhoTriggered == capturedPlayer.Value then return end

			local capturedPlr = capturedPlayer.Value
			if not capturedPlr then return end

			-- Rescue the player
			local rchar = capturedPlr.Character
			if rchar then
				rchar:SetAttribute("Freezing", false)
				rchar:SetAttribute("InPod", false)
				capturedPlr:SetAttribute("Captured", false)

				local hrp = rchar:WaitForChild("HumanoidRootPart")
				hrp.CFrame = pod.Glass.CFrame * CFrame.new(0, 0, 3)
				hrp.Anchored = false

				captured -= 1
			end

			if captureTimer then captureTimer:Disconnect() end

			rescuePrompt.Enabled = false
			beastPrompt.Enabled = true
		end)

		-- Function to create blue clone
	end

	local function initMap()
		for _, pod in Freezers:GetChildren() do
			initPod(pod)
		end

		for _, door in Doors:GetChildren() do
			initDoor(door)
		end

		for _, PC in Computers:GetChildren() do
			initPC(PC)
		end

		local removeAmount = #Freezers:GetChildren() - (#ingame + 2)

		for i=1, removeAmount do
			Freezers:GetChildren()[math.random(1,#Freezers:GetChildren())]:Destroy()
		end

		local removeAmount = #Computers:GetChildren() - (pcCount + 1)

		for i=1, removeAmount do
			Computers:GetChildren()[math.random(1,#Computers:GetChildren())]:Destroy()
		end
	end

	if not killswitch then
		local s, e = pcall(function()
			hammer.Parent = beast.Backpack

			beast.Character:FindFirstChildOfClass("Humanoid"):EquipTool(hammer)

			-- Prevent hammer from being unequipped
			hammer.Unequipped:Connect(function()
				task.wait(0.1)
				if beast.Character and beast.Character:FindFirstChildOfClass("Humanoid") then
					beast.Character:FindFirstChildOfClass("Humanoid"):EquipTool(hammer)
				end
			end)
		end)

		print(s)
		print(e)
	end

	local function initExit(exit)
		exit:SetAttribute("Open", false)
	end

	local heartBeat = soundService.Heartbeat:Clone()

	local BeastJumping

	local BeastAbilityConnection

	local AbilityDebounce = false
	BeastAbilityConnection = replicatedstorage.Remotes.Ability.OnServerEvent:Connect(function(p)
		if p == beast and not AbilityDebounce then
			if beast:GetAttribute("Sprint") == false then
				beast:SetAttribute("Sprint", true)
				beast.Character.Humanoid.WalkSpeed = 25
				beast.Character.Humanoid.JumpHeight = 0
				task.delay(4.5, function()
					beast:SetAttribute("Sprint", false)
					beast.Character.Humanoid.WalkSpeed = 19
					beast.Character.Humanoid.JumpHeight = 3.5
					AbilityDebounce = true
					task.delay(15, function()
						AbilityDebounce = false
					end)
				end)
			end
		end
	end)

	local function initBeast()
		if not killswitch then
			local char = beast.Character
			beast:SetAttribute("Sprint", false)

			char.Humanoid.WalkSpeed = 19

			char.Crouchable.Value = false
			beast.CameraMode = Enum.CameraMode.LockFirstPerson

			heartBeat.Parent = char.HumanoidRootPart

			heartBeat:Play()
			replicatedstorage.Remotes.Misc.Delete:FireClient(beast, heartBeat)

			-- Beast jumping mechanic - slow down for 0.5 seconds when landing
			BeastJumping = char:FindFirstChildOfClass("Humanoid").StateChanged:Connect(function(_, new)
				if new == Enum.HumanoidStateType.Jumping then
					char:FindFirstChildOfClass("Humanoid").StateChanged:Wait()
					local humanoid = char:FindFirstChildOfClass("Humanoid")
					humanoid.WalkSpeed = 10
					task.wait(0.6)
					humanoid.WalkSpeed = 19
				end
			end)
		end
	end

	local function tp_Players()
		spawn(function()
			if not killswitch then
				beast.Character:PivotTo(workspace.BeastTemp.Spawn.CFrame * CFrame.new(0, 1.5, 0))

				local function getSpawn(role: string)
					repeat wait() until currMap.Main ~= nil
					currMap.Main:WaitForChild("Spawns")

					if not currMap.Main.Spawns[role] then
						warn("No spawns found for role ", role, ".")
						return
					end

					local spawns = currMap.Main:WaitForChild("Spawns")[role]:GetChildren()

					if #spawns == 0 then
						warn("No spawns found in the map.")
						return
					end

					local cspawn = spawns[math.random(1, #spawns)]
					return cspawn
				end

				if not killswitch then
					for _, player in ingame do
						local char = player.Character
						local hum = char:FindFirstChildOfClass("Humanoid")

						local spawnlocation = getSpawn("Survivor")

						char:PivotTo(spawnlocation.CFrame * CFrame.new(0, 1.5 + hum.HipHeight, 0))
						replicatedstorage.Remotes.Game.Lighting:FireClient(player, currMap.Settings.Lighting)
					end
				end

				local beastspawn = getSpawn("Beast")

				local char = beast.Character
				local hum = char:FindFirstChildOfClass("Humanoid")


				wait(15)
				if not killswitch then

					initBeast()

					char:PivotTo(beastspawn.CFrame * CFrame.new(0, 1.5, 0))
					replicatedstorage.Remotes.Game.Lighting:FireClient(beast, currMap.Settings.Lighting)
				end
			end
		end)

		task.spawn(ui.setStatus, "BEAST IS COMING", 15)
	end

	local hit_conn = replicatedstorage.Remotes.Beast.Hit.OnServerEvent:Connect(function(_, potential)
		if potential.Parent:FindFirstChild("Humanoid") then
			kickOutPlayerFromHacking(findCurrentPcHackedBy(players:GetPlayerFromCharacter(potential.Parent)), players:GetPlayerFromCharacter(potential.Parent) )
		end
	end)

	local rope_conn = replicatedstorage.Remotes.Beast.Rope.OnServerEvent:Connect(function(_, c)
		if c then
			roped = (roped == players:GetPlayerFromCharacter(c.Parent) and nil) or players:GetPlayerFromCharacter(c.Parent)
			print("ROPED: ", roped)
		else
			roped = nil
			print("UNROPED")
		end
	end)

	tp_Players()
	initMap()

	function g.ending()	
		rope_conn:Disconnect()
		hit_conn:Disconnect()
		BeastAbilityConnection:Disconnect()

		workspace.Bills:ClearAllChildren()

		ambiance:Stop()
		lobbymusic.Volume = 0.5
		lobbymusic:Play()

		if beast and beast.Character then
			hammer:Destroy()
			light:Destroy()
			beast.Character.Humanoid.WalkSpeed = 18
			beast.Character.Crouchable.Value = true
			beast.CameraMode = Enum.CameraMode.Classic
			heartBeat:Destroy()
		end

		clone:Destroy()

		for i, connection in connections do
			connection:Disconnect()
		end

		pcall(function()
			BeastJumping:Disconnect()
		end)

		print("ending benchmark 1")

		for _, pod in currMap.Main.Freezers:GetChildren() do
			if pod:FindFirstChild("CapturedPlayer") and pod.CapturedPlayer.Value then
				local cp = pod.CapturedPlayer.Value

				if cp.Character then
					cp.Character.HumanoidRootPart.Anchored = false
					cp.Character.Humanoid.Health = 0
				end
			end
		end
		print("ending benchmark 2")



		-- Reset lighting for all player s and notify them they're back in lobby
		for _, plr in players:GetPlayers() do
			replicatedstorage.Remotes.Game.ResetLighting:FireClient(plr)
			replicatedstorage.Remotes.Game.SetGameState:FireClient(plr, "lobby")
		end

		-- Teleport all players back to lobby                                
		for _, plr in players:GetPlayers() do
			if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
				-- Find a lobby spawn
				local lobbySpawns = workspace.Lobby:FindFirstChild("SpawnLocation")
				if lobbySpawns then
					plr.Character:PivotTo(lobbySpawns.CFrame * CFrame.new(0, 3, 0))
				end

				-- Reset health
				local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.Health = humanoid.MaxHealth
				end
			end
		end

		ui.endStatus()

		currMap:Destroy()

		killswitch = true
		print("successful")
	end

	task.delay(15, function()
		if not killswitch then
			ui.setStatus("Ingame", 900)
		else
			print("it ended?")
		end
	end)

	function g.playerGone(survivor)
		if survivor == beast then
			sendPlayerToLobby(survivor)
			g.ending()
		else
			sendPlayerToLobby(survivor)
			table.remove(ingame, table.find(ingame, survivor))

			pcCount -= 1

			if pcCount == 0 then
				openExits()
			end

			if #ingame == 0 then
				g.ending()
			end
		end
	end

	spawn(function()
		repeat wait(.1) until #ingame == 0 or not beast or captured == #ingame or timer == 0
		g.ending()
		task.cancel(TIMER_CONNECTION)
	end)

	local function postInit()
		Conn(beast.CharacterRemoving, function()
			g.playerGone(beast)
		end)

		for _, survivor:Player in ingame do
			Conn(survivor.CharacterRemoving, function()
				-- Clear rope attribute when player dies
				if survivor.Character then
					survivor.Character:SetAttribute("IsRoped", false)
				end
				g.playerGone(survivor)
			end)

			Conn(survivor.Destroying, function()
				g.playerGone(survivor)
			end)

			-- Clear rope attribute when character respawns
			Conn(survivor.CharacterAdded, function(character)
				character:SetAttribute("IsRoped", false)
			end)
		end
	end

	postInit()

	while killswitch == false do
		task.wait(0)
	end

	return
end

return module
