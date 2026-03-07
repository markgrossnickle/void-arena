--!strict
--[=[
	@class PlatformUtil
	Cross-platform detection utilities.
]=]

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local PlatformUtil = {}

function PlatformUtil.IsMobile(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function PlatformUtil.IsConsole(): boolean
	return GuiService:IsTenFootInterface()
end

function PlatformUtil.IsPC(): boolean
	return UserInputService.KeyboardEnabled and not GuiService:IsTenFootInterface()
end

function PlatformUtil.IsGamepad(): boolean
	return UserInputService.GamepadEnabled
end

function PlatformUtil.GetPlatform(): string
	if PlatformUtil.IsConsole() then
		return "Console"
	elseif PlatformUtil.IsMobile() then
		return "Mobile"
	else
		return "PC"
	end
end

return PlatformUtil
