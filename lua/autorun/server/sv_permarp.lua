-- PermaRP (c) spycrab0 2017
-- Serverside script
if CLIENT then return end

just_joined = {}

function set_door_lock(door,locked)
   door:SetSaveValue("m_bLocked",locked)
end

-- DB Helper
function db_do(query,fnc)
   MySQLite.query(query,
                   fnc,
                   function(result)
                      error("MySQLite error occured on query '"..query.."': "..result, 2)
                   end
   )
end

function db_write_locked(door,locked)
      db_do(
      string.format([[
UPDATE permarp_door_owners
SET locked = %s
WHERE id = %s AND map = %s;
]],
         MySQLite.SQLStr(locked),
         MySQLite.SQLStr(door:doorIndex()),
         MySQLite.SQLStr(string.lower(game.GetMap()))
      ))
end

---- Hook handlers
function permarp_load()
   print("Loading PermaRP data...")
   db_parse()
end

function permarp_door_bought(ply,door)
   print(tostring(ply:SteamID64())..' bought a door with the ID '..tostring(door:doorIndex()))
   db_do(
      string.format(
         [[REPLACE INTO permarp_door_owners VALUES(%s,%s,%s,%s,%s)]],
         MySQLite.SQLStr(door:doorIndex()),
         MySQLite.SQLStr(string.lower(game.GetMap())),
         MySQLite.SQLStr(ply:SteamID64()),
         MySQLite.SQLStr(ply:GetName()),
         MySQLite.SQLStr(false)))
   return true
end

function permarp_door_sold(ply,door)
   print(tostring(ply:SteamID64())..' sold a door with the ID '..tostring(door:doorIndex()))
   db_do(
      string.format([[
DELETE FROM permarp_door_owners
WHERE id = %s AND map = %s;]],
         MySQLite.SQLStr(door:doorIndex()),
         MySQLite.SQLStr(string.lower(game.GetMap())))
   )
end

function permarp_player_name_update(ply)
   db_do(
      string.format([[
UPDATE permarp_door_owners
SET user_name = %s
WHERE user_id = %s;
]],
         MySQLite.SQLStr(ply:GetName()),
         MySQLite.SQLStr(ply:SteamID64())
   ))
end

function permarp_player_join(ply)
   permarp_player_name_update(ply)
   just_joined[ply:SteamID64()] = true;

   db_do(
      string.format([[
SELECT id, locked
FROM permarp_door_owners
WHERE user_id = %s;
]],
         MySQLite.SQLStr(ply:SteamID64())),
      function(r)
         if not r then return end
         for _, row in pairs(r) do
            local e = DarkRP.doorIndexToEnt(tonumber(row.id))
            if not IsValid(e) then continue end
            e:setKeysTitle("")
            e:setKeysNonOwnable(false)
            e:getDoorData().allowedToOwn = {}
            e:getDoorData().allowedToOwn[ply:UserID()] = true
            DarkRP.updateDoorData(e,"allowedToOwn")
            e:SetVar("user_id",tostring(ply:SteamID64()))
            e:keysOwn(ply)            
            set_door_lock(e,row.locked == "true")
         end
      end
   )
end

function permarp_door_locked(door)
   db_write_locked(door,true)
end

function permarp_door_unlocked(door)
   db_write_locked(door,false)
end

function permarp_player_position_update(ply)
   if not ply:Alive() or (not ply:IsOnGround() and not ply:InVehicle()) then return end
   db_do(
      string.format([[
REPLACE INTO permarp_player_positions
VALUES(%s,%s,%s,%s,%s,%s)
]],
         MySQLite.SQLStr(ply:SteamID64()),
         MySQLite.SQLStr(ply:GetName()),
         MySQLite.SQLStr(string.lower(game.GetMap())),
         MySQLite.SQLStr(tostring(ply:GetPos().x)),
         MySQLite.SQLStr(tostring(ply:GetPos().y)),
         MySQLite.SQLStr(tostring(ply:GetPos().z)))
   )
end

function permarp_player_leave(ply)
   permarp_player_name_update(ply)
   permarp_player_position_update(ply)
   db_do(
      string.format([[
SELECT *
FROM permarp_door_owners
WHERE user_id = %s AND map = %s;
]],
         MySQLite.SQLStr(ply:SteamID64()),
         MySQLite.SQLStr(string.lower(game.GetMap()))),
      function(r)
         if not r then return end
         for _, row in pairs(r) do
            local e = DarkRP.doorIndexToEnt(tonumber(row.id))
            if not IsValid(e) then continue end
            e:setKeysNonOwnable(true)
            e:setKeysTitle("Owned by:\n"..row.user_name.."\n(Steam ID: "..tostring(row.user_id)..")")
            e:SetVar("user_id",tostring(ply:SteamID64()))

            timer.Create("permarp_player_leave_lock_door_"..tostring(row.id),1,1,
                         function()
                            set_door_lock(e,row.locked == "true")
                         end
            )
         end
      end
   )
end

-- Parse database contents
function db_parse()
   db_do(
      string.format([[
SELECT *
FROM permarp_door_owners
WHERE map = %s;]],
         MySQLite.SQLStr(string.lower(game.GetMap()))),
      function(r)
         if not r then return end
         for _, row in pairs(r) do
            local e = DarkRP.doorIndexToEnt(tonumber(row.id))
            if not IsValid(e) then continue end
            e:getDoorData().nonOwnable = true
            e:getDoorData().title = "Owned by:\n "..row.user_name.."\n(Steam ID: "..tostring(row.user_id)..")"
            DarkRP.updateDoorData(e,"title")
            DarkRP.updateDoorData(e,"nonOwnable")
            
            e:SetVar("user_id",row.user_id)
            set_door_lock(e,row.locked == "true")
         end
      end
   )
end

-- Check whether a table exists or not, if not call db_init()
function table_check(name)
   MySQLite.tableExists(
      name,
      function(exists)
         if exists then
            print(name..": present")
         else
            print(name..": missing")
            db_init()
         end
      end
   )                           
end

-- Initialize database
function db_init()
   print ("Initializing database...")
   db_do([[
CREATE TABLE IF NOT EXISTS permarp_door_owners(
id INTEGER NOT NULL, 
map VARCHAR(45) NOT NULL, 
user_id BIGINT NOT NULL,
user_name VARCHAR(64) NOT NULL,
locked BOOL NOT NULL,
PRIMARY KEY(id,map));

CREATE TABLE IF NOT EXISTS permarp_player_positions(
user_id BIGINT NOT NULL,
user_name VARCHAR(64) NOT NULL,
map VARCHAR(45) NOT NULL,
posx FLOAT NOT NULL,
posy FLOAT NOT NULL,
posz FLOAT NOT NULL,
PRIMARY KEY(user_id,map));
]])
end

-- Check database
function db_check()
   table_check("permarp_door_owners")
   table_check("permarp_player_positions")
end

function permarp_player_spawn(ply)
   if not just_joined[ply:SteamID64()] then return end
   db_do(
      string.format([[
SELECT posx, posy, posz
FROM permarp_player_positions
WHERE user_id = %s AND map = %s
]],
         MySQLite.SQLStr(ply:SteamID64()),
         MySQLite.SQLStr(string.lower(game.GetMap()))),
      function (r)
         if not r then return end
         for _, row in pairs(r) do
            timer.Create("permarp_spawn_timer", 0, 1,
                         function()
                            ply:SetPos(Vector(row.posx,row.posy,row.posz))
                         end
            )
         end
      end
   )
   just_joined[ply:SteamID64()] = false
end

hook.Add("OnGamemodeLoaded","permarp_gamemode_serverhook",
         function()
            if GAMEMODE.Name != "DarkRP" then return end

            -- db_do("DROP TABLE permarp_door_owners")
            db_check()            
            print("PermaRP Serverside loaded")
            hook.Add("InitPostEntity","permarp_load",permarp_load)
            hook.Add("playerBoughtDoor","permarp_door_bouglht",permarp_door_bought)
            hook.Add("playerKeysSold","permarp_door_sold",permarp_door_sold)
            hook.Add("onKeysLocked","permarp_door_locked",permarp_door_locked)
            hook.Add("onKeysUnlocked","permarp_door_locked",permarp_door_unlocked)           
            hook.Add("PlayerInitialSpawn","permarp_player_join",permarp_player_join)
            hook.Add("PlayerDisconnected","permarp_player_disconnected",permarp_player_leave)
            hook.Add("PlayerSpawn","permarp_player_spawn",permarp_player_spawn)
         end
)
