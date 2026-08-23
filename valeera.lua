local _, ExpansionUtils = ...
local bar = nil
local ticker = nil
local valeeraFactionID = nil
local runStart = nil
local runGain = 0
local runKey = nil
local function GetDB()
	EVTAB = EVTAB or {}
	EVTAB["ValeeraXPBar"] = EVTAB["ValeeraXPBar"] or {}
	return EVTAB["ValeeraXPBar"]
end

local function GetFriendshipData(factionID)
	if C_GossipInfo == nil or C_GossipInfo.GetFriendshipReputation == nil then return nil end
	local ok, rep = pcall(C_GossipInfo.GetFriendshipReputation, factionID)
	if not ok or rep == nil then return nil end
	if rep.friendshipFactionID == nil or rep.friendshipFactionID == 0 then return nil end
	return rep
end

local function GetFactionName(factionID)
	local rep = GetFriendshipData(factionID)
	if rep and rep.name and rep.name ~= "" then return rep.name end
	if C_Reputation and C_Reputation.GetFactionDataByID then
		local ok, data = pcall(C_Reputation.GetFactionDataByID, factionID)
		if ok and data and data.name and data.name ~= "" then return data.name end
	end

	return nil
end

local function ForeachCompanion(callback)
	if C_DelvesUI == nil or C_DelvesUI.GetFactionForCompanion == nil then return end
	for companionID = 1, 20 do
		local ok, factionID = pcall(C_DelvesUI.GetFactionForCompanion, companionID)
		if ok and type(factionID) == "number" and factionID > 0 and callback(companionID, factionID) then return end
	end
end

local function FindValeeraFactionID()
	local res = nil
	ForeachCompanion(
		function(companionID, factionID)
			local name = GetFactionName(factionID)
			if name and strfind(name, "Valeera", 1, true) then
				res = factionID
				return true
			end

			return false
		end
	)

	return res
end

local function GetValeeraXP()
	if valeeraFactionID == nil then valeeraFactionID = FindValeeraFactionID() end
	if valeeraFactionID == nil then return nil end
	local rep = GetFriendshipData(valeeraFactionID)
	if rep == nil then return nil end
	local level, maxLevel = nil, nil
	if C_GossipInfo.GetFriendshipReputationRanks then
		local ok, ranks = pcall(C_GossipInfo.GetFriendshipReputationRanks, valeeraFactionID)
		if ok and ranks then
			level = ranks.currentLevel
			maxLevel = ranks.maxLevel
		end
	end

	local minValue = rep.reactionThreshold or 0
	local maxValue = rep.nextThreshold or 0
	local value = rep.standing or 0
	if maxValue <= minValue then return level, maxLevel, 0, 0, rep.name end
	return level, maxLevel, value - minValue, maxValue - minValue, rep.name
end

local function GetValeeraTotal()
	if valeeraFactionID == nil then return nil end
	local rep = GetFriendshipData(valeeraFactionID)
	if rep == nil then return nil end
	return rep.standing or 0
end

local function GetDelveHeader()
	if type(C_UIWidgetManager) ~= "table" then return nil end
	if C_UIWidgetManager.GetAllWidgetsBySetID == nil or C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo == nil then return nil end
	local setID = nil
	if C_ScenarioInfo and C_ScenarioInfo.GetScenarioStepInfo then
		local ok, step = pcall(C_ScenarioInfo.GetScenarioStepInfo)
		if ok and type(step) == "table" then setID = step.widgetSetID end
	end

	if type(setID) ~= "number" or setID == 0 then return nil end
	local ok2, widgets = pcall(C_UIWidgetManager.GetAllWidgetsBySetID, setID)
	if not ok2 or type(widgets) ~= "table" then return nil end
	for _, w in ipairs(widgets) do
		local ok3, info = pcall(C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo, w.widgetID)
		if ok3 and type(info) == "table" and info.tierText then return info end
	end

	return nil
end

local function GetDelveContext()
	if GetInstanceInfo == nil then return nil end
	local ok, name, instanceType, _, difficultyName = pcall(GetInstanceInfo)
	if not ok or name == nil or name == "" then return nil end
	if instanceType ~= "scenario" then return nil end
	if C_DelvesUI and C_DelvesUI.HasActiveDelve then
		local ok2, has = pcall(C_DelvesUI.HasActiveDelve)
		if ok2 and has == false then return nil end
	end

	local tier = nil
	local header = GetDelveHeader()
	if header then
		tier = tonumber(header.tierText)
		if header.headerText and header.headerText ~= "" then name = header.headerText end
	end

	if tier == nil and difficultyName then tier = tonumber(strmatch(difficultyName, "%d+")) end
	return name, tier
end

local function GetScores()
	local db = GetDB()
	local scores = ExpansionUtils:GV(db, "HIGHSCORE", nil)
	if type(scores) ~= "table" then
		scores = {}
		ExpansionUtils:SV(db, "HIGHSCORE", scores)
	end

	return scores
end

local function GetBestScore()
	local best = nil
	for _, v in pairs(GetScores()) do
		if type(v) == "table" and (best == nil or (v.xp or 0) > (best.xp or 0)) then best = v end
	end

	return best
end

local function IsValeeraUnitActive()
	local unitName = nil
	if valeeraFactionID then
		local rep = GetFriendshipData(valeeraFactionID)
		if rep then unitName = rep.name end
	end

	for i = 1, 4 do
		local unit = "party" .. i
		if UnitExists(unit) then
			local name = UnitName(unit)
			if name and (name == unitName or strfind(name, "Valeera", 1, true)) then return true end
		end
	end

	return false
end

local function UpdateRun(active)
	if active ~= true then
		runStart = nil
		runGain = 0
		runKey = nil

		return
	end

	local total = GetValeeraTotal()
	if total == nil then return end
	local name, tier = GetDelveContext()
	local key = nil
	if name then key = name .. "|" .. tostring(tier or 0) end
	if runStart == nil or key ~= runKey then
		runStart = total
		runKey = key
	end

	runGain = total - runStart
	if runGain < 0 then runGain = 0 end
	if key and runGain > 0 then
		local scores = GetScores()
		local best = scores[key]
		if type(best) ~= "table" or (best.xp or 0) < runGain then
			scores[key] = {
				["xp"] = runGain,
				["name"] = name,
				["tier"] = tier
			}
		end
	end
end

local function FormatNr(nr)
	if BreakUpLargeNumbers then return BreakUpLargeNumbers(nr) end
	return tostring(nr)
end

local function UpdateBar()
	if bar == nil then return end
	if ExpansionUtils:GV(GetDB(), "SHOWVALEERAXPBAR", true) ~= true then
		bar:Hide()

		return
	end

	local level, maxLevel, cur, maxXP, name = GetValeeraXP()
	if name == nil then
		bar:Hide()

		return
	end

	local active = IsValeeraUnitActive()
	UpdateRun(active)
	if active ~= true then
		bar:Hide()

		return
	end

	if maxXP == nil or maxXP <= 0 or (level ~= nil and maxLevel ~= nil and maxLevel > 0 and level >= maxLevel) then
		bar:Hide()

		return
	end

	local title = name
	if level then
		title = title .. " |cFFFFFFFF" .. (LEVEL or "Level") .. " " .. level
		if maxLevel and maxLevel > 0 then title = title .. "|cFFAAAAAA/" .. maxLevel end
	end

	bar.left:SetText(title)
	bar.status:SetMinMaxValues(0, maxXP)
	bar.status:SetValue(cur)
	local right = FormatNr(cur) .. "|cFFAAAAAA/|r" .. FormatNr(maxXP) .. " |cFFFFFF00(" .. floor(cur / maxXP * 100) .. "%)"
	if runGain > 0 then right = right .. " |cFF00FF00+" .. FormatNr(runGain) end
	bar.right:SetText(right)
	bar:Show()
end

local function CreateBar()
	if bar then return bar end
	bar = CreateFrame("Frame", "EUValeeraXPBar", UIParent)
	bar:SetSize(340, 22)
	bar:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
	bar:SetFrameStrata("MEDIUM")
	ExpansionUtils:SetClampedToScreen(bar, true)
	bar:SetMovable(true)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript(
		"OnDragStart",
		function(sel)
			if InCombatLockdown() then
				ExpansionUtils:MSG(ExpansionUtils:Trans("LID_CANTBEMOVEDINCOMBAT"))

				return
			end

			if ExpansionUtils:GV(GetDB(), "LOCKED", false) == true then
				ExpansionUtils:MSG(ExpansionUtils:Trans("LID_LOCKED"))

				return
			end

			ExpansionUtils:ShowGrid(sel)
			sel:StartMoving()
		end
	)

	bar:SetScript(
		"OnDragStop",
		function(sel)
			ExpansionUtils:HideGrid(sel)
			sel:StopMovingOrSizing()
			local p1, _, p3, p4, p5 = sel:GetPoint()
			p4 = ExpansionUtils:Grid(p4)
			p5 = ExpansionUtils:Grid(p5)
			ExpansionUtils:SV(GetDB(), "POS", {p1, "UIParent", p3, p4, p5})
			sel:ClearAllPoints()
			sel:SetPoint(p1, "UIParent", p3, p4, p5)
			ExpansionUtils:MSG(ExpansionUtils:Trans("LID_SAVEDNEWPOSITION"))
		end
	)

	bar:SetScript(
		"OnEnter",
		function(sel)
			local level, maxLevel, cur, maxXP, name = GetValeeraXP()
			if name == nil then return end
			GameTooltip:SetOwner(sel, "ANCHOR_TOP")
			GameTooltip:AddDoubleLine(name, "|T136033:16:16:0:0|t ExpansionUtils")
			if level then
				local lvl = tostring(level)
				if maxLevel and maxLevel > 0 then lvl = lvl .. "/" .. maxLevel end
				GameTooltip:AddDoubleLine(LEVEL or "Level", lvl)
			end

			if maxXP and maxXP > 0 then
				GameTooltip:AddDoubleLine(XP or "XP", FormatNr(cur) .. "/" .. FormatNr(maxXP))
				GameTooltip:AddDoubleLine(ExpansionUtils:Trans("LID_REMAINING"), FormatNr(maxXP - cur))
			else
				GameTooltip:AddDoubleLine(XP or "XP", MAXIMUM or "MAX")
			end

			local runTxt = FormatNr(runGain)
			local dName, dTier = GetDelveContext()
			if dName then
				local nm = dName
				if dTier then nm = nm .. " (" .. ExpansionUtils:Trans("LID_TIER") .. " " .. dTier .. ")" end
				runTxt = runTxt .. " |cFFAAAAAA(" .. nm .. ")"
			end

			GameTooltip:AddDoubleLine(ExpansionUtils:Trans("LID_XPTHISDELVE"), runTxt)
			local best = GetBestScore()
			if best then
				local txt = FormatNr(best.xp or 0)
				if best.name then
					local nm = best.name
					if best.tier then nm = nm .. " (" .. ExpansionUtils:Trans("LID_TIER") .. " " .. best.tier .. ")" end
					txt = txt .. " |cFFAAAAAA(" .. nm .. ")"
				end

				GameTooltip:AddDoubleLine(ExpansionUtils:Trans("LID_HIGHSCORE"), txt)
			end

			GameTooltip:AddDoubleLine(" ", " ")
			GameTooltip:AddDoubleLine(ExpansionUtils:Trans("LID_DRAGTOMOVE"), "/valeera")
			GameTooltip:Show()
		end
	)

	bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints(bar)
	bar.bg:SetColorTexture(0, 0, 0, 0.6)
	bar.status = CreateFrame("StatusBar", "EUValeeraXPBarStatus", bar)
	bar.status:SetPoint("TOPLEFT", bar, "TOPLEFT", 2, -2)
	bar.status:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, 2)
	bar.status:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar.status:GetStatusBarTexture():SetHorizTile(false)
	bar.status:GetStatusBarTexture():SetVertTile(false)
	local r, g, b = ExpansionUtils:GetClassColor("ROGUE")
	bar.status:SetStatusBarColor(r, g, b, 0.9)
	bar.status:SetMinMaxValues(0, 1)
	bar.status:SetValue(0)
	bar.right = bar.status:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bar.right:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
	bar.right:SetJustifyH("RIGHT")
	bar.left = bar.status:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	bar.left:SetPoint("LEFT", bar, "LEFT", 6, 0)
	bar.left:SetPoint("RIGHT", bar.right, "LEFT", -6, 0)
	bar.left:SetJustifyH("LEFT")
	bar.left:SetWordWrap(false)
	local p1, p2, p3, p4, p5 = unpack(ExpansionUtils:GV(GetDB(), "POS", {}))
	if p1 then
		bar:ClearAllPoints()
		bar:SetPoint(p1, p2 or "UIParent", p3, p4, p5)
	end

	bar:Hide()

	return bar
end

local fVXP = CreateFrame("Frame")
ExpansionUtils:RegisterEvent(fVXP, "PLAYER_LOGIN")
ExpansionUtils:OnEvent(
	fVXP,
	function(sel, event)
		if event == "PLAYER_LOGIN" then
			ExpansionUtils:UnregisterEvent(fVXP, "PLAYER_LOGIN")
			if ExpansionUtils:GetWoWBuild() ~= "RETAIL" then return end
			GetDB()
			CreateBar()
			ExpansionUtils:RegisterEvent(fVXP, "UPDATE_FACTION")
			ExpansionUtils:RegisterEvent(fVXP, "PLAYER_ENTERING_WORLD")
			ExpansionUtils:RegisterEvent(fVXP, "GROUP_ROSTER_UPDATE")
			if ticker == nil then ticker = C_Timer.NewTicker(5, function() UpdateBar() end) end
		end

		UpdateBar()
	end,
	"ExpansionUtils ValeeraXPBar"
)

ExpansionUtils:AddSlash(
	"valeera",
	function(msg)
		local cmd = strlower(strtrim(msg or ""))
		local db = GetDB()
		if cmd == "reset" then
			ExpansionUtils:SV(db, "POS", nil)
			if bar then
				bar:ClearAllPoints()
				bar:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
			end

			ExpansionUtils:MSG(ExpansionUtils:Trans("LID_SAVEDNEWPOSITION"))
		elseif cmd == "lock" then
			local locked = ExpansionUtils:GV(db, "LOCKED", false) ~= true
			ExpansionUtils:SV(db, "LOCKED", locked)
			if locked then
				ExpansionUtils:MSG(ExpansionUtils:Trans("LID_VALEERAXPBAR"), ExpansionUtils:Trans("LID_LOCKED"))
			else
				ExpansionUtils:MSG(ExpansionUtils:Trans("LID_VALEERAXPBAR"), ExpansionUtils:Trans("LID_UNLOCKED"))
			end
		elseif cmd == "resetscore" then
			ExpansionUtils:SV(db, "HIGHSCORE", {})
			runStart = nil
			runGain = 0
			runKey = nil
			ExpansionUtils:MSG(ExpansionUtils:Trans("LID_HIGHSCORE"), ExpansionUtils:Trans("LID_RESET"))
		else
			local show = ExpansionUtils:GV(db, "SHOWVALEERAXPBAR", true) ~= true
			ExpansionUtils:SV(db, "SHOWVALEERAXPBAR", show)
			if show == false and bar then bar:Hide() end
		end

		UpdateBar()
	end
)
