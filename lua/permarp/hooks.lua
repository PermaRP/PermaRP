AddCSLuaFile()

if SERVER then
   -- Server hooks
   include("permarp.lua")
   include("spawn/spawn.lua")
   include("doors/doors.lua")
   
   Spawn.Hooks.register()
   Doors.Hooks.register()

   hook.Add("InitPostEntity","permarp_load_data",PermaRP.loadData)
else
   -- Client hooks
end
