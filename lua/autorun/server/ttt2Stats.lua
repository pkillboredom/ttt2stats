--Uncomment if switching to mysql, will need for mysql connection
--include("ttt2stats/config.lua")

function dropTables()
	-- Drop Tables in sv.db if they exist
	if (sql.TableExists("ttt2stats_players") == true) then
		sql.Query("DROP TABLE ttt2stats_players;")
	end
	if (sql.TableExists("ttt2stats_rounds") == true) then
		sql.Query("DROP TABLE ttt2stats_rounds;")
	end
	if (sql.TableExists("ttt2stats_player_round_roles") == true) then
		sql.Query("DROP TABLE ttt2stats_player_round_roles;")
	end
	if (sql.TableExists("ttt2stats_player_round_karma") == true) then
		sql.Query("DROP TABLE ttt2stats_player_round_karma;")
	end
	if (sql.TableExists("ttt2stats_player_damage") == true) then
		sql.Query("DROP TABLE ttt2stats_player_damage;")
	end
	if (sql.TableExists("ttt2stats_equipment_buy") == true) then
		sql.Query("DROP TABLE ttt2stats_equipment_buy;")
	end
end

function createTables()
	-- Create Tables in sv.db if they do not exist
	if (sql.TableExists("ttt2stats_players") == false) then
		sql.Query("CREATE TABLE ttt2stats_players (steamid TEXT PRIMARY KEY, friendly_name TEXT );")
		-- Pre-populate table with 'world' player
		sql.Query("INSERT INTO ttt2stats_players (steamid, friendly_name) VALUES ('world', 'world');")
	end
	sql.Query("CREATE TABLE ttt2stats_rounds (id INTEGER PRIMARY KEY AUTOINCREMENT, map TEXT NOT NULL, start_time INTEGER NOT NULL, end_time INTEGER, ended_normally INTEGER (0, 1) DEFAULT (0), result TEXT);")
	sql.Query("CREATE TABLE ttt2stats_player_round_roles (id INTEGER PRIMARY KEY AUTOINCREMENT, player_steamid TEXT REFERENCES ttt2stats_players (steamid), round_id INTEGER REFERENCES ttt2stats_rounds (id), player_role TEXT NOT NULL, role_assign_time INTEGER NOT NULL);")
	sql.Query("CREATE TABLE ttt2stats_player_damage (id INTEGER PRIMARY KEY AUTOINCREMENT, round_id INTEGER REFERENCES ttt2stats_rounds (id), attacker_steamid TEXT REFERENCES ttt2stats_players (steamid), victim_steamid TEXT REFERENCES ttt2stats_players (steamid) NOT NULL, damage_time INTEGER NOT NULL, damage_dealt INTEGER NOT NULL, health_remain INTEGER NOT NULL, weapon TEXT);")
	sql.Query("CREATE TABLE ttt2stats_player_round_karma (id INTEGER PRIMARY KEY AUTOINCREMENT, player_steamid INTEGER REFERENCES ttt2stats_players (steamid), round_id INTEGER REFERENCES ttt2stats_rounds (id), player_starting_karma NUMERIC, player_ending_karma NUMERIC);")
	sql.Query("CREATE TABLE ttt2stats_equipment_buy (id INTEGER PRIMARY KEY AUTOINCREMENT, player_steamid INTEGER REFERENCES ttt2stats_players (steamid), round_id INTEGER REFERENCES ttt2stats_rounds (id), equip_class TEXT NOT NULL, equip_cost INTEGER, was_free INTEGER (0, 1) DEFAULT (0), buy_time INTEGER);")
end

if SERVER then
	-- Create Debug Convar
	CreateConVar("ttt2stats_debug", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enables debug output for ttt2stats.")
	concommand.Add("ttt2stats_reset_tables", function(ply, cmd, args)
		dropTables()
		createTables()
	end)

	local roundID = -1 -- This is a placeholder value that will be overwritten when a round starts.
	
	-- Hook that inserts a new player row into ttt2stats_players when a player joins the server IF they haven't already been added.
	hook.Add("PlayerInitialSpawn", "ttt2stats_playerInitialSpawn", function(ply)
		local playerNickname = sql.SQLStr(ply:Nick())
		if GetConVar("ttt2stats_debug"):GetBool() then
			print("DEBUG-TTT2STATS: PlayerInitialSpawn hook called for " .. playerNickname .. " (" .. ply:SteamID64() .. ")")
		end
		local playerRow = sql.QueryRow("SELECT * FROM ttt2stats_players WHERE steamid = " .. sql.SQLStr(ply:SteamID64()) .. ";")
		if playerRow == nil or playerRow == false then
			if GetConVar("ttt2stats_debug"):GetBool() then
				print("DEBUG-TTT2STATS: Player " .. playerNickname .. " (" .. sql.SQLStr(ply:SteamID64()) .. ") not found in ttt2stats_players. Adding them.")
			end
			// Note: playerNickname is already surrounded w/ quotes
			sql.Query("INSERT INTO ttt2stats_players (steamid,friendly_name) VALUES (" .. sql.SQLStr(ply:SteamID64()) .. "," .. playerNickname .. ");")
		else -- If the player has already been added, update their friendly name if it has changed.
			if playerRow["friendly_name"] ~= playerNickname then
				sql.Query("UPDATE ttt2stats_players SET friendly_name = " .. playerNickname .. " WHERE steamid = " .. sql.SQLStr(ply:SteamID64()) .. ";")
			end
		end
	end)
	
	-- Hook that inserts a new row into ttt2stats_rounds when a round starts. The hook keeps the id of the round in the roundID variable.
	hook.Add("TTTBeginRound", "ttt2stats_tttbeginround", function()
		if GetConVar("ttt2stats_debug"):GetBool() then 
			print("DEBUG-TTT2STATS: TTTBeginRound hook called.")
		end
		local mapName = game.GetMap()
		local startTime = os.time()
		-- Insert a new row into ttt2stats_rounds for this round. Default value for ended_normally is 0.
		sql.Query("INSERT INTO ttt2stats_rounds (map,start_time,ended_normally) VALUES (" .. sql.SQLStr(mapName) .."," .. sql.SQLStr(startTime) .. ", '0');")
		roundID = sql.QueryValue("SELECT last_insert_rowid();")
		if GetConVar("ttt2stats_debug"):GetBool() then 
			print("DEBUG-TTT2STATS: Round ID is " .. roundID .. ".")
		end
		-- Get all players who will participate in this round
		local allPlayers = player.GetAll()
		local activePlayers = {}
		for i = 1, #allPlayers do
			if allPlayers[i]:WasActiveInRound() then
				table.insert(activePlayers, allPlayers[i])
			end
		end
		-- Insert a row into ttt2stats_player_round_karma for each player who will participate in this round
		for i = 1, #activePlayers do
			local playerSteamID = activePlayers[i]:SteamID64()
			local playerKarma = activePlayers[i]:GetBaseKarma()
			sql.Query("INSERT INTO ttt2stats_player_round_karma (player_steamid, round_id, player_starting_karma) VALUES (" .. sql.SQLStr(playerSteamID) .. ", " .. sql.SQLStr(roundID) .. ", " .. sql.SQLStr(playerKarma) .. ");")
		end
		-- Insert a row into ttt2stats_player_round_roles for each player who will participate in this round
		for i = 1, #activePlayers do
			local playerSteamID = activePlayers[i]:SteamID64()
			local playerRole = activePlayers[i]:GetRole()
			local roleAssignTime = os.time()
			sql.Query("INSERT INTO ttt2stats_player_round_roles (player_steamid, round_id, player_role, role_assign_time) VALUES (" .. sql.SQLStr(playerSteamID) .. ", " .. sql.SQLStr(roundID) .. ", " .. sql.SQLStr(playerRole) .. ", " .. sql.SQLStr(roleAssignTime) .. ");")
		end
	end)
	
	-- Hook that updates the end_time and ended_normally columns of the round row in ttt2stats_rounds when a round ends.
	hook.Add("TTTEndRound", "ttt2stats_tttendround", function(result)
		if GetConVar("ttt2stats_debug"):GetBool() then 
			print("DEBUG-TTT2STATS: TTTEndRound hook called.")
		end
		local endTime = os.time()
		sql.Query("UPDATE ttt2stats_rounds SET end_time = " .. sql.SQLStr(endTime) .. ", result = " .. sql.SQLStr(result) .. " ended_normally = '1' WHERE id = " .. sql.SQLStr(roundID) .. ";")
		-- Get all players who participated in this round
		local allPlayers = player.GetAll()
		local activePlayers = {}
		for i = 1, #allPlayers do
			if allPlayers[i]:WasActiveInRound() then
				table.insert(activePlayers, allPlayers[i])
			end
		end
		-- Update the ending karma of each player who participated in this round
		for i = 1, #activePlayers do
			local playerSteamID = activePlayers[i]:SteamID64()
			local playerKarma = activePlayers[i]:GetLiveKarma()
			sql.Query("UPDATE ttt2stats_player_round_karma SET player_ending_karma = " .. sql.SQLStr(playerKarma) .. " WHERE player_steamid = " .. sql.SQLStr(playerSteamID) .. " AND round_id = " .. sql.SQLStr(roundID) .. ";")
		end

		-- Lastly, set roundID back to -1 so that it is ready for the next round.
		roundID = -1
	end)
	
	-- Hook that inserts a new row into ttt2stats_player_round_roles when a player is assigned a role.
	-- Because TTT2UpdateSubrole is called before the round starts, this only applies to any mid-round role changes.
	hook.Add("TTT2UpdateSubrole", "ttt2stats_ttt2updaterole", function(ply, oldSubrole, newSubrole)
		if roundID == -1 then
			if GetConVar("ttt2stats_debug"):GetBool() then 
				print("DEBUG-TTT2STATS: TTT2UpdateSubrole hook called before a round has started. Skipping.")
			end
			return
		end
		local playerNickname = sql.SQLStr(ply:Nick())
		if GetConVar("ttt2stats_debug"):GetBool() then 
			print("DEBUG-TTT2STATS: TTT2UpdateSubrole hook called for " .. playerNickname .. " (" .. ply:SteamID64() .. ")")
		end
		local steamID = ply:SteamID64()
		local assignTime = os.time()
		local newRole = roles.GetByIndex(newSubrole).name
		sql.Query("INSERT INTO ttt2stats_player_round_roles (player_steamid,round_id,player_role,role_assign_time) VALUES (" .. sql.SQLStr(steamID) .. "," .. sql.SQLStr(roundID) .. "," .. sql.SQLStr(newRole) .. "," .. sql.SQLStr(assignTime) .. ");")
	end)
	
	-- Hook that inserts a new row into ttt2stats_player_damage when any damage is taken.
	hook.Add("PlayerTakeDamage", "ttt2stats_playerTakeDamage", function(victimEnt, _inflEnt, _attacker, _dmgAmount, dmgInfo)
		if victimEnt:IsPlayer() then
			local victimNickname = sql.SQLStr(victimEnt:Nick())
			if GetConVar("ttt2stats_debug"):GetBool() then 
				print("DEBUG-TTT2STATS: PlayerHurt hook called for " .. victimNickname .. " (" .. victimEnt:SteamID64() .. ")")
			end
			local victimSteamID = victimEnt:SteamID64()
			local damageTaken = dmgInfo:GetDamage()
			local healthRemaining = victimEnt:Health() - damageTaken
			local attacker = dmgInfo:GetAttacker()
			local inflictor = dmgInfo:GetInflictor()
			local attackerSteamID = "world"
			local weapon = "world"
			if attacker != nil then 
				if attacker:IsPlayer() then
					attackerSteamID = attacker:SteamID64()
					weapon = attacker:GetActiveWeapon():GetClass()
				end
			end
			if inflictor:IsValid() and not inflictor:IsPlayer() then
				weapon = inflEnt:GetClass()
			elseif dmgInfo:IsDamageType(DMG_BURN) then
				weapon = "fire"
			elseif dmgInfo:IsDamageType(DMG_FALL) then
				weapon = "fall"
			elseif dmgInfo:IsDamageType(DMG_VEHICLE) then
				weapon = "vehicle"
			elseif dmgInfo:IsDamageType(DMG_SLASH) then
				weapon = "slash"
			elseif dmgInfo:IsDamageType(DMG_CRUSH) then
				weapon = "physics"
			elseif dmgInfo:IsDamageType(DMG_BLAST) then
				weapon = "explosion"
			end
			local hurtTime = os.time()
			sql.Query("INSERT INTO ttt2stats_player_damage (round_id,attacker_steamid,victim_steamid,damage_time,damage_dealt,health_remain,weapon) VALUES (" .. sql.SQLStr(roundID) .. "," .. sql.SQLStr(attackerSteamID) .. "," .. sql.SQLStr(victimSteamID) .. "," .. sql.SQLStr(hurtTime) .. "," .. sql.SQLStr(damageTaken) .. "," .. sql.SQLStr(healthRemaining) .. "," .. sql.SQLStr(weapon) ..");")
		end
	end)

	-- Hook that inserts a new row into ttt2stats_equipment_buy when a player buys equipment.
	hook.Add("TTT2OrderedEquipment", "ttt2stats_orderedEquipment", function(ply, class, isItem, credits, ignoreCost)
		if roundID == -1 then
			if GetConVar("ttt2stats_debug"):GetBool() then 
				print("DEBUG-TTT2STATS: TTT2OrderedEquipment hook called before a round has started. Skipping.")
			end
			return
		end
		local steamID = ply:SteamID64()
		local buyTime = os.time()
		local ignoreCostInt = 0
		if ignoreCost then
			ignoreCostInt = 1
		end
		sql.Query("INSERT INTO ttt2stats_equipment_buy (player_steamid,round_id,equip_class,equip_cost,was_free,buy_time) VALUES (" .. sql.SQLStr(steamID) .. "," .. sql.SQLStr(roundID) .. "," .. sql.SQLStr(class) .. "," .. sql.SQLStr(credits) .. "," .. sql.SQLStr(ignoreCostInt) .. "," .. sql.SQLStr(buyTime) .. ");")
	end)
end