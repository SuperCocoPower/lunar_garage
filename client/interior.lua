-- This part of the script could've been written much better, if you have the time to do so, create a PR.
-- TODO: Refactor

local busy = false

---@param index integer The garage index
function EnterInterior(index)
    local garage = Config.Garages[index]

    if not garage?.Interior then return end

    local interior = Config.GarageInteriors[garage.Interior]

    if busy then return end

    busy = true

    DoScreenFadeOut(500)

    while not IsScreenFadedOut() do Wait(100) end

    local lastCoords = cache.coords
    SetEntityCoords(cache.ped, interior.Coords.x, interior.Coords.y, interior.Coords.z)
    SetEntityHeading(cache.ped, interior.Coords.w)
    SetGameplayCamRelativeHeading(0.0)

    local vehicles = lib.callback.await('lunar_garage:enterInterior', false, garage.Type)
    ---@type number[]
    local entities = {}

    local vehicleIndex = 1
    for i = 1, #interior.Vehicles do
        local coords = interior.Vehicles[i]
        local spawned = false

        repeat
            local vehicle = vehicles[vehicleIndex]

            if not vehicle then goto skip end

            ---@type VehicleProperties
            local props = json.decode(vehicle.vehicle or vehicle.mods)

            if props?.model and IsModelValid(props.model) then
                lib.requestModel(props.model)
                Framework.spawnLocalVehicle(props.model, coords.xyz, coords.w, function(entity)
                    lib.setVehicleProperties(entity, props)
                    
                    for _ = 1, 10 do
                        SetVehicleOnGroundProperly(entity)
                        Wait(0)
                    end

                    FreezeEntityPosition(entity, true)
                    table.insert(entities, entity)
                end)

                spawned = true
            end

            vehicleIndex += 1
        until spawned
    end

    ::skip::

    Wait(1000)
    DoScreenFadeIn(500)
    
    while not IsScreenFadedIn() do Wait(100) end

    busy = false

    if #vehicles > #interior.Vehicles then
        ShowNotification(locale('too_many_vehicles'), 'error')
    end

    ---@type CPoint, fun()
    local point, chooseVehicle

    -- Add the event manually instead of using lib.onCache so we can remove it later
    local eventData = AddEventHandler('ox_lib:cache:vehicle', function(vehicle)
        if vehicle then
            ShowUI(locale('choose_vehicle', Binds.first.currentKey))
            Binds.first.addListener('choose_vehicle', chooseVehicle)
        else
            HideUI()
            Binds.first.removeListener('choose_vehicle')
        end
    end)

    chooseVehicle = function()
        if busy then return end

        busy = true
        local vehicle = cache.vehicle
        local props = lib.getVehicleProperties(vehicle)

        if not props then return end

        DoScreenFadeOut(500)
        
        while not IsScreenFadedOut() do Wait(100) end

        for _, entity in ipairs(entities) do
            DeleteEntity(entity)
        end
        
        point:remove()
        RemoveEventHandler(eventData)
        DeleteEntity(vehicle)
        TriggerServerEvent('lunar_garage:exitInterior')
        Wait(1000)
        SetEntityCoords(cache.ped, lastCoords.x, lastCoords.y, lastCoords.z)
        SpawnVehicle({ index = index, props = props })
        DoScreenFadeIn(500)

        while not IsScreenFadedIn() do Wait(100) end

        busy = false
    end

    point = lib.points.new(interior.Coords.xyz, 1.0, {
        onEnter = function(self)
            ShowUI(locale('exit_garage', Binds.first.currentKey), 'door-open')
            Binds.first.addListener('exit_garage', function()
                if busy then return end

                busy = true
                DoScreenFadeOut(500)

                while not IsScreenFadedOut() do Wait(100) end

                for _, entity in ipairs(entities) do
                    DeleteEntity(entity)
                end

                self:onExit()
                self:remove()
                RemoveEventHandler(eventData)
                TriggerServerEvent('lunar_garage:exitInterior')
                SetEntityCoords(cache.ped, lastCoords.x, lastCoords.y, lastCoords.z)
                Wait(1000)
                DoScreenFadeIn(500)
                busy = false
            end)
        end,
        onExit = function()
            HideUI()
            Binds.first.removeListener('exit_garage')
        end
    })
end