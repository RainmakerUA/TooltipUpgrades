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
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local print = print
local select = select
local type = type
local unpack = unpack

local math_ceil = math.ceil
local math_min = math.min
local table_concat = table.concat

local GetAddOnMetadata = GetAddOnMetadata
local GetDetailedItemLevelInfo = GetDetailedItemLevelInfo
local GetSpellPowerCost = GetSpellPowerCost or C_Spell.GetSpellPowerCost
local UnitAura = UnitAura
local UnitBuff = UnitBuff
local UnitClass = UnitClass
local UnitDebuff = UnitDebuff
local UnitGUID = UnitGUID
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsUnit = UnitIsUnit
local UnitName = UnitName
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitSex = UnitSex
local TooltipType = Enum.TooltipDataType
local GameTooltip = GameTooltip
local GameTooltip_UnitColor = GameTooltip_UnitColor
local PowerBarColor = PowerBarColor
local TooltipDataProcessor = TooltipDataProcessor
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local WHITE_FONT_COLOR = WHITE_FONT_COLOR

local powerTypeMana = Enum.PowerType.Mana
local powerTypeEssence = Enum.PowerType.Essence
local powerTypeBlood = Enum.PowerType.RuneBlood
local powerTypeFrost = Enum.PowerType.RuneFrost
local powerTypeUnholy = Enum.PowerType.RuneUnholy

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

local customPowerColors = {
	[powerTypeEssence] = RAID_CLASS_COLORS['EVOKER'],
	[powerTypeBlood] = { r = 0.8, b = 0.2, g = 0.2 },
	[powerTypeFrost] = { r = 0.6, b = 1, g = 0.6 },
	[powerTypeUnholy] = { r = 0.5, b = 0.5, g = 1 },
}

-- Default options
local defaults = {
	global = {
		healthBar = true,
		genderIcon = true,
		npcID = true,
		itemLevel = true,
		auraSource = true,
		manaCosts = {
			enabled = true,
			baseFormat = "[name][colName::] [cost] [costPM] [costPC]",
			perSecFormatNoBase = ("[name][colName:/%s:] [costSec] [costSecPM] [costSecPC]"):format(L"sec"),
			perSecFormat = ("[name][colName::] [cost] [costPM] [costPC] + [costSec] [costSecPM] [costSecPC] /%s"):format(L"sec"),
			colors = {
				colGlobal = { r = 1, g = 1, b = 1, a = 1 },
				colName = { r = 0, g = 0, b = 1, a = 1 },
				colCost = { r = 1, g = 1, b = 1, a = 1 },
				colPM = { r = 0, g = 0, b = 1, a = 1 },
				colPC = { r = 0.4, g = 0.4, b = 1, a = 1 },
				colSec = { r = 1, g = 1, b = 1, a = 1 },
				colSecPM = { r = 0, g = 0, b = 1, a = 1 },
				colSecPC = { r = 0.4, g = 0.4, b = 1, a = 1 },
			},
			useApiPercents = false,
			commify = true,
			showTenths = true,
			disableColors = false,
			colorAllCosts = false,
		}
	}
}

local aceDB
local db

local function getOptions()
	local options = {
		type = "group",
		name = metadata.title,
		childGroups = "tab",
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
			manaCosts = {
				type = "group",
				order = 40,
				name = L"Spell Costs",
				width = "full",
				get = function(info)
					return db.manaCosts[info[#info]]
				end,
				set = function(info, value)
					db.manaCosts[info[#info]] = value
				end,
				args = {
					enabled = {
						type = "toggle",
						order = 0,
						name = _G["ENABLE"],
						desc = L"Enable custom display of mana (or other power) cost for spells",
						width = 2,
					},
					patterns = {
						name = L"Patterns",
						type = "group",
						order = 1,
						inline = true,
						width = "full",
						disabled = function() return not db.manaCosts.enabled end,
						args = {
							pdesc = {
								type = "description",
								order = 10,
								name = L"Mana text patterns"
							},
							baseFormat = {
								name = L"Base Mana Cost Text Pattern",
								desc = L"Customise the mana cost text for spell with base cost only",
								type = "input",
								order = 11,
								width = "full"
							},
							perSecFormatNoBase = {
								name = L"Per Time Mana Cost Text Pattern",
								desc = L"Customise the mana cost text for spell with per-time cost only",
								type = "input",
								order = 12,
								width = "full"
							},
							perSecFormat = {
								name = L"Base + Per Time Mana Cost Text Pattern",
								desc = L"Customise the mana cost text for spell with base and per-time cost",
								type = "input",
								order = 13,
								width = "full"
							},
							commify = {
								name = L"Break up big numbers",
								desc = L"Add thousand separators to numbers over 1000",
								type = "toggle",
								order = 14,
							},
							showTenths = {
								name = L"Show tenth of percents",
								desc = L"Show percent values with tenth parts",
								type = "toggle",
								order = 15,
							},
							useApiPercents = {
								name = L"Percents by Blizzard",
								desc = L"Obtain percent values returned by WoW API",
								type = "toggle",
								order = 16,
							}
						}
					},
					colors = {
						name = L"Colors",
						type = "group",
						order = 2,
						width = "full",
						inline = true,
						get = function(info)
							local col = db.manaCosts.colors[info[#info]]
							return col.r, col.g, col.b, col.a or 1
						end,
						set = function(info, r, g, b, a)
							local col = db.manaCosts.colors[info[#info]]
							col.r, col.g, col.b, col.a = r, g, b, a
						end,
						disabled = function() return not db.manaCosts.enabled end,
						args = {
							cdesc = {
								name = L"Mana text colors",
								type = "description",
								order = 10
							},
							colGlobal = {
								name = L"General",
								desc = L"Set the color of mana cost string",
								type = "color",
								order = 20,
								hasAlpha = true,
							},
							colName = {
								name = L"Name",
								desc = L"Set the color of mana power name",
								type = "color",
								order = 30,
								hasAlpha = true,
							},
							colDummy = {
								name = "",
								type = "color",
								order = 35,
								hasAlpha = true,
								disabled = true,
								get = function() return 0, 0, 0, 0 end,
								set = function() end
							},
							colCost = {
								name = L"Cost",
								desc = L"Set the color of mana cost number",
								type = "color",
								order = 40,
								hasAlpha = true,
							},
							colPM = {
								name = L"Cost max. percent",
								desc = L"Set the color of mana cost percent of maximum amount",
								type = "color",
								order = 50,
								hasAlpha = true,
							},
							colPC = {
								name = L"Cost curr. percent",
								desc = L"Set the color of mana cost percent of current amount",
								type = "color",
								order = 60,
								hasAlpha = true,
							},
							colSec = {
								name = L"Cost per time",
								desc = L"Set the color of mana cost per time number",
								type = "color",
								order = 70,
								hasAlpha = true,
							},
							colSecPM = {
								name = L"Cost/time max. percent",
								desc = L"Set the color of mana cost per time percent of maximum amount",
								type = "color",
								order = 80,
								hasAlpha = true,
							},
							colSecPC = {
								name = L"Cost/time curr. percent",
								desc = L"Set the color of mana cost per time percent of current amount",
								type = "color",
								order = 90,
								hasAlpha = true,
							},
							colorToggles = {
								name = "",
								type = "group",
								inline = true,
								order = 95,
								get = function(info)
									return db.manaCosts[info[#info]]
								end,
								set = function(info, value)
									db.manaCosts[info[#info]] = value
								end,
								args = {
									disableColors = {
										name = L"Disable cost text coloring",
										desc = L"Ignore any color settings and display cost text in original color",
										type = "toggle",
										order = 100,
										set = function(info, value)
											if value then
												db.manaCosts.colorAllCosts = false
											end
											db.manaCosts[info[#info]] = (not db.manaCosts.disableColors) and value
										end,
									},
									colorAllCosts = {
										name = L"Color other cost powers",
										desc = L"Color cost text of all spell with its power bar color",
										type = "toggle",
										order = 110,
										disabled = function() return (not db.manaCosts.enabled) or db.manaCosts.disableColors end
									},
								},
							},
						},
					},
				},
			},
		},
	}
	return options
end

local function createGroupItems(description, items, keyMap)
	local result = {
		text = {
			name = description,
			type = "description",
			order = 10,
			fontSize = "medium",
		},
	}

	for i, v in ipairs(items) do
		local k, vv = unpack(v)
		result[k] = {
			name = keyMap and keyMap(k, vv) or k,
			type = "group",
			order = (i + 1) * 10,
			width = "full",
			guiInline = true,
			args = {
				text = {
					name = vv,
					type = "description",
					fontSize = "medium",
				},
			}
		}
	end

	return result
end

local function getHelp()
	return {
		name = L"Help on patterns",
		type = "group",
		width = "full",
		childGroups = "tab",
		args = {
			text = {
				name = L"HELP.GENERIC",
				type = "description",
				order = 1,
				fontSize = "medium",
			},
			patternGroup = {
				name = L"Content patterns",
				type = "group",
				order = 2,
				width = "full",
				args = createGroupItems(
					L"HELP.CONTENTPT", {
						{ "name", L"Name of the Power Type: \"Mana\"" },
						{ "cost", L"Number for spell base absolute power cost" },
						{ "costPM", L"Spell base cost percentage of maximum player mana amount" },
						{ "costPC", L"Spell base cost percentage of current player mana amount" },
						{ "costSec", L"Number for spell absolute power cost per second (usually for channeling spells)" },
						{ "costSecPM", L"Spell cost per second percentage of maximum player mana amount" },
						{ "costSecPC", L"Spell cost per second percentage of current player mana amount" },
					},
					function(key)
						return "|cffffff00[" .. key .. "]|r"
					end
				)
			},
			patternColGroup = {
				name = L"Text color patterns",
				type = "group",
				order = 3,
				width = "full",
				args = createGroupItems(
					L"HELP.CONTENTCOL", {
						{ "colName", L"Set text color to color of power type name color" },
						{ "colCost", L"Set text color to color of spell base cost absolute number" },
						{ "colPM", L"Set text color to color of spell cost in percent of maximum mana" },
						{ "colPC", L"Set text color to color of spell cost in percent of current mana" },
						{ "colSec", L"Set text color to color of spell absolute power cost per second" },
						{ "colSecPM", L"Set text color to color of spell cost per second in percent of maximum mana" },
						{ "colSecPC", L"Set text color to color of spell cost per second in percent of current mana" },
					},
					function(key)
						return ("|cffffff00[%s:...]|r"):format(key)
					end
				)
			},
		}
	}
end

function M:OnInitialize()
	-- Grab our DB and fill in the 'db' variable
	aceDB = AceDB:New(addonName .. "DB", defaults)

	db = aceDB.global

	--@debug@
	self.db = aceDB
	--@end-debug@

	-- Register our options
	local helpName = addonName .. "-Help"

	ACReg:RegisterOptionsTable(addonName, getOptions)
	ACReg:RegisterOptionsTable(helpName, getHelp)
	ACDialog:AddToBlizOptions(addonName, metadata.title)
	ACDialog:AddToBlizOptions(helpName, L"Help on patterns", metadata.title)

	Frame = TooltipUpgrades:GetModule("Frame")
end

function M:OnEnable()
	local shopping1, shopping2 = unpack(GameTooltip.shoppingTooltips)

	if Utils.IsClassic then
		self:SecureHookScript(GameTooltip, "OnTooltipSetSpell", "OnTooltipSetSpell")
		self:SecureHookScript(GameTooltip, "OnTooltipSetUnit", "OnTooltipSetUnit")
		self:SecureHookScript(GameTooltip, "OnTooltipSetItem", "OnTooltipSetItem")
		self:SecureHookScript(GameTooltip.shoppingTooltips[1], "OnTooltipSetItem", "OnTooltipSetItem")
		self:SecureHookScript(GameTooltip.shoppingTooltips[2], "OnTooltipSetItem", "OnTooltipSetItem")

	else
		TooltipDataProcessor.AddTooltipPostCall(TooltipType.Item, Utils.Bind(self.OnTooltipSetItem, self))
		TooltipDataProcessor.AddTooltipPostCall(TooltipType.Spell, Utils.Bind(self.OnTooltipSetSpell, self))
		TooltipDataProcessor.AddTooltipPostCall(TooltipType.Macro, Utils.Bind(self.OnTooltipSetSpell, self))
		TooltipDataProcessor.AddTooltipPostCall(TooltipType.Unit, Utils.Bind(self.OnTooltipSetUnit, self))
	end

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

local function getSpellCosts(id)
	if type(id) == "number" and id > 0 then
		local costs = Utils.Filter(
							GetSpellPowerCost(id) or {},
							function (v)
								return v.requiredAuraID == 0 or v.hasRequiredAura
							end
						)
		local _, manaCost = findFirst(
								costs,
								function(v)
									return v.type == powerTypeMana
								end
							)
		if manaCost then -- assume spells to cost only mana
			local currMana = UnitPower("player", powerTypeMana)
			local totalMana = UnitPowerMax("player", powerTypeMana)

			return {
				name = _G[manaCost.name],
				cost = manaCost.cost,
				costPerSec = manaCost.costPerSec,
				costPercentMax = db.manaCosts.useApiPercents
									and manaCost.costPercent
									or getPercent(manaCost.cost, totalMana),
				costPercentCurr = getPercent(manaCost.cost, currMana),
				costPerSecPercentMax = getPercent(manaCost.costPerSec, totalMana),
				costPerSecPercentCurr = getPercent(manaCost.costPerSec, currMana)
			}
		else
			return Utils.Map(
					-- Skip zero costs (due to some aura(s)), for they do not have costs text in tooltip
					Utils.Filter(costs, function(v) return v.cost > 0 or v.costPerSec > 0 end),
					function(v) return v.type end
				)
		end
	end
	return nil
end

local function formatPercent(num)
	local fmt
	if db.manaCosts.showTenths then
		fmt = "%.1f%%"
		num = math_ceil(10 * num) / 10
	else
		fmt = "%d%%"
		num = math_ceil(num)
	end
	return fmt:format(num) .. "%" -- double trailing percent for using result in string.gsub()
end

local function rgbaPercToHex(colorTable)
	local r, g, b, a = colorTable.r, colorTable.g, colorTable.b, colorTable.a
	r = r and r <= 1 and r >= 0 and r or 0
	g = g and g <= 1 and g >= 0 and g or 0
	b = b and b <= 1 and b >= 0 and b or 0
	a = a and a <= 1 and a >= 0 and a or 1
	return ("%02x%02x%02x%02x"):format(a * 255, r * 255, g * 255, b * 255)
end

local function wrapInColorTag(text, color)
	if not db.manaCosts.disableColors and color and text and #text > 0 then
		return ("|c%s%s|r"):format(rgbaPercToHex(color), text)
	end
	return text
end

local function replaceColorPlaceholder(colorKey, text)
	local color = db.manaCosts.colors[colorKey]
	return color and wrapInColorTag(text, color) or text
end

local function getManaCostText(costs)
	if costs then
		local result
		local cols = db.manaCosts.colors

		if costs.cost > 0 and costs.costPerSec > 0 then
			result = db.manaCosts.perSecFormat
		elseif costs.cost > 0 then
			result = db.manaCosts.baseFormat
		else
			result = db.manaCosts.perSecFormatNoBase
		end

		result = result:gsub("%[name%]", wrapInColorTag(costs.name, cols.colName))
		result = result:gsub("%[cost%]", wrapInColorTag(Utils.Commify(costs.cost), cols.colCost))
		result = result:gsub("%[costPM%]", wrapInColorTag(formatPercent(costs.costPercentMax), cols.colPM))
		result = result:gsub("%[costPC%]", wrapInColorTag(formatPercent(costs.costPercentCurr), cols.colPC))
		result = result:gsub("%[costSec%]", wrapInColorTag(Utils.Commify(costs.costPerSec), cols.colSec))
		result = result:gsub("%[costSecPM%]", wrapInColorTag(formatPercent(costs.costPerSecPercentMax), cols.colSecPM))
		result = result:gsub("%[costSecPC%]", wrapInColorTag(formatPercent(costs.costPerSecPercentCurr), cols.colSecPC))
		-- replace [colorKey:text] with text wrapped in db.manaCosts.colors[colorKey] colored tag
		result = result:gsub("%[(%a+):([^%]]+)%]", replaceColorPlaceholder)

		return wrapInColorTag(result, cols.colGlobal)
	end
	return nil
end

local function getPowerColor(powerType)
	return PowerBarColor[powerType] or customPowerColors[powerType]
end

function M:OnTooltipSetSpell(tt, data)
	if db.manaCosts.enabled then
		local id

		if data then
			if data.type == TooltipType.Macro then
				if data.lines[1] and data.lines[1].tooltipType == TooltipType.Spell then
					id = data.lines[1].tooltipID
				else
					return -- not a spell macro
				end
			elseif data.type == TooltipType.Spell then
				id = data.id
			end
		else
			id = select(2, tt:GetSpell())
		end

		if not id then
			--@debug@
			print(Utils.Text.GetError("TTU: Cannot get spell ID!"))
			--@end-debug@
			return
		end

		local costs = getSpellCosts(id)
		local textLine = getTooltipFontString(tt, "TextLeft2")
		local text = textLine:GetText()

		if not text or #text == 0 or text == "\032" then
			textLine = getTooltipFontString(tt, "TextLeft3")
			text = textLine:GetText()
		end

		if not costs then
			-- Do nothing
		elseif costs.name then
			text = getManaCostText(costs)
		elseif not db.manaCosts.disableColors and db.manaCosts.colorAllCosts and #costs > 0 then
			local parts, i = {}, 1
			for m in text:gmatch("[^\n]+") do
				parts[i] = wrapInColorTag(m, getPowerColor(costs[math_min(i, #costs)]))
				i = i + 1
			end
			text = table_concat(parts, "\n")
		end

		if text then
			textLine:SetText(text)
		end
	end
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
	if db.itemLevel and tt.GetItem then
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
