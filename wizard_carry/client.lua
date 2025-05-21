local carrySystem = {
    isActive = false,
    partnerId = -1,
    role = "",
    carrier = {
        dict = "missfinale_c2mcs_1",
        anim = "fin_c2_mcs_1_camman",
        flag = 49,
    },
    carried = {
        dict = "nm",
        anim = "firemans_carry",
        offsetX = 0.27,
        offsetY = 0.15,
        offsetZ = 0.63,
        flag = 33,
    }
}

local pendingRequests = {}

local function findNearestPlayer(maxDist)
    local closestPlayer, closestDist = -1, -1
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)

    for _, id in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(id)
        if targetPed ~= myPed then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(targetCoords - myCoords)
            if closestDist == -1 or distance < closestDist then
                closestDist = distance
                closestPlayer = id
            end
        end
    end

    if closestDist ~= -1 and closestDist <= maxDist then
        return closestPlayer
    end

    return nil
end

local function loadAnim(dict)
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do Wait(0) end
    end
end

local function showCarryMenu(fromId)
    lib.registerContext({
        id = 'carry_permission',
        title = 'Carry Consent',
        options = {
            {
                title = 'Accept',
                description = 'Allow this player to carry you.',
                onSelect = function()
                    TriggerServerEvent("wizard_carry:respond", fromId, true)
                end
            },
            {
                title = 'Decline',
                description = 'Reject the carry request.',
                onSelect = function()
                    TriggerServerEvent("wizard_carry:respond", fromId, false)
                end
            }
        }
    })
    lib.showContext('carry_permission')
end

RegisterCommand("carry", function()
    if not carrySystem.isActive then
        local target = findNearestPlayer(3.0)
        if target then
            local serverId = GetPlayerServerId(target)
            TriggerServerEvent("wizard_carry:request", serverId)
            lib.notify({
                title = 'Carry Request',
                description = 'Requesting permission...',
                type = 'inform',
                position = 'top'
            })
        else
            lib.notify({
                title = 'No Players Nearby',
                description = 'There is no one close enough to carry.',
                type = 'error',
                position = 'top'
            })
        end
    else
        carrySystem.isActive = false
        ClearPedTasks(PlayerPedId())
        DetachEntity(PlayerPedId(), true, false)
        TriggerServerEvent("wizard_carry:cancel", carrySystem.partnerId)
        carrySystem.partnerId = -1
    end
end, false)

RegisterNetEvent("wizard_carry:showMenu", function(fromId)
    showCarryMenu(fromId)
end)

RegisterNetEvent("wizard_carry:begin", function(partnerId)
    carrySystem.isActive = true
    carrySystem.partnerId = partnerId
    carrySystem.role = "carrier"
    loadAnim(carrySystem.carrier.dict)
    lib.notify({
        title = 'Carry Started',
        description = 'You are now carrying someone.',
        type = 'success',
        position = 'top'
    })
end)

RegisterNetEvent("wizard_carry:attachToCarrier", function(partnerId)
    local carrierPed = GetPlayerPed(GetPlayerFromServerId(partnerId))
    carrySystem.isActive = true
    carrySystem.role = "carried"
    loadAnim(carrySystem.carried.dict)
    AttachEntityToEntity(PlayerPedId(), carrierPed, 0, carrySystem.carried.offsetX, carrySystem.carried.offsetY, carrySystem.carried.offsetZ, 0.5, 0.5, 180.0, false, false, false, false, 2, false)
end)

RegisterNetEvent("wizard_carry:stop", function()
    carrySystem.isActive = false
    ClearPedTasks(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)
end)

CreateThread(function()
    while true do
        if carrySystem.isActive then
            local ped = PlayerPedId()
            if carrySystem.role == "carried" then
                if not IsEntityPlayingAnim(ped, carrySystem.carried.dict, carrySystem.carried.anim, 3) then
                    TaskPlayAnim(ped, carrySystem.carried.dict, carrySystem.carried.anim, 8.0, -8.0, -1, carrySystem.carried.flag, 0, false, false, false)
                end
            elseif carrySystem.role == "carrier" then
                if not IsEntityPlayingAnim(ped, carrySystem.carrier.dict, carrySystem.carrier.anim, 3) then
                    TaskPlayAnim(ped, carrySystem.carrier.dict, carrySystem.carrier.anim, 8.0, -8.0, -1, carrySystem.carrier.flag, 0, false, false, false)
                end
            end
        end
        Wait(0)
    end
end)
