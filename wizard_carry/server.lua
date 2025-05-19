if GetResourceState('ox_lib') ~= 'started' then
 --   print('^[1][ERROR] ox_lib is not started. wizard_carry notifications will fail.^7')
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
 --       print(('[wizard_carry] Error: Target player ped (%s) not found for carry request from source %s'):format(targetSrc, source))
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Error',
            description = 'Target player not found.',
            type = 'error',
            position = 'top'
        })
        return
    end

    local targetCoords = GetEntityCoords(targetPed)

    if not sourceCoords or not targetCoords then
   --     print(('[wizard_carry] Error: Could not get coordinates for carry request between %s and %s'):format(source, targetSrc))
        return
    end

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

    if carryRequests[responderSrc] and carryRequests[responderSrc] == requesterSrc then
        carryRequests[responderSrc] = nil

        local requesterPed = GetPlayerPed(requesterSrc)
        local responderPed = GetPlayerPed(responderSrc)
        if not requesterPed or requesterPed == 0 or not responderPed or responderPed == 0 then
         --    print(('[wizard_carry] Error: Player(s) not found during response (%s or %s).'):format(requesterSrc, responderSrc))
             TriggerClientEvent('ox_lib:notify', requesterSrc, { title = 'Carry System', description = 'Player disconnected.', type = 'error', position = 'top' })
             TriggerClientEvent('ox_lib:notify', responderSrc, { title = 'Carry System', description = 'Player disconnected.', type = 'error', position = 'top' })
             return
        end
        local requesterCoords = GetEntityCoords(requesterPed)
        local responderCoords = GetEntityCoords(responderPed)
        if not requesterCoords or not responderCoords or #(requesterCoords - responderCoords) > 4.0 then
             TriggerClientEvent('ox_lib:notify', requesterSrc, { title = 'Carry System', description = 'Players moved too far apart.', type = 'error', position = 'top' })
             TriggerClientEvent('ox_lib:notify', responderSrc, { title = 'Carry System', description = 'Players moved too far apart.', type = 'error', position = 'top' })
             return
        end
        if carrying[requesterSrc] or carried[requesterSrc] or carrying[responderSrc] or carried[responderSrc] then
            TriggerClientEvent('ox_lib:notify', requesterSrc, { title = 'Carry System', description = 'Action cancelled, one player is now busy.', type = 'warning', position = 'top' })
            TriggerClientEvent('ox_lib:notify', responderSrc, { title = 'Carry System', description = 'Action cancelled, one player is now busy.', type = 'warning', position = 'top' })
            return
        end

        if accepted then
            TriggerClientEvent("wizard_carry:startCarry", requesterSrc, responderSrc)
            TriggerClientEvent("wizard_carry:syncTarget", responderSrc, requesterSrc)

            carrying[requesterSrc] = responderSrc
            carried[responderSrc] = requesterSrc

            TriggerClientEvent('ox_lib:notify', requesterSrc, {
                title = 'Carry Request',
                description = 'Your carry request has been accepted!',
                type = 'success',
                position = 'top'
            })
             TriggerClientEvent('ox_lib:notify', responderSrc, {
                title = 'Carry Request',
                description = 'You accepted the request and are now being carried.',
                type = 'success',
                position = 'top'
            })
        else
            TriggerClientEvent('ox_lib:notify', requesterSrc, {
                title = 'Carry Request',
                description = 'Your carry request was rejected.',
                type = 'error',
                position = 'top'
            })
            TriggerClientEvent('ox_lib:notify', responderSrc, {
                title = 'Carry Request',
                description = 'You rejected the carry request.',
                type = 'inform',
                position = 'top'
            })
        end
    else
   --     print(('[wizard_carry] Warning: Carry response from %s for requester %s ignored or already handled.'):format(responderSrc, requesterSrc))
        TriggerClientEvent('ox_lib:notify', responderSrc, { title = 'Carry System', description = 'Carry action could not be completed (request expired or invalid).', type = 'warning', position = 'top'})
        if requesterSrc ~= -1 then
            TriggerClientEvent('ox_lib:notify', requesterSrc, { title = 'Carry System', description = 'Carry action could not be completed (request expired or invalid).', type = 'warning', position = 'top'})
        end
    end
end)

RegisterServerEvent("wizard_carry:stop")
AddEventHandler("wizard_carry:stop", function(targetSrc)
    local source = source
    local carrierSrc = nil
    local carriedSrc = nil

    if carrying[source] == targetSrc then
        carrierSrc = source
        carriedSrc = targetSrc
    elseif carried[source] == targetSrc then
        carriedSrc = source
        carrierSrc = targetSrc
    else
    --    print(('[wizard_carry] Stop Warning: Player %s tried to stop carrying/being carried by %s, but state mismatch or already stopped.'):format(source, targetSrc))
        TriggerClientEvent("wizard_carry:cl_stop", source)
        if GetPlayerPed(targetSrc) then
             TriggerClientEvent("wizard_carry:cl_stop", targetSrc)
        end
        if carrying[source] then carried[carrying[source]] = nil; carrying[source] = nil end
        if carried[source] then carrying[carried[source]] = nil; carried[source] = nil end
        if carrying[targetSrc] then carried[carrying[targetSrc]] = nil; carrying[targetSrc] = nil end
        if carried[targetSrc] then carrying[carried[targetSrc]] = nil; carried[targetSrc] = nil end
        return
    end

    if carrierSrc and carriedSrc then
        TriggerClientEvent("wizard_carry:cl_stop", carrierSrc)
        TriggerClientEvent("wizard_carry:cl_stop", carriedSrc)

        TriggerClientEvent('ox_lib:notify', carrierSrc, {
            title = 'Carry System',
            description = 'You have stopped carrying the player.',
            type = 'inform',
            position = 'top'
        })
        TriggerClientEvent('ox_lib:notify', carriedSrc, {
            title = 'Carry System',
            description = 'You are no longer being carried.',
            type = 'inform',
            position = 'top'
        })

        carrying[carrierSrc] = nil
        carried[carriedSrc] = nil
    end
end)

AddEventHandler('playerDropped', function(reason)
    local source = source

    local otherPlayerSrc = nil

    if carrying[source] then
        otherPlayerSrc = carrying[source]
        print(('[wizard_carry] Player %s (carrier) dropped, stopping carry for player %s.'):format(source, otherPlayerSrc))
        if GetPlayerPed(otherPlayerSrc) then
            TriggerClientEvent("wizard_carry:cl_stop", otherPlayerSrc)
            TriggerClientEvent('ox_lib:notify', otherPlayerSrc, {
                title = 'Carry System',
                description = 'The player carrying you has disconnected.',
                type = 'warning',
                position = 'top'
            })
            carried[otherPlayerSrc] = nil
        end
        carrying[source] = nil
    end

    if carried[source] then
        otherPlayerSrc = carried[source]
        print(('[wizard_carry] Player %s (carried) dropped, stopping carry by player %s.'):format(source, otherPlayerSrc))
        if GetPlayerPed(otherPlayerSrc) then
            TriggerClientEvent("wizard_carry:cl_stop", otherPlayerSrc)
             TriggerClientEvent('ox_lib:notify', otherPlayerSrc, {
                title = 'Carry System',
                description = 'The player you were carrying has disconnected.',
                type = 'warning',
                position = 'top'
            })
            carrying[otherPlayerSrc] = nil
        end
        carried[source] = nil
    end

    local requestsCleaned = 0
    for target, requester in pairs(carryRequests) do
        if requester == source then
            carryRequests[target] = nil
            requestsCleaned = requestsCleaned + 1
            if GetPlayerPed(target) then
                TriggerClientEvent('ox_lib:notify', target, { title = 'Carry Request', description = 'Incoming carry request cancelled (player disconnected).', type = 'inform', position = 'top' })
            end
        elseif target == source then
            local originalRequester = carryRequests[target]
            carryRequests[target] = nil
            requestsCleaned = requestsCleaned + 1
            if GetPlayerPed(originalRequester) then
                 TriggerClientEvent('ox_lib:notify', originalRequester, { title = 'Carry Request', description = 'Carry request cancelled (target player disconnected).', type = 'error', position = 'top' })
            end
        end
    end
    if requestsCleaned > 0 then
      --   print(('[wizard_carry] Cleaned up %s pending carry requests involving player %s.'):format(requestsCleaned, source))
    end

  --  print(('[wizard_carry] Player %s dropped. Final carry state cleanup complete. Reason: %s'):format(source, reason))
end)