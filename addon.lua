--[=====[
		## Tooltip Upgrades ver. @@release-version@@
		## addon.lua - module
		Initialization module for TooltipUpgrades addon
--]=====]

local addonName = ...
local TooltipUpgrades = LibStub("AceAddon-3.0"):NewAddon(addonName)

function TooltipUpgrades:OnInitialize()
	--@debug@
	_G["TooltipUpgrades"] = TooltipUpgrades

	for k, v in pairs(TooltipUpgrades.modules) do
		TooltipUpgrades[k] = v
	end
	--@end-debug@
end
