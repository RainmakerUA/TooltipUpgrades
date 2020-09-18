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
local GetLocale = GetLocale
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local GameTooltip = GameTooltip

local metadata = {
	title = GetAddOnMetadata(addonName, "Title"),
	notes = GetAddOnMetadata(addonName, "Notes")
}

local genderTags

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
	self:SecureHookScript(GameTooltip, "OnTooltipSetUnit", "OnTooltipSetUnit")
	self:SecureHookScript(GameTooltip, "OnHide", "OnTooltipHide")
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
		local hp, maxhp, sex = UnitHealth(unit), UnitHealthMax(unit), UnitSex(unit)
		local color = { GameTooltip_UnitColor(unit) }
		local frame = Frame:CreateHealthBarFrame(tt, hp, maxhp, color)
		GameTooltipTextLeft1:SetText(GameTooltipTextLeft1:GetText() .. "\32" .. genderTags[sex or 0])
	end
end

function M:OnTooltipHide(tt)
	Frame:RemoveHealthBarFrame()
end
