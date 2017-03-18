local just_joined = {}

Spawn = {
   Hooks = {
      onPlayerJoined = function(ply)
         just_joined[ply:SteamID64()] = true
      end,
      onPlayerDisconnected = function(ply)
         Spawn.DB.updatePlayerSpawnPosition(ply)
      end,
      onPlayerSpawn = function(ply)
         if not just_joined[ply:SteamID64()] then return end
         Database.query(
            string.format([[
SELECT posx, posy, posz
FROM permarp_player_positions
WHERE user_id = %s AND map = %s
]],
               Database.escape(ply:SteamID64()),
               Database.escape(string.lower(game.GetMap()))),
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
      end,
      register = function()
         hook.Add("PlayerInitialSpawn","permarp_spawn_player_joined",Spawn.Hooks.onPlayerJoined)
         hook.Add("PlayerDisconnected","permarp_spawn_player_disconnected",Spawn.Hooks.onPlayerDisconnceted)
         hook.Add("PlayerSpawn","permarp_spawn_player_spawn",Spawn.Hooks.onPlayerSpawn)
      end
   },
   DB = {
      updatePlayerSpawnPosition = function(ply)
         if not ply:Alive() or (not ply:IsOnGround() and not ply:InVehicle()) then return end
         Database.query(
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
   }
}
