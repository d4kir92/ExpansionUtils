local _, ExpansionUtils = ...
local ICON = ExpansionUtils:GetAddonIcon()
local DEFAULT_WIDTH = 420
local DEFAULT_HEIGHT = 320
local settings = nil
local mmbtnCheckbox = nil
ExpansionUtils.LANGUAGES = {{"English", "enUS"}, {"Deutsch", "deDE"}, {"Español (España)", "esES"}, {"Español (México)", "esMX"}, {"Français", "frFR"}, {"Italiano", "itIT"}, {"한국어", "koKR"}, {"Português (Brasil)", "ptBR"}, {"Русский", "ruRU"}, {"简体中文", "zhCN"}, {"繁體中文", "zhTW"}}
local languageNames = {}
for _, info in ipairs(ExpansionUtils.LANGUAGES) do
	languageNames[info[2]] = info[1]
end

local languageCallbacks = {}
function ExpansionUtils:GetLanguage()
	local lang = type(EVTAB) == "table" and EVTAB.LANGUAGE or nil
	if languageNames[lang] then return lang end
	return languageNames[GetLocale()] and GetLocale() or "enUS"
end

function ExpansionUtils:GetLanguageName()
	return languageNames[self:GetLanguage()]
end

local LibTrans = ExpansionUtils.Trans
function ExpansionUtils:Trans(key, lang, ...)
	return LibTrans(self, key, lang or ExpansionUtils:GetLanguage(), ...)
end

function ExpansionUtils:OnLanguage(callback)
	table.insert(languageCallbacks, callback)
end

function ExpansionUtils:SetLanguage(lang)
	if not languageNames[lang] or lang == self:GetLanguage() then return end
	EVTAB = EVTAB or {}
	EVTAB.LANGUAGE = lang ~= GetLocale() and lang or nil
	for _, callback in ipairs(languageCallbacks) do
		callback()
	end
end

local LibCreateMinimapButton = ExpansionUtils.CreateMinimapButton
function ExpansionUtils:CreateMinimapButton(params)
	local translations = {}
	for index, line in ipairs(params.vTT or {}) do
		for column, value in ipairs(line) do
			if type(value) == "string" and string.find(value, "LID_", 1, true) == 1 then
				table.insert(translations, {index, column, value})
			end
		end
	end

	local function Refresh()
		for _, entry in ipairs(translations) do
			params.vTT[entry[1]][entry[2]] = ExpansionUtils:Trans(entry[3])
		end
	end

	Refresh()
	self:OnLanguage(Refresh)
	return LibCreateMinimapButton(self, params)
end

local function AddLanguageSelector(window)
	window.languageRefresh = {}
	for _, method in ipairs({"AddCategory", "AddCheckbox", "AddSlider", "AddOrderList"}) do
		local add = window[method]
		window[method] = function(self, tab)
			local key = tab.label
			local widget = add(self, tab)
			local element = self.elements[#self.elements]
			local function Refresh()
				local text = ExpansionUtils:Trans(key)
				if method == "AddSlider" then
					widget.Label:SetText(text .. ": " .. tostring(widget.value))
				elseif widget.Label then
					widget.Label:SetText(text)
				end

				ExpansionUtils.UI:SetLabel(element, text)
				ExpansionUtils.UI:RefreshNewBadge(widget)
				ExpansionUtils.UI:RefreshNewBadge(widget:GetParent())
			end

			if method == "AddSlider" then widget.slider:HookScript("OnValueChanged", Refresh) end
			table.insert(self.languageRefresh, Refresh)
			return widget
		end
	end

	function window.LanguageMenu(_, root)
		root:CreateTitle(ExpansionUtils:Trans("LID_LANGUAGE"))
		for _, info in ipairs(ExpansionUtils.LANGUAGES) do
			local lang = info[2]
			root:CreateRadio(format("%s (%s)", info[1], lang), function() return ExpansionUtils:GetLanguage() == lang end, function() ExpansionUtils:SetLanguage(lang) end)
		end
	end

	if ExpansionUtils:CheckTemplates("WowStyle1DropdownTemplate") then
		window.Language = CreateFrame("DropdownButton", "ExpansionUtilsOptions_Language", window.titleBar or window, "WowStyle1DropdownTemplate")
		window.Language:SetScale(0.8)
		window.Language:SetSize(130, 25)
		window.Language:SetPoint("TOPLEFT", window.titleBar or window, "TOPLEFT", 10, -1.25)
		window.Language:SetSelectionText(function() return ExpansionUtils:GetLanguageName() end)
		window.Language:SetTooltip(function(tooltip) tooltip:SetText(ExpansionUtils:Trans("LID_LANGUAGE")) end)
		window.Language:SetupMenu(window.LanguageMenu)
	else
		window.Language = ExpansionUtils:CreateButton("ExpansionUtilsOptions_Language", window.titleBar or window)
		window.Language:SetSize(104, 20)
		window.Language:SetPoint("TOPLEFT", window.titleBar or window, "TOPLEFT", 7, -2)
		window.Language.Arrow = window.Language:CreateTexture(nil, "OVERLAY")
		window.Language.Arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
		window.Language.Arrow:SetSize(16, 16)
		window.Language.Arrow:SetPoint("RIGHT", window.Language, "RIGHT", -2, 0)
		window.Language:SetScript("OnClick", function(button)
			if MenuUtil and MenuUtil.CreateContextMenu then
				MenuUtil.CreateContextMenu(button, window.LanguageMenu)
			else
				local current = 1
				for index, info in ipairs(ExpansionUtils.LANGUAGES) do
					if info[2] == ExpansionUtils:GetLanguage() then current = index end
				end

				ExpansionUtils:SetLanguage(ExpansionUtils.LANGUAGES[current % #ExpansionUtils.LANGUAGES + 1][2])
			end
		end)

		window.Language:SetScript("OnEnter", function(button)
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			GameTooltip:SetText(ExpansionUtils:Trans("LID_LANGUAGE"))
			GameTooltip:Show()
		end)

		window.Language:SetScript("OnLeave", GameTooltip_Hide)
	end

	window.Language:SetText(ExpansionUtils:GetLanguageName())
	ExpansionUtils:OnLanguage(function()
		for _, refresh in ipairs(window.languageRefresh) do
			refresh()
		end

		window.Language:SetText(ExpansionUtils:GetLanguageName())
		if window.Language.GenerateMenu then window.Language:GenerateMenu() end
		if window.search then
			window.search.Hint:SetText(ExpansionUtils:Trans("LID_SEARCH"))
			window:Filter(window.search:GetText())
		end
	end)
end

function ExpansionUtils:ToggleSettings()
	if settings == nil then return end
	settings:Toggle()
end

function ExpansionUtils:OpenSettings()
	if settings == nil then return end
	settings:Show()
	settings:Raise()
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

function ExpansionUtils:InitSettings()
	EVTAB = EVTAB or {}
	if EVTAB["MMBTN"] == nil then ExpansionUtils:SV(EVTAB, "MMBTN", true) end
	ExpansionUtils:AddSlash("exut", ExpansionUtils.ToggleSettings)
	ExpansionUtils:AddSlash("expansionutils", ExpansionUtils.ToggleSettings)
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

	AddLanguageSelector(settings)
	settings:SuspendLayout()
	settings:AddSearch()
	AddCategory("MINIMAPBUTTONS")
	mmbtnCheckbox = AddMinimapCheckbox("LID_MMBTN", EVTAB, "MMBTN", "ExpansionUtils")
	if ExpansionUtils:HasSystem("GREATVAULT") then AddMinimapCheckbox("LID_SHOWVAULTMMBTN", EVTAB["MMBtnGreatVault"], "MMBTNGREATVAULT", "ExpansionUtilsGreatVault") end
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

	local columnOrder = settings:AddOrderList({
		["label"] = "LID_COLUMNS",
		["search"] = "COLUMNS",
		["items"] = ExpansionUtils:GetCharacterOverviewColumnTree(),
		["func"] = function() ExpansionUtils:UpdateCharacterOverviewColumns() end
	})

	ExpansionUtils:OnLanguage(function()
		columnOrder:Refresh()
		ExpansionUtils:RefreshCharacterOverviewLanguage()
		GameTooltip:Hide()
	end)

	settings:ResumeLayout()
	ExpansionUtils:CreateMinimapButton({
		["name"] = "ExpansionUtils",
		["icon"] = ICON,
		["dbtab"] = EVTAB,
		["vTT"] = {{title, version}, {"LID_LEFTCLICK", "LID_OPENSETTINGS"}, {"LID_SHIFTLEFTCLICK", "LID_TOGGLECHARACTEROVERVIEW"}, {"LID_RIGHTCLICK", "LID_HIDEMINIMAPBUTTON"}},
		["funcL"] = function() ExpansionUtils:ToggleSettings() end,
		["funcSL"] = function() ExpansionUtils:ToggleCharacterOverview() end,
		["funcR"] = function()
			ExpansionUtils:SV(EVTAB, "MMBTN", false)
			ExpansionUtils:HideMMBtn("ExpansionUtils")
			if mmbtnCheckbox then mmbtnCheckbox:SetChecked(false) end
			ExpansionUtils:MSG(ExpansionUtils:Trans("LID_MMBTNHIDDEN"))
		end,
		["dbkey"] = "MMBTN"
	})
end
