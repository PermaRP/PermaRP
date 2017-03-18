if CLIENT then return end
PermaRP = {
   init = function()
      if GAMEMODE.Name != "DarkRP" then return end
      print("PermaRP Serverside loaded")

      include("permarp/database.lua")
      include("permarp/hooks.lua")

      Database.check()
   end,
   loadData = function()
      print("Loading PermaRP data...")
      Database.parse()
   end
}
