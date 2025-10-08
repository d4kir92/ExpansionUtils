local _, ExpansionUtils = ...
local function GetVaultData()
	local vaultData = C_WeeklyRewards.GetActivities()
	if not vaultData then return {}, {}, {} end
	local res = {}
	res["raid"] = {}
	res["mplus"] = {}
	res["world"] = {}
	for x, data in pairs(vaultData) do
		if data.type == 1 then
			table.insert(res["mplus"], data)
		elseif data.type == 3 then
			table.insert(res["raid"], data)
		elseif data.type == 6 then
			table.insert(res["world"], data)
		else
			ExpansionUtils:MSG("[GetVaultData] Missing Type:", data.type)
		end
	end

	return res
end

local function GetVaultStatus(vaultData, name)
	local res = ""
	for i, data in pairs(vaultData[name]) do
		local color = "|cFFFFFFFF"
		if data.progress == 0 then
			color = "|cFFFF0000"
		elseif data.progress >= data.threshold then
			color = "|cFF00FF00"
		else
			color = "|cFFFFFF00"
		end

		local status = color .. data.progress .. "|cFFFFFFFF/" .. color .. data.threshold
		if data.progress > data.threshold then
			status = color .. data.threshold .. "|cFFFFFFFF/" .. color .. data.threshold
		end

		if res ~= "" then
			res = res .. "     "
		end

		res = res .. status
	end

	res = res .. "  "

	return res
end

local function GetVaultStatusIlvl(vaultData, name)
	local res = ""
	for i, data in pairs(vaultData[name]) do
		local ilvl = nil
		local itemLink = C_WeeklyRewards.GetExampleRewardItemHyperlinks(data.id)
		if itemLink then
			ilvl = GetDetailedItemLevelInfo(itemLink)
		end

		local color = "|cFFFFFFFF"
		if data.progress == 0 then
			color = "|cFFFF0000"
		elseif data.progress >= data.threshold then
			color = "|cFF00FF00"
		else
			color = "|cFFFFFF00"
		end

		if res ~= "" then
			res = res .. " "
		end

		if ilvl then
			res = res .. " |cFFFFFFFF(" .. color .. ilvl .. "|cFFFFFFFF" .. ")"
		else
			res = res .. "         "
		end
	end

	return res
end

local reshii = false
local fEV = CreateFrame("Frame")
ExpansionUtils:RegisterEvent(fEV, "PLAYER_LOGIN")
ExpansionUtils:OnEvent(
	fEV,
	function()
		ExpansionUtils:UnregisterEvent(fEV, "PLAYER_LOGIN")
		ExpansionUtils:SetAddonOutput("ExpansionUtils", 133740)
		ExpansionUtils:SetVersion(133740, "1.2.6")
		if EVTAB == nil or EVTAB["MMBtnReshiWrap"] == nil or EVTAB["MMBtnGreatVault"] == nil then
			EVTAB = EVTAB or {}
			EVTAB["MMBtnReshiWrap"] = EVTAB["MMBtnReshiWrap"] or {}
			EVTAB["MMBtnGreatVault"] = EVTAB["MMBtnGreatVault"] or {}
			ExpansionUtils:SV(EVTAB["MMBtnReshiWrap"], "MMBTNRESHIIWRAP", true)
			ExpansionUtils:SV(EVTAB["MMBtnGreatVault"], "MMBTNGREATVAULT", true)
		end

		if ExpansionUtils:GetWoWBuild() == "RETAIL" then
			if ExpansionUtils:GV(EVTAB["MMBtnReshiWrap"], "MMBTNRESHIIWRAP", true) then
				local btnReshii = ExpansionUtils:CreateMinimapButton(
					{
						["name"] = "ReshiiWraps",
						["atlas"] = "poi-workorders",
						["dbtab"] = EVTAB["MMBtnReshiWrap"],
						["vTT"] = {{ExpansionUtils:Trans("LID_RESHIIWRAP"), "|T136033:16:16:0:0|t ExpansionUtils"}, {ExpansionUtils:Trans("LID_LEFTCLICK"), ExpansionUtils:Trans("LID_TOGGLERESHIIWRAP")}},
						["funcL"] = function()
							if GenericTraitUI_LoadUI and reshii == false then
								reshii = true
								GenericTraitUI_LoadUI()
							end

							if GenericTraitFrame then
								GenericTraitFrame:SetSystemID(29)
								GenericTraitFrame:SetTreeID(1115)
								ToggleFrame(GenericTraitFrame)
							end
						end,
						["dbkey"] = "MMBTNRESHIIWRAP",
						["parent"] = CharacterBackSlot,
						["point"] = {"Right", CharacterBackSlot, "Left", 4, 0},
						["noalpha"] = true,
					}
				)

				btnReshii:SetScript(
					"OnUpdate",
					function()
						local itemID = GetInventoryItemID("player", 15)
						if itemID and itemID == 235499 then
							btnReshii:SetAlpha(1)
							btnReshii:EnableMouse(true)
						else
							btnReshii:SetAlpha(0)
							btnReshii:EnableMouse(false)
						end
					end
				)
			end

			if ExpansionUtils:GV(EVTAB["MMBtnGreatVault"], "MMBTNVAULT", true) then
				local mmbtn = nil
				ExpansionUtils:CreateMinimapButton(
					{
						["name"] = "ExpansionUtilsGreatVault",
						["atlas"] = "GreatVault-32x32",
						["var"] = mmbtn,
						["dbtab"] = EVTAB["MMBtnGreatVault"],
						["vTT"] = {{ExpansionUtils:Trans("LID_GREATVAULT"), "|T136033:16:16:0:0|t ExpansionUtils"}, {ExpansionUtils:Trans("LID_LEFTCLICK"), ExpansionUtils:Trans("LID_TOGGLEGREATVAULT")}},
						["vTTUpdate"] = function(sel, tt)
							if C_WeeklyRewards.HasAvailableRewards() or C_WeeklyRewards.HasGeneratedRewards() then
								tt:AddDoubleLine(" ", " ")
								tt:AddDoubleLine("GREAT VAULT HAS REWARD", "")
							end

							tt:AddDoubleLine(" ", " ")
							local vaultData = GetVaultData()
							local raid = GetVaultStatus(vaultData, "raid")
							tt:AddDoubleLine(RAID, raid)
							local raidIlvl = GetVaultStatusIlvl(vaultData, "raid")
							if strtrim(raidIlvl) ~= "" then
								tt:AddDoubleLine(" ", raidIlvl)
							end

							tt:AddDoubleLine(" ", " ")
							local mplus = GetVaultStatus(vaultData, "mplus")
							tt:AddDoubleLine(PLAYER_DIFFICULTY_MYTHIC_PLUS, mplus)
							local mplusIlvl = GetVaultStatusIlvl(vaultData, "mplus")
							if strtrim(mplusIlvl) ~= "" then
								tt:AddDoubleLine(" ", mplusIlvl)
							end

							tt:AddDoubleLine(" ", " ")
							local world = GetVaultStatus(vaultData, "world")
							tt:AddDoubleLine(WORLD, world)
							local worldIlvl = GetVaultStatusIlvl(vaultData, "world")
							if strtrim(worldIlvl) ~= "" then
								tt:AddDoubleLine(" ", worldIlvl)
							end

							for i = 1, 99 do
								local tr = _G[ExpansionUtils:GetName(tt) .. "TextRight" .. i]
								if tr then
									tr:SetFontObject("ConsoleFontNormal")
									local f1, _, f3 = tr:GetFont()
									tr:SetFont(f1, 14, f3)
								end
							end

							return false
						end,
						["funcL"] = function()
							if not InCombatLockdown() then
								if WeeklyRewardsFrame == nil then
									WeeklyRewards_ShowUI()
								elseif WeeklyRewardsFrame:IsShown() then
									WeeklyRewardsFrame:Hide()
								else
									WeeklyRewards_ShowUI()
								end
							end
						end,
						["addoncomp"] = false,
						["sw"] = 64,
						["sh"] = 64,
						["border"] = false,
						["dbkey"] = "MMBTNGREATVAULT",
						["noalpha"] = true
					}
				)
			end
		end

		if ChallengesKeystoneFrame then
			local startButton = ChallengesKeystoneFrame.StartButton
			if startButton then
				local sw, sh = startButton:GetSize()
				ChallengesKeystoneFrame.readyCheck = CreateFrame("Button", "readyCheck", ChallengesKeystoneFrame, "UIPanelButtonTemplate")
				ChallengesKeystoneFrame.readyCheck:SetSize(sw, sh)
				ChallengesKeystoneFrame.readyCheck:SetPoint("RIGHT", startButton, "LEFT", -4, 0)
				ChallengesKeystoneFrame.readyCheck:SetText(READY_CHECK)
				ChallengesKeystoneFrame.readyCheck:SetScript(
					"OnClick",
					function()
						DoReadyCheck()
					end
				)

				ChallengesKeystoneFrame.readyCheckText = ChallengesKeystoneFrame:CreateFontString(nil, nil, "GameFontNormal")
				ChallengesKeystoneFrame.readyCheckText:SetSize(sw, sh)
				ChallengesKeystoneFrame.readyCheckText:SetPoint("BOTTOM", ChallengesKeystoneFrame.readyCheck, "TOP", 0, -4)
				ChallengesKeystoneFrame.readyCheckText:SetText("")
				ChallengesKeystoneFrame:HookScript(
					"OnUpdate",
					function()
						local count = 0
						if GetReadyCheckStatus("player") == nil then
							ChallengesKeystoneFrame.readyCheckText:SetText("")

							return
						end

						if GetReadyCheckStatus("player") == "ready" then
							count = count + 1
						end

						for i = 1, 4 do
							if UnitExists("party" .. i) and GetReadyCheckStatus("party" .. i) == "ready" then
								count = count + 1
							end
						end

						if count ~= GetNumGroupMembers() then
							ChallengesKeystoneFrame.readyCheckText:SetText(count .. "/" .. GetNumGroupMembers())
						else
							ChallengesKeystoneFrame.readyCheckText:SetText(ALL)
						end
					end
				)

				local countdowns = {3, 5, 10}
				for x, w in pairs(countdowns) do
					ChallengesKeystoneFrame["countdown" .. w] = CreateFrame("Button", "countdown" .. w, ChallengesKeystoneFrame, "UIPanelButtonTemplate")
					ChallengesKeystoneFrame["countdown" .. w]:SetSize(sw / #countdowns, sh)
					ChallengesKeystoneFrame["countdown" .. w]:SetPoint("LEFT", startButton, "RIGHT", 4 + ((x - 1) * (sw / #countdowns + 4)), 0)
					ChallengesKeystoneFrame["countdown" .. w]:SetText(SECOND_ONELETTER_ABBR:format(w))
					ChallengesKeystoneFrame["countdown" .. w]:SetScript(
						"OnClick",
						function()
							if SlashCmdList["DEADLYBOSSMODS"] then
								SlashCmdList["DEADLYBOSSMODS"]("pull " .. w)
							elseif TankHelper:IsAddOnLoaded("BigWigs") then
								DEFAULT_CHAT_FRAME.editBox:SetText("/pull " .. w)
								ChatEdit_SendText(DEFAULT_CHAT_FRAME.editBox, 0)
							elseif C_PartyInfo and C_PartyInfo.DoCountdown then
								C_PartyInfo.DoCountdown(w)
							end
						end
					)
				end
			end
		end
	end, "ExpansionUtils"
)
