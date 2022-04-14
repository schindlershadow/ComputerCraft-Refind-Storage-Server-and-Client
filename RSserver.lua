local modem = peripheral.find("modem", rednet.open)
local bridge = peripheral.find("rsBridge") -- Finds the peripheral if one is connected
local monitor = peripheral.find("monitor")
local enderChestSide = "left" -- Side the ender chest (or output chest) is on
local clients = {}

-- bridge.exportItemToPeripheral({name="minecraft:cobblestone", count=1}, "top")
-- bridge.importItemFromPeripheral({name="minecraft:cobblestone", count=1}, "top")


if bridge == nil then error("rsBridge not found") end

local function sendToClients(text)
    for i in pairs(clients) do
        rednet.send(clients[i], text)
    end
end

function centerText(text)
  x,y = monitor.getSize()
  x1,y1 = monitor.getCursorPos()
  monitor.setCursorPos((math.floor(x/2) - (math.floor(#text/2))), y1)
  monitor.write(text)
end

local function draw()
while true do
    local items = bridge.listItems()
    table.sort(items, function(a,b) return a.amount > b.amount end)

    monitor.clear()
    monitor.setCursorPos(1, 1)



    for k,v in pairs(items) do
        monitor.setCursorPos(1, k)
        local text = v["displayName"] .. " #" .. v["amount"]
        centerText(text)
    end


    os.sleep(5)
end
end

local function server()
    while true do
        local id, message = rednet.receive()
        print(("Computer %d sent message %s"):format(id, message))
        if message == "rsServer" then
            rednet.send(id, tostring(os.computerID()))
            local uniq = true
            for i in pairs(clients) do
                if clients[i] == id then
                    uniq = false
                end
            end
            if uniq then
                clients[#clients + 1] = id
            end
            print("")
            print("clients: ")
            for i in pairs(clients) do
                print(tostring(clients[i]))
            end
            print("")
        elseif message == "getItems" then
            print(bridge.listItems())
            rednet.send(id, bridge.listItems())
        elseif message == "getItem" then
            local id2, message2 = rednet.receive()
            print(bridge.listItem(message2))
            rednet.send(id, bridge.listItem(message2))
        elseif message == "import" then
            local id2, message2
            repeat
                id2, message2 = rednet.receive()
            until id ==  id2
            bridge.importItemFromPeripheral(message2, enderChestSide)
        elseif message == "importAll" then
            local list = peripheral.wrap(enderChestSide).list()
            for i in pairs(list) do
                --bridge.importItemFromPeripheral({i["name"], i["count"]}, enderChestSide)
                bridge.importItemFromPeripheral(list[i], enderChestSide)
            end
        elseif message == "export" then
            local id2, message2
            repeat
                id2, message2 = rednet.receive()
            until id ==  id2

            print("got")
            print(tostring(message2))
            print(message2["name"])
            print(message2["count"])
            local result = bridge.exportItemToPeripheral(message2, enderChestSide)
            print(result)
        end
    end
end

while true do
    parallel.waitForAny(server, draw)
   sleep(1)
end
