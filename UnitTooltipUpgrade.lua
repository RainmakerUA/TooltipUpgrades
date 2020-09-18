--[=====[
		## Unit Tooltip Upgrade ver. @@release-version@@
		## UnitTooltipUpgrade.lua - module
		Initialization module for UnitTooltipUpgrade addon
--]=====]

local addonName = ...
local UnitTooltipUpgrade = LibStub("AceAddon-3.0"):NewAddon(addonName)

function UnitTooltipUpgrade:OnInitialize()
	--@debug@
	_G["UnitTooltipUpgrade"] = UnitTooltipUpgrade

	for k, v in pairs(UnitTooltipUpgrade.modules) do
		UnitTooltipUpgrade[k] = v
	end
	--@end-debug@
end
