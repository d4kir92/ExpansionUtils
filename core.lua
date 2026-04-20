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

function ExpansionUtils:FixCastBar(castbar, notInterruptible)
	if castbar.BorderShield == nil then
		castbar.BorderShield = castbar:CreateTexture(nil, "OVERLAY", nil, -2)
		castbar.BorderShield:SetTexture("Interface\\AddOns\\ExpansionUtils\\media\\unkickable")
		castbar.BorderShield:SetTexCoord(0, 1, 0, 1)
		castbar.BorderShield:SetSize(32, 32)
		if castbar.Icon then
			castbar.BorderShield:SetPoint("CENTER", castbar.Icon, "CENTER", 0, -2)
			castbar.BorderShield:SetDrawLayer("OVERLAY", -2)
			castbar.Icon:SetDrawLayer("OVERLAY", -1)
		else
			castbar.BorderShield:SetPoint("LEFT", castbar.Icon, "LEFT", 0, 0)
		end
	end

	castbar.BorderShield:ClearAllPoints()
	castbar.BorderShield:SetPoint("CENTER", castbar.Icon, "CENTER", -0.6, -2)
	if notInterruptible then
		castbar.BorderShield:Show()
		if castbar.BarBorder then
			castbar.BarBorder:Show()
		end

		castbar:SetStatusBarColor(0.5, 0.5, 0.5)
	else
		castbar.BorderShield:Hide()
		if castbar.BarBorder then
			castbar.BarBorder:Hide()
		end
	end
end

local reshii = false
local fEV = CreateFrame("Frame")
ExpansionUtils:RegisterEvent(fEV, "PLAYER_LOGIN")
ExpansionUtils:OnEvent(
	fEV,
	function()
		ExpansionUtils:UnregisterEvent(fEV, "PLAYER_LOGIN")
		ExpansionUtils:SetAddonOutput("ExpansionUtils", 133740)
		ExpansionUtils:SetVersion(133740, "1.2.26")
		EVTAB = EVTAB or {}
		if EVTAB["MMBtnReshiWrap"] == nil then
			EVTAB["MMBtnReshiWrap"] = EVTAB["MMBtnReshiWrap"] or {}
			ExpansionUtils:SV(EVTAB["MMBtnReshiWrap"], "MMBTNRESHIIWRAP", true)
		end

		if EVTAB["MMBtnGreatVault"] == nil then
			EVTAB["MMBtnGreatVault"] = EVTAB["MMBtnGreatVault"] or {}
			ExpansionUtils:SV(EVTAB["MMBtnGreatVault"], "MMBTNGREATVAULT", true)
		end

		if EVTAB["MMBtnCooldownViewerSettings"] == nil then
			EVTAB["MMBtnCooldownViewerSettings"] = EVTAB["MMBtnCooldownViewerSettings"] or {}
			ExpansionUtils:SV(EVTAB["MMBtnCooldownViewerSettings"], "MMBTNCooldownViewerSettings", true)
		end

		if ExpansionUtils:GetWoWBuild() == "RETAIL" then
			if ExpansionUtils:GV(EVTAB["MMBtnCooldownViewerSettings"], "MMBTNCooldownViewerSettings", true) then
				local mmbtn = nil
				ExpansionUtils:CreateMinimapButton(
					{
						["name"] = "CooldownViewerSettings",
						["atlas"] = "QuestLog-icon-setting",
						["var"] = mmbtn,
						["dbtab"] = EVTAB["MMBtnCooldownViewerSettings"],
						["vTT"] = {{ExpansionUtils:Trans("LID_CooldownViewerSettings"), "|T136033:16:16:0:0|t ExpansionUtils"}, {ExpansionUtils:Trans("LID_LEFTCLICK"), ExpansionUtils:Trans("LID_TOGGLECooldownViewerSettings")}},
						["vTTUpdate"] = function(sel, tt) return false end,
						["funcL"] = function()
							if not InCombatLockdown() and CooldownViewerSettings then
								if CooldownViewerSettings:IsVisible() then
									CooldownViewerSettings:Hide()
								else
									CooldownViewerSettings:Show()
								end
							end
						end,
						["addoncomp"] = false,
						["sw"] = 64,
						["sh"] = 64,
						["border"] = false,
						["dbkey"] = "MMBTNCooldownViewerSettings"
					}
				)
			end

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
								if GenericTraitFrame.SetSystemID then
									GenericTraitFrame:SetSystemID(29)
								end

								if GenericTraitFrame.SetTreeID then
									GenericTraitFrame:SetTreeID(1115)
								end

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

		if ExpansionUtils:GetWoWBuild() ~= "RETAIL" then
			local frame = CreateFrame("Frame")
			frame:RegisterEvent("UNIT_SPELLCAST_START")
			frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
			frame:RegisterEvent("PLAYER_TARGET_CHANGED")
			local function UpdateShieldIcon(unit)
				if unit ~= "target" and unit ~= "focus" then return end
				local _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
				if notInterruptible == nil then
					_, _, _, _, _, _, notInterruptible = UnitChannelInfo(unit)
				end

				if unit == "target" then
					if DragonflightUITargetCastbar then
						ExpansionUtils:FixCastBar(DragonflightUITargetCastbar, notInterruptible)
					else
						ExpansionUtils:FixCastBar(TargetFrameSpellBar, notInterruptible)
					end
				elseif unit == "focus" then
					if DragonflightUIFocusCastbar then
						ExpansionUtils:FixCastBar(DragonflightUIFocusCastbar, notInterruptible)
					else
						ExpansionUtils:FixCastBar(FocusFrameSpellBar, notInterruptible)
					end
				end
			end

			frame:SetScript(
				"OnEvent",
				function(self, event, unit)
					UpdateShieldIcon(unit or "target")
				end
			)
		end
	end, "ExpansionUtils"
)

local lastCount = 0
local fCUI = CreateFrame("Frame")
ExpansionUtils:RegisterEvent(fCUI, "ADDON_LOADED")
ExpansionUtils:RegisterEvent(fCUI, "READY_CHECK_CONFIRM")
ExpansionUtils:RegisterEvent(fCUI, "READY_CHECK_FINISHED")
ExpansionUtils:OnEvent(
	fCUI,
	function(sel, event, ...)
		if event == "READY_CHECK_CONFIRM" then
			if ChallengesKeystoneFrame then
				local isReady = select(2, ...)
				if isReady then
					lastCount = lastCount + 1
				end

				if (lastCount > 0) and lastCount ~= GetNumGroupMembers() then
					if READY then
						ChallengesKeystoneFrame.readyCheckText:SetText("|cffffff00" .. lastCount .. "/" .. GetNumGroupMembers() .. " " .. READY)
					else
						ChallengesKeystoneFrame.readyCheckText:SetText("|cffffff00" .. lastCount .. "/" .. GetNumGroupMembers() .. " READY")
					end
				end
			end
		elseif event == "READY_CHECK_FINISHED" then
			if ChallengesKeystoneFrame then
				readyCheckDone = true
				if lastCount == GetNumGroupMembers() then
					if READY_CHECK_ALL_READY then
						ChallengesKeystoneFrame.readyCheckText:SetText("|cff00ff00" .. READY_CHECK_ALL_READY)
					elseif ALL then
						ChallengesKeystoneFrame.readyCheckText:SetText("|cff00ff00" .. ALL)
					else
						ChallengesKeystoneFrame.readyCheckText:SetText("|cff00ff00" .. "ALL READY")
					end
				else
					if NOT_READY then
						ChallengesKeystoneFrame.readyCheckText:SetText("|cffff0000" .. NOT_READY)
					else
						ChallengesKeystoneFrame.readyCheckText:SetText("|cffff0000" .. "NOT READY")
					end
				end

				C_Timer.After(
					6,
					function()
						ChallengesKeystoneFrame.readyCheckText:SetText("")
					end
				)
			end
		else
			local addonName = select(1, ...)
			if addonName == "Blizzard_ChallengesUI" then
				ExpansionUtils:UnregisterEvent(fCUI, "ADDON_LOADED")
				if ChallengesKeystoneFrame then
					local startButton = ChallengesKeystoneFrame.StartButton
					if startButton then
						local sw, sh = startButton:GetSize()
						ChallengesKeystoneFrame.readyCheck = CreateFrame("Button", "readyCheck", ChallengesKeystoneFrame, "UIPanelButtonTemplate")
						ChallengesKeystoneFrame.readyCheck:SetSize(sw, sh)
						ChallengesKeystoneFrame.readyCheck:SetPoint("RIGHT", startButton, "LEFT", -4, 0)
						ChallengesKeystoneFrame.readyCheck:SetText(READY_CHECK or "Ready Check")
						ChallengesKeystoneFrame.readyCheck:SetScript(
							"OnClick",
							function()
								lastCount = 1
								DoReadyCheck()
								if READY then
									ChallengesKeystoneFrame.readyCheckText:SetText("|cffffff00" .. lastCount .. "/" .. GetNumGroupMembers() .. " " .. READY)
								else
									ChallengesKeystoneFrame.readyCheckText:SetText("|cffffff00" .. lastCount .. "/" .. GetNumGroupMembers() .. " READY")
								end
							end
						)

						ChallengesKeystoneFrame.readyCheckText = ChallengesKeystoneFrame:CreateFontString(nil, nil, "GameFontNormal")
						ChallengesKeystoneFrame.readyCheckText:SetSize(sw, sh)
						ChallengesKeystoneFrame.readyCheckText:SetPoint("TOP", ChallengesKeystoneFrame.readyCheck, "BOTTOM", 0, 2)
						ChallengesKeystoneFrame.readyCheckText:SetText("")
						local countdowns = {10, 5, 3}
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
									elseif ExpansionUtils:IsAddOnLoaded("BigWigs") then
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
			end
		end
	end, "ExpansionUtils ChallengesUI"
)
