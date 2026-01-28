--[=====[
		## Tooltip Upgrades ver. @@release-version@@
		## frame.lua - module
		Frame (Status Bar) module for TooltipUpgrades addon
--]=====]

local addonName = ...
local TooltipUpgrades = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Frame = TooltipUpgrades:NewModule("Frame", "AceHook-3.0")

local unpack = unpack

local AbbreviateLargeNumbers = AbbreviateLargeNumbers
local CreateFramePool = CreateFramePool
local GameTooltip = GameTooltip
local GameTooltip_InsertFrame = GameTooltip_InsertFrame
local GameTooltipStatusBar = GameTooltipStatusBar

-- Remove all known globals after this point
-- luacheck: std none

local F = Frame
local Bar = {}

-- luacheck: push globals TooltipUpgradesStatusMixin TU_TooltipStatusBackdrop

TooltipUpgradesStatusMixin = Bar
TU_TooltipStatusBackdrop = {
							edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
							edgeSize = 10,
							insets = { left = 5, right = 5, top = 5, bottom = 5 },
						}

-- luacheck: pop

function Bar:OnLoad()
	self:SetFrameLevel(2)

	local level = self:GetFrameLevel()
	self.status:SetFrameLevel(level + 1)
	self.border:SetFrameLevel(level + 2)
end

function F:OnInitialize()
end

function F:OnEnable()
end

local function AddStatusBarFrame(tt, pool, min, max, value)
	local frame = pool:Acquire();
	local bar = frame.status

	bar:SetMinMaxValues(min, max)
	bar:SetValue(value)

	local fullHeight = GameTooltip_InsertFrame(tt, frame)
	local _, relative = frame:GetPoint(1)
	local freeHeight = fullHeight - frame:GetHeight()

	GameTooltip:SetMinimumWidth(160)
	frame:SetPoint("RIGHT", tt, "RIGHT", -10, 0)
	frame:SetPoint("TOPLEFT", relative, "TOPLEFT", 0, - freeHeight / 2)
	frame:Show()

	return frame
end

function F:CreateHealthBarFrame(parent, hp, maxhp, perchp, color)
	if not self.healthBarPool then
		self.healthBarPool = CreateFramePool("FRAME", nil, "TooltipUpgradesStatus")
	else
		self.healthBarPool:ReleaseAll()
		self.frame = nil
	end

	local frame = AddStatusBarFrame(parent, self.healthBarPool, 0, maxhp, hp)
	GameTooltipStatusBar:Hide();

	local bar = frame.status
	local border = frame.border

	bar:SetStatusBarColor(unpack(color))
	border:SetBackdropBorderColor(unpack(color))

	local abbr = AbbreviateLargeNumbers

	if not perchp then
		perchp = maxhp > 0 and ((hp / maxhp) * 100) or 0
	end

	border.leftText:SetText(("%.1f%%"):format(perchp))
	border.rightText:SetText(("%s/%s"):format(abbr(hp), abbr(maxhp)));

	--@debug@
	self.frame = frame
	--@end-debug@

	return frame
end

function F:RemoveHealthBarFrame()
	if self.healthBarPool then
		self.healthBarPool:ReleaseAll()
		self.frame = nil
	end
end
