local ui = {}
local core = script.Parent.GameLoop

local startergui = game:GetService("StarterGui")
local guiRemotes = startergui.Main.Remotes

function ui.setStatus(status, dur)
	local function secondsToTime(s)
		if s%60 >= 10 then
			return tostring(math.floor(s/60)).. ":".. tostring(s%60)
		else
			return tostring(math.floor(s/60)).. ":0".. tostring(s%60)
		end
	end
	core:SetAttribute("gamestate", status)
	print("state: ", core:GetAttribute("gamestate"))

	if dur then
		for i=dur, 1, -1 do
			if core:GetAttribute("gamestate") ~= status then
				break
			end
			print(i, status)
			guiRemotes.Misc.SetStatusText:FireAllClients(status.. " ".. secondsToTime(i))
			wait(1)
		end
	else
		guiRemotes.Misc.SetStatusText:FireAllClients(status)
	end
end

function ui.endStatus()
	core:SetAttribute("gamestate", "")
end

return ui
