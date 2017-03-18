if CLIENT then return end
-- DB Helper
Database = {
   escape = function(obj)
      return MySQLite.SQLStr(obj)
   end,
   query = function(query,fnc)
      MySQLite.query(query,
                     fnc,
                     function(result)
                        error("MySQLite error occured on query '"..query.."': "..result, 2)
                     end
      )
   end,
   init = function()
      print ("Initializing database...")
      Database.query([[
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
   end,
   checkTable = function()
      MySQLite.tableExists(
         name,
         function(exists)
            if exists then
               print(name..": present")
            else
               print(name..": missing")
               Database.init()
            end
         end
      )
   end,
   check = function()
      checkTable("permarp_door_owners")
      checkTable("permarp_player_positions")
   end,
   parse = function()
       Database.query(
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
}
