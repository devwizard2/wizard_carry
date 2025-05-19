local carry = {
    InProgress = false,
    targetSrc = -1,
    type = "",
    personCarrying = {
        animDict = "missfinale_c2mcs_1",
        anim = "fin_c2_mcs_1_camman",
        flag = 49,
    },
    personCarried = {
        animDict = "nm",
        anim = "firemans_carry",
        attachX = 0.27,
        attachY = 0.15,
        attachZ = 0.63,
        flag = 33,
    }
}

local carryRequests = {}

local function GetClosestPlayer(radius)
    local players = GetActivePlayers()
    local closestDistance = -1
    local closestPlayer = -1
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    for _,playerId in ipairs(players) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed ~= playerPed then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(targetCoords-playerCoords)
            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = playerId
                closestDistance = distance
            end
        end
    end
    if closestDistance ~= -1 and closestDistance <= radius then
        return closestPlayer
    else
        return nil
    end
end

local function ensureAnimDict(animDict)
    if not HasAnimDictLoaded(animDict) then
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(0)
        end        
    end
    return animDict
end

local function OpenCarryRequestMenu(targetId)
    local targetName = GetPlayerName(GetPlayerFromServerId(targetId))

    lib.registerContext({
        id = 'carry_request_menu',
        title = 'Carry Request',
        options = {
            {
                title = 'Accept Request',
                description = 'Someone wants to carry you',
                onSelect = function()
                    TriggerServerEvent("wizard_carry:responseCarry", targetId, true)
                end
            },
            {
                title = 'Decline Request',
                description = 'Decline carry request',
                onSelect = function()
                    TriggerServerEvent("wizard_carry:responseCarry", targetId, false)
                end
            }
        }
    })
    
    lib.showContext('carry_request_menu')
end

RegisterCommand("carry", function(source, args)
    if not carry.InProgress then
        local closestPlayer = GetClosestPlayer(3)
        if closestPlayer then
            local targetSrc = GetPlayerServerId(closestPlayer)
            if targetSrc ~= -1 then
                TriggerServerEvent("wizard_carry:requestCarry", targetSrc)
                lib.notify({
                    title = 'Carry Request',
                    description = 'Asking for permission to carry...',
                    type = 'inform',
                    position = 'top'
                })
            else
                lib.notify({
                    title = 'Error',
                    description = 'No one nearby to carry!',
                    type = 'error',
                    position = 'top'
                })
            end
        else
            lib.notify({
                title = 'Error',
                description = 'No one nearby to carry!',
                type = 'error',
                position = 'top'
            })
        end
    else
        carry.InProgress = false
        ClearPedSecondaryTask(PlayerPedId())
        DetachEntity(PlayerPedId(), true, false)
        TriggerServerEvent("wizard_carry:stop", carry.targetSrc)
        carry.targetSrc = 0
    end
end, false)

RegisterNetEvent("wizard_carry:showRequestMenu")
AddEventHandler("wizard_carry:showRequestMenu", function(targetSrc)
    OpenCarryRequestMenu(targetSrc)
end)

RegisterNetEvent("wizard_carry:startCarry")
AddEventHandler("wizard_carry:startCarry", function(targetSrc)
    carry.InProgress = true
    carry.targetSrc = targetSrc
    ensureAnimDict(carry.personCarrying.animDict)
    carry.type = "carrying"
    lib.notify({
        title = 'Carrying',
        description = 'You are now carrying someone',
        type = 'success',
        position = 'top'
    })
end)

RegisterNetEvent("wizard_carry:syncTarget")
AddEventHandler("wizard_carry:syncTarget", function(targetSrc)
    local targetPed = GetPlayerPed(GetPlayerFromServerId(targetSrc))
    carry.InProgress = true
    ensureAnimDict(carry.personCarried.animDict)
    AttachEntityToEntity(PlayerPedId(), targetPed, 0, carry.personCarried.attachX, carry.personCarried.attachY, carry.personCarried.attachZ, 0.5, 0.5, 180, false, false, false, false, 2, false)
    carry.type = "beingcarried"
end)

RegisterNetEvent("wizard_carry:cl_stop")
AddEventHandler("wizard_carry:cl_stop", function()
    carry.InProgress = false
    ClearPedSecondaryTask(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)
end)

Citizen.CreateThread(function()
    while true do
        if carry.InProgress then
            if carry.type == "beingcarried" then
                if not IsEntityPlayingAnim(PlayerPedId(), carry.personCarried.animDict, carry.personCarried.anim, 3) then
                    TaskPlayAnim(PlayerPedId(), carry.personCarried.animDict, carry.personCarried.anim, 8.0, -8.0, 100000, carry.personCarried.flag, 0, false, false, false)
                end
            elseif carry.type == "carrying" then
                if not IsEntityPlayingAnim(PlayerPedId(), carry.personCarrying.animDict, carry.personCarrying.anim, 3) then
                    TaskPlayAnim(PlayerPedId(), carry.personCarrying.animDict, carry.personCarrying.anim, 8.0, -8.0, 100000, carry.personCarrying.flag, 0, false, false, false)
                end
            end
        end
        Wait(0)
    end
end)