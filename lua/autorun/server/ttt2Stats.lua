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
	if (sql.TableExists("ttt2stats_player_deaths") == true) then
		sql.Query("DROP TABLE ttt2stats_player_deaths;")
	end
	if (sql.TableExists("ttt2stats_credit_transactions") == true) then
		sql.Query("DROP TABLE ttt2stats_credit_transactions;")
	end
end

function createTables()
	-- Create Tables in sv.db if they do not exist
	if (sql.TableExists("ttt2stats_players") == false) then
		sql.Query("CREATE TABLE ttt2stats_players (steamid TEXT PRIMARY KEY, friendly_name TEXT );")
		-- Pre-populate table with 'world' player
		sql.Query("INSERT INTO ttt2stats_players (steamid, friendly_name) VALUES ('world', 'world');")
	end
	if (sql.TableExists("ttt2stats_rounds") == false) then
		sql.Query("CREATE TABLE ttt2stats_rounds (id INTEGER PRIMARY KEY AUTOINCREMENT, map TEXT NOT NULL, start_time INTEGER NOT NULL, end_time INTEGER, ended_normally INTEGER (0, 1) DEFAULT (0), result TEXT);")
	end
	if (sql.TableExists("ttt2stats_player_round_roles") == false) then
		sql.Query("CREATE TABLE ttt2stats_player_round_roles (id INTEGER PRIMARY KEY AUTOINCREMENT, player_steamid TEXT REFERENCES ttt2stats_players (steamid), round_id INTEGER REFERENCES ttt2stats_rounds (id), player_role TEXT NOT NULL, role_assign_time INTEGER NOT NULL);")
	end
	if (sql.TableExists("ttt2stats_player_damage") == false) then
		sql.Query("CREATE TABLE ttt2stats_player_damage (id INTEGER PRIMARY KEY AUTOINCREMENT, round_id INTEGER REFERENCES ttt2stats_rounds (id), attacker_steamid TEXT REFERENCES ttt2stats_players (steamid), victim_steamid TEXT REFERENCES ttt2stats_players (steamid) NOT NULL, damage_time INTEGER NOT NULL, damage_dealt INTEGER NOT NULL, health_remain INTEGER NOT NULL, weapon TEXT);")
	end
	if (sql.TableExists("ttt2stats_player_round_karma") == false) then
		sql.Query("CREATE TABLE ttt2stats_player_round_karma (id INTEGER PRIMARY KEY AUTOINCREMENT, player_steamid INTEGER REFERENCES ttt2stats_players (steamid), round_id INTEGER REFERENCES ttt2stats_rounds (id), player_starting_karma NUMERIC, player_ending_karma NUMERIC);")
	end
	if (sql.TableExists("ttt2stats_equipment_buy") == false) then
		sql.Query("CREATE TABLE ttt2stats_equipment_buy (id INTEGER PRIMARY KEY AUTOINCREMENT, player_steamid INTEGER REFERENCES ttt2stats_players (steamid), round_id INTEGER REFERENCES ttt2stats_rounds (id), equip_class TEXT NOT NULL, equip_cost INTEGER, was_free INTEGER (0, 1) DEFAULT (0), buy_time INTEGER, credit_balance TEXT);")
	end
	if (sql.TableExists("ttt2stats_player_deaths") == false) then
		sql.Query("CREATE TABLE ttt2stats_player_deaths ( id INTEGER PRIMARY KEY AUTOINCREMENT, round_id INTEGER REFERENCES ttt2stats_rounds (id), player_steamid TEXT REFERENCES ttt2stats_players (steamid), killer TEXT NOT NULL, death_time INTEGER NOT NULL, death_cause TEXT NOT NULL, death_flags TEXT ); ")
	end
	if (sql.TableExists("ttt2stats_credit_transactions") == false) then
		sql.Query("CREATE TABLE ttt2stats_credit_transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, round_id INTEGER REFERENCES ttt2stats_rounds (id) NOT NULL, transaction_type TEXT NOT NULL, trans_time INTEGER NOT NULL, credit_amount INTEGER NOT NULL, source TEXT, destination TEXT, source_new_balance INTEGER, dest_new_balance INTEGER);")
	end
end

function dropViews()
	sql.Query("DROP VIEW IF EXISTS v_CombatLog;")
	sql.Query("DROP VIEW IF EXISTS v_GetMapPlayCount;")
	sql.Query("DROP VIEW IF EXISTS v_RoleAssignmentsWithFriendlyNames;")
end

function createViews()
	sql.Query("CREATE VIEW v_CombatLog AS SELECT damage_time, players1.friendly_name AS attacker_name, attacker_steamid, players2.friendly_name AS victim_name, victim_steamid, damage_dealt, health_remain, weapon FROM ttt2stats_player_damage dmg LEFT JOIN ttt2stats_players players1 ON players1.steamid = dmg.attacker_steamid LEFT JOIN ttt2stats_players players2 ON players2.steamid = dmg.victim_steamid ORDER BY damage_time DESC;")
	sql.Query("CREATE VIEW v_GetMapPlayCount AS SELECT map, COUNT(map) AS roundsCompletedCount, 0 AS roundsIncompleteCount FROM ttt2stats_rounds r WHERE r.ended_normally = '1' GROUP BY map UNION ALL SELECT map, 0 AS roundsCompletedCount, COUNT(map) AS roundsIncompleteCount FROM ttt2stats_rounds r2 WHERE r2.ended_normally != '1' GROUP BY map;")
	sql.Query("CREATE VIEW v_RoleAssignmentsWithFriendlyNames AS SELECT round_id, friendly_name, player_role, role_assign_time FROM ttt2stats_player_round_roles LEFT JOIN ttt2stats_players ON ttt2stats_player_round_roles.player_steamid = ttt2stats_players.steamid")
end

if SERVER then
	-- Create Debug Convar
	CreateConVar("ttt2stats_debug", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enables debug output for ttt2stats.")
	concommand.Add("ttt2stats_create_tables", function (ply, cmd, args)
		createTables()
	end)
	concommand.Add("ttt2stats_reset_tables", function(ply, cmd, args)
		dropTables()
		createTables()
	end)
	concommand.Add("ttt2stats_reset_views", function(ply, cmd, args)
		dropViews()
		createViews()
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
			-- Note: playerNickname is already surrounded w/ quotes
			sql.Query("INSERT INTO ttt2stats_players (steamid,friendly_name) VALUES (" .. sql.SQLStr(ply:SteamID64()) .. "," .. playerNickname .. ");")
		else -- If the player has already been added, update their friendly name if it has changed.
			if playerRow["friendly_name"] != playerNickname then
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
		sql.Query("INSERT INTO ttt2stats_rounds (map,start_time,ended_normally) VALUES (" .. sql.SQLStr(mapName) .. "," .. sql.SQLStr(startTime) .. ", '0');")
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
		sql.Query("UPDATE ttt2stats_rounds SET end_time = " .. sql.SQLStr(endTime) .. ", result = " .. sql.SQLStr(result) .. ", ended_normally = '1' WHERE id = " .. sql.SQLStr(roundID) .. ";")
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
		if GetConVar("ttt2stats_debug"):GetBool() then
			if roundID == -1 then
				print("DEBUG-TTT2STATS: TTT2UpdateSubrole hook called before a round has started. Skipping.")
				return
			end
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

	-- Hook that handles recording player damage and deaths.
	hook.Add("PlayerTakeDamage", "ttt2stats_playerTakeDamage", function(victimEnt, _inflEnt, _attacker, _dmgAmount, dmgInfo)
		if IsValid(victimEnt) and victimEnt:IsPlayer() then
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
			if attacker != nil and attacker:IsValid() and attacker:IsPlayer() then
				attackerSteamID = attacker:SteamID64()
				if attacker:GetActiveWeapon():IsValid() then
					weapon = attacker:GetActiveWeapon():GetClass()
				end
			end
			if inflictor:IsValid() and not inflictor:IsPlayer() then
				weapon = inflictor:GetClass()
			end
			local hurtTime = os.time()
			sql.Query("INSERT INTO ttt2stats_player_damage (round_id,attacker_steamid,victim_steamid,damage_time,damage_dealt,health_remain,weapon) VALUES (" .. sql.SQLStr(roundID) .. "," .. sql.SQLStr(attackerSteamID) .. "," .. sql.SQLStr(victimSteamID) .. "," .. sql.SQLStr(hurtTime) .. "," .. sql.SQLStr(damageTaken) .. "," .. sql.SQLStr(healthRemaining) .. "," .. sql.SQLStr(weapon) .. ");")
			-- Also insert row to ttt2_player_deaths if the player died.
			if healthRemaining <= 0 then
				local deathTime = os.time()
				-- Create table for death flags
				local deathFlags = {}
				-- Determine if player was headshot
				if victimEnt.was_headshot then
					deathFlags.headshot = true;
				end
				-- Determine if player was burned to death
				if dmgInfo:IsDamageType(DMG_BURN) or weapon == "env_fire" then
					deathFlags.burned = true;
				end
				-- Determine if player was in the air when they died
				if victimEnt:WaterLevel() == 0 and not victimEnt:IsOnGround() then
					deathFlags.airborne = true;
				end
				-- Determine if player was killed by a prop
				if dmgInfo:IsDamageType(DMG_CRUSH) then
					deathFlags.crushed = true;
				end
				-- Determine if player was blown up
				if dmgInfo:IsDamageType(DMG_BLAST) then
					deathFlags.explosion = true;
				end
				-- stringify deathFlags table
				local deathFlagsJson = ""
				if (next(deathFlags) == nil) then
					deathFlags = "{}"
				else
					deathFlagsJson = util.TableToJSON(deathFlags)
				end
				sql.Query("INSERT INTO ttt2stats_player_deaths (round_id,player_steamid,killer,death_time,death_cause,death_flags) VALUES (" .. sql.SQLStr(roundID) .. "," .. sql.SQLStr(victimSteamID) .. "," .. sql.SQLStr(attackerSteamID) .. "," .. sql.SQLStr(deathTime) .. "," .. sql.SQLStr(weapon) .. "," .. sql.SQLStr(deathFlagsJson) .. ");")
			end
		end
	end)

	-- Hook that inserts a new row into ttt2stats_equipment_buy when a player buys equipment.
	hook.Add("TTT2OrderedEquipment", "ttt2stats_orderedEquipment", function(ply, class, isItem, credits, ignoreCost)
		if GetConVar("ttt2stats_debug"):GetBool() then
			print("DEBUG-TTT2STATS: TTT2OrderedEquipment hook called for " .. ply:Nick() .. " (" .. ply:SteamID64() .. ")")
			if roundID == -1 then
				print("DEBUG-TTT2STATS: TTT2OrderedEquipment hook called before a round has started. Skipping.")
				return
			end
		end
		local steamID = ply:SteamID64()
		local buyTime = os.time()
		local playerCreditBalance = ply:GetCredits()
		local ignoreCostInt = 0
		if ignoreCost then
			ignoreCostInt = 1
		end
		sql.Query("INSERT INTO ttt2stats_equipment_buy (player_steamid,round_id,equip_class,equip_cost,was_free,buy_time,credit_balance) VALUES (" .. sql.SQLStr(steamID) .. "," .. sql.SQLStr(roundID) .. "," .. sql.SQLStr(class) .. "," .. sql.SQLStr(credits) .. "," .. sql.SQLStr(ignoreCostInt) .. "," .. sql.SQLStr(buyTime) .. "," .. sql.SQLStr(playerCreditBalance) .. ");")
		local equipBuyId = sql.QueryValue("SELECT last_insert_rowid();")
		if (not ignoreCost) then
			local queryText = "INSERT INTO ttt2stats_credit_transactions (round_id,transaction_type,trans_time,credit_amount,source,destination,source_new_balance,dest_new_balance) VALUES (" .. sql.SQLStr(roundID) .. ",'equipment_buy'," .. sql.SQLStr(buyTime) .. "," .. sql.SQLStr(credits) .. "," .. sql.SQLStr(steamID) .. "," .. sql.SQLStr(equipBuyId) .. "," .. sql.SQLStr(playerCreditBalance) .. ",NULL);"
			--print("DEBUG-TTT2STATS: equip_buy credit transaction query text; " .. queryText)
			sql.Query(queryText);
		end
	end)

	-- Hook TTT2OnGiveFoundCredits; inserts a new row into ttt2stats_credit_transactions when a player takes credits from a corpse
	hook.Add("TTT2OnGiveFoundCredits", "ttt2stats_OnGiveFoundCredits", function(ply, rag, credits)
		if GetConVar("ttt2stats_debug"):GetBool() then
			print("TTT2OnGiveFoundCredits hook called")
			if roundID == -1 then
				print("DEBUG-TTT2STATS: TTT2OnGiveFoundCredits hook called before a round has started. Skipping.")
				return
			end
		end
		local transaction_type = "CorpseCreditsFound"
		local trans_time = os.time()
		local sourceSteamId = rag.sid64
		local destSteamId = ply:SteamID64()
		local source_new_balance = 0
		local dest_new_balance = ply:GetCredits()
		sql.Query("INSERT INTO ttt2stats_credit_transactions (round_id,transaction_type,trans_time,credit_amount,source,destination,source_new_balance,dest_new_balance) VALUES (" .. sql.SQLStr(roundID) .. "," .. sql.SQLStr(transaction_type) .. "," .. sql.SQLStr(trans_time) .. "," .. sql.SQLStr(credits) .. "," .. sql.SQLStr(sourceSteamId) .. "," .. sql.SQLStr(destSteamId) .. "," .. sql.SQLStr(source_new_balance) .. "," .. sql.SQLStr(dest_new_balance) .. ");");
	end)

	-- Hook TTT2CanTransferCredits; inserts a new row into ttt2stats_credit_transactions when a player transfers credits to another player
	hook.Add("TTT2TransferedCredits", "ttt2stats_TTT2TransferedCredits", function(sender, recipient, credits, isRecipientDead)
		if GetConVar("ttt2stats_debug"):GetBool() then
			print("DEBUG-TTT2STATS: TTT2TransferedCredits hook called. Sender: " .. sender:Nick() .. " Recipient: " .. recipient:Nick() .. " Credits: " .. credits .. " isRecipientDead: " .. tostring(isRecipientDead))
			if roundID == -1 then
				print("DEBUG-TTT2STATS: TTT2OnGiveFoundCredits hook called before a round has started. Skipping.")
				return
			end
		end
		local transaction_type = "CreditTransfer"
		local trans_time = os.time()
		local sourceSteamId = sender:SteamID64()
		local source_new_balance = sender:GetCredits()
		local destSteamId = ""
		local dest_new_balance = 0
		if isRecipientDead then
			local rag = recipient:FindCorpse()
			if IsValid(rag) then
				destSteamId = rag.sid64
				dest_new_balance = CORPSE.GetCredits(rag, 0)
			end
		else
			destSteamId = recipient:SteamID64()
			dest_new_balance = recipient:GetCredits()
		end
		sql.Query("INSERT INTO ttt2stats_credit_transactions (round_id,transaction_type,trans_time,credit_amount,source,destination,source_new_balance,dest_new_balance) VALUES (" .. sql.SQLStr(roundID) .. "," .. sql.SQLStr(transaction_type) .. "," .. sql.SQLStr(trans_time) .. "," .. sql.SQLStr(credits) .. "," .. sql.SQLStr(sourceSteamId) .. "," .. sql.SQLStr(destSteamId) .. "," .. sql.SQLStr(source_new_balance) .. "," .. sql.SQLStr(dest_new_balance) .. ");")
	end)

	-- Hook TTT2ReceivedKillCredits; inserts a new row into ttt2stats_credit_transactions when a player receives credits for killing another player
	hook.Add("TTT2ReceivedKillCredits", "ttt2stats_TTT2ReceivedKillCredits", function(victim, attacker, creditsAmount)
		if GetConVar("ttt2stats_debug"):GetBool() then
			print("DEBUG-TTT2STATS: TTT2ReceivedKillCredits hook called.")
			if roundID == -1 then
				print("DEBUG-TTT2STATS: TTT2OnGiveFoundCredits hook called before a round has started. Skipping.")
				return
			end
		end
		local transaction_type = "KillCreditAward"
		local trans_time = os.time()
		local sourceSteamId = victim:SteamID64()
		local source_new_balance = NULL
		local destSteamId = attacker:SteamID64()
		local dest_new_balance = attacker:GetCredits()
		local queryText = "INSERT INTO ttt2stats_credit_transactions (round_id,transaction_type,trans_time,credit_amount,source,destination,source_new_balance,dest_new_balance) VALUES (" .. sql.SQLStr(roundID) .. "," .. sql.SQLStr(transaction_type) .. "," .. sql.SQLStr(trans_time) .. "," .. sql.SQLStr(creditsAmount) .. "," .. sql.SQLStr(sourceSteamId) .. "," .. sql.SQLStr(destSteamId) .. ",NULL," .. sql.SQLStr(dest_new_balance) .. ");"
		--print(creditsAmount)
		--print("DEBUG-TTT2STATS: " .. queryText)
		sql.Query(queryText)
	end)

	-- Hook TTT2ReceivedTeamAwardCredits; inserts a new row into ttt2stats_credit_transactions when a player receives credits from a team award.
	hook.Add("TTT2ReceivedTeamAwardCredits", "ttt2stats_TTT2ReceivedTeamAwardCredits", function(ply, creditsAmount)
		if GetConVar("ttt2stats_debug"):GetBool() then
			print("DEBUG-TTT2STATS: TTT2ReceivedTeamAwardCredits hook called.")
			if roundID == -1 then
				print("DEBUG-TTT2STATS: TTT2OnGiveFoundCredits hook called before a round has started. Skipping.")
				return
			end
		end
		local transaction_type = "TeamCreditAward"
		local trans_time = os.time()
		local sourceSteamId = NULL
		local source_new_balance = NULL
		local destSteamId = ply:SteamID64()
		local dest_new_balance = ply:GetCredits()
		local queryText = "INSERT INTO ttt2stats_credit_transactions (round_id,transaction_type,trans_time,credit_amount,source,destination,source_new_balance,dest_new_balance) VALUES (" .. sql.SQLStr(roundID) .. "," .. sql.SQLStr(transaction_type) .. "," .. sql.SQLStr(trans_time) .. "," .. sql.SQLStr(creditsAmount) .. ",NULL," .. sql.SQLStr(destSteamId) .. ",NULL," .. sql.SQLStr(dest_new_balance) .. ");"
		--print(queryText)
		sql.Query(queryText)
	end)

end