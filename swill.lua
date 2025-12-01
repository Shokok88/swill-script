-- SWILL Auto Joiner v1.0
-- Полный автоматический джойнер для Roblox с WebSocket управлением

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

-- Конфигурация
local WEBSOCKET_PORT = 51948
local WEBSOCKET_HOST = "127.0.0.1"
local RECONNECT_DELAY = 1
local MAX_RECONNECT_ATTEMPTS = 10

-- Глобальные переменные
local wsConnection = nil
local reconnectAttempts = 0
local isActive = true

-- Поиск элементов интерфейса
local function findUIElements()
    local success, elements = pcall(function()
        local mainFrame = CoreGui:FindFirstChild("Folder", true)
        if not mainFrame then
            mainFrame = CoreGui:WaitForChild("Folder", 5)
        end
        
        if mainFrame then
            local chilliUI = mainFrame:FindFirstChild("ChilliLibUI")
            if not chilliUI then
                chilliUI = mainFrame:WaitForChild("ChilliLibUI", 5)
            end
            
            if chilliUI then
                local mainBase = chilliUI:FindFirstChild("MainBase")
                if mainBase then
                    local frameContainer = mainBase.Frame
                    if frameContainer and #frameContainer:GetChildren() >= 3 then
                        local targetFrame = frameContainer:GetChildren()[3]
                        if targetFrame and #targetFrame:GetChildren() >= 6 then
                            local contentFrame = targetFrame:GetChildren()[6]
                            if contentFrame then
                                local contentHolder = contentFrame:FindFirstChild("ContentHolder")
                                if contentHolder then
                                    -- Поиск поля ввода
                                    local textBoxContainer = contentHolder:GetChildren()[5]
                                    local textBox = textBoxContainer and textBoxContainer.Frame.TextBox
                                    
                                    -- Поиск кнопки
                                    local joinButton = contentHolder:GetChildren()[6]
                                    
                                    if textBox and joinButton then
                                        return {
                                            Input = textBox,
                                            Button = joinButton,
                                            Connections = {
                                                FocusLost = getconnections(textBox.FocusLost),
                                                MouseClick = getconnections(joinButton.MouseButton1Click)
                                            }
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return nil
    end)
    
    return success and elements or nil
end

-- Функция присоединения к работе
local function ultraBypass(jobId)
    local uiElements = findUIElements()
    
    if not uiElements then
        warn("[SWILL] UI элементы не найдены. Повторная попытка...")
        task.wait(0.5)
        uiElements = findUIElements()
    end
    
    if uiElements and uiElements.Input and uiElements.Button then
        -- Установка Job ID
        uiElements.Input.Text = tostring(jobId)
        
        -- Активация события FocusLost
        if uiElements.Connections.FocusLost then
            for i = 1, #uiElements.Connections.FocusLost do
                uiElements.Connections.FocusLost[i]:Fire(true)
            end
        end
        
        task.wait(0.1)
        
        -- Активация клика по кнопке
        if uiElements.Connections.MouseClick then
            for i = 1, #uiElements.Connections.MouseClick do
                uiElements.Connections.MouseClick[i]:Fire()
            end
        end
        
        print("[SWILL] Успешно отправлен запрос на Job ID:", jobId)
        return true
    else
        warn("[SWILL] Не удалось найти необходимые элементы UI")
        return false
    end
end

-- Прямой телепорт (альтернативный метод)
local function directTeleport(placeId, jobId)
    local success, result = pcall(function()
        return TeleportService:TeleportToPlaceInstance(
            placeId,
            jobId,
            Players.LocalPlayer
        )
    end)
    
    if success then
        print("[SWILL] Прямой телепорт выполнен на Job ID:", jobId)
    else
        warn("[SWILL] Ошибка прямого телепорта:", result)
    end
end

-- Обработчик WebSocket сообщений
local function handleWebSocketMessage(message)
    print("[SWILL] Получена команда:", message)
    
    -- Парсинг команды
    if message:lower():sub(1, 4) == "join" then
        local jobId = message:match("%d+")
        if jobId then
            ultraBypass(jobId)
        end
    elseif message:lower():sub(1, 5) == "teleport" then
        local placeId, jobId = message:match("teleport%s+(%d+)%s+(%S+)")
        if placeId and jobId then
            directTeleport(tonumber(placeId), jobId)
        end
    elseif message:lower():sub(1, 6) == "rejoin" then
        local jobId = message:match("%S+$")
        if jobId then
            ultraBypass(jobId)
            task.wait(1)
            ultraBypass(jobId) -- Двойная отправка для надежности
        end
    elseif message:lower():sub(1, 6) == "status" then
        if wsConnection then
            wsConnection:Send("STATUS:ACTIVE")
        end
    else
        -- Прямой Job ID
        ultraBypass(message)
    end
end

-- Установка WebSocket соединения
local function setupWebSocket()
    while isActive do
        local success, ws = pcall(function()
            local ws = WebSocket.connect("ws://" .. WEBSOCKET_HOST .. ":" .. WEBSOCKET_PORT)
            
            ws.OnMessage:Connect(function(message)
                handleWebSocketMessage(message)
            end)
            
            ws.OnClose:Connect(function()
                print("[SWILL] WebSocket соединение закрыто")
                reconnectAttempts = 0
            end)
            
            print("[SWILL] WebSocket подключен к", WEBSOCKET_HOST .. ":" .. WEBSOCKET_PORT)
            wsConnection = ws
            reconnectAttempts = 0
            
            -- Отправка статуса подключения
            ws:Send("SWILL_AUTO_JOINER_ACTIVATED")
            
            return ws
        end)
        
        if not success then
            reconnectAttempts += 1
            if reconnectAttempts > MAX_RECONNECT_ATTEMPTS then
                warn("[SWILL] Достигнуто максимальное количество попыток переподключения")
                break
            end
            
            local delay = RECONNECT_DELAY * math.min(reconnectAttempts, 5)
            print("[SWILL] Ошибка подключения. Повторная попытка через", delay, "секунд...")
            task.wait(delay)
        else
            -- Ожидание закрытия соединения
            ws.OnClose:Wait()
        end
    end
end

-- Автоматическое переподключение при сбое UI
local function uiMonitor()
    while isActive do
        task.wait(5)
        
        local elements = findUIElements()
        if not elements then
            warn("[SWILL] Мониторинг UI: элементы не обнаружены")
        end
    end
end

-- Командная строка в игре
local function setupCommandLine()
    Players.LocalPlayer.Chatted:Connect(function(message)
        if message:lower():sub(1, 6) == "/swill" then
            local command = message:sub(8)
            if command == "status" then
                print("[SWILL] Статус: АКТИВЕН")
                print("[SWILL] WebSocket:", wsConnection and "ПОДКЛЮЧЕН" or "ОТКЛЮЧЕН")
            elseif command:sub(1, 4) == "join" then
                local jobId = command:match("%d+")
                if jobId then
                    ultraBypass(jobId)
                end
            end
        end
    end)
end

-- Инициализация
print("[SWILL] Auto Joiner инициализирован")
print("[SWILL] Поиск UI элементов...")

local uiElements = findUIElements()
if uiElements then
    print("[SWILL] UI элементы найдены успешно")
else
    warn("[SWILL] UI элементы не найдены. Проверьте наличие ChilliLibUI")
end

-- Запуск компонентов
spawn(setupWebSocket)
spawn(uiMonitor)
spawn(setupCommandLine)

-- Основной цикл
while isActive do
    task.wait(1)
    
    -- Автоматическое восстановление WebSocket
    if wsConnection == nil then
        spawn(setupWebSocket)
    end
end

-- Очистка при завершении
if wsConnection then
    wsConnection:Close()
end

print("[SWILL] Auto Joiner остановлен")
