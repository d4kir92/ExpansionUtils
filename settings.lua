local _, ExpansionUtils = ...
local ICON = 133740
local DEFAULT_WIDTH = 420
local DEFAULT_HEIGHT = 320
local settings = nil
local mmbtnCheckbox = nil
function ExpansionUtils:ToggleSettings()
	if settings == nil then return end
	settings:Toggle()
end

local function GetCollapsed(key)
	if key == nil then return nil end
	if type(EVTAB) ~= "table" then return nil end
	if type(EVTAB["COLLAPSED"]) ~= "table" then return nil end
	return EVTAB["COLLAPSED"][key]
end

local function SetCollapsed(key, collapsed)
	if key == nil then return end
	if type(EVTAB) ~= "table" then return end
	if type(EVTAB["COLLAPSED"]) ~= "table" then EVTAB["COLLAPSED"] = {} end
	if collapsed then
		EVTAB["COLLAPSED"][key] = true
	else
		EVTAB["COLLAPSED"][key] = nil
	end
end

local function AddCategory(key)
	settings:AddCategory({
		["label"] = "LID_" .. key,
		["key"] = key,
		["search"] = key
	})
end

local function AddMinimapCheckbox(label, db, key, name)
	return settings:AddCheckbox({
		["label"] = label,
		["search"] = key,
		["value"] = ExpansionUtils:GV(db, key, true),
		["func"] = function(value)
			ExpansionUtils:SV(db, key, value)
			if value then
				ExpansionUtils:ShowMMBtn(name)
			else
				ExpansionUtils:HideMMBtn(name)
			end
		end
	})
end

local function HandleSlash(msg)
	if strlower(strtrim(msg or "")) == "raid" then
		ExpansionUtils:PrintCharacterOverviewRaidDebug()
		return
	end

	ExpansionUtils:ToggleSettings()
end

function ExpansionUtils:InitSettings()
	EVTAB = EVTAB or {}
	if EVTAB["MMBTN"] == nil then ExpansionUtils:SV(EVTAB, "MMBTN", true) end
	ExpansionUtils:AddSlash("exut", HandleSlash)
	ExpansionUtils:AddSlash("expansionutils", HandleSlash)
	local title = "|T" .. ICON .. ":16:16:0:0|t ExpansionUtils"
	local version = "v" .. (ExpansionUtils:GetVersion() or "")
	settings = ExpansionUtils:CreateUIWindow({
		["name"] = "ExpansionUtilsSettings",
		["pTab"] = {"CENTER"},
		["width"] = ExpansionUtils:GV(EVTAB, "WINDOWWIDTH", DEFAULT_WIDTH),
		["height"] = ExpansionUtils:GV(EVTAB, "WINDOWHEIGHT", DEFAULT_HEIGHT),
		["minWidth"] = 360,
		["minHeight"] = 240,
		["onResize"] = function(width, height)
			ExpansionUtils:SV(EVTAB, "WINDOWWIDTH", width)
			ExpansionUtils:SV(EVTAB, "WINDOWHEIGHT", height)
		end,
		["getCollapsed"] = function(key) return GetCollapsed(key) end,
		["setCollapsed"] = function(key, collapsed) SetCollapsed(key, collapsed) end,
		["title"] = title .. " " .. version
	})

	settings:SuspendLayout()
	settings:AddSearch()
	AddCategory("MINIMAPBUTTONS")
	mmbtnCheckbox = AddMinimapCheckbox("LID_MMBTN", EVTAB, "MMBTN", "ExpansionUtils")
	AddMinimapCheckbox("LID_SHOWVAULTMMBTN", EVTAB["MMBtnGreatVault"], "MMBTNGREATVAULT", "ExpansionUtilsGreatVault")
	AddMinimapCheckbox("LID_SHOWCOOLDOWNVIEWERMMBTN", EVTAB["MMBtnCooldownViewerSettings"], "MMBTNCooldownViewerSettings", "CooldownViewerSettings")
	AddCategory("CHARACTEROVERVIEW")
	ExpansionUtils.settingsOnlyMaxLevel = settings:AddCheckbox({
		["label"] = "LID_ONLYMAXLEVEL",
		["search"] = "ONLYMAXLEVEL",
		["value"] = ExpansionUtils:IsCharacterOverviewOnlyMaxLevel(),
		["func"] = function(value) ExpansionUtils:SetCharacterOverviewOnlyMaxLevel(value) end
	})

	local fontMin, fontMax = ExpansionUtils:GetCharacterOverviewFontRange()
	ExpansionUtils.settingsFontSize = settings:AddSlider({
		["label"] = "LID_FONTSIZE",
		["search"] = "FONTSIZE",
		["value"] = ExpansionUtils:GetCharacterOverviewFontSize(),
		["min"] = fontMin,
		["max"] = fontMax,
		["step"] = 1,
		["func"] = function(value) ExpansionUtils:SetCharacterOverviewFontSize(value) end
	})

	settings:AddCategory({
		["label"] = "LID_COLUMNS",
		["key"] = "COLUMNS",
		["search"] = "COLUMNS",
		["sub"] = true
	})

	settings:AddOrderList({
		["label"] = "LID_COLUMNS",
		["search"] = "COLUMNS",
		["items"] = ExpansionUtils:GetCharacterOverviewColumnTree(),
		["func"] = function() ExpansionUtils:UpdateCharacterOverviewColumns() end
	})

	settings:ResumeLayout()
	ExpansionUtils:CreateMinimapButton({
		["name"] = "ExpansionUtils",
		["icon"] = ICON,
		["dbtab"] = EVTAB,
		["vTT"] = {{title, version}, {ExpansionUtils:Trans("LID_LEFTCLICK"), ExpansionUtils:Trans("LID_OPENSETTINGS")}, {ExpansionUtils:Trans("LID_RIGHTCLICK"), ExpansionUtils:Trans("LID_HIDEMINIMAPBUTTON")}},
		["funcL"] = function() ExpansionUtils:ToggleSettings() end,
		["funcR"] = function()
			ExpansionUtils:SV(EVTAB, "MMBTN", false)
			ExpansionUtils:HideMMBtn("ExpansionUtils")
			if mmbtnCheckbox then mmbtnCheckbox:SetChecked(false) end
			ExpansionUtils:MSG(ExpansionUtils:Trans("LID_MMBTNHIDDEN"))
		end,
		["dbkey"] = "MMBTN"
	})
end
