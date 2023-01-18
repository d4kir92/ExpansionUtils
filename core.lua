
local EVVersion = 23
local EVLatest = nil
local EVLoaded = false

EVBUILD = "CLASSIC"
if select(4, GetBuildInfo()) >= 100000 then
	EVBUILD = "RETAIL"
elseif select(4, GetBuildInfo()) > 29999 then
	EVBUILD = "WRATH"
elseif select(4, GetBuildInfo()) > 19999 then
	EVBUILD = "TBC"
end


local function EVOnEvent(self, event, ...)
	if GEVVersion == nil then
		GEVVersion = 0
	end

	if EVVersion > GEVVersion then
		GEVVersion = EVVersion
		EVLatest = true
	elseif EVVersion < GEVVersion then
		EVLatest = false
	end

	if event == "PLAYER_ENTERING_WORLD" and not EVLoaded then
		if EVLatest then
			EVLoaded = true

			function DBNameByUnit(unit)
				if UnitExists(unit) and UnitIsPlayer(unit) then
					local name, realm = UnitName(unit)
					if realm and realm ~= "" then
						name = name .. "-" .. realm
					else
						name = name .. "-" .. GetRealmName()
					end
					return name
				else
					return ""
				end
			end

			if EVTAB == nil then
				EVTAB = {}
			end

			if MAITAB then
				EVTAB = MAITAB
			elseif MIPO then
				EVTAB = MIPO
			elseif HPTAB then
				EVTAB = HPTAB
			elseif THTAB then
				EVTAB = THTAB
			elseif DRFTAB then
				EVTAB = DRFTAB
			elseif LOCTAB then
				EVTAB = LOCTAB
			end

			-- "GLOBALS"
			function EVSameFaction(unit)
				if unit == nil then return false end
				return UnitFactionGroup(unit) == UnitFactionGroup("PLAYER")
			end



			if EVTAB.ILVL == nil then
				EVTAB.ILVL = {}
			end
	
			-- ITEM LEVEL
			if GetAverageItemLevel then
				local ilvlqueue = {}

				function UnitILvl(unit)
					local ilvl = 0

					if UnitIsPlayer(unit) and UnitIsConnected(unit) then
						if GetInspectInfo and GetInspectInfo(unit) then -- TINYINSPECT
							local tab = GetInspectInfo(unit)
							if tab.ilevel and tab.ilevel > 0 and tab.ilevel ~= EVTAB.ILVL[DBNameByUnit(unit)] then
								EVTAB.ILVL[DBNameByUnit(unit)] = tab.ilevel
							end
						end

						if EVTAB.ILVL[DBNameByUnit(unit)] then
							ilvl = EVTAB.ILVL[DBNameByUnit(unit)]
						elseif EVLoaded and UnitExists(unit) then
							local name = DBNameByUnit(unit)
							if not tContains(ilvlqueue, name) then
								tinsert(ilvlqueue, name)

								if EVSameFaction(unit) then
									C_ChatInfo.SendAddonMessage("EVILvl", "ASK" .. "," .. DBNameByUnit(unit), "WHISPER", name)
								end
							end
						end
					end
					return ilvl
				end
		
				function EVSendILvl()
					local overall, equipped = GetAverageItemLevel()
					local prefix = "EVILvl"
					data = "RECEIVE" .. "," .. equipped .. "," .. DBNameByUnit("PLAYER")

					if IsInRaid(LE_PARTY_CATEGORY_HOME) then
						C_ChatInfo.SendAddonMessage(prefix, data, "RAID")
					elseif IsInRaid(LE_PARTY_CATEGORY_INSTANCE) or IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
						C_ChatInfo.SendAddonMessage(prefix, data, "INSTANCE_CHAT")
					elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
						C_ChatInfo.SendAddonMessage(prefix, data, "PARTY")
					end
				end
				
				local EVILvlAntiSpam = {}
				C_ChatInfo.RegisterAddonMessagePrefix("EVILvl")
				local function ILvlOnEvent(self, event, prefix, ...)                    
					if event == "CHAT_MSG_ADDON" then
						if prefix == "EVILvl" then
							local msg, channel, name = ...
							local art, t2, t3 = strsplit(",", msg)
							if art == "RECEIVE" then
								ilvl = t2
								guid = t3
								EVTAB.ILVL[guid] = tonumber(ilvl)
							elseif art == "ASK" then
								local guid = t2
								if not EVILvlAntiSpam[name] then
									EVILvlAntiSpam[name] = true

									C_ChatInfo.SendAddonMessage("EVILvl", "RECEIVE" .. "," .. UnitILvl("PLAYER") .. "," .. DBNameByUnit("PLAYER"), channel, name)

									C_Timer.After(1, function()
										EVILvlAntiSpam[name] = false
									end)
								end
							end
						end
					elseif event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
						EVSendILvl()
					end
				end
				local fILvl = CreateFrame("Frame")
				fILvl:RegisterEvent("CHAT_MSG_ADDON")
				fILvl:RegisterEvent("PLAYER_ENTERING_WORLD")
				fILvl:RegisterEvent("GROUP_ROSTER_UPDATE")
				fILvl:SetScript("OnEvent", ILvlOnEvent)
		
				function EVILvlThink()
					local overall, equipped = GetAverageItemLevel()
		
					if equipped ~= EVTAB.ILVL[DBNameByUnit("PLAYER")] then
						EVTAB.ILVL[DBNameByUnit("PLAYER")] = equipped
				
						EVSendILvl()
					end
		
					C_Timer.After(1, EVILvlThink)
				end
		
				function EVSetupILvl()
					EVILvlThink()
				end
				EVSetupILvl()
				
				if EVTAB["cg"] == nil then
					EVTAB["cg"] = true
				end

				SLASH_CG1 = "/cg"
				SLASH_CG2 = "/checkgear"
				SlashCmdList["CG"] = function(msg)
					if msg == "0" then
						EVTAB["cg"] = false
						print("|cFFFF6060" .. "CheckGear turned OFF")
					elseif msg == "1" then
						EVTAB["cg"] = true
						print("|cFF60FF60" .. "CheckGear turned ON")
					else
						if EVTAB["cg"] then
							print("|cFF60FF60" .. "CheckGear is ON")
						else
							print("|cFF60FF60" .. "CheckGear is OFF")
						end
					end
				end 

				if EVTAB["ilvl"] == nil then
					EVTAB["ilvl"] = true
				end

				SLASH_ILVL1 = "/ilvl"
				SLASH_ILVL2 = "/itemlevel"
				SlashCmdList["ILVL"] = function(msg)
					if msg == "0" then
						EVTAB["ilvl"] = false
						print("|cFFFF6060" .. "ItemLevel turned OFF")
					elseif msg == "1" then
						EVTAB["ilvl"] = true
						print("|cFF60FF60" .. "ItemLevel turned ON")
					else
						if EVTAB["ilvl"] then
							print("|cFF60FF60" .. "ItemLevel is ON")
						else
							print("|cFF60FF60" .. "ItemLevel is OFF")
						end
					end
				end 

				SLASH_EV1 = "/ev"
				SLASH_EV2 = "/extendedvariables"
				SlashCmdList["EV"] = function(msg)
					print("|cFF60FF60" .. "----- ----- ----- ----- -----")
					print("|cFF60FF60" .. "[EV] Extended Variables")
					if EVTAB["cg"] then
						print("|cFF60FF60" .. "• CheckGear is ON (/cg 0: off, /cg 1: on)")
					else
						print("|cFF60FF60" .. "• CheckGear is OFF (/cg 0: off, /cg 1: on)")
					end
					if EVTAB["ilvl"] then
						print("|cFF60FF60" .. "• ItemLevel is ON (/ilvl 0: off, /ilvl 1: on)")
					else
						print("|cFF60FF60" .. "• ItemLevel is OFF (/ilvl 0: off, /ilvl 1: on)")
					end
					print("|cFF60FF60" .. "----- ----- ----- ----- -----")
				end 

				-- BLIZZARD
				local ids = {
					1, -- KOPF
					2, -- HALS
					3, -- SCHULTER
					--4, -- HEMD
					5, -- BRUST
					6, -- TAILLE
					7, -- BEINE
					8, -- FÜßE
					9, -- HANDGELENK
					10, -- HÄNDE
					11, -- RING 1
					12, -- RING 2
					13, -- SCHMUCK 1
					14, -- SCHMUCK 2
					15, -- UMHANG
					16, -- WAFFE 1
					17, -- WAFFE 2
					--18, -- ?
					--19, -- WAPPENROCK 
				}
				
				local eids = {
					5, 11, 12, 15, 16
				}
				
				function MAICheckGems(ItemLink)
					local gems = {
						"EMPTY_SOCKET_RED",
						"EMPTY_SOCKET_YELLOW",
						"EMPTY_SOCKET_BLUE",
						"EMPTY_SOCKET_META",
						"EMPTY_SOCKET_PRISMATIC"
					}
				
					local stats = GetItemStats(ItemLink)
					
					if stats then
						for i, v in pairs(gems) do
							if stats[v] then
								return true
							end
						end
					end
				
					return false
				end

				local wasbad = false
				function EVCheckGear(unit)
					local items = 0
					local ilvlsum = 0
					local worked = true

					local printtab = {}

					for i, id in pairs(ids) do
						local ItemID = GetInventoryItemID(unit, id)
						if ItemID then
							local ItemLink = GetInventoryItemLink(unit, id)
							if ItemLink then
								local test, itemid, enchant, gem1, gem2, gem3, gem4 = string.split(":", ItemLink)
								local ilvl = GetDetailedItemLevelInfo(ItemLink)
								if ilvl then
									ilvlsum = ilvlsum + ilvl
									items = items + 1
								else
									worked = false
								end

								if UnitLevel(unit) >= 60 then
									if tContains(eids, id) and enchant == "" then
										tinsert(printtab, ItemLink .. " |cFFFF0000" .. ADDON_MISSING .."|r (" .. ENCHANTS .. ")")
									end
									
									if MAICheckGems(ItemLink) and gem1 == "" then
										tinsert(printtab, ItemLink .. " |cFFFF0000" .. ADDON_MISSING .."|r (" .. AUCTION_CATEGORY_GEMS .. ")")
									end
								end
							end
						end
					end

					local ilvl = 0
					if worked and items > 0 then
						local name = DBNameByUnit(unit)
						ilvl = ilvlsum/items
						EVTAB.ILVL[name] = ilvl
					end

					if EVTAB["cg"] then
						if #printtab > 0 then
							wasbad = true
							print("|cFFFFFF00---------- ---------- ---------- ---------- ---------- ---------- ----------")
							if ilvl > 0 then
								print("|cFFFFFF00" .. BAG_FILTER_EQUIPMENT .. " " .. string.format("%.1f", ilvl) .. " (/cg 0: off, /cg 1: on)")
							else
								print("|cFFFFFF00" .. BAG_FILTER_EQUIPMENT)
							end

							for i, line in pairs(printtab) do
								print(line)
							end
							print("|cFFFFFF00---------- ---------- ---------- ---------- ---------- ---------- ----------")
						elseif wasbad then
							wasbad = false
							if ilvl > 0 then
								print("|cFF00FF00" .. BAG_FILTER_EQUIPMENT .. " " .. string.format("%.1f", ilvl) .. ": " .. GMSURVEYRATING4 )
							else
								print("|cFF00FF00" .. BAG_FILTER_EQUIPMENT .. ": " .. GMSURVEYRATING4 )
							end
						end
					end
				end
				C_Timer.After(4, function()
					EVCheckGear("PLAYER")

					local f = CreateFrame("FRAME")
					f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
					f:RegisterEvent("PLAYER_ENTERING_WORLD")
					f:SetScript("OnEvent", function(event, ...)
						EVCheckGear("PLAYER")
					end)
				end)

				-- TARGET
				local tf = _G["TargetFrameTextureFrame"]
				if tf then
					tf.text = tf:CreateFontString(nil, "ARTWORK")
					tf.text:SetPoint("CENTER", tf, "TOPRIGHT", -74, -6)
					tf.text:SetFont(STANDARD_TEXT_FONT, 8, "")
					tf.text:SetText("")
					tf.text:SetShadowOffset(1, -1)

					function EVILVLTFThink()
						local tf = _G["TargetFrameTextureFrame"]
						local ilvl = UnitILvl("TARGET")
						if EVTAB["ilvl"] then
							if tf.ilvl ~= ilvl then
								tf.ilvl = ilvl

								if ilvl > 0 then
									tf.text:SetText(string.format("%.1f", ilvl))
								else
									tf.text:SetText("")
								end
							end
						else
							tf.text:SetText("")
						end

						C_Timer.After(0.1, EVILVLTFThink)
					end
					EVILVLTFThink()
				end
			end
		end
	end
end
local fEV = CreateFrame("Frame")
fEV:RegisterEvent("PLAYER_ENTERING_WORLD")
fEV:RegisterEvent("ADDON_LOADED")
fEV:SetScript("OnEvent", EVOnEvent)
