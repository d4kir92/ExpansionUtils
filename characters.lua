local _, ExpansionUtils = ...
local WIDTH = 920
local HEIGHT = 400
local GREY = "ff808080"
local window = nil
local list = nil
local listMaps = nil
local pending = false
local RAID_DIFFICULTIES = {
	{
		["id"] = 16,
		["short"] = "M",
		["color"] = "ffff8000"
	},
	{
		["id"] = 15,
		["short"] = "H",
		["color"] = "ffa335ee"
	},
	{
		["id"] = 14,
		["short"] = "N",
		["color"] = "ff0070dd"
	},
	{
		["id"] = 17,
		["short"] = "LFR",
		["color"] = "ff1eff00"
	},
}

local RAID_RANK = {
	[17] = 1,
	[14] = 2,
	[15] = 3,
	[16] = 4
}

local VAULT_TYPES = {
	{
		["key"] = "raid",
		["type"] = 3,
		["label"] = RAID
	},
	{
		["key"] = "dungeon",
		["type"] = 1,
		["label"] = PLAYER_DIFFICULTY_MYTHIC_PLUS
	},
	{
		["key"] = "world",
		["type"] = 6,
		["label"] = WORLD
	},
}

local DATA_EVENTS = {"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_MONEY", "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_AVG_ITEM_LEVEL_UPDATE", "PLAYER_SPECIALIZATION_CHANGED", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_MAPS_UPDATE", "MYTHIC_PLUS_NEW_WEEKLY_RECORD", "WEEKLY_REWARDS_UPDATE", "BAG_UPDATE_DELAYED", "ENCOUNTER_END"}
local function GetDB()
	EVTAB = EVTAB or {}
	EVTAB["CharacterOverview"] = EVTAB["CharacterOverview"] or {}
	local db = EVTAB["CharacterOverview"]
	db["CHARS"] = db["CHARS"] or {}
	return db
end

local function Clean(value)
	if ExpansionUtils:IsSecret(value) then return nil end
	return value
end

local function Color(color, text)
	return "|c" .. color .. text .. "|r"
end

local function ColorMixinText(color, text)
	if color and color.WrapTextInColorCode then return color:WrapTextInColorCode(text) end
	return text
end

local function Icon(texture, size)
	if texture == nil then return "" end
	return "|T" .. texture .. ":" .. size .. ":" .. size .. ":0:0|t"
end

local function GetNow()
	return GetServerTime()
end

local function IsStale(char)
	return char["reset"] == nil or GetNow() >= char["reset"]
end

local function GetMapInfo(mapID)
	if mapID == nil or C_ChallengeMode == nil or C_ChallengeMode.GetMapUIInfo == nil then return nil, nil end
	local name, _, _, texture = C_ChallengeMode.GetMapUIInfo(mapID)
	return name, texture
end

local function FormatDuration(ms)
	if ms == nil then return "" end
	local seconds = math.floor(ms / 1000)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function GetSpecData()
	local getSpec = GetSpecialization
	local getInfo = GetSpecializationInfo
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then getSpec = C_SpecializationInfo.GetSpecialization end
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then getInfo = C_SpecializationInfo.GetSpecializationInfo end
	if getSpec == nil or getInfo == nil then return nil end
	local index = Clean(getSpec())
	if index == nil or index == 0 then return nil end
	local specID, name, _, icon = getInfo(index)
	return Clean(specID), Clean(name), Clean(icon)
end

local function GetItemLevelFromLink(link)
	if link == nil then return nil end
	if C_Item and C_Item.GetDetailedItemLevelInfo then return C_Item.GetDetailedItemLevelInfo(link) end
	if GetDetailedItemLevelInfo then return GetDetailedItemLevelInfo(link) end
	return nil
end

local function UpdateRuns(db, char)
	if C_MythicPlus == nil or C_MythicPlus.GetCurrentSeason == nil then return end
	local season = Clean(C_MythicPlus.GetCurrentSeason())
	if season == nil or season <= 0 then return end
	if C_PlayerInfo == nil or C_PlayerInfo.GetPlayerMythicPlusRatingSummary == nil then return end
	local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
	if summary == nil or ExpansionUtils:IsSecret(summary) then return end
	local score = Clean(summary.currentSeasonScore)
	if score == nil then return end
	db["SEASON"] = season
	if char["season"] == season and (char["score"] or 0) > score then return end
	local runs = {}
	for _, run in ipairs(summary.runs or {}) do
		local mapID = Clean(run.challengeModeID)
		local level = Clean(run.bestRunLevel)
		if mapID and level and level > 0 then
			runs[mapID] = {
				["level"] = level,
				["score"] = Clean(run.mapScore),
				["timed"] = Clean(run.finishedSuccess) == true,
				["duration"] = Clean(run.bestRunDurationMS)
			}
		end
	end

	char["season"] = season
	char["score"] = score
	char["runs"] = runs
end

local function UpdateKeystone(char)
	if C_MythicPlus == nil or C_MythicPlus.GetOwnedKeystoneChallengeMapID == nil then return end
	local mapID = Clean(C_MythicPlus.GetOwnedKeystoneChallengeMapID())
	local level = Clean(C_MythicPlus.GetOwnedKeystoneLevel())
	if mapID and mapID > 0 and level and level > 0 then
		char["keyMap"] = mapID
		char["keyLevel"] = level
	else
		char["keyMap"] = nil
		char["keyLevel"] = nil
	end
end

local function UpdateVault(char)
	if C_WeeklyRewards == nil or C_WeeklyRewards.GetActivities == nil then return false end
	local vault = {}
	local found = false
	for _, vaultType in ipairs(VAULT_TYPES) do
		local slots = {}
		for _, activity in ipairs(C_WeeklyRewards.GetActivities(vaultType.type) or {}) do
			local progress = Clean(activity.progress)
			local threshold = Clean(activity.threshold)
			if progress and threshold then
				local ilvl = nil
				if progress >= threshold and C_WeeklyRewards.GetExampleRewardItemHyperlinks then ilvl = GetItemLevelFromLink(C_WeeklyRewards.GetExampleRewardItemHyperlinks(activity.id)) end
				tinsert(
					slots,
					{
						["index"] = activity.index,
						["progress"] = progress,
						["threshold"] = threshold,
						["ilvl"] = ilvl
					}
				)
			end
		end

		table.sort(slots, function(a, b) return a.index < b.index end)
		if #slots > 0 then found = true end
		vault[vaultType.key] = slots
	end

	if not found then return false end
	char["vault"] = vault
	if C_WeeklyRewards.HasAvailableRewards then
		char["vaultRewards"] = Clean(C_WeeklyRewards.HasAvailableRewards()) == true
	end

	return true
end

local function UpdateRaid(char)
	if C_WeeklyRewards == nil or C_WeeklyRewards.GetActivityEncounterInfo == nil then return false end
	local encounters = C_WeeklyRewards.GetActivityEncounterInfo(3, 1)
	if encounters == nil or #encounters == 0 then return false end
	local raid = {
		["total"] = 0,
		["kills"] = {}
	}

	for _, difficulty in ipairs(RAID_DIFFICULTIES) do
		raid.kills[difficulty.id] = 0
	end

	for _, encounter in ipairs(encounters) do
		raid.total = raid.total + 1
		local rank = RAID_RANK[Clean(encounter.bestDifficulty) or 0]
		if rank then
			for _, difficulty in ipairs(RAID_DIFFICULTIES) do
				if rank >= RAID_RANK[difficulty.id] then raid.kills[difficulty.id] = raid.kills[difficulty.id] + 1 end
			end
		end
	end

	char["raid"] = raid
	return true
end

local function GetSeasonMaps()
	local db = GetDB()
	local maps = {}
	if C_ChallengeMode and C_ChallengeMode.GetMapTable then
		for _, mapID in ipairs(C_ChallengeMode.GetMapTable() or {}) do
			tinsert(maps, mapID)
		end
	end

	if #maps > 0 then
		db["MAPS"] = maps
	else
		for _, mapID in ipairs(db["MAPS"] or {}) do
			tinsert(maps, mapID)
		end
	end

	table.sort(
		maps,
		function(a, b)
			local nameA = GetMapInfo(a) or ""
			local nameB = GetMapInfo(b) or ""
			if nameA == nameB then return a < b end
			return nameA < nameB
		end
	)

	return maps
end

local function GetRuns(char)
	if char["season"] == nil or char["season"] ~= GetDB()["SEASON"] then return nil end
	return char["runs"]
end

local function GetVaultSlots(char, key)
	if char["vault"] == nil then return nil end
	return char["vault"][key]
end

local function HasVaultRewardsWaiting(char)
	if not IsStale(char) then return char["vaultRewards"] == true end
	if char["vaultRewards"] then return true end
	for _, vaultType in ipairs(VAULT_TYPES) do
		for _, slot in ipairs(GetVaultSlots(char, vaultType.key) or {}) do
			if slot.progress >= slot.threshold then return true end
		end
	end

	return false
end

local function GetVaultState(char, key)
	local slots = GetVaultSlots(char, key)
	if slots == nil or #slots == 0 then return nil end
	local stale = IsStale(char)
	local maxThreshold = slots[#slots].threshold
	local progress = 0
	local unlocked = 0
	for _, slot in ipairs(slots) do
		if not stale then
			progress = math.max(progress, slot.progress)
			if slot.progress >= slot.threshold then unlocked = unlocked + 1 end
		end
	end

	return slots, math.min(progress, maxThreshold), maxThreshold, unlocked, stale
end

local function GetRaidKills(char)
	local raid = char["raid"]
	if raid == nil or raid.total == nil or raid.total == 0 then return nil end
	if IsStale(char) then return raid.total, {} end
	return raid.total, raid.kills or {}
end

function ExpansionUtils:UpdateCharacterOverviewData()
	if InCombatLockdown() then return end
	local guid = Clean(UnitGUID("player"))
	if guid == nil then return end
	local db = GetDB()
	local char = db["CHARS"][guid] or {}
	db["CHARS"][guid] = char
	local className, classFile = UnitClass("player")
	char["name"] = Clean(UnitName("player")) or char["name"]
	char["realm"] = Clean(GetRealmName()) or char["realm"]
	char["className"] = Clean(className) or char["className"]
	char["class"] = Clean(classFile) or char["class"]
	char["level"] = Clean(UnitLevel("player")) or char["level"]
	local specID, specName, specIcon = GetSpecData()
	if specID then
		char["specID"] = specID
		char["specName"] = specName
		char["specIcon"] = specIcon
	end

	local _, equipped = GetAverageItemLevel()
	char["ilvl"] = Clean(equipped) or char["ilvl"]
	char["money"] = Clean(GetMoney()) or char["money"]
	UpdateRuns(db, char)
	UpdateKeystone(char)
	local wasStale = IsStale(char)
	if not UpdateVault(char) and wasStale then
		char["vault"] = nil
		char["vaultRewards"] = nil
	end

	if not UpdateRaid(char) and wasStale then char["raid"] = nil end
	if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
		local seconds = Clean(C_DateAndTime.GetSecondsUntilWeeklyReset())
		if seconds then char["reset"] = GetNow() + seconds end
	end

	char["updated"] = GetNow()
	if window and window:IsShown() and list then list:SetRows(ExpansionUtils:GetCharacterOverviewRows()) end
end

function ExpansionUtils:GetCharacterOverviewRows()
	local rows = {}
	for _, char in pairs(GetDB()["CHARS"]) do
		if char["name"] then tinsert(rows, char) end
	end
	return rows
end

local function RequestUpdate(delay)
	if pending then return end
	pending = true
	C_Timer.After(
		delay or 2,
		function()
			pending = false
			ExpansionUtils:UpdateCharacterOverviewData()
		end
	)
end

local function NameTooltip(tooltip, char)
	local _, _, _, colorStr = ExpansionUtils:GetClassColor(char["class"])
	tooltip:AddLine(Color(colorStr, char["name"]) .. " - " .. (char["realm"] or ""))
	tooltip:AddLine((char["className"] or "") .. " " .. (char["level"] or ""), 1, 1, 1)
	if HasVaultRewardsWaiting(char) then tooltip:AddLine(ExpansionUtils:Trans("LID_GREATVAULT") .. ": " .. ExpansionUtils:Trans("LID_REWARDSWAITING"), 0, 1, 0) end
	if char["updated"] then tooltip:AddDoubleLine(ExpansionUtils:Trans("LID_LASTUPDATE"), date("%Y-%m-%d %H:%M", char["updated"]), 0.7, 0.7, 0.7, 1, 1, 1) end
end

local function RunTooltip(tooltip, mapID, char)
	local name = GetMapInfo(mapID)
	tooltip:AddLine(name or tostring(mapID))
	local runs = GetRuns(char)
	local run = runs and runs[mapID]
	if run == nil then
		tooltip:AddLine("-", 0.5, 0.5, 0.5)
		return
	end

	tooltip:AddDoubleLine(ExpansionUtils:Trans("LID_LEVELSHORT"), "+" .. run.level, 1, 1, 1, 1, 1, 1)
	if run.score then tooltip:AddDoubleLine(ExpansionUtils:Trans("LID_SCORE"), tostring(run.score), 1, 1, 1, 1, 1, 1) end
	if run.duration then tooltip:AddDoubleLine(ExpansionUtils:Trans("LID_TIME"), FormatDuration(run.duration), 1, 1, 1, 1, 1, 1) end
	if run.timed then
		tooltip:AddLine(ExpansionUtils:Trans("LID_TIMED"), 0, 1, 0)
	else
		tooltip:AddLine(ExpansionUtils:Trans("LID_NOTTIMED"), 1, 0.3, 0.3)
	end
end

local function VaultTooltip(tooltip, vaultType, char)
	tooltip:AddLine(ExpansionUtils:Trans("LID_GREATVAULT") .. ": " .. (vaultType.label or ""))
	local slots, _, _, _, stale = GetVaultState(char, vaultType.key)
	if slots == nil then return end
	if stale then
		tooltip:AddLine(ExpansionUtils:Trans("LID_OUTDATED"), 0.5, 0.5, 0.5)
		if HasVaultRewardsWaiting(char) then tooltip:AddLine(ExpansionUtils:Trans("LID_REWARDSWAITING"), 0, 1, 0) end
		return
	end

	for index, slot in ipairs(slots) do
		local r, g, b = 1, 1, 0
		if slot.progress >= slot.threshold then
			r, g, b = 0, 1, 0
		elseif slot.progress == 0 then
			r, g, b = 0.5, 0.5, 0.5
		end

		local right = ""
		if slot.ilvl then right = ExpansionUtils:Trans("LID_ITEMLEVELSHORT") .. " " .. slot.ilvl end
		tooltip:AddDoubleLine(index .. ".  " .. math.min(slot.progress, slot.threshold) .. "/" .. slot.threshold, right, r, g, b, 1, 1, 1)
	end
end

local function BuildColumns(maps)
	local columns = {
		{
			["key"] = "name",
			["label"] = "LID_NAME",
			["width"] = 100,
			["flex"] = true,
			["text"] = function(char)
				local _, _, _, colorStr = ExpansionUtils:GetClassColor(char["class"])
				local text = Color(colorStr, char["name"])
				if HasVaultRewardsWaiting(char) then text = text .. " |A:GreatVault-32x32:14:14|a" end
				return text
			end,
			["value"] = function(char) return char["name"] end,
			["tooltip"] = NameTooltip
		},
		{
			["key"] = "level",
			["label"] = "LID_LEVELSHORT",
			["width"] = 34,
			["align"] = "CENTER",
			["descending"] = true
		},
		{
			["key"] = "spec",
			["label"] = "LID_SPEC",
			["width"] = 34,
			["align"] = "CENTER",
			["text"] = function(char) return Icon(char["specIcon"], 16) end,
			["value"] = function(char) return char["specName"] end,
			["tooltip"] = function(tooltip, char) if char["specName"] then tooltip:AddLine(char["specName"], 1, 1, 1) end end
		},
		{
			["key"] = "ilvl",
			["label"] = "LID_ITEMLEVELSHORT",
			["headerTooltip"] = "LID_ITEMLEVEL",
			["width"] = 44,
			["align"] = "CENTER",
			["descending"] = true,
			["text"] = function(char)
				if char["ilvl"] == nil then return "" end
				return tostring(math.floor(char["ilvl"]))
			end,
			["tooltip"] = function(tooltip, char) if char["ilvl"] then tooltip:AddDoubleLine(ExpansionUtils:Trans("LID_ITEMLEVEL"), string.format("%.1f", char["ilvl"]), 1, 1, 1, 1, 1, 1) end end
		},
		{
			["key"] = "score",
			["label"] = "LID_SCORE",
			["headerTooltip"] = "LID_MYTHICPLUSSCORE",
			["width"] = 48,
			["align"] = "CENTER",
			["descending"] = true,
			["text"] = function(char)
				local score = nil
				if GetRuns(char) then score = char["score"] end
				if score == nil then return "" end
				local color = nil
				if C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor then color = C_ChallengeMode.GetDungeonScoreRarityColor(score) end
				return ColorMixinText(color, tostring(score))
			end,
			["value"] = function(char)
				if GetRuns(char) then return char["score"] end
				return nil
			end
		},
	}

	for _, mapID in ipairs(maps) do
		local name, texture = GetMapInfo(mapID)
		local label = nil
		if texture == nil then label = name end
		tinsert(
			columns,
			{
				["key"] = "map" .. mapID,
				["icon"] = texture,
				["label"] = label,
				["headerTooltip"] = name,
				["group"] = "LID_BESTRUNS",
				["width"] = 32,
				["align"] = "CENTER",
				["descending"] = true,
				["text"] = function(char)
					local runs = GetRuns(char)
					local run = runs and runs[mapID]
					if run == nil then return "" end
					if not run.timed then return Color(GREY, run.level) end
					local color = nil
					if run.score and C_ChallengeMode and C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor then color = C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(run.score) end
					return ColorMixinText(color, tostring(run.level))
				end,
				["value"] = function(char)
					local runs = GetRuns(char)
					local run = runs and runs[mapID]
					if run == nil then return nil end
					return run.score or run.level
				end,
				["tooltip"] = function(tooltip, char) RunTooltip(tooltip, mapID, char) end
			}
		)
	end

	tinsert(
		columns,
		{
			["key"] = "keystone",
			["label"] = "LID_KEYSTONE",
			["width"] = 56,
			["align"] = "CENTER",
			["descending"] = true,
			["text"] = function(char)
				if char["keyLevel"] == nil then return "" end
				local _, texture = GetMapInfo(char["keyMap"])
				local level = tostring(char["keyLevel"])
				if IsStale(char) then
					level = Color(GREY, level)
				elseif C_ChallengeMode and C_ChallengeMode.GetKeystoneLevelRarityColor then
					level = ColorMixinText(C_ChallengeMode.GetKeystoneLevelRarityColor(char["keyLevel"]), level)
				end
				return Icon(texture, 14) .. " " .. level
			end,
			["value"] = function(char) return char["keyLevel"] end,
			["tooltip"] = function(tooltip, char)
				if char["keyLevel"] == nil then return end
				local name = GetMapInfo(char["keyMap"])
				tooltip:AddLine((name or "") .. " +" .. char["keyLevel"])
				if IsStale(char) then tooltip:AddLine(ExpansionUtils:Trans("LID_OUTDATED"), 0.5, 0.5, 0.5) end
			end
		}
	)

	tinsert(
		columns,
		{
			["key"] = "money",
			["label"] = "LID_GOLD",
			["width"] = 84,
			["align"] = "RIGHT",
			["descending"] = true,
			["text"] = function(char)
				if char["money"] == nil then return "" end
				local gold = math.floor(char["money"] / 10000)
				if BreakUpLargeNumbers then gold = BreakUpLargeNumbers(gold) end
				return gold .. " |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t"
			end,
			["tooltip"] = function(tooltip, char)
				if char["money"] == nil or GetMoneyString == nil then return end
				tooltip:AddLine(GetMoneyString(char["money"], true), 1, 1, 1)
			end
		}
	)

	tinsert(
		columns,
		{
			["key"] = "raid",
			["label"] = "LID_RAIDPROGRESS",
			["headerTooltip"] = "LID_RAIDPROGRESSWEEK",
			["width"] = 60,
			["align"] = "CENTER",
			["descending"] = true,
			["text"] = function(char)
				local total, kills = GetRaidKills(char)
				if total == nil then return "" end
				for _, difficulty in ipairs(RAID_DIFFICULTIES) do
					local count = kills[difficulty.id] or 0
					if count > 0 then return Color(difficulty.color, count .. "/" .. total .. " " .. difficulty.short) end
				end
				return Color(GREY, "0/" .. total)
			end,
			["value"] = function(char)
				local total, kills = GetRaidKills(char)
				if total == nil then return nil end
				return (kills[16] or 0) * 1000000 + (kills[15] or 0) * 10000 + (kills[14] or 0) * 100 + (kills[17] or 0)
			end,
			["tooltip"] = function(tooltip, char)
				local total, kills = GetRaidKills(char)
				if total == nil then return end
				tooltip:AddLine(ExpansionUtils:Trans("LID_RAIDPROGRESSWEEK"))
				if IsStale(char) then tooltip:AddLine(ExpansionUtils:Trans("LID_OUTDATED"), 0.5, 0.5, 0.5) end
				for _, difficulty in ipairs(RAID_DIFFICULTIES) do
					local name = GetDifficultyInfo and GetDifficultyInfo(difficulty.id) or difficulty.short
					tooltip:AddDoubleLine(Color(difficulty.color, name), (kills[difficulty.id] or 0) .. "/" .. total, 1, 1, 1, 1, 1, 1)
				end
			end
		}
	)

	for _, vaultType in ipairs(VAULT_TYPES) do
		tinsert(
			columns,
			{
				["key"] = "vault" .. vaultType.key,
				["label"] = vaultType.label,
				["group"] = "LID_GREATVAULT",
				["width"] = 44,
				["align"] = "CENTER",
				["descending"] = true,
				["text"] = function(char)
					local slots, progress, maxThreshold, unlocked = GetVaultState(char, vaultType.key)
					if slots == nil then return "" end
					local color = GREY
					if unlocked >= #slots then
						color = "ff00ff00"
					elseif unlocked > 0 then
						color = "ffffff00"
					end
					return Color(color, progress .. "/" .. maxThreshold)
				end,
				["value"] = function(char)
					local slots, progress, _, unlocked = GetVaultState(char, vaultType.key)
					if slots == nil then return nil end
					return unlocked * 1000 + progress
				end,
				["tooltip"] = function(tooltip, char) VaultTooltip(tooltip, vaultType, char) end
			}
		)
	end

	return columns
end

local function IsSameMaps(a, b)
	if a == nil or b == nil or #a ~= #b then return false end
	for index, mapID in ipairs(a) do
		if b[index] ~= mapID then return false end
	end

	return true
end

local function CreateWindow()
	local db = GetDB()
	window = ExpansionUtils:CreateUIWindow({
		["name"] = "ExpansionUtilsCharacterOverview",
		["title"] = "LID_CHARACTEROVERVIEW",
		["width"] = math.max(db["WIDTH"] or WIDTH, WIDTH),
		["height"] = db["HEIGHT"] or HEIGHT,
		["minWidth"] = WIDTH,
		["minHeight"] = 200,
		["pTab"] = db["POINT"],
		["onResize"] = function(width, height)
			db["WIDTH"] = width
			db["HEIGHT"] = height
		end,
		["onMove"] = function(point, relativePoint, x, y) db["POINT"] = {point, "UIParent", relativePoint, x, y} end,
	})

	tinsert(UISpecialFrames, "ExpansionUtilsCharacterOverview")
	listMaps = GetSeasonMaps()
	list = window:AddList({
		["columns"] = BuildColumns(listMaps),
		["rows"] = ExpansionUtils:GetCharacterOverviewRows(),
		["sortKey"] = db["SORTKEY"] or "name",
		["ascending"] = db["ASCENDING"],
		["onSort"] = function(key, ascending)
			db["SORTKEY"] = key
			db["ASCENDING"] = ascending
		end,
	})
end

function ExpansionUtils:ToggleCharacterOverview()
	if window == nil then CreateWindow() end
	if window:IsShown() then
		window:Hide()
		return
	end

	local maps = GetSeasonMaps()
	if not IsSameMaps(maps, listMaps) then
		listMaps = maps
		list:SetColumns(BuildColumns(maps))
	end

	ExpansionUtils:UpdateCharacterOverviewData()
	list:SetRows(ExpansionUtils:GetCharacterOverviewRows())
	window:Show()
end

local fData = CreateFrame("Frame")
ExpansionUtils:RegisterEvent(fData, "PLAYER_LOGIN")
ExpansionUtils:OnEvent(
	fData,
	function(sel, event)
		if event == "PLAYER_LOGIN" then
			ExpansionUtils:UnregisterEvent(fData, "PLAYER_LOGIN")
			for _, dataEvent in ipairs(DATA_EVENTS) do
				ExpansionUtils:RegisterEvent(fData, dataEvent)
			end

			if C_MythicPlus and C_MythicPlus.RequestMapInfo then C_MythicPlus.RequestMapInfo() end
			EVTAB = EVTAB or {}
			if EVTAB["MMBtnCharacterOverview"] == nil then
				EVTAB["MMBtnCharacterOverview"] = {}
				ExpansionUtils:SV(EVTAB["MMBtnCharacterOverview"], "MMBTNCHARACTEROVERVIEW", true)
			end

			if ExpansionUtils:GV(EVTAB["MMBtnCharacterOverview"], "MMBTNCHARACTEROVERVIEW", true) then
				ExpansionUtils:CreateMinimapButton({
					["name"] = "ExpansionUtilsCharacterOverview",
					["icon"] = "Interface\\Icons\\INV_Misc_GroupNeedMore",
					["dbtab"] = EVTAB["MMBtnCharacterOverview"],
					["vTT"] = {{ExpansionUtils:Trans("LID_CHARACTEROVERVIEW"), "|T136033:16:16:0:0|t ExpansionUtils"}, {ExpansionUtils:Trans("LID_LEFTCLICK"), ExpansionUtils:Trans("LID_TOGGLECHARACTEROVERVIEW")}},
					["funcL"] = function() ExpansionUtils:ToggleCharacterOverview() end,
					["addoncomp"] = false,
					["dbkey"] = "MMBTNCHARACTEROVERVIEW"
				})
			end
		end

		RequestUpdate(3)
	end, "ExpansionUtils CharacterOverview"
)
