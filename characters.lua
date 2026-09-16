local _, ExpansionUtils = ...
local DEFAULT_WIDTH = 920
local DEFAULT_HEIGHT = 400
local MIN_HEIGHT = 200
local FONT_MIN = 8
local FONT_MAX = 18
local GREY = "ff808080"
local MISSING = "|c" .. GREY .. "?|r"
local window = nil
local list = nil
local listMaps = nil
local onlyMaxLevel = nil
local accountGold = nil
local accountPlayed = nil
local fontSlider = nil
local settingFontSize = false
local LOADING = "|c" .. GREY .. "...|r"
local RAID_HISTORY_BUDGET = 4
local raidHistory = nil
local raidHistoryRetry = 0
local raidHistoryJob = nil
local raidHistoryFrame = CreateFrame("Frame")
local currentChar = nil
local columnTree = nil
local childSkillLines = {}
local pending = false
local playedTotal = nil
local playedLevel = nil
local playedAt = nil
local playedFrames = nil
local playedRequest = 0
local RAID_DIFFICULTIES = {
	{
		["id"] = 17,
		["short"] = "LFR",
		["color"] = "ff1eff00"
	},
	{
		["id"] = 14,
		["short"] = "N",
		["color"] = "ff0070dd"
	},
	{
		["id"] = 15,
		["short"] = "H",
		["color"] = "ffa335ee"
	},
	{
		["id"] = 16,
		["short"] = "M",
		["color"] = "ffff8000"
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

local DATA_EVENTS = {"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_MONEY", "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_AVG_ITEM_LEVEL_UPDATE", "PLAYER_SPECIALIZATION_CHANGED", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_MAPS_UPDATE", "MYTHIC_PLUS_NEW_WEEKLY_RECORD", "WEEKLY_REWARDS_UPDATE", "BAG_UPDATE_DELAYED", "ENCOUNTER_END", "ACCOUNT_MONEY", "BANKFRAME_OPENED", "SKILL_LINES_CHANGED", "TRADE_SKILL_SHOW", "TRAIT_CONFIG_UPDATED", "CURRENCY_DISPLAY_UPDATE", "TIME_PLAYED_MSG", "PLAYER_LOGOUT"}
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

local function Trans(key)
	return ExpansionUtils:Trans(key)
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

local function ScaledIcon(size)
	if list then return list:Scaled(size) end
	return size
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

local function GetDifficultyName(difficulty)
	if GetDifficultyInfo then return GetDifficultyInfo(difficulty.id) or difficulty.short end
	return difficulty.short
end

local function FormatGold(copper, iconSize)
	local gold = math.floor(copper / 10000)
	if BreakUpLargeNumbers then gold = BreakUpLargeNumbers(gold) end
	return gold .. " " .. Icon("Interface\\MoneyFrame\\UI-GoldIcon", iconSize or 12)
end

local function GetBaseFontSize()
	if GameFontHighlightSmall and GameFontHighlightSmall.GetFont then
		local _, size = GameFontHighlightSmall:GetFont()
		if size and size > 0 then return math.floor(size + 0.5) end
	end

	return 10
end

local function GetFontSize()
	local size = GetDB()["FONTSIZE"] or GetBaseFontSize()
	return math.min(FONT_MAX, math.max(FONT_MIN, size))
end

local function GetMaxLevel()
	if GetMaxLevelForPlayerExpansion then return Clean(GetMaxLevelForPlayerExpansion()) end
	return MAX_PLAYER_LEVEL
end

local function HasWarbandMoney()
	return C_Bank ~= nil and C_Bank.FetchDepositedMoney ~= nil and Enum ~= nil and Enum.BankType ~= nil and Enum.BankType.Account ~= nil
end

local function HasKnowledgePoints()
	return C_ProfSpecs ~= nil and C_ProfSpecs.GetCurrencyInfoForSkillLine ~= nil
end

local function UpdateWarbandMoney(changed)
	if not HasWarbandMoney() then return end
	local ok, money = pcall(C_Bank.FetchDepositedMoney, Enum.BankType.Account)
	money = Clean(money)
	if not ok or type(money) ~= "number" then return end
	if changed or money > 0 then GetDB()["WARBANDMONEY"] = money end
end

local function FormatDuration(ms)
	if ms == nil then return "" end
	local seconds = math.floor(ms / 1000)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function SplitSeconds(seconds)
	seconds = math.max(0, math.floor(seconds))
	return math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600), math.floor(seconds % 3600 / 60), seconds % 60
end

local function FormatPlayedShort(seconds)
	if SecondsToTime then
		local text = SecondsToTime(math.max(0, seconds), true, false, 2)
		if text and text ~= "" then return text end
		if MINUTES_ABBR then return string.format(MINUTES_ABBR, 0) end
	end

	local days, hours, minutes = SplitSeconds(seconds)
	local dayFormat = DAY_ONELETTER_ABBR or "%d d"
	local hourFormat = HOUR_ONELETTER_ABBR or "%d h"
	local minuteFormat = MINUTE_ONELETTER_ABBR or "%d m"
	if days > 0 then return string.format(dayFormat, days) .. " " .. string.format(hourFormat, hours) end
	if hours > 0 then return string.format(hourFormat, hours) .. " " .. string.format(minuteFormat, minutes) end
	return string.format(minuteFormat, minutes)
end

local function FormatPlayedLong(seconds)
	if TIME_DAYHOURMINUTESECOND == nil then return FormatPlayedShort(seconds) end
	return string.format(TIME_DAYHOURMINUTESECOND, SplitSeconds(seconds))
end

local function GetChatFrames()
	local frames = {}
	if type(CHAT_FRAMES) == "table" then
		for _, name in ipairs(CHAT_FRAMES) do
			if _G[name] then tinsert(frames, _G[name]) end
		end
	else
		for index = 1, NUM_CHAT_WINDOWS or 10 do
			if _G["ChatFrame" .. index] then tinsert(frames, _G["ChatFrame" .. index]) end
		end
	end

	return frames
end

local function RestorePlayedMessages()
	if playedFrames == nil then return end
	for _, frame in ipairs(playedFrames) do
		frame:RegisterEvent("TIME_PLAYED_MSG")
	end

	playedFrames = nil
end

local function RequestPlayed()
	if RequestTimePlayed == nil or playedFrames then return end
	playedFrames = {}
	for _, frame in ipairs(GetChatFrames()) do
		if frame.IsEventRegistered and frame:IsEventRegistered("TIME_PLAYED_MSG") then
			frame:UnregisterEvent("TIME_PLAYED_MSG")
			tinsert(playedFrames, frame)
		end
	end

	playedRequest = playedRequest + 1
	local request = playedRequest
	RequestTimePlayed()
	C_Timer.After(
		10,
		function()
			if request == playedRequest then RestorePlayedMessages() end
		end
	)
end

local function OnTimePlayed(total, level)
	total = Clean(total)
	level = Clean(level)
	if type(total) == "number" and type(level) == "number" then
		playedTotal = total
		playedLevel = level
		playedAt = GetTime()
	end

	C_Timer.After(0, RestorePlayedMessages)
end

local function UpdatePlayed(char)
	if playedAt == nil then return end
	local elapsed = math.floor(GetTime() - playedAt)
	char["played"] = playedTotal + elapsed
	char["playedLevel"] = playedLevel + elapsed
end

local function NewKills()
	local kills = {}
	for _, difficulty in ipairs(RAID_DIFFICULTIES) do
		kills[difficulty.id] = 0
	end

	return kills
end

local function AddKills(kills, rank)
	for _, difficulty in ipairs(RAID_DIFFICULTIES) do
		if rank >= RAID_RANK[difficulty.id] then kills[difficulty.id] = kills[difficulty.id] + 1 end
	end
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
		["kills"] = NewKills()
	}

	for _, encounter in ipairs(encounters) do
		raid.total = raid.total + 1
		local rank = RAID_RANK[Clean(encounter.bestDifficulty) or 0]
		if rank then AddKills(raid.kills, rank) end
	end

	char["raid"] = raid
	return true
end

local DIFFICULTY_STRINGS = {
	[17] = {"PLAYER_DIFFICULTY3", "RAID_FINDER"},
	[14] = {"PLAYER_DIFFICULTY1"},
	[15] = {"PLAYER_DIFFICULTY2"},
	[16] = {"PLAYER_DIFFICULTY6"},
}

local function NormalizeName(name)
	return string.lower(string.gsub(name, "[%s%p]", ""))
end

local function SplitStatisticName(statName)
	local cut = string.find(statName, "(", 1, true)
	local width = 1
	local wide = string.find(statName, "\239\188\136", 1, true)
	if wide and (cut == nil or wide < cut) then
		cut = wide
		width = 3
	end

	if cut == nil or cut <= 1 then return nil, nil end
	return NormalizeName(string.sub(statName, 1, cut - 1)), string.sub(statName, cut + width)
end

local function FindStatisticBoss(key, bossKeys)
	if key == nil or key == "" then return nil end
	if bossKeys[key] then return bossKeys[key], true end
	local best = nil
	local bestLength = 0
	for bossKey, boss in pairs(bossKeys) do
		local length = math.min(#bossKey, #key)
		if length >= 4 and length > bestLength and string.sub(key, 1, length) == string.sub(bossKey, 1, length) then
			best = boss
			bestLength = length
		end
	end

	return best, false
end

local function GetDifficultyNames()
	local names = {}
	for _, difficulty in ipairs(RAID_DIFFICULTIES) do
		local difficultyNames = {}
		if GetDifficultyInfo then
			local name = GetDifficultyInfo(difficulty.id)
			if type(name) == "string" and name ~= "" then tinsert(difficultyNames, name) end
		end

		for _, global in ipairs(DIFFICULTY_STRINGS[difficulty.id]) do
			if type(_G[global]) == "string" and _G[global] ~= "" then tinsert(difficultyNames, _G[global]) end
		end

		names[difficulty.id] = difficultyNames
	end

	return names
end

local function GetStatisticDifficulty(detail, difficultyNames)
	if detail == nil then return nil end
	local lowerDetail = string.lower(detail)
	local best = nil
	local bestLength = 0
	for difficultyID, names in pairs(difficultyNames) do
		for _, name in ipairs(names) do
			if #name > bestLength and (string.find(detail, name, 1, true) or string.find(lowerDetail, string.lower(name), 1, true)) then
				best = difficultyID
				bestLength = #name
			end
		end
	end

	return best
end

local function HasRaidHistoryAPI()
	if EJ_GetNumTiers == nil or EJ_SelectTier == nil or EJ_GetCurrentTier == nil or EJ_GetInstanceByIndex == nil or EJ_GetInstanceInfo == nil or EJ_SelectInstance == nil or EJ_GetEncounterInfoByIndex == nil or GetServerExpansionLevel == nil then return false end
	return GetStatisticsCategoryList ~= nil and GetCategoryNumAchievements ~= nil and GetAchievementInfo ~= nil and GetStatistic ~= nil and debugprofilestop ~= nil
end

local function WaitForJournal()
	while EncounterJournal and EncounterJournal:IsShown() do
		coroutine.yield()
	end
end

local function RestoreJournal(previousTier)
	if previousTier and EJ_GetCurrentTier() ~= previousTier then EJ_SelectTier(previousTier) end
	if EncounterJournal and EncounterJournal.instanceID then EJ_SelectInstance(EncounterJournal.instanceID) end
end

local function BuildRaidHistory()
	local tier = GetServerExpansionLevel() + 1
	if tier > EJ_GetNumTiers() then return nil end
	WaitForJournal()
	local raids = {}
	local previousTier = EJ_GetCurrentTier()
	EJ_SelectTier(tier)
	local index = 1
	local instanceID = EJ_GetInstanceByIndex(index, true)
	while instanceID do
		if select(9, EJ_GetInstanceInfo(instanceID)) then
			tinsert(
				raids,
				{
					["instanceID"] = instanceID,
					["bosses"] = {}
				}
			)
		end

		index = index + 1
		instanceID = EJ_GetInstanceByIndex(index, true)
	end

	RestoreJournal(previousTier)
	local bossKeys = {}
	for _, raid in ipairs(raids) do
		coroutine.yield()
		WaitForJournal()
		previousTier = EJ_GetCurrentTier()
		EJ_SelectInstance(raid.instanceID)
		local bossIndex = 1
		local bossName, _, bossID = EJ_GetEncounterInfoByIndex(bossIndex)
		while bossName and bossID and bossID > 0 do
			local boss = {
				["stats"] = {},
				["fuzzy"] = {},
				["byDifficulty"] = {}
			}

			tinsert(raid.bosses, boss)
			bossKeys[NormalizeName(bossName)] = boss
			bossIndex = bossIndex + 1
			bossName, _, bossID = EJ_GetEncounterInfoByIndex(bossIndex)
		end

		RestoreJournal(previousTier)
	end

	coroutine.yield()
	local difficultyNames = GetDifficultyNames()
	local started = debugprofilestop()
	for _, categoryID in ipairs(GetStatisticsCategoryList() or {}) do
		for statIndex = 1, GetCategoryNumAchievements(categoryID) or 0 do
			if debugprofilestop() - started > RAID_HISTORY_BUDGET then
				coroutine.yield()
				started = debugprofilestop()
			end

			local _, skip, statID = GetStatistic(categoryID, statIndex)
			local statName = nil
			if not skip and statID then statName = select(2, GetAchievementInfo(statID)) end
			if statName then
				local key, detail = SplitStatisticName(statName)
				local boss, exact = FindStatisticBoss(key, bossKeys)
				local difficultyID = nil
				if boss then difficultyID = GetStatisticDifficulty(detail, difficultyNames) end
				if difficultyID then
					local target = boss.fuzzy
					if exact then target = boss.stats end
					if (target[difficultyID] or 0) < statID then target[difficultyID] = statID end
				end
			end
		end
	end

	local history = {}
	for _, raid in ipairs(raids) do
		local found = false
		for _, boss in ipairs(raid.bosses) do
			for _, difficulty in ipairs(RAID_DIFFICULTIES) do
				boss.byDifficulty[difficulty.id] = boss.stats[difficulty.id] or boss.fuzzy[difficulty.id]
				if boss.byDifficulty[difficulty.id] then found = true end
			end
		end

		if found then tinsert(history, raid) end
	end

	if #history == 0 then return nil end
	return history
end

local function FinishRaidHistory(history)
	raidHistoryJob = nil
	raidHistoryFrame:SetScript("OnUpdate", nil)
	if history then
		raidHistory = history
	else
		raidHistoryRetry = GetTime() + 60
	end

	ExpansionUtils:UpdateCharacterOverviewRaidHistory()
end

local function StartRaidHistoryLoad(delay)
	if raidHistory or raidHistoryJob or GetTime() < raidHistoryRetry or not HasRaidHistoryAPI() then return end
	raidHistoryJob = coroutine.create(BuildRaidHistory)
	local startAt = GetTime() + (delay or 0)
	raidHistoryFrame:SetScript(
		"OnUpdate",
		function()
			if GetTime() < startAt then return end
			local ok, result = coroutine.resume(raidHistoryJob)
			if not ok then
				FinishRaidHistory(nil)
				geterrorhandler()(result)
				return
			end

			if coroutine.status(raidHistoryJob) == "dead" then FinishRaidHistory(result) end
		end
	)
end

local function GetStatisticCount(statID)
	local value = Clean(GetStatistic(statID))
	if value == nil then return 0 end
	local digits = string.gsub(tostring(value), "[^%d]", "")
	return tonumber(digits) or 0
end

local function UpdateRaidHistory(char)
	local history = raidHistory
	if history == nil then return end
	local result = {
		["totals"] = NewKills(),
		["kills"] = NewKills(),
		["raids"] = {}
	}

	for _, raid in ipairs(history) do
		local entry = {
			["instanceID"] = raid.instanceID,
			["totals"] = NewKills(),
			["kills"] = NewKills()
		}

		for _, boss in ipairs(raid.bosses) do
			local best = 0
			for difficultyID, statID in pairs(boss.byDifficulty) do
				if RAID_RANK[difficultyID] > best and GetStatisticCount(statID) > 0 then best = RAID_RANK[difficultyID] end
			end

			for _, difficulty in ipairs(RAID_DIFFICULTIES) do
				if boss.byDifficulty[difficulty.id] then
					entry.totals[difficulty.id] = entry.totals[difficulty.id] + 1
					result.totals[difficulty.id] = result.totals[difficulty.id] + 1
					if best >= RAID_RANK[difficulty.id] then
						entry.kills[difficulty.id] = entry.kills[difficulty.id] + 1
						result.kills[difficulty.id] = result.kills[difficulty.id] + 1
					end
				end
			end
		end

		tinsert(result.raids, entry)
	end

	char["raidHistory"] = result
end

local function IsRaidHistoryLoading(char)
	return raidHistoryJob ~= nil and char == currentChar
end

function ExpansionUtils:UpdateCharacterOverviewRaidHistory()
	if currentChar then UpdateRaidHistory(currentChar) end
	if window and window:IsShown() then ExpansionUtils:RefreshCharacterOverview() end
end

local function GetChildSkillLine(skillLine, lineName)
	if skillLine == nil then return nil end
	if childSkillLines[skillLine] then return childSkillLines[skillLine] end
	if C_TradeSkillUI == nil or C_TradeSkillUI.GetAllProfessionTradeSkillLines == nil or C_TradeSkillUI.GetProfessionInfoBySkillLineID == nil then return nil end
	local best = nil
	for _, skillLineID in ipairs(C_TradeSkillUI.GetAllProfessionTradeSkillLines() or {}) do
		local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLineID)
		if ok and info and info.parentProfessionID == skillLine then
			if lineName and info.professionName == lineName then
				best = skillLineID
				break
			end

			if best == nil or skillLineID > best then best = skillLineID end
		end
	end

	childSkillLines[skillLine] = best
	return best
end

local function GetKnowledgeForSkillLine(skillLineID)
	if skillLineID == nil then return nil end
	if C_ProfSpecs.SkillLineHasSpecialization then
		local ok, hasSpecialization = pcall(C_ProfSpecs.SkillLineHasSpecialization, skillLineID)
		if not ok or not hasSpecialization then return nil end
	end

	local ok, info = pcall(C_ProfSpecs.GetCurrencyInfoForSkillLine, skillLineID)
	if not ok or info == nil then return nil end
	return Clean(info.numAvailable)
end

local function GetKnowledgePoints(skillLine, lineName)
	if not HasKnowledgePoints() then return nil end
	local points = GetKnowledgeForSkillLine(GetChildSkillLine(skillLine, lineName))
	if points ~= nil then return points end
	return GetKnowledgeForSkillLine(skillLine)
end

local function GetProfessionData(index, old)
	if index == nil then return nil end
	local name, icon, rank, maxRank, _, _, skillLine, _, _, _, lineName = GetProfessionInfo(index)
	name = Clean(name)
	if name == nil then return nil end
	local profession = {
		["name"] = name,
		["icon"] = Clean(icon),
		["rank"] = Clean(rank),
		["maxRank"] = Clean(maxRank),
		["skillLine"] = Clean(skillLine),
		["lineName"] = Clean(lineName)
	}

	profession.points = GetKnowledgePoints(profession.skillLine, profession.lineName)
	if profession.points == nil and old and old.skillLine == profession.skillLine then profession.points = old.points end
	return profession
end

local function UpdateProfessions(char)
	if GetProfessions == nil or GetProfessionInfo == nil then return end
	local prof1, prof2 = GetProfessions()
	char["prof1"] = GetProfessionData(prof1, char["prof1"])
	char["prof2"] = GetProfessionData(prof2, char["prof2"])
	char["professions"] = true
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

local function GetRaidHistoryKills(char)
	local history = char["raidHistory"]
	if history == nil or history.totals == nil then return nil end
	return history.totals, history.kills or {}
end

local function PickTotal(total, difficultyID)
	if type(total) == "table" then return total[difficultyID] or 0 end
	return total
end

function ExpansionUtils:UpdateCharacterOverviewData()
	if InCombatLockdown() then return end
	local guid = Clean(UnitGUID("player"))
	if guid == nil then return end
	local db = GetDB()
	local char = db["CHARS"][guid] or {}
	db["CHARS"][guid] = char
	currentChar = char
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

	UpdateRaidHistory(char)
	UpdateProfessions(char)
	UpdatePlayed(char)
	char["updated"] = GetNow()
	UpdateWarbandMoney(false)
	if window and window:IsShown() then ExpansionUtils:RefreshCharacterOverview() end
end

function ExpansionUtils:IsCharacterOverviewOnlyMaxLevel()
	return GetDB()["ONLYMAXLEVEL"] == true
end

function ExpansionUtils:GetCharacterOverviewRows()
	local rows = {}
	local maxLevel = nil
	if ExpansionUtils:IsCharacterOverviewOnlyMaxLevel() then maxLevel = GetMaxLevel() end
	for _, char in pairs(GetDB()["CHARS"]) do
		if char["name"] and (maxLevel == nil or (char["level"] or 0) >= maxLevel) then tinsert(rows, char) end
	end
	return rows
end

local function GetAccountMoney()
	local total = 0
	for _, char in pairs(GetDB()["CHARS"]) do
		total = total + (char["money"] or 0)
	end

	if HasWarbandMoney() then total = total + (GetDB()["WARBANDMONEY"] or 0) end
	return total
end

local function GetAccountPlayed()
	local total = 0
	local missing = 0
	for _, char in pairs(GetDB()["CHARS"]) do
		if char["played"] then
			total = total + char["played"]
		elseif char["name"] then
			missing = missing + 1
		end
	end

	return total, missing
end

local function SetFooterText(frame, text)
	if frame == nil then return end
	frame.Text:SetText(text)
	frame:SetWidth(math.max(1, frame.Text:GetStringWidth()))
end

local function UpdateFooter()
	SetFooterText(accountGold, Trans("LID_ACCOUNTGOLD") .. ": " .. FormatGold(GetAccountMoney()))
	local played, missing = GetAccountPlayed()
	local text = FormatPlayedShort(played)
	if missing > 0 then text = text .. " +" .. MISSING end
	SetFooterText(accountPlayed, Trans("LID_ACCOUNTPLAYED") .. ": " .. text)
end

function ExpansionUtils:RefreshCharacterOverview()
	if list == nil then return end
	list:SetRows(ExpansionUtils:GetCharacterOverviewRows())
	UpdateFooter()
end

function ExpansionUtils:SetCharacterOverviewOnlyMaxLevel(value)
	GetDB()["ONLYMAXLEVEL"] = value == true
	if onlyMaxLevel then onlyMaxLevel:SetChecked(value == true) end
	if ExpansionUtils.settingsOnlyMaxLevel then ExpansionUtils.settingsOnlyMaxLevel:SetChecked(value == true) end
	ExpansionUtils:RefreshCharacterOverview()
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
	if HasVaultRewardsWaiting(char) then tooltip:AddLine(Trans("LID_GREATVAULT") .. ": " .. Trans("LID_REWARDSWAITING"), 0, 1, 0) end
	if char["updated"] then tooltip:AddDoubleLine(Trans("LID_LASTUPDATE"), date("%Y-%m-%d %H:%M", char["updated"]), 0.7, 0.7, 0.7, 1, 1, 1) end
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

	tooltip:AddDoubleLine(Trans("LID_LEVELSHORT"), "+" .. run.level, 1, 1, 1, 1, 1, 1)
	if run.score then tooltip:AddDoubleLine(Trans("LID_SCORE"), tostring(run.score), 1, 1, 1, 1, 1, 1) end
	if run.duration then tooltip:AddDoubleLine(Trans("LID_TIME"), FormatDuration(run.duration), 1, 1, 1, 1, 1, 1) end
	if run.timed then
		tooltip:AddLine(Trans("LID_TIMED"), 0, 1, 0)
	else
		tooltip:AddLine(Trans("LID_NOTTIMED"), 1, 0.3, 0.3)
	end
end

local function VaultTooltip(tooltip, vaultType, char)
	tooltip:AddLine(Trans("LID_GREATVAULT") .. ": " .. (vaultType.label or ""))
	local slots, _, _, _, stale = GetVaultState(char, vaultType.key)
	if slots == nil then return end
	if stale then
		tooltip:AddLine(Trans("LID_OUTDATED"), 0.5, 0.5, 0.5)
		if HasVaultRewardsWaiting(char) then tooltip:AddLine(Trans("LID_REWARDSWAITING"), 0, 1, 0) end
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
		if slot.ilvl then right = Trans("LID_ITEMLEVELSHORT") .. " " .. slot.ilvl end
		tooltip:AddDoubleLine(index .. ".  " .. math.min(slot.progress, slot.threshold) .. "/" .. slot.threshold, right, r, g, b, 1, 1, 1)
	end
end

local function RaidWeekTooltip(tooltip, difficulty, char)
	local total, kills = GetRaidKills(char)
	if total == nil then return end
	tooltip:AddLine(Trans("LID_RAIDPROGRESSWEEK"))
	tooltip:AddDoubleLine(Color(difficulty.color, GetDifficultyName(difficulty)), (kills[difficulty.id] or 0) .. "/" .. total, 1, 1, 1, 1, 1, 1)
	if IsStale(char) then tooltip:AddLine(Trans("LID_OUTDATED"), 0.5, 0.5, 0.5) end
end

local function RaidHistoryTooltip(tooltip, difficulty, char)
	local history = char["raidHistory"]
	if history == nil or history.totals == nil then return end
	tooltip:AddLine(Trans("LID_RAIDPROGRESSTOTAL"))
	tooltip:AddLine(Color(difficulty.color, GetDifficultyName(difficulty)))
	for _, raid in ipairs(history.raids or {}) do
		local total = PickTotal(raid.totals, difficulty.id)
		if total > 0 then
			local name = EJ_GetInstanceInfo and EJ_GetInstanceInfo(raid.instanceID) or tostring(raid.instanceID)
			tooltip:AddDoubleLine(name, (raid.kills[difficulty.id] or 0) .. "/" .. total, 1, 1, 1, 1, 1, 1)
		end
	end
end

local function ProfessionTooltip(tooltip, profession)
	if profession == nil then return end
	tooltip:AddLine(profession.name)
	if profession.lineName and profession.lineName ~= profession.name then tooltip:AddLine(profession.lineName, 1, 1, 1) end
	if profession.rank then tooltip:AddDoubleLine(Trans("LID_SKILL"), profession.rank .. "/" .. (profession.maxRank or "?"), 1, 1, 1, 1, 1, 1) end
	if profession.points then tooltip:AddDoubleLine(Trans("LID_KNOWLEDGEPOINTS"), tostring(profession.points), 1, 1, 1, 1, 1, 1) end
end

local function RaidColumn(prefix, difficulty, getKills, tooltipFunc, isLoading)
	return {
		["key"] = prefix .. difficulty.id,
		["label"] = difficulty.short,
		["headerTooltip"] = GetDifficultyName(difficulty),
		["width"] = 40,
		["align"] = "CENTER",
		["descending"] = true,
		["text"] = function(char)
			local total, kills = getKills(char)
			if total == nil then
				if isLoading and isLoading(char) then return LOADING end
				return MISSING
			end
			total = PickTotal(total, difficulty.id)
			local count = kills[difficulty.id] or 0
			if count > 0 then return Color(difficulty.color, count .. "/" .. total) end
			return Color(GREY, "0/" .. total)
		end,
		["value"] = function(char)
			local total, kills = getKills(char)
			if total == nil then return nil end
			return kills[difficulty.id] or 0
		end,
		["tooltip"] = function(tooltip, char) tooltipFunc(tooltip, difficulty, char) end
	}
end

local function ProfessionColumn(slot)
	local key = "prof" .. slot
	return {
		["key"] = key,
		["label"] = "LID_PROFESSION",
		["width"] = 80,
		["text"] = function(char)
			local profession = char[key]
			if profession == nil then
				if char["professions"] then return "" end
				return MISSING
			end

			local text = Icon(profession.icon, ScaledIcon(14))
			if profession.rank then text = text .. " " .. profession.rank .. "/" .. (profession.maxRank or "?") end
			return text
		end,
		["value"] = function(char) return char[key] and char[key].name end,
		["tooltip"] = function(tooltip, char) ProfessionTooltip(tooltip, char[key]) end
	}
end

local function KnowledgeColumn(slot)
	local key = "prof" .. slot
	return {
		["key"] = key .. "points",
		["label"] = "LID_KNOWLEDGE",
		["headerTooltip"] = "LID_KNOWLEDGEPOINTS",
		["width"] = 54,
		["align"] = "CENTER",
		["descending"] = true,
		["text"] = function(char)
			local profession = char[key]
			if profession == nil then
				if char["professions"] then return "" end
				return MISSING
			end

			if profession.points == nil then return MISSING end
			if profession.points > 0 then return Color("ff00ff00", profession.points) end
			return Color(GREY, profession.points)
		end,
		["value"] = function(char) return char[key] and char[key].points end,
		["tooltip"] = function(tooltip, char) ProfessionTooltip(tooltip, char[key]) end
	}
end

local function PlayedColumn(key, label, headerTooltip)
	return {
		["key"] = key,
		["label"] = label,
		["headerTooltip"] = headerTooltip,
		["width"] = 96,
		["align"] = "RIGHT",
		["descending"] = true,
		["text"] = function(char)
			if char[key] == nil then return MISSING end
			return FormatPlayedShort(char[key])
		end,
		["tooltip"] = function(tooltip, char)
			if char[key] == nil then return end
			tooltip:AddLine(Trans(headerTooltip))
			tooltip:AddLine(FormatPlayedLong(char[key]), 1, 1, 1)
		end
	}
end

local function NameColumn()
	return {
		["key"] = "name",
		["label"] = "LID_NAME",
		["width"] = 100,
		["flex"] = true,
		["text"] = function(char)
			local _, _, _, colorStr = ExpansionUtils:GetClassColor(char["class"])
			local text = Color(colorStr, char["name"])
			if HasVaultRewardsWaiting(char) then
				local size = ScaledIcon(14)
				text = text .. " |A:GreatVault-32x32:" .. size .. ":" .. size .. "|a"
			end
			return text
		end,
		["value"] = function(char) return char["name"] end,
		["tooltip"] = NameTooltip
	}
end

local function LevelColumn()
	return {
		["key"] = "level",
		["label"] = "LID_LEVELSHORT",
		["width"] = 46,
		["align"] = "CENTER",
		["descending"] = true,
		["text"] = function(char)
			if char["level"] == nil then return MISSING end
			return tostring(char["level"])
		end
	}
end

local function SpecColumn()
	return {
		["key"] = "spec",
		["label"] = "LID_SPEC",
		["width"] = 46,
		["align"] = "CENTER",
		["text"] = function(char)
			if char["specIcon"] == nil then return MISSING end
			return Icon(char["specIcon"], ScaledIcon(16))
		end,
		["value"] = function(char) return char["specName"] end,
		["tooltip"] = function(tooltip, char) if char["specName"] then tooltip:AddLine(char["specName"], 1, 1, 1) end end
	}
end

local function ItemLevelColumn()
	return {
		["key"] = "ilvl",
		["label"] = "LID_ITEMLEVELSHORT",
		["headerTooltip"] = "LID_ITEMLEVEL",
		["width"] = 44,
		["align"] = "CENTER",
		["descending"] = true,
		["text"] = function(char)
			if char["ilvl"] == nil then return MISSING end
			return tostring(math.floor(char["ilvl"]))
		end,
		["tooltip"] = function(tooltip, char) if char["ilvl"] then tooltip:AddDoubleLine(Trans("LID_ITEMLEVEL"), string.format("%.1f", char["ilvl"]), 1, 1, 1, 1, 1, 1) end end
	}
end

local function ScoreColumn()
	return {
		["key"] = "score",
		["label"] = "LID_SCORE",
		["headerTooltip"] = "LID_MYTHICPLUSSCORE",
		["width"] = 60,
		["align"] = "CENTER",
		["descending"] = true,
		["text"] = function(char)
			local score = nil
			if GetRuns(char) then score = char["score"] end
			if score == nil then return MISSING end
			local color = nil
			if C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor then color = C_ChallengeMode.GetDungeonScoreRarityColor(score) end
			return ColorMixinText(color, tostring(score))
		end,
		["value"] = function(char)
			if GetRuns(char) then return char["score"] end
			return nil
		end
	}
end

local function MapColumn(mapID)
	local name, texture = GetMapInfo(mapID)
	local label = nil
	if texture == nil then label = name end
	return {
		["key"] = "map" .. mapID,
		["icon"] = texture,
		["label"] = label,
		["headerTooltip"] = name,
		["width"] = 32,
		["align"] = "CENTER",
		["descending"] = true,
		["text"] = function(char)
			local runs = GetRuns(char)
			if runs == nil then return MISSING end
			local run = runs[mapID]
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
end

local function KeystoneColumn()
	return {
		["key"] = "keystone",
		["label"] = "LID_KEYSTONE",
		["width"] = 70,
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
			return Icon(texture, ScaledIcon(14)) .. " " .. level
		end,
		["value"] = function(char) return char["keyLevel"] end,
		["tooltip"] = function(tooltip, char)
			if char["keyLevel"] == nil then return end
			local name = GetMapInfo(char["keyMap"])
			tooltip:AddLine((name or "") .. " +" .. char["keyLevel"])
			if IsStale(char) then tooltip:AddLine(Trans("LID_OUTDATED"), 0.5, 0.5, 0.5) end
		end
	}
end

local function VaultColumn(vaultType)
	return {
		["key"] = "vault" .. vaultType.key,
		["label"] = vaultType.label,
		["width"] = 44,
		["align"] = "CENTER",
		["descending"] = true,
		["text"] = function(char)
			local slots, progress, maxThreshold, unlocked = GetVaultState(char, vaultType.key)
			if slots == nil then return MISSING end
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
end

local function MoneyColumn()
	return {
		["key"] = "money",
		["label"] = "LID_GOLD",
		["width"] = 90,
		["align"] = "RIGHT",
		["descending"] = true,
		["text"] = function(char)
			if char["money"] == nil then return MISSING end
			return FormatGold(char["money"], ScaledIcon(12))
		end,
		["tooltip"] = function(tooltip, char)
			if char["money"] == nil or GetMoneyString == nil then return end
			tooltip:AddLine(GetMoneyString(char["money"], true), 1, 1, 1)
		end
	}
end

local function Single(factory, ...)
	local args = {...}
	return function() return {factory(unpack(args))} end
end

local function CreateColumnTree()
	local raidWeek = {}
	local raidTotal = {}
	for _, difficulty in ipairs(RAID_DIFFICULTIES) do
		tinsert(
			raidWeek,
			{
				["key"] = "raidweek" .. difficulty.id,
				["label"] = GetDifficultyName(difficulty),
				["movable"] = false,
				["columns"] = Single(RaidColumn, "raidweek", difficulty, GetRaidKills, RaidWeekTooltip)
			}
		)

		tinsert(
			raidTotal,
			{
				["key"] = "raidtotal" .. difficulty.id,
				["label"] = GetDifficultyName(difficulty),
				["movable"] = false,
				["columns"] = Single(RaidColumn, "raidtotal", difficulty, GetRaidHistoryKills, RaidHistoryTooltip, IsRaidHistoryLoading)
			}
		)
	end

	local vault = {}
	for _, vaultType in ipairs(VAULT_TYPES) do
		tinsert(
			vault,
			{
				["key"] = "vault" .. vaultType.key,
				["label"] = vaultType.label,
				["columns"] = Single(VaultColumn, vaultType)
			}
		)
	end

	local professions = {}
	for slot = 1, 2 do
		local node = {
			["key"] = "prof" .. slot,
			["label"] = "LID_PROFESSION" .. slot
		}

		if HasKnowledgePoints() then
			node.children = {
				{
					["key"] = "prof" .. slot .. "skill",
					["label"] = "LID_PROFESSION",
					["columns"] = Single(ProfessionColumn, slot)
				},
				{
					["key"] = "prof" .. slot .. "points",
					["label"] = "LID_KNOWLEDGEPOINTS",
					["columns"] = Single(KnowledgeColumn, slot)
				},
			}
		else
			node.group = "LID_PROFESSION" .. slot
			node.columns = Single(ProfessionColumn, slot)
		end

		tinsert(professions, node)
	end

	return {
		{
			["key"] = "level",
			["label"] = "LID_LEVELSHORT",
			["columns"] = Single(LevelColumn)
		},
		{
			["key"] = "spec",
			["label"] = "LID_SPEC",
			["columns"] = Single(SpecColumn)
		},
		{
			["key"] = "ilvl",
			["label"] = "LID_ITEMLEVEL",
			["columns"] = Single(ItemLevelColumn)
		},
		{
			["key"] = "mythicplus",
			["label"] = "LID_MYTHICPLUS",
			["children"] = {
				{
					["key"] = "score",
					["label"] = "LID_SCORE",
					["columns"] = Single(ScoreColumn)
				},
				{
					["key"] = "bestruns",
					["label"] = "LID_BESTRUNS",
					["group"] = "LID_BESTRUNS",
					["columns"] = function(maps)
						local columns = {}
						for _, mapID in ipairs(maps) do
							tinsert(columns, MapColumn(mapID))
						end
						return columns
					end
				},
				{
					["key"] = "keystone",
					["label"] = "LID_KEYSTONE",
					["columns"] = Single(KeystoneColumn)
				},
			}
		},
		{
			["key"] = "raid",
			["label"] = "LID_RAID",
			["children"] = {
				{
					["key"] = "raidweek",
					["label"] = "LID_WEEK",
					["children"] = raidWeek
				},
				{
					["key"] = "raidtotal",
					["label"] = "LID_EXPANSION",
					["children"] = raidTotal
				},
			}
		},
		{
			["key"] = "professions",
			["label"] = "LID_PROFESSIONS",
			["children"] = professions
		},
		{
			["key"] = "vault",
			["label"] = "LID_GREATVAULT",
			["children"] = vault
		},
		{
			["key"] = "played",
			["label"] = "LID_PLAYED",
			["children"] = {
				{
					["key"] = "playedtotal",
					["label"] = "LID_PLAYEDTOTAL",
					["columns"] = Single(PlayedColumn, "played", "LID_TOTAL", "LID_PLAYEDTOTAL")
				},
				{
					["key"] = "playedlevel",
					["label"] = "LID_PLAYEDLEVEL",
					["columns"] = Single(PlayedColumn, "playedLevel", "LID_LEVELSHORT", "LID_PLAYEDLEVEL")
				},
			}
		},
		{
			["key"] = "money",
			["label"] = "LID_GOLD",
			["columns"] = Single(MoneyColumn)
		},
	}
end

local function SortColumnNodes(nodes, parentKey, order, hidden)
	local rank = {}
	if type(order[parentKey]) == "table" then
		for index, key in ipairs(order[parentKey]) do
			rank[key] = index
		end
	end

	local default = {}
	for index, node in ipairs(nodes) do
		default[node] = index
		node.checked = hidden[node.key] ~= true
	end

	table.sort(
		nodes,
		function(a, b)
			local rankA = rank[a.key] or (1000 + default[a])
			local rankB = rank[b.key] or (1000 + default[b])
			if rankA == rankB then return default[a] < default[b] end
			return rankA < rankB
		end
	)

	for _, node in ipairs(nodes) do
		if node.children then SortColumnNodes(node.children, node.key, order, hidden) end
	end
end

local function SaveColumnNodes(nodes, parentKey, order, hidden)
	local keys = {}
	for _, node in ipairs(nodes) do
		tinsert(keys, node.key)
		if node.checked == false then
			hidden[node.key] = true
		else
			hidden[node.key] = nil
		end

		if node.children then SaveColumnNodes(node.children, node.key, order, hidden) end
	end

	order[parentKey] = keys
end

local function GetColumnTree()
	if columnTree then return columnTree end
	local db = GetDB()
	db["COLUMNORDER"] = db["COLUMNORDER"] or {}
	db["HIDDENCOLUMNS"] = db["HIDDENCOLUMNS"] or {}
	columnTree = CreateColumnTree()
	SortColumnNodes(columnTree, "root", db["COLUMNORDER"], db["HIDDENCOLUMNS"])
	return columnTree
end

local function CopyPath(path, label)
	local copy = {}
	for _, value in ipairs(path) do
		tinsert(copy, value)
	end

	if label then tinsert(copy, label) end
	return copy
end

local function AddTreeColumns(columns, nodes, path, maps)
	for _, node in ipairs(nodes) do
		if node.checked ~= false then
			if node.children then
				AddTreeColumns(columns, node.children, CopyPath(path, node.label), maps)
			elseif node.columns then
				local group = CopyPath(path, node.group)
				if #group == 0 then group = nil end
				for _, column in ipairs(node.columns(maps)) do
					column.group = group
					tinsert(columns, column)
				end
			end
		end
	end
end

local function BuildColumns(maps)
	local columns = {NameColumn()}
	AddTreeColumns(columns, GetColumnTree(), {}, maps)
	return columns
end

local function IsSameMaps(a, b)
	if a == nil or b == nil or #a ~= #b then return false end
	for index, mapID in ipairs(a) do
		if b[index] ~= mapID then return false end
	end

	return true
end

local function UpdateWindowWidth()
	if window == nil or list == nil then return end
	local maxWidth = math.floor(UIParent:GetWidth())
	local required = math.min(list:GetColumnsWidth() + 64, maxWidth)
	if window.SetResizeBounds then
		window:SetResizeBounds(required, MIN_HEIGHT, 0, 0)
	elseif window.SetMinResize then
		window:SetMinResize(required, MIN_HEIGHT)
	end

	window:SetWidth(math.min(math.max(GetDB()["WIDTH"] or 0, required), maxWidth))
end

function ExpansionUtils:GetCharacterOverviewColumnTree()
	return GetColumnTree()
end

function ExpansionUtils:UpdateCharacterOverviewColumns()
	local tree = GetColumnTree()
	local db = GetDB()
	db["COLUMNORDER"] = {}
	SaveColumnNodes(tree, "root", db["COLUMNORDER"], db["HIDDENCOLUMNS"])
	if list == nil then return end
	listMaps = GetSeasonMaps()
	list:SetColumns(BuildColumns(listMaps))
	UpdateWindowWidth()
end

function ExpansionUtils:GetCharacterOverviewFontSize()
	return GetFontSize()
end

function ExpansionUtils:GetCharacterOverviewFontRange()
	return FONT_MIN, FONT_MAX
end

function ExpansionUtils:SetCharacterOverviewFontSize(value)
	if settingFontSize or type(value) ~= "number" then return end
	settingFontSize = true
	value = math.min(FONT_MAX, math.max(FONT_MIN, math.floor(value + 0.5)))
	GetDB()["FONTSIZE"] = value
	if fontSlider and not fontSlider.dragging then fontSlider:SetValue(value) end
	local settingsSlider = ExpansionUtils.settingsFontSize and ExpansionUtils.settingsFontSize.slider
	if settingsSlider then settingsSlider:SetValue(value) end
	if list and list:GetFontSize() ~= value then
		list:SetFontSize(value)
		UpdateWindowWidth()
	end

	settingFontSize = false
end

local function CreateFontSizeSlider(footer, anchor)
	local label = footer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("LEFT", anchor, "RIGHT", 24, 0)
	label:SetText(Trans("LID_FONTSIZE"))
	local template = "OptionsSliderTemplate"
	if ExpansionUtils:CheckTemplates("MinimalSliderTemplate") then
		template = "MinimalSliderTemplate"
	elseif ExpansionUtils:CheckTemplates("UISliderTemplate") then
		template = "UISliderTemplate"
	end

	local slider = CreateFrame("Slider", "ExpansionUtilsCharacterOverviewFontSize", footer, template)
	slider:SetSize(140, 16)
	slider:SetPoint("LEFT", label, "RIGHT", 8, 0)
	slider:SetOrientation("HORIZONTAL")
	slider:SetMinMaxValues(FONT_MIN, FONT_MAX)
	slider:SetValueStep(1)
	if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
	for _, key in ipairs({"Text", "Low", "High"}) do
		local region = slider[key] or _G[slider:GetName() .. key]
		if region then region:Hide() end
	end

	local valueText = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
	valueText:SetText(GetFontSize())
	slider:SetValue(GetFontSize())
	slider:SetScript(
		"OnValueChanged",
		function(sel, value)
			value = math.floor(value + 0.5)
			valueText:SetText(value)
			if not sel.dragging then ExpansionUtils:SetCharacterOverviewFontSize(value) end
		end
	)

	slider:HookScript("OnMouseDown", function(sel) sel.dragging = true end)
	slider:HookScript(
		"OnMouseUp",
		function(sel)
			sel.dragging = false
			ExpansionUtils:SetCharacterOverviewFontSize(sel:GetValue())
		end
	)

	slider:EnableMouseWheel(true)
	slider:SetScript("OnMouseWheel", function(sel, delta) sel:SetValue(sel:GetValue() + delta) end)
	fontSlider = slider

	return slider
end

local function CreateSettingsButton(footer)
	local button = CreateFrame("Button", "ExpansionUtilsCharacterOverviewSettings", footer)
	button:SetSize(28, 28)
	if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("GM-icon-settings") then
		button:SetNormalAtlas("GM-icon-settings")
		button:SetPushedAtlas("GM-icon-settings-pressed")
		button:SetHighlightAtlas("GM-icon-settings-hover", "BLEND")
	else
		button:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
		button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	end

	button:SetScript("OnClick", function() ExpansionUtils:OpenSettings() end)
	button:SetScript(
		"OnEnter",
		function(sel)
			GameTooltip:SetOwner(sel, "ANCHOR_TOP")
			GameTooltip:SetText(Trans("LID_OPENSETTINGS"), 1, 1, 1)
			GameTooltip:Show()
		end
	)

	button:SetScript(
		"OnLeave",
		function(sel)
			if GameTooltip:GetOwner() == sel then GameTooltip:Hide() end
		end
	)

	return button
end

local function CreateFooterInfo(footer, onEnter)
	local frame = CreateFrame("Frame", nil, footer)
	frame:SetHeight(24)
	frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.Text:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
	frame:EnableMouse(true)
	frame:SetScript(
		"OnEnter",
		function(sel)
			GameTooltip:SetOwner(sel, "ANCHOR_TOP")
			if onEnter(GameTooltip) then
				GameTooltip:Show()
			else
				GameTooltip:Hide()
			end
		end
	)

	frame:SetScript(
		"OnLeave",
		function(sel)
			if GameTooltip:GetOwner() == sel then GameTooltip:Hide() end
		end
	)

	return frame
end

local function CreateWindow()
	local db = GetDB()
	window = ExpansionUtils:CreateUIWindow({
		["name"] = "ExpansionUtilsCharacterOverview",
		["title"] = "LID_CHARACTEROVERVIEW",
		["width"] = db["WIDTH"] or DEFAULT_WIDTH,
		["height"] = db["HEIGHT"] or DEFAULT_HEIGHT,
		["minWidth"] = DEFAULT_WIDTH,
		["minHeight"] = MIN_HEIGHT,
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
		["fontSize"] = GetFontSize(),
		["columns"] = BuildColumns(listMaps),
		["rows"] = ExpansionUtils:GetCharacterOverviewRows(),
		["sortKey"] = db["SORTKEY"] or "name",
		["ascending"] = db["ASCENDING"],
		["onSort"] = function(key, ascending)
			db["SORTKEY"] = key
			db["ASCENDING"] = ascending
		end,
	})

	local footer = window:AddFooter({["height"] = 30})
	onlyMaxLevel = ExpansionUtils:CreateCheckButton("ExpansionUtilsCharacterOverviewOnlyMaxLevel", footer)
	onlyMaxLevel:SetSize(24, 24)
	onlyMaxLevel:SetHitRectInsets(0, 0, 0, 0)
	onlyMaxLevel:SetPoint("LEFT", footer, "LEFT", 8, 0)
	onlyMaxLevel:SetChecked(ExpansionUtils:IsCharacterOverviewOnlyMaxLevel())
	onlyMaxLevel.Label = onlyMaxLevel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	onlyMaxLevel.Label:SetPoint("LEFT", onlyMaxLevel, "RIGHT", 4, 0)
	onlyMaxLevel.Label:SetText(Trans("LID_ONLYMAXLEVEL"))
	onlyMaxLevel:SetScript("OnClick", function(sel) ExpansionUtils:SetCharacterOverviewOnlyMaxLevel(sel:GetChecked() == true) end)
	CreateFontSizeSlider(footer, onlyMaxLevel.Label)
	accountGold = CreateFooterInfo(
		footer,
		function(tooltip)
			if not HasWarbandMoney() or GetMoneyString == nil then return false end
			tooltip:AddDoubleLine(Trans("LID_WARBANDGOLD"), GetMoneyString(GetDB()["WARBANDMONEY"] or 0, true), 1, 0.82, 0, 1, 1, 1)
			return true
		end
	)

	local settingsButton = CreateSettingsButton(footer)
	settingsButton:SetPoint("RIGHT", footer, "RIGHT", -8, 0)
	accountGold:SetPoint("RIGHT", settingsButton, "LEFT", -12, 0)
	accountPlayed = CreateFooterInfo(
		footer,
		function(tooltip)
			local played, missing = GetAccountPlayed()
			tooltip:AddLine(Trans("LID_ACCOUNTPLAYED"))
			tooltip:AddLine(FormatPlayedLong(played), 1, 1, 1)
			if missing > 0 then tooltip:AddDoubleLine(Trans("LID_CHARSWITHOUTDATA"), tostring(missing), 1, 0.82, 0, 1, 1, 1) end
			return true
		end
	)

	accountPlayed:SetPoint("RIGHT", accountGold, "LEFT", -24, 0)
	UpdateFooter()
	UpdateWindowWidth()
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
		UpdateWindowWidth()
	end

	ExpansionUtils:UpdateCharacterOverviewData()
	StartRaidHistoryLoad(0.5)
	ExpansionUtils:RefreshCharacterOverview()
	window:Show()
end

local fData = CreateFrame("Frame")
ExpansionUtils:RegisterEvent(fData, "PLAYER_LOGIN")
ExpansionUtils:OnEvent(
	fData,
	function(sel, event, ...)
		if event == "PLAYER_LOGIN" then
			ExpansionUtils:UnregisterEvent(fData, "PLAYER_LOGIN")
			for _, dataEvent in ipairs(DATA_EVENTS) do
				ExpansionUtils:RegisterEvent(fData, dataEvent)
			end

			if C_MythicPlus and C_MythicPlus.RequestMapInfo then C_MythicPlus.RequestMapInfo() end
			C_Timer.After(5, RequestPlayed)
		elseif event == "PLAYER_LOGOUT" then
			local guid = Clean(UnitGUID("player"))
			local char = guid and GetDB()["CHARS"][guid]
			if char then UpdatePlayed(char) end
			return
		elseif event == "TIME_PLAYED_MSG" then
			OnTimePlayed(...)
		elseif event == "PLAYER_LEVEL_UP" then
			RequestPlayed()
		elseif event == "ACCOUNT_MONEY" then
			UpdateWarbandMoney(true)
		end

		RequestUpdate(3)
	end, "ExpansionUtils CharacterOverview"
)
