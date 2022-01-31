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
local isNearPump = false
local isFueling = false
local currentFuel = 0.0
local currentCost = 0.0
local currentCash = 1000
local fuelSynced = false
local inBlacklisted = false
local compFuel = 0.0
local compFuel2 = 0.0

local enableField = false

AddEventHandler('onResourceStart', function(name)
    if GetCurrentResourceName() ~= name then
        return
    end

    close()
end)

function open()
    SetNuiFocus(true, true)
	enableField = true

	SendNUIMessage({
		action = "open",
    })

	SendNUIMessage({
		action = "tankpreis",
		tankpreis = tostring(Round(Config.CostMultiplier, 2)) .. "0"
	})

	SendNUIMessage({
		action = "price",
		price = "$ " .. Round(0, 1)
	})

	SendNUIMessage({
		action = "currentfuel",
		currentfuel = Round(GetVehicleFuelLevel(GetPlayersLastVehicle()), 1)
	})

	SendNUIMessage({
		action = "max",
		max = Config.FuelClassesMax[GetVehicleClass(GetPlayersLastVehicle())] .. " L"
	})
end
  
function close()
	SetNuiFocus(false, false)
	enableField = false
	
	SendNUIMessage({
		action = "close"
	})
	isFueling = false

	ClearPedTasks(PlayerPedId())
	RemoveAnimDict("timetable@gardener@filling_can")

	SendNUIMessage({
		action = "currentfuel",
		currentfuel = Round(0, 1)
	})

	SendNUIMessage({
		action = "compfuel",
		currentfuel = Round(0, 1)
	})

	SendNUIMessage({
		action = "tankpreis",
		currentfuel = "0 L"
	})
end

RegisterNUICallback('escape', function(data, cb)
	close()
end)

function ManageFuelUsage(vehicle)
	if not DecorExistOn(vehicle, Config.FuelDecor) then
		SetFuel(vehicle, math.random(200, 800) / 10)
	elseif not fuelSynced then
		SetFuel(vehicle, GetFuel(vehicle))

		fuelSynced = true
	end

	if IsVehicleEngineOn(vehicle) then
		SetFuel(vehicle, GetVehicleFuelLevel(vehicle) - Config.FuelUsage[Round(GetVehicleCurrentRpm(vehicle), 1)] * (Config.Classes[GetVehicleClass(vehicle)] or 1.0) / 10)
	end
end

Citizen.CreateThread(function()
	DecorRegister(Config.FuelDecor, 1)

	for index = 1, #Config.Blacklist do
		if type(Config.Blacklist[index]) == 'string' then
			Config.Blacklist[GetHashKey(Config.Blacklist[index])] = true
		else
			Config.Blacklist[Config.Blacklist[index]] = true
		end
	end

	for index = #Config.Blacklist, 1, -1 do
		table.remove(Config.Blacklist, index)
	end

	while true do
		Wait(1000)

		local ped = PlayerPedId()

		if IsPedInAnyVehicle(ped) then
			local vehicle = GetVehiclePedIsIn(ped)

			if Config.Blacklist[GetEntityModel(vehicle)] then
				inBlacklisted = true
			else
				inBlacklisted = false
			end

			if not inBlacklisted and GetPedInVehicleSeat(vehicle, -1) == ped then
				ManageFuelUsage(vehicle)
			end
		else
			if fuelSynced then
				fuelSynced = false
			end

			if inBlacklisted then
				inBlacklisted = false
			end
		end
	end
end)

CreateThread(function()
	while true do
		Wait(250)

		local pumpObject, pumpDistance = FindNearestFuelPump()

		if pumpDistance < 2.5 then
			isNearPump = pumpObject
			currentCash = QBCore.Functions.GetPlayerData().money['cash']
		else
			isNearPump = false

			Wait(math.ceil(pumpDistance * 20))
		end
	end
end)

AddEventHandler('fuel:startFuelUpTick', function(pumpObject, ped, vehicle)
	currentFuel = GetVehicleFuelLevel(vehicle)

	while isFueling do
		Wait(150)

		QBCore.Functions.TriggerCallback('fuel:money', function(money)
			if Round(money, 1) < Round(currentCost, 1) then
				isFueling = false
			end
		end)

		local oldFuel = DecorGetFloat(vehicle, Config.FuelDecor)
		local fuelToAdd = 0.1
		local extraCost = fuelToAdd * Config.CostMultiplier

		if not pumpObject then
			if GetAmmoInPedWeapon(ped, 883325847) - fuelToAdd * 100 >= 0 then
				currentFuel = oldFuel + fuelToAdd

				SetPedAmmo(ped, 883325847, math.floor(GetAmmoInPedWeapon(ped, 883325847) - fuelToAdd * 100))
			else
				isFueling = false
			end
		else
			compFuel = compFuel + fuelToAdd
			compFuel2 = compFuel2 + fuelToAdd
		end

		if currentFuel > Config.FuelClassesMax[GetVehicleClass(vehicle)] then
			currentFuel = Config.FuelClassesMax[GetVehicleClass(vehicle)]
			isFueling = false
		end

		currentCost = currentCost + extraCost

		if currentCash >= currentCost and compFuel <= Config.FuelClassesMax[GetVehicleClass(vehicle)] then
			SetFuel(vehicle, compFuel)
		else
			isFueling = false
		end
	end

	if pumpObject then
		TriggerServerEvent('fuel:pay', currentCost)
	end

	currentCost = 0.0
end)

RegisterNUICallback('unfuel', function(data, cb)
	isFueling = false
end)

AddEventHandler('fuel:refuelFromPump', function(pumpObject, ped, vehicle)
	TaskTurnPedToFaceEntity(ped, vehicle, 1000)
	Wait(1000)
	SetCurrentPedWeapon(ped, -1569615261, true)

	TriggerEvent('fuel:startFuelUpTick', pumpObject, ped, vehicle)

	while isFueling do
		for _, controlIndex in pairs(Config.DisableKeys) do
			DisableControlAction(0, controlIndex)
		end

		local vehicleCoords = GetEntityCoords(vehicle)

		if pumpObject then
			local stringCoords = GetEntityCoords(pumpObject)
			local extraString = ""


			SendNUIMessage({
				action = "price",
				price = "$ " .. Round(currentCost, 1)
			})
			--DrawText3Ds(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.CancelFuelingPump .. extraString)
			--DrawText3Ds(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 0.5, Round(compFuel, 1) .. "%")

			SendNUIMessage({
				action = "currentfuel",
				currentfuel = Round(compFuel, 1)
			})

			SendNUIMessage({
				action = "compfuel",
				compfuel = Round(compFuel2, 1)
			})
			
		end

		if DoesEntityExist(GetPedInVehicleSeat(vehicle, -1)) or (isNearPump and GetEntityHealth(pumpObject) <= 0) then
			isFueling = false
		end

		Wait(0)
	end

	compFuel2 = 0.0
end)

local vehicleToRefuel = GetPlayersLastVehicle()

function ShowAboveRadarMessage(message)
	SetNotificationTextEntry("STRING")
	AddTextComponentString(message)
	DrawNotification(0,1)
end

RegisterNUICallback('enternotify', function(data, cb)
	ShowAboveRadarMessage("Halte ENTER zum tanken.")
end)

RegisterNUICallback('refuel', function(data, cb)
	isFueling = true
	TriggerEvent('fuel:refuelFromPump', isNearPump, PlayerPedId(), GetPlayersLastVehicle())
	compFuel = GetVehicleFuelLevel(GetPlayersLastVehicle())
end)

Citizen.CreateThread(function()
	while true do
		local ped = PlayerPedId()

		if not isFueling and ((isNearPump and GetEntityHealth(isNearPump) > 0) or (GetSelectedPedWeapon(ped) == 883325847 and not isNearPump)) then
			if IsPedInAnyVehicle(ped) and GetPedInVehicleSeat(GetVehiclePedIsIn(ped), -1) == ped then
				local pumpCoords = GetEntityCoords(isNearPump)

				DrawText3Ds(pumpCoords.x, pumpCoords.y, pumpCoords.z + 1.2, Config.Strings.ExitVehicle)
			else
				local vehicle = GetPlayersLastVehicle()
				local vehicleCoords = GetEntityCoords(vehicle)

				if DoesEntityExist(vehicle) and GetDistanceBetweenCoords(GetEntityCoords(ped), vehicleCoords) < 2.5 then
					if not DoesEntityExist(GetPedInVehicleSeat(vehicle, -1)) then
						local stringCoords = GetEntityCoords(isNearPump)
						local canFuel = true

						if GetSelectedPedWeapon(ped) == 883325847 then
							stringCoords = vehicleCoords

							if GetAmmoInPedWeapon(ped, 883325847) < 100 then
								canFuel = false
							end
						end

						if GetVehicleFuelLevel(vehicle) < 95 and canFuel then
							if currentCash > 0 then
								DrawText3Ds(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.EToRefuel)

								if IsControlJustReleased(0, 38) then
									isFueling = true

									open()
									LoadAnimDict("timetable@gardener@filling_can")
									if not IsEntityPlayingAnim(ped, "timetable@gardener@filling_can", "gar_ig_5_filling_can", 3) then
										TaskPlayAnim(ped, "timetable@gardener@filling_can", "gar_ig_5_filling_can", 2.0, 8.0, -1, 50, 0, 0, 0, 0)
									end
								end
							else
								DrawText3Ds(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.NotEnoughCash)
							end
						elseif not canFuel then
						else
							DrawText3Ds(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.FullTank)
						end
					end
				else
					Wait(50)
				end
			end
		else
			Wait(50)
		end

		Wait(0)
	end
end)

if Config.ShowNearestGasStationOnly then
	Citizen.CreateThread(function()
		local currentGasBlip = 0

		while true do
			local coords = GetEntityCoords(PlayerPedId())
			local closest = 1000
			local closestCoords

			for _, gasStationCoords in pairs(Config.GasStations) do
				local dstcheck = GetDistanceBetweenCoords(coords, gasStationCoords)

				if dstcheck < closest then
					closest = dstcheck
					closestCoords = gasStationCoords
				end
			end

			if DoesBlipExist(currentGasBlip) then
				RemoveBlip(currentGasBlip)
			end

			currentGasBlip = CreateBlip(closestCoords)

			Wait(10000)
		end
	end)
elseif Config.ShowAllGasStations then
	Citizen.CreateThread(function()
		for _, gasStationCoords in pairs(Config.GasStations) do
			CreateBlip(gasStationCoords)
		end
	end)
end
