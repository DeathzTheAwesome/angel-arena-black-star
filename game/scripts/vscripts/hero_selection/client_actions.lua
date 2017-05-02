function HeroSelection:OnHeroSelectHero(data)
	local hero = tostring(data.hero)
	local playerID = data.PlayerID
	if HeroSelection:GetState() == HERO_SELECTION_PHASE_BANNING and not PLAYER_DATA[playerID].HeroSelectionBanned and NPC_HEROES_CUSTOM[hero] and NPC_HEROES_CUSTOM[hero].Enabled ~= 0 then
		HeroSelection:NominateHeroForBan(playerID, data.hero)
	elseif HeroSelection:GetState() == HERO_SELECTION_PHASE_HERO_PICK and not HeroSelection:IsHeroSelected(hero) and not HeroSelection:IsHeroBanned(hero) and HeroSelection:VerifyHeroGroup(hero) then
		local linked = GetKeyValue(hero, "LinkedHero")
		local newStatus = "picked"
		if linked then
			local team = PlayerResource:GetTeam(playerID)
			linked = string.split(linked, " | ")
			local selected = HeroSelection:GetLinkedHeroLockedAlly(hero, team)
			if selected == playerID then
				newStatus = "hover"
			elseif selected then
				return
			else
				newStatus = "locked"
			end
			local areLinkedPicked = true
			local linkedMap = {}
			for _,v in ipairs(linked) do
				linkedMap[v] = HeroSelection:GetLinkedHeroLockedAlly(v, team)
				if linkedMap[v] == nil then
					areLinkedPicked = false
					break
				end
			end
			if areLinkedPicked then
				for hero, heroplayer in ipairs(linkedMap) do
					HeroSelection:UpdateStatusForPlayer(heroplayer, "picked", hero)
				end
				for team,teamdata in pairs(PlayerTables:GetAllTableValuesForReadOnly("hero_selection")) do
					for plyId,playerStatus in pairs(teamdata) do
						if (table.contains(linked, playerStatus.hero) or hero == playerStatus.hero) and playerStatus.status == "locked" then
							HeroSelection:UpdateStatusForPlayer(plyId, "hover")
						end
					end
				end
				newStatus = "picked"
			end
		end
		if HeroSelection:UpdateStatusForPlayer(playerID, newStatus, hero, true) and newStatus == "picked" then
			PrecacheUnitByNameAsync(GetKeyValue(hero, "base_hero") or hero, function() end, playerID)
			Gold:ModifyGold(playerID, CUSTOM_STARTING_GOLD)
			HeroSelection:CheckEndHeroSelection()
		end
	end
end

function HeroSelection:OnHeroHover(data)
	if HeroSelection:GetState() == HERO_SELECTION_PHASE_HERO_PICK then
		HeroSelection:UpdateStatusForPlayer(data.PlayerID, "hover", tostring(data.hero), true)
	end
end

function HeroSelection:OnHeroRandomHero(data)
	local team = PlayerResource:GetTeam(data.PlayerID)
	if HeroSelection:GetState() == HERO_SELECTION_PHASE_HERO_PICK and HeroSelection:GetPlayerStatus(data.PlayerID).status ~= "picked" then
		HeroSelection:PreformPlayerRandom(data.PlayerID)
	end
	HeroSelection:CheckEndHeroSelection()
end

function HeroSelection:OnHeroRepick(data)
	if HeroSelection:GetState() == HERO_SELECTION_PHASE_HERO_PICK and not PLAYER_DATA[data.PlayerID].HeroSelectionRepicked then
		PLAYER_DATA[data.PlayerID].HeroSelectionRepicked = true
		HeroSelection:UpdateStatusForPlayer(data.PlayerID, "hover", tostring(data.hero))
		PLAYER_DATA[data.PlayerID].SavedGold = -CUSTOM_GOLD_REPICK_COST
	end
end

function HeroSelection:OnMinimapSetSpawnbox(data)
	local team = PlayerResource:GetTeam(data.PlayerID)

	local tableData = PlayerTables:GetTableValue("hero_selection", PlayerResource:GetTeam(data.PlayerID))
	if HeroSelection:GetState() < HERO_SELECTION_PHASE_END then
		local SpawnBoxes = tableData[data.PlayerID].SpawnBoxes or {}
		local nd = (data.team or 2) .. "_" .. (data.level or 1) .. "_" .. (data.index or 0)
		if not table.contains(SpawnBoxes, nd) then
			if #SpawnBoxes >= MAX_SPAWNBOXES_SELECTED then
				table.remove(SpawnBoxes, 1)
			end
			table.insert(SpawnBoxes, nd)
		else
			table.removeByValue(SpawnBoxes, nd)
		end
		tableData[data.PlayerID].SpawnBoxes = SpawnBoxes
	end
	PlayerTables:SetTableValue("hero_selection", PlayerResource:GetTeam(data.PlayerID), tableData)
end