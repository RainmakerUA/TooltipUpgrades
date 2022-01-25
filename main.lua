--[=====[
		## Tooltip Upgrades ver. @@release-version@@
		## main.lua - module
		Main module for TooltipUpgrades addon
--]=====]

local addonName = ...
local TooltipUpgrades = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Main = TooltipUpgrades:NewModule("Main", "AceHook-3.0")
--local AceL = LibStub("AceLocale-3.0"):GetLocale(addonName)
local Utils = LibStub("rmUtils-1.0")

local _G = _G
local pcall = pcall
local select = select
local type = type
local unpack = unpack

local GetAddOnMetadata = GetAddOnMetadata
local GetDetailedItemLevelInfo = GetDetailedItemLevelInfo
local UnitAura = UnitAura
local UnitBuff = UnitBuff
local UnitClass = UnitClass
local UnitDebuff = UnitDebuff
local UnitGUID = UnitGUID
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsUnit = UnitIsUnit
local UnitName = UnitName
local UnitSex = UnitSex
local GameTooltip = GameTooltip
local GameTooltip_UnitColor = GameTooltip_UnitColor
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local WHITE_FONT_COLOR = WHITE_FONT_COLOR

-- Remove all known globals after this point
-- luacheck: std none

local M = Main
--local L = Utils.UpgradeL(AceL)
local Frame

local genderTags
local gameTooltipShoppingTooltips

do
	local genderTex = [[Interface\Glues\CharacterCreate\UI-CharacterCreate-Gender]]
	local format = "|T%s:16:16:0:0:128:64:%d:%d:0:63|t"

	genderTags = {
		[0] = "|TInterface\\friendsframe\\blockcommunicationsicon:0|t",
		[1] = "",
		[2] = format:format(genderTex, 0, 63),
		[3] = format:format(genderTex, 64, 127),
	}
end

--[=[ TODO: Settings

local metadata = {
	title = GetAddOnMetadata(addonName, "Title"),
	notes = GetAddOnMetadata(addonName, "Notes")
}

-- Default options
local defaults = {
	profile = {
		-- Settings defaults
	}
}

local db

local function getOptions()
	local options = {
		name = metadata.title,
		type = "group",
		guiInline = true,
		get = function(info)
			return db[info[#info]]
		end,
		set = function(info, value)
			db[info[#info]] = value
		end,
		args = {
			mpdesc = {
				name = metadata.notes,
				type = "description",
				order = 0,
			},

		}
	}
	return options
end
]=]

function M:OnInitialize()
--[[	-- Grab our DB and fill in the 'db' variable
	self.db = LibStub("AceDB-3.0"):New(addonName .. "DB", defaults, "Default")
	db = self.db.profile

	-- Register our options
	local ACReg, ACDialog = LibStub("AceConfigRegistry-3.0"), LibStub("AceConfigDialog-3.0")
	local helpName = addonName .. "-Help"
	ACReg:RegisterOptionsTable(addonName, getOptions)
	ACReg:RegisterOptionsTable(helpName, getHelp)
	ACDialog:AddToBlizOptions(addonName, metadata.title)
	ACDialog:AddToBlizOptions(helpName, L["Help on patterns"], metadata.title)
]]--
	Frame = TooltipUpgrades:GetModule("Frame")
end

function M:OnEnable()
	local shopping1, shopping2 = unpack(GameTooltip.shoppingTooltips)

	self:SecureHookScript(GameTooltip, "OnTooltipSetUnit", "OnTooltipSetUnit")
	self:SecureHookScript(GameTooltip, "OnTooltipSetItem", "OnTooltipSetItem")
	self:SecureHookScript(GameTooltip.shoppingTooltips[1], "OnTooltipSetItem", "OnTooltipSetItem")
	self:SecureHookScript(GameTooltip.shoppingTooltips[2], "OnTooltipSetItem", "OnTooltipSetItem")
	self:SecureHookScript(GameTooltip, "OnHide", "OnTooltipHide")

	self:SecureHook(GameTooltip, "SetUnitAura", Utils.Bind(self.OnTooltipSetAura, self, UnitAura));
	self:SecureHook(GameTooltip, "SetUnitBuff", Utils.Bind(self.OnTooltipSetAura, self, UnitBuff));
	self:SecureHook(GameTooltip, "SetUnitDebuff", Utils.Bind(self.OnTooltipSetAura, self, UnitDebuff));

	gameTooltipShoppingTooltips = {shopping1, shopping2}
end

local function isShoppingTooltip(tt)
	return tt == gameTooltipShoppingTooltips[1] or tt == gameTooltipShoppingTooltips[2]
end

local function getTooltipFontString(tooltip, key)
	return _G[tooltip:GetName() .. key]
end

function M:OnTooltipSetUnit(tt)
	local _, unit = tt:GetUnit()

	if unit then
		local hp, maxhp, sex, guid = UnitHealth(unit), UnitHealthMax(unit), UnitSex(unit), UnitGUID(unit)
		local color = { GameTooltip_UnitColor(unit) }
		local _ = Frame:CreateHealthBarFrame(tt, hp, maxhp, color)
		local fontString = getTooltipFontString(tt, "TextLeft1")
		local text = fontString:GetText()
		local id = ""
		if (guid and guid:match("^%a+") == "Creature") then
			id = guid:match("-(%d+)-%x+$")
		end
		fontString:SetText(("%s %s %s"):format(text, genderTags[sex or 0], WHITE_FONT_COLOR:WrapTextInColorCode(id)))
	end
end

function M:OnTooltipSetItem(tt)
	local _, item = tt:GetItem()

	if item then
		local itemLevel = GetDetailedItemLevelInfo(item)

		if type(itemLevel) == "number" and itemLevel > 1 then
			local textNameSuffix = isShoppingTooltip(tt) and "TextLeft2" or "TextLeft1"
			local text = getTooltipFontString(tt, textNameSuffix)
			local orgTextValue = text:GetText()

			text:SetText(("%s :: %d"):format(orgTextValue, itemLevel))
		end
	end
end

function M:OnTooltipSetAura(func, tooltip, ...)
	local ok, _, _, _, _, _, _, caster = pcall(func, ...);

	if ok and caster then
		local pet = caster;

		caster = (UnitIsUnit(caster, "pet") and "player" or caster:gsub("[pP][eE][tT]", ""));

		tooltip:AddDoubleLine(
								" ",
								(pet == caster
									and "|cffffc000Source:|r %s"
									or "|cffffc000Source:|r %s (%s)"):format(UnitName(caster), UnitName(pet)),
								1, 0.975, 0, RAID_CLASS_COLORS[select(2, UnitClass(caster))]:GetRGB()
							);
		tooltip:Show();
	end

end

function M:OnTooltipHide()
	Frame:RemoveHealthBarFrame()
end
