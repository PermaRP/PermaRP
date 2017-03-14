-- PermaRP (c) spycrab0 2017
-- Clientside script
if SERVER then return end
hook.Add("OnGamemodeLoaded","permarp_gamemode_clienthook",
         function()
            if GAMEMODE.Name != "DarkRP" then return end
            print("PermaMP Clientside loaded")
         end
)
