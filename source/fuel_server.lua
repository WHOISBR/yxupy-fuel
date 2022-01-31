--[[                                                          	
 _   ___  ___   _ _ __  _   _ 
 | | | \ \/ / | | | '_ \| | | |
 | |_| |>  <| |_| | |_) | |_| |
  \__, /_/\_\\__,_| .__/ \__, |
   __/ |          | |     __/ |
  |___/           |_|    |___/ 
]]
--Legacy Fuel whit ui



local QBCore = exports['qb-core']:GetCoreObject()
    if Config.UseQB then
    
	RegisterServerEvent('fuel:pay')
	AddEventHandler('fuel:pay', function(price)
		local Player = QBCore.GetPlayerFromId(source)
		local amount = QBCore.Math.Round(price)

		if price > 0 then
			Player.Functions.RemoveMoney (amount)
		end
	end)

	QBCore.Functions.CreateCallback('fuel:money', function(playerId, cb)
		local Player = QBCore.Functions.GetPlayer(playerId)
		local money = Player.getMoney()
	
		cb(money)
	end)
end
