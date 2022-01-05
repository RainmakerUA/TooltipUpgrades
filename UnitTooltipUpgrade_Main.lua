--[=====[
		## Unit Tooltip Upgrade ver. @@release-version@@
		## UnitTooltipUpgrade_Main.lua - module
		Main module for UnitTooltipUpgrade addon
--]=====]

local addonName = ...
local UnitTooltipUpgrade = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Main = UnitTooltipUpgrade:NewModule("Main", "AceHook-3.0")

local M = Main
local Frame

-- Locale
--local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

-- Some local functions/values
local _G = _G
local ipairs = ipairs
local pairs = pairs
local tinsert = tinsert
local tonumber = tonumber
local type = type
local math_ceil = math.ceil
local math_min = math.min
local table_concat = table.concat
local AbbreviateLargeNumbers = AbbreviateLargeNumbers
local BreakUpLargeNumbers = BreakUpLargeNumbers
local GetDetailedItemLevelInfo = GetDetailedItemLevelInfo
local GetLocale = GetLocale
local ItemRefTooltip = ItemRefTooltip
local UnitGUID = UnitGUID
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local GameTooltip = GameTooltip
local GameTooltipTextLeft1 = GameTooltipTextLeft1
local WHITE_FONT_COLOR = WHITE_FONT_COLOR

local metadata = {
	title = GetAddOnMetadata(addonName, "Title"),
	notes = GetAddOnMetadata(addonName, "Notes")
}

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

local function printThru(label, text)
	if not text then
		label, text = nil, label
	end
	print(label and label..": "..text or text)
	return text
end

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
	Frame = UnitTooltipUpgrade:GetModule("Frame")
end

function M:OnEnable()
	local shopping1, shopping2 = unpack(GameTooltip.shoppingTooltips)
	self:SecureHookScript(GameTooltip, "OnTooltipSetUnit", "OnTooltipSetUnit")
	self:SecureHookScript(GameTooltip, "OnTooltipSetItem", "OnTooltipSetItem")
	self:SecureHookScript(GameTooltip.shoppingTooltips[1], "OnTooltipSetItem", "OnTooltipSetItem")
	self:SecureHookScript(GameTooltip.shoppingTooltips[2], "OnTooltipSetItem", "OnTooltipSetItem")
	-- ItemRefTooltip, EmbeddedItemTooltip, EmbeddedItemTooltipTooltip
	self:SecureHookScript(GameTooltip, "OnHide", "OnTooltipHide")

	gameTooltipShoppingTooltips = {shopping1, shopping2}
end

local function isShoppingTooltip(tt)
	return tt == gameTooltipShoppingTooltips[1] or tt == gameTooltipShoppingTooltips[2]
end

local function findFirst(t, filterFunc)
	for k, v in pairs(t) do
		if filterFunc(v, k, t) then
			return k, v
		end
	end
	return nil
end

local function getPercent(num, whole)
	return whole ~= 0 and (num / whole) * 100 or 0
end

local function formatPercent(num, showTenths)
	local fmt
	if showTenths then
		fmt = "%.1f%%"
		num = math_ceil(10 * num) / 10
	else
		fmt = "%d%%"
		num = math_ceil(num)
	end
	return fmt:format(num) .. "%" -- double trailing percent for using result in string.gsub()
end

local function commify(num)
	if db.commify and type(num) == "number" and num >= 1000 then
		return BreakUpLargeNumbers(num)
	end
	return tostring(num)
end

function M:OnTooltipSetUnit(tt, ...)
	local _, unit = tt:GetUnit()

	if unit then
		local hp, maxhp, sex, guid = UnitHealth(unit), UnitHealthMax(unit), UnitSex(unit), UnitGUID(unit)
		local color = { GameTooltip_UnitColor(unit) }
		local frame = Frame:CreateHealthBarFrame(tt, hp, maxhp, color)
		local text = GameTooltipTextLeft1:GetText()
		local id = ""
		if (guid and guid:match("^%a+") == "Creature") then
			id = guid:match("-(%d+)-%x+$")
		end
		GameTooltipTextLeft1:SetText(("%s %s %s"):format(text, genderTags[sex or 0], WHITE_FONT_COLOR:WrapTextInColorCode(id)))
	end
end

function M:OnTooltipSetItem(tt)
	local _, item = tt:GetItem()

	if item then
		local itemLevel = GetDetailedItemLevelInfo(item)

		if type(itemLevel) == "number" and itemLevel > 1 then
			local textNameSuffix = isShoppingTooltip(tt) and "TextLeft2" or "TextLeft1"
			local text = _G[tt:GetName() .. textNameSuffix]
			local orgTextValue = text:GetText()

			text:SetText(("%s :: %d"):format(orgTextValue, itemLevel))
		end
	end
end

function M:OnTooltipHide(tt)
	Frame:RemoveHealthBarFrame()
end
