-- PermaRP (c) spycrab0 2017
-- Serverside script
if CLIENT then return end

ignore_lock = false

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
   if ignore_lock then return end
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

   db_do(
      string.format([[
SELECT posx, posy, posz, orix, oriy, oriz
FROM permarp_player_positions
WHERE user_id = %s AND map = %s
]],
         MySQLite.SQLStr(ply:SteamID64()),
         MySQLite.SQLStr(string.lower(game.GetMap()))),
      function (r)
         if not r then return end
         for _, row in pairs(r) do
            ply:SetPos(Vector(row.posx,row.posy,row.posz))
         end
      end
   )
   
   ignore_lock = true
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
            e:getDoorData().title = ""
            e:getDoorData().nonOwnable = false
            e:getDoorData().allowedToOwn = {}
            e:getDoorData().allowedToOwn[ply:UserID()] = true
            DarkRP.updateDoorData(e,"title")
            DarkRP.updateDoorData(e,"nonOwnable")
            DarkRP.updateDoorData(e,"allowedToOwn")
            e:SetVar("user_id",tostring(ply:SteamID64()))
            e:keysOwn(ply)
            if row.locked == "true" then e:keysLock() else e:keysUnLock() end
         end
      end
   )
   ignore_lock = false
end

function permarp_door_locked(door)
   db_write_locked(door,true)
end

function permarp_door_unlocked(door)
   db_write_locked(door,false)
end

function permarp_player_position_update(ply)
   if not ply:Alive() then return end
   db_do(
      string.format([[
REPLACE INTO permarp_player_position
VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s)
]],
         MySQLite.SQLStr(ply:SteamID64()),
         MySQLite.SQLStr(ply:GetName()),
         MySQLite.SQLStr(string.lower(game.GetMap())),
         MySQLite.SQLStr(tostring(ply:GetPos().x)),
         MySQLite.SQLStr(tostring(ply:GetPos().y)),
         MySQLite.SQLStr(tostring(ply:GetPos().z)),
         MySQLite.SQLStr(0),
         MySQLite.SQLStr(0),
         MySQLite.SQLStr(0)))
end

function permarp_player_leave(ply)
   permarp_player_name_update(ply)
   permarp_player_position_update(ply)
   ignore_lock = true
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
            e:getDoorData().nonOwnable = true
            e:getDoorData().title = "Owned by:\n"..row.user_name.."\n(Steam ID: "..tostring(row.user_id)..")"
            DarkRP.updateDoorData(e,"title")
            DarkRP.updateDoorData(e,"nonOwnable")
            e:SetVar("user_id",tostring(ply:SteamID64()))
            if row.locked == "true" then e:keysLock() else e:keysUnLock() end
         end
      end
   )
   ignore_lock = false
end

-- Parse database contents
function db_parse()
   ignore_lock = true
   db_do(
      string.format([[
SELECT *
FROM permarp_door_owners
WHERE map = %s;]],MySQLite.SQLStr(string.lower(game.GetMap()))),
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
            if row.locked == "true" then e:keysLock() else e:keysUnLock() end
         end
      end
   )
   ignore_lock = false
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
orix FLOAT NOT NULL,
oriy FLOAT NOT NULL,
oriz FLOAT NOT NULL,
PRIMARY KEY(user_id,map));
]])
end

-- Check database
function db_check()
   table_check("permarp_door_owners")
   table_check("permarp_player_positions")
end

function db_check_data_valid()
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
            valid = true
            
            if not IsValid(e) then
               print("Bad entry: Not a valid entity")
               valid = false
            else
               if e:getKeysNonOwnable() then
                  if (e:getDoorData().title != "Owned by:\n"..row.user_name.."\n(Steam ID: "..tostring(row.user_id)..")") then
                     print("Bad entry: Bad title for offline player door")
                     valid = false
                  elseif (tostring(e:getDoorOwner().SteamID64()) != e:GetVar("user_id","0")) then
                     print("Bad entry: Player doesn't seem to own this door anymore")
                     valid = false
                  end
               end
            end
            
            if not valid then
               print("Found bad entry for door "..row.id..", throwing out...")
               db_do(
                  string.format([[
DELETE FROM permarp_door_owners
WHERE id = %s AND map = %s;]],
                     MySQLite.SQLStr(row.id),
                     MySQLite.SQLStr(string.lower(game.GetMap())))
               )
            end
         end
      end
   )
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
            timer.Create("permarp_data_validity_check",5*60,0,db_check_data_valid)
         end
)
