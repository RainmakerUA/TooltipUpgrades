--[=====[
		## Tooltip Upgrades ver. @@release-version@@
		## main.lua - module
		Main module for TooltipUpgrades addon
--]=====]

local addonName = ...
local TooltipUpgrades = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Main = TooltipUpgrades:NewModule("Main", "AceHook-3.0")
local AceDB = LibStub("AceDB-3.0")
local ACReg = LibStub("AceConfigRegistry-3.0")
local ACDialog = LibStub("AceConfigDialog-3.0")
local AceL = LibStub("AceLocale-3.0"):GetLocale(addonName)
local Utils = LibStub("rmUtils-1.1")

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
local L = Utils.UpgradeL(AceL)
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

local metadata = {
	title = GetAddOnMetadata(addonName, "Title"),
	notes = GetAddOnMetadata(addonName, "Notes")
}

-- Default options
local defaults = {
	global = {
		healthBar = true,
		genderIcon = true,
		npcID = true,
		itemLevel = true,
		auraSource = true,
	}
}

local aceDB
local db

local function getOptions()
	local options = {
		type = "group",
		name = metadata.title,
		inline = true,
		get = function(info)
			return db[info[#info]]
		end,
		set = function(info, value)
			db[info[#info]] = value
		end,
		args = {
			desc = {
				type = "description",
				name = metadata.notes,
				order = 0,
			},
			unit = {
				type = "group",
				order = 10,
				name = L"Unit Tooltip",
				inline = true,
				width = "full",
				args = {
					healthBar = {
						type = "toggle",
						order = 10,
						name = L"Health Bar",
						desc = L"Add health bar to the unit (PC/NPC) tooltip",
						width = 1,
					},
					genderIcon = {
						type = "toggle",
						order = 20,
						name = L"Gender Icon",
						desc = L"Add gender (body type) icon (male/female) to the unit (PC/NPC) tooltip",
						width = 1,
					},
					npcID = {
						type = "toggle",
						order = 30,
						name = L"NPC ID",
						desc = L"Add NPC ID to the unit tooltip",
						width = 1,
					},
				},
			},
			item = {
				type = "group",
				order = 20,
				name = L"Item Tooltip",
				inline = true,
				width = "full",
				args = {
					itemLevel = {
						type = "toggle",
						order = 10,
						name = L"Item Level",
						desc = L"Add item level to the item tooltip",
						width = 1,
					},
				},
			},
			aura = {
				type = "group",
				order = 30,
				name = L"Buff/Debuff/Aura Tooltip",
				inline = true,
				width = "full",
				args = {
					auraSource = {
						type = "toggle",
						order = 10,
						name = L"Source of Aura",
						desc = L"Add source name to the aura tooltip",
						width = 1,
					},
				},
			},
		}
	}
	return options
end

function M:OnInitialize()
	-- Grab our DB and fill in the 'db' variable
	aceDB = AceDB:New(addonName .. "DB", defaults)
	db = aceDB.global

	--@debug@
	self.db = aceDB
	--@end-debug@

	-- Register our options
	ACReg:RegisterOptionsTable(addonName, getOptions)
	ACDialog:AddToBlizOptions(addonName, metadata.title)

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
		if db.healthBar then
			local hp, maxhp = UnitHealth(unit), UnitHealthMax(unit)
			local color = { GameTooltip_UnitColor(unit) }
			local _ = Frame:CreateHealthBarFrame(tt, hp, maxhp, color)
		end

		local fontString = getTooltipFontString(tt, "TextLeft1")
		local text = fontString:GetText()

		if db.genderIcon then
			local sex = UnitSex(unit)
			text = text .. "\032" .. genderTags[sex or 0]
		end

		if db.npcID then
			local guid = UnitGUID(unit)
			if (guid and guid:match("^%a+") == "Creature") then
				local id = guid:match("-(%d+)-%x+$")
				text = text .. "\032" .. WHITE_FONT_COLOR:WrapTextInColorCode(id)
			end
		end

		fontString:SetText(text)
	end
end

function M:OnTooltipSetItem(tt)
	if db.itemLevel then
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
end

function M:OnTooltipSetAura(func, tooltip, ...)
	if db.auraSource then
		local ok, _, _, _, _, _, _, caster = pcall(func, ...);

		if ok and caster then
			local pet = caster;

			caster = (UnitIsUnit(caster, "pet") and "player" or caster:gsub("[pP][eE][tT]", ""));

			tooltip:AddDoubleLine(
									" ",
									(pet == caster
										and "|cffffc000%s:|r %s"
										or "|cffffc000%s:|r %s (%s)"):format(L"Source", UnitName(caster), UnitName(pet)),
									1, 0.975, 0, RAID_CLASS_COLORS[select(2, UnitClass(caster))]:GetRGB()
								);
			tooltip:Show();
		end
	end
end

function M:OnTooltipHide()
	Frame:RemoveHealthBarFrame()
end
