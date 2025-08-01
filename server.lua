local QBCore = exports['qb-core']:GetCoreObject()

local allowedJobs = {
    lapd = true,
    lasd = true,
    cdcr = true,
    chp = true
}

-- Veritabanı tablosunu başlat
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS kamu_cezalar (
            license VARCHAR(50) PRIMARY KEY,
            tasks_left INT NOT NULL,
            job VARCHAR(32) NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {})
end)

-- License / identifier alma
local function GetLicense(src)
    if not src then return nil end
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:match("^license:") then
            return id
        end
    end
    return nil
end

-- Veritabanı yardımcıları
local function SetCommunityService(license, tasks, job, cb)
    exports.oxmysql:execute(
        'INSERT INTO kamu_cezalar (license, tasks_left, job) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE tasks_left = VALUES(tasks_left), job = VALUES(job)',
        {license, tasks, job},
        function(res)
            if cb then cb() end
        end
    )
end

local function RemoveCommunityService(license, cb)
    exports.oxmysql:execute('DELETE FROM kamu_cezalar WHERE license = ?', {license}, function(res)
        if cb then cb() end
    end)
end

local function GetCommunityService(license, cb)
    exports.oxmysql:execute('SELECT tasks_left, job FROM kamu_cezalar WHERE license = ?', {license}, function(result)
        if result and result[1] then
            cb(tonumber(result[1].tasks_left), result[1].job)
        else
            cb(nil, nil)
        end
    end)
end

-- Discord log
local function SendKamuDiscordLog(staffName, staffLicense, playerName, playerLicense, sure, job)
    local webhook = Config.Webhook
    if not webhook or webhook == "" then return end
    local embed = {
        {
            ["title"] = "🧹 Kamu Atma Logu",
            ["fields"] = {
                {
                    ["name"] = "Atan Yetkili",
                    ["value"] = string.format("%s\n(%s)", staffName or "Bilinmiyor", staffLicense or "Yok"),
                    ["inline"] = true
                },
                {
                    ["name"] = "Gönderilen Oyuncu",
                    ["value"] = string.format("%s\n(%s)", playerName or "Bilinmiyor", playerLicense or "Yok"),
                    ["inline"] = true
                },
                {
                    ["name"] = "Miktar",
                    ["value"] = tostring(sure),
                    ["inline"] = true
                },
                {
                    ["name"] = "Departman",
                    ["value"] = job or "Bilinmiyor",
                    ["inline"] = true
                }
            },
            ["footer"] = { ["text"] = "Xavi Kamu Sistemi" },
            ["color"] = 16760576
        }
    }
    PerformHttpRequest(webhook, function() end, "POST", json.encode({embeds = embed}), {["Content-Type"]="application/json"})
end

-- Menü açma
RegisterNetEvent('kamu:openMenu', function()
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    local job = xPlayer and xPlayer.PlayerData.job and xPlayer.PlayerData.job.name
    if job and allowedJobs[job] then
        TriggerClientEvent('kamu:showMenu', src)
    else
        TriggerClientEvent('QBCore:Notify', src, "Sadece yetkili departmanlar açabilir!", "error")
    end
end)

QBCore.Commands.Add('kamu', 'Kamu cezası menüsünü açar', {}, false, function(source)
    TriggerEvent('kamu:openMenu', source)
end)

-- Kamu başlatma (yetkili tarafından)
RegisterNetEvent('kamu:policeStart', function(targetId, taskCount)
    local src = source
    local officer = QBCore.Functions.GetPlayer(src)
    local job = officer and officer.PlayerData.job and officer.PlayerData.job.name
    if not job or not allowedJobs[job] then
        TriggerClientEvent('QBCore:Notify', src, "Yetkin yok.", "error")
        return
    end

    local target = tonumber(targetId)
    taskCount = tonumber(taskCount)
    if not target or not GetPlayerName(target) or not taskCount or taskCount < 1 then
        TriggerClientEvent('QBCore:Notify', src, 'Geçersiz miktar veya oyuncu.', 'error')
        return
    end

    local license = GetLicense(target)
    if not license then
        TriggerClientEvent('QBCore:Notify', src, 'Oyuncunun lisansı bulunamadı!', 'error')
        return
    end

    SetCommunityService(license, taskCount, job, function()
        -- Hedefe başlat sinyali
        TriggerClientEvent('kamu:start', target, taskCount)
        TriggerClientEvent('QBCore:Notify', src, 'Oyuncuya kamu cezası verdin!', 'success')

        -- Log için bilgiler
        local staffName = officer and officer.PlayerData.charinfo and (officer.PlayerData.charinfo.firstname .. " " .. officer.PlayerData.charinfo.lastname) or GetPlayerName(src)
        local staffLicense = GetLicense(src)
        local targetPlayer = QBCore.Functions.GetPlayer(target)
        local playerName = targetPlayer and targetPlayer.PlayerData.charinfo and (targetPlayer.PlayerData.charinfo.firstname .. " " .. targetPlayer.PlayerData.charinfo.lastname) or GetPlayerName(target)
        local playerLicense = GetLicense(target)
        SendKamuDiscordLog(staffName, staffLicense, playerName, playerLicense, taskCount, job)
    end)
end)

-- Kamu bitir komutu
QBCore.Commands.Add('kamubitir', 'Bir oyuncunun kamu cezasını bitirir (/kamubitir [id])', {
    {name='id', help='Oyuncu ID'}
}, true, function(source, args)
    local src = source
    local officer = QBCore.Functions.GetPlayer(src)
    local job = officer and officer.PlayerData.job and officer.PlayerData.job.name
    if not job or not allowedJobs[job] then
        TriggerClientEvent('QBCore:Notify', src, 'Sadece yetkili departmanlar kullanabilir!', 'error')
        return
    end

    local target = tonumber(args[1])
    if not target or not GetPlayerName(target) then
        TriggerClientEvent('QBCore:Notify', src, 'Oyuncu bulunamadı!', 'error')
        return
    end

    local license = GetLicense(target)
    if not license then
        TriggerClientEvent('QBCore:Notify', src, 'Oyuncu kamu cezasında değil!', 'error')
        return
    end

    RemoveCommunityService(license, function()
        TriggerClientEvent('kamu:finish', target)
        TriggerClientEvent('QBCore:Notify', src, 'Oyuncunun kamu cezasını bitirdin!', 'success')
    end)
end)

-- Görev tamamlandı
RegisterNetEvent('kamu:completeTask', function()
    local src = source
    local license = GetLicense(src)
    if not license then return end

    GetCommunityService(license, function(tasks, job)
        if tasks then
            tasks = tasks - 1
            if tasks <= 0 then
                RemoveCommunityService(license, function()
                    TriggerClientEvent('kamu:finish', src)
                end)
            else
                SetCommunityService(license, tasks, job or "UNKNOWN", function()
                    TriggerClientEvent('kamu:updateTasks', src, tasks)
                end)
            end
        end
    end)
end)

-- Zone dışına çıkma cezası (+5)
RegisterNetEvent('kamu:zonePunish', function()
    local src = source
    local license = GetLicense(src)
    if not license then return end

    GetCommunityService(license, function(tasks, job)
        if tasks then
            local newtasks = tasks + 5
            SetCommunityService(license, newtasks, job or "UNKNOWN", function()
                TriggerClientEvent('kamu:updateTasks', src, newtasks)
                -- Client kendi içinden zaten uyarı gösteriyor ama ekstra bildirim:
                TriggerClientEvent('QBCore:Notify', src, "Kamu alanını terk ettiğin için +5 görev eklendi.", "error")
            end)
        end
    end)
end)

-- Oyuncu yüklendiğinde ceza durumunu kontrol et (tek handler)
AddEventHandler('QBCore:Server:PlayerLoaded', function(playerId)
    local license = GetLicense(playerId)
    if not license then return end
    GetCommunityService(license, function(tasks, job)
        if tasks and tonumber(tasks) > 0 then
            TriggerClientEvent('kamu:start', playerId, tasks)
        end
    end)
end)

-- İstemciden durum istenirse
RegisterNetEvent('kamu:requestStatus', function()
    local src = source
    local license = GetLicense(src)
    if not license then return end
    GetCommunityService(license, function(tasks, job)
        if tasks and tonumber(tasks) > 0 then
            TriggerClientEvent('kamu:forceCheck', src, tasks)
        end
    end)
end)

-- Kamu status göster
QBCore.Commands.Add('kamustatus', 'Kalan kamu cezanı gösterir', {}, false, function(source)
    local license = GetLicense(source)
    if not license then
        TriggerClientEvent('QBCore:Notify', source, 'Lisansa ulaşılamadı!', 'error')
        return
    end
    exports.oxmysql:execute('SELECT tasks_left, job FROM kamu_cezalar WHERE license = ?', {license}, function(rows)
        local row = rows and rows[1]
        if row and tonumber(row.tasks_left) > 0 then
            TriggerClientEvent('QBCore:Notify', source,
                string.format("Hala %s adet kamu görevin var. Cezayı yazan departman: %s", row.tasks_left, row.job), "info")
            TriggerClientEvent("chat:addMessage", source, {
                color = {255,255,0},
                multiline = true,
                args = {"Kamu Status", "Cezan: " .. row.tasks_left .. " | Departman: " .. row.job}
            })
        else
            TriggerClientEvent('QBCore:Notify', source, "Tertemizsin, hiç kamu cezan yok!", "success")
            TriggerClientEvent("chat:addMessage", source, {
                color = {0,255,0},
                multiline = true,
                args = {"Kamu Status", "Şu an kamu cezan yok! Temizsin."}
            })
        end
    end)
end)
