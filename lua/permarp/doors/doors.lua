Doors = {
   Hooks = {
      onDoorLocked = function(door) DB.writeLocked(door,true) end,      
      onDoorUnlocked = function(door) DB.writeLocked(door,false) end,
      
      onDoorBought = function(ply,door)
         print(tostring(ply:SteamID64())..' bought a door with the ID '..tostring(door:doorIndex()))
         DB.addDoorOwnership(door)
      end,
      
      onDoorSold = function(ply,door)
         print(tostring(ply:SteamID64())..' sold a door with the ID '..tostring(door:doorIndex()))
         DB.deleteDoorOwnership(door)
      end,
      
      onPlayerJoined = function(ply)
         Doors.Database.UpdatePlayerName(ply)
         Database.query(
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
      end,
      
      onPlayerDisconnected = function(ply)
         Database.UpdatePlayerName(ply)
         Database.query(
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
      end,
      
      register = function()
         hook.Add("playerBoughtDoor","permarp_door_bought",onDoorBought)
         hook.Add("playerKeysSold","permarp_door_sold",onDoorSold)
         hook.Add("onKeysLocked","permarp_door_locked",onDoorLocked)
         hook.Add("onKeysUnlocked","permarp_door_unlocked",onDoorUnlocked)
         hook.Add("PlayerInitialSpawn","permarp_door_player_joined",onPlayerJoined)
         hook.add("PlayerDisconnected","permarp_door_player_disconnected",onPlayerDisconnected)
      end      
   },
   DB = {
      writeLocked = function(door,locked)
         Database.query(
            string.format([[
UPDATE permarp_door_owners
SET locked = %s
WHERE id = %s AND map = %s;
]],
               MySQLite.SQLStr(locked),
               MySQLite.SQLStr(door:doorIndex()),
               MySQLite.SQLStr(string.lower(game.GetMap()))
         ))
      end,
      
      updatePlayerName = function(ply)
         Database.query(
            string.format([[
UPDATE permarp_door_owners
SET user_name = %s
WHERE user_id = %s;
]],
               MySQLite.SQLStr(ply:GetName()),
               MySQLite.SQLStr(ply:SteamID64())
         ))
      end,
      
      removeDoorOwnership = function(door)
         Database.query(
            string.format([[
DELETE FROM permarp_door_owners
WHERE id = %s AND map = %s;]],
               MySQLite.SQLStr(door:doorIndex()),
               MySQLite.SQLStr(string.lower(game.GetMap())))
         )
      end,
      
      addDoorOwnership = function(door)
         Database.query(
            string.format(
               [[REPLACE INTO permarp_door_owners VALUES(%s,%s,%s,%s,%s)]],
               MySQLite.SQLStr(door:doorIndex()),
               MySQLite.SQLStr(string.lower(game.GetMap())),
               MySQLite.SQLStr(ply:SteamID64()),
               MySQLite.SQLStr(ply:GetName()),
               MySQLite.SQLStr(false))
         )
      end
   }
}
