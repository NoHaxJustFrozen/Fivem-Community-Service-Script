local QBCore = exports['qb-core']:GetCoreObject()

-- State
local inCommunity = false
local tasksLeft = 0
local doingTask = false
local outWarning = false
local zoneTimer = 0

local kamuSpawn = Config.KamuSpawn
local allTasks = Config.TaskVectors
local currentTaskIndex = nil
local currentTaskBlip = nil

local anabacikiZone = PolyZone:Create({
    vector2(127.17999267578, -1004.4939575195),
    vector2(209.54539489746, -1032.4323730469),
    vector2(222.59660339355, -990.15197753906),
    vector2(143.29776000977, -960.18511962891)
}, {
    name = "anabaciki"
})

-- Blip ayarı
function SetNewTaskBlip(coords)
    if currentTaskBlip then
        RemoveBlip(currentTaskBlip)
        currentTaskBlip = nil
    end
    currentTaskBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(currentTaskBlip, 1)
    SetBlipScale(currentTaskBlip, 0.85)
    SetBlipColour(currentTaskBlip, 3)
    SetBlipAsShortRange(currentTaskBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Kamu Görevi")
    EndTextCommandSetBlipName(currentTaskBlip)
end

function SelectRandomTask()
    local prevIndex = currentTaskIndex
    if not allTasks or #allTasks == 0 then return end
    repeat
        currentTaskIndex = math.random(1, #allTasks)
    until currentTaskIndex ~= prevIndex or #allTasks == 1
    local coords = allTasks[currentTaskIndex].coords
    if coords then
        SetNewTaskBlip(coords)
    end
end

-- Zone giriş/çıkış
anabacikiZone:onPlayerInOut(function(isPointInside)
    if not inCommunity then return end
    if isPointInside then
        if outWarning then
            outWarning = false
            zoneTimer = 0
            lib.notify({title='Kamu', description='Kamu alanına geri döndün', type='success'})
            lib.hideTextUI()
        end
    else
        if not outWarning then
            outWarning = true
            zoneTimer = 20
            lib.notify({title = 'Uyarı', description = 'Kamu alanını terk ettin, 20 saniye içinde dön yoksa +5 ceza!', type = 'error'})
            Citizen.CreateThread(function()
                while outWarning and zoneTimer > 0 do
                    lib.showTextUI('Kamu alanına dönmen için: ' .. zoneTimer .. ' saniye')
                    Wait(1000)
                    zoneTimer = zoneTimer - 1
                    if not outWarning then
                        lib.hideTextUI()
                        break
                    end
                end
                if outWarning and zoneTimer <= 0 then
                    TriggerServerEvent('kamu:zonePunish')
                    SetEntityCoords(PlayerPedId(), kamuSpawn.x, kamuSpawn.y, kamuSpawn.z, false, false, false, true)
                    SetEntityHeading(PlayerPedId(), kamuSpawn.w)
                    lib.hideTextUI()
                    outWarning = false
                end
            end)
        end
    end
end)

-- Menü açma fonksiyonu
local function OpenKamuMenu()
    local input = lib.inputDialog('Kamuya Gönder', {
        {type = 'number', label = 'Oyuncu ID', description = 'Ceza verilecek oyuncu ID'},
        {type = 'number', label = 'Ceza Miktarı', description = 'Kaç görev yapılacak'}
    })
    if not input or not input[1] or not input[2] then return end
    local targetId = tonumber(input[1])
    local miktar = tonumber(input[2])
    if not targetId or not miktar then return end
    if miktar < 1 then
        lib.notify({title = 'UYARI', description = 'Geçersiz Miktar', type = 'error'})
        return
    end
    TriggerServerEvent('kamu:policeStart', targetId, miktar)
end

-- /kamu komutu (yetki kontrolü)
RegisterCommand("kamu", function()
    local playerData = QBCore.Functions.GetPlayerData()
    local jobName = playerData and playerData.job and playerData.job.name or nil
    if not jobName then
        lib.notify({title='Hata', description='İş bilgisi alınamadı.', type='error'})
        return
    end
    OpenKamuMenu()
end, false)

-- Kamu başlat
RegisterNetEvent('kamu:start', function(amount)
    inCommunity = true
    tasksLeft = amount or tasksLeft
    doingTask = false
    outWarning = false
    zoneTimer = 0
    if currentTaskBlip then
        RemoveBlip(currentTaskBlip)
        currentTaskBlip = nil
    end
    SetEntityCoords(PlayerPedId(), kamuSpawn.x, kamuSpawn.y, kamuSpawn.z, false, false, false, true)
    SetEntityHeading(PlayerPedId(), kamuSpawn.w)
    lib.notify({title = 'Kamu', description = 'Kamu cezan başladı, ' .. tasksLeft .. ' görev kaldı', type = 'info'})
    SelectRandomTask()
end)

-- Force check (sunucudan cevap)
RegisterNetEvent('kamu:forceCheck', function(tasks)
    if tasks and tonumber(tasks) > 0 then
        TriggerEvent('kamu:start', tasks)
    end
end)

-- Güncelle
RegisterNetEvent('kamu:updateTasks', function(left)
    tasksLeft = left
    lib.notify({title = 'Kamu', description = 'Kamu cezasında ' .. tasksLeft .. ' görev kaldı', type = 'info'})
    SelectRandomTask()
end)

-- Bitir
RegisterNetEvent('kamu:finish', function()
    inCommunity = false
    tasksLeft = 0
    doingTask = false
    outWarning = false
    zoneTimer = 0
    if currentTaskBlip then
        RemoveBlip(currentTaskBlip)
        currentTaskBlip = nil
    end
    SetEntityCoords(PlayerPedId(), kamuSpawn.x, kamuSpawn.y, kamuSpawn.z, false, false, false, true)
    SetEntityHeading(PlayerPedId(), kamuSpawn.w)
    lib.hideTextUI()
    lib.notify({title = 'Kamu', description = 'Kamu cezan bitti, geçmiş olsun', type = 'success'})
end)

-- Görev döngüsü
Citizen.CreateThread(function()
    while true do
        Wait(0)
        if inCommunity and not doingTask and currentTaskIndex then
            local ped = PlayerPedId()
            local task = allTasks[currentTaskIndex]
            if not task or not task.coords then goto continue end
            local dist = #(GetEntityCoords(ped) - vector3(task.coords.x, task.coords.y, task.coords.z))
            if dist < 2.0 then
                DrawText3D(task.coords.x, task.coords.y, task.coords.z + 0.3, "[E] Görev Yap")
                DrawBlueArrowMarker(task.coords.x, task.coords.y, task.coords.z)
                if IsControlJustReleased(0, 38) then
                    doingTask = true
                    if task.type == "garden" then
                        TaskStartScenarioInPlace(ped, "WORLD_HUMAN_GARDENER_PLANT", 0, true)
                        Wait(5000)
                        ClearPedTasks(ped)
                    elseif task.type == "broom" then
                        playBroomAnim(ped)
                        Wait(5000)
                        ClearPedTasks(ped)
                    end
                    TriggerServerEvent('kamu:completeTask')
                    doingTask = false
                end
            else
                DrawBlueArrowMarker(task.coords.x, task.coords.y, task.coords.z)
            end
        end
        ::continue::
    end
end)

-- Süpürge animasyonu
function playBroomAnim(ped)
    RequestAnimDict("anim@amb@drug_field_workers@rake@male_a@base")
    while not HasAnimDictLoaded("anim@amb@drug_field_workers@rake@male_a@base") do Wait(10) end
    local broom = CreateObject(GetHashKey("prop_tool_broom"), 1.0, 1.0, 1.0, true, true, false)
    AttachEntityToEntity(broom, ped, 28422, -0.01, 0.04, -0.03, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    TaskPlayAnim(ped, "anim@amb@drug_field_workers@rake@male_a@base", "base", 8.0, -8.0, 5000, 1, 0, false, false, false)
    Citizen.SetTimeout(5000, function() if DoesEntityExist(broom) then DeleteEntity(broom) end end)
end

-- 3D yazı
function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(8)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

-- Mavi ok marker
function DrawBlueArrowMarker(x, y, z)
    DrawMarker(21, x, y, z + 1.0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 0, 102, 255, 200, false, true, 2, false, nil, nil, false)
end

-- Sunucuya yeniden girişte ceza kontrolü isteği
Citizen.CreateThread(function()
    Wait(5000)
    TriggerServerEvent('kamu:requestStatus')
end)
