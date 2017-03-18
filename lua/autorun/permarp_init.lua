-- PermaRP (c) spycrab0 2017
-- Serverside script
if CLIENT then return end
include("permarp/permarp.lua")
hook.Add("OnGamemodeLoaded","permarp_gamemode_loaded",PermaRP.init)
