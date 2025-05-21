if GetResourceState('ox_lib') ~= 'started' then
    -- ox_lib is required for notifications
end

local carrying = {}
local carried = {}
local carryRequests = {}

RegisterServerEvent("wizard_carry:requestCarry")
AddEventHandler("wizard_carry:requestCarry", function(targetSrc)
    local source = source
    local sourcePed = GetPlayerPed(source)
    local sourceCoords = GetEntityCoords(sourcePed)
    local targetPed = GetPlayerPed(targetSrc)

    if not targetPed or targetPed == 0 then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Error',
            description = 'Target player not found.',
            type = 'error',
            position = 'top'
        })
        return
    end

    local targetCoords = GetEntityCoords(targetPed)
    if not sourceCoords or not targetCoords then return end

    if #(sourceCoords - targetCoords) <= 3.0 then
        if carryRequests[targetSrc] or carrying[targetSrc] or carried[targetSrc] or carrying[source] or carried[source] then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Carry System',
                description = 'Cannot send request now (player busy or already has a request).',
                type = 'warning',
                position = 'top'
            })
            return
        end

        carryRequests[targetSrc] = source
        TriggerClientEvent("wizard_carry:showRequestMenu", targetSrc, source)

        SetTimeout(15000, function()
            if carryRequests[targetSrc] == source then
                carryRequests[targetSrc] = nil
                TriggerClientEvent('ox_lib:notify', source, {
                    title = 'Carry Request',
                    description = 'Carry request has expired.',
                    type = 'error',
                    position = 'top'
                })
                TriggerClientEvent('ox_lib:notify', targetSrc, {
                    title = 'Carry Request',
                    description = 'Incoming carry request has expired.',
                    type = 'inform',
                    position = 'top'
                })
            end
        end)
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Carry System',
            description = 'Player is too far away.',
            type = 'warning',
            position = 'top'
        })
    end
end)

RegisterServerEvent("wizard_carry:responseCarry")
AddEventHandler("wizard_carry:responseCarry", function(requesterSrc, accepted)
    local responderSrc = source

    if carryRequests[responderSrc] ~= requesterSrc then
        TriggerClientEvent('ox_lib:notify', responderSrc, {
            title = 'Carry System',
            description = 'Carry action could not be completed (request expired or invalid).',
            type = 'warning',
            position = 'top'
        })
        if requesterSrc ~= -1 then
            TriggerClientEvent('ox_lib:notify', requesterSrc, {
                title = 'Carry System',
                description = 'Carry action could not be completed (request expired or invalid).',
                type = 'warning',
                position = 'top'
            })
        end
        return
    end

    carryRequests[responderSrc] = nil

    local requesterPed = GetPlayerPed(requesterSrc)
    local responderPed = GetPlayerPed(responderSrc)

    if not requesterPed or not responderPed or requesterPed == 0 or responderPed == 0 then
        TriggerClientEvent('ox_lib:notify', requesterSrc, {
            title = 'Carry System',
            description = 'Player disconnected.',
            type = 'error',
            position = 'top'
        })
        TriggerClientEvent('ox_lib:notify', responderSrc, {
            title = 'Carry System',
            description = 'Player disconnected.',
            type = 'error',
            position = 'top'
        })
        return
    end

    local requesterCoords = GetEntityCoords(requesterPed)
    local responderCoords = GetEntityCoords(responderPed)

    if #(requesterCoords - responderCoords) > 4.0 then
        TriggerClientEvent('ox_lib:notify', requesterSrc, {
            title = 'Carry System',
            description = 'Player moved too far away.',
            type = 'error',
            position = 'top'
        })
        TriggerClientEvent('ox_lib:notify', responderSrc, {
            title = 'Carry System',
            description = 'Player moved too far away.',
            type = 'error',
            position = 'top'
        })
        return
    end

    if accepted then
        carrying[requesterSrc] = responderSrc
        carried[responderSrc] = requesterSrc

        TriggerClientEvent("wizard_carry:startCarry", requesterSrc, responderSrc)
        TriggerClientEvent("wizard_carry:getCarried", responderSrc, requesterSrc)
    else
        TriggerClientEvent('ox_lib:notify', requesterSrc, {
            title = 'Carry System',
            description = 'Carry request denied.',
            type = 'error',
            position = 'top'
        })
        TriggerClientEvent('ox_lib:notify', responderSrc, {
            title = 'Carry System',
            description = 'You denied the carry request.',
            type = 'inform',
            position = 'top'
        })
    end
end)

RegisterServerEvent("wizard_carry:stopCarry")
AddEventHandler("wizard_carry:stopCarry", function()
    local source = source
    local partner = carrying[source] or carried[source]

    if partner then
        TriggerClientEvent("wizard_carry:forceStop", source)
        TriggerClientEvent("wizard_carry:forceStop", partner)
        carrying[source] = nil
        carried[source] = nil
        carrying[partner] = nil
        carried[partner] = nil
    end
end)

AddEventHandler("playerDropped", function()
    local source = source
    local partner = carrying[source] or carried[source]

    if partner then
        TriggerClientEvent("wizard_carry:forceStop", partner)
        carrying[partner] = nil
        carried[partner] = nil
    end

    carrying[source] = nil
    carried[source] = nil
    carryRequests[source] = nil
end)
