local modem = peripheral.find("modem", rednet.open)
local width, height = term.getSize()
local server = 0
local search = ""
local items = {}
local menu = false

-- Settings
local logging = true
local debug = false

term.setBackgroundColor(colors.blue)

Item = {name = "", count = 1, fingerprint = "", nbt = ""}
function Item:new(name, count, fingerprint, nbt)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    self.name = name or ""
    self.count = count or 1
    self.fingerprint = fingerprint or ""
    --self.fingerprint = ""
    self.nbt = nbt or nil

    return obj
end

function Item:getTable()
    local table = {}
    if self.name ~= "" then
        table["name"] = self.name
    end
    if self.count ~= 0 then
        table["count"] = self.count
    end
    if self.fingerprint ~= "" then
        table["fingerprint"] = self.fingerprint
    end
    return table
end

local function log(text)
    if type(text) == "string" and logging then
        local logFile = fs.open("logs/RSclient.csv", "a")
        logFile.writeLine(os.date("%A/%d/%B/%Y %I:%M%p") .. "," .. text)
        logFile.close()
    end
end

local function broadcast()
    print("Searching for rsServer server")
    rednet.broadcast("rsServer")
    local id, message = rednet.receive(nil, 5)
    if type(tonumber(message)) == "number" and id == tonumber(message) then
        print("Server set to: " .. tostring(message))
        server = tonumber(message)
        return tonumber(message)
    else
        sleep(1)
        return broadcast()
    end
end

local function getItems()
    rednet.send(server, "getItems")
    local id, message = rednet.receive(nil, 5)
    --print("got " .. tostring(message) .. " type " .. type(message))
    if type(message) == "table" then
        if search == "" then
            return message
        end
        local filteredTable = {}
        for k, v in pairs(message) do
            if string.find(string.lower(v["displayName"]), string.lower(search)) then
                table.insert(filteredTable, v)
            end
        end
        return filteredTable
    else
        sleep(1)
        return getItems()
    end
end

local function import(item)
    rednet.send(server, "import")
    rednet.send(server, item:getTable())
end

local function importAll()
    rednet.send(server, "importAll")
end

local function export(item)
    rednet.send(server, "export")
    rednet.send(server, item:getTable())
end

local function centerText(text)
    local x, y = term.getSize()
    local x1, y1 = term.getCursorPos()
    term.setCursorPos((math.floor(x / 2) - (math.floor(#text / 2))), y1)
    write(text)
end

local function dump(o)
    if type(o) == "table" then
        local s = ""
        for k, v in pairs(o) do
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            s = s .. "[" .. k .. "] = " .. dump(v) .. ","
        end
        return s
    else
        return tostring(o)
    end
end

local function drawNBTmenu(sel)
    local amount = 1
    local done = false
    while done == false do
        term.setBackgroundColor(colors.green)
        for k = 1, height - 1, 1 do
            for i = 1, width, 1 do
                term.setCursorPos(i, k)
                term.write(" ")
            end
        end
        term.setCursorPos(1,1)
        centerText("NBT Menu")
        term.setCursorPos(1, 2)
        centerText(items[sel].name .. " #" .. tostring(items[sel].amount))
        term.setCursorPos(1, 3)
        if items[sel].nbt ~= nil then
            write(dump(items[sel].nbt))
        end
        term.setCursorPos(width, 1)
        term.setBackgroundColor(colors.red)
        term.write("x")
        term.setBackgroundColor(colors.green)


        local event, button, x, y = os.pullEvent("mouse_click")

        if y < 2 and x > width - 1 then
            done = true
        end

        --sleep(5)
    end
end

local function drawMenu(sel)
    local amount = 1
    done = false
    while done == false do
        term.setBackgroundColor(colors.green)
        for k = 1, height - 1, 1 do
            for i = 1, width, 1 do
                term.setCursorPos(i, k)
                term.write(" ")
            end
        end
        term.setCursorPos(1,1)
        centerText("Menu")
        term.setCursorPos(1, 2)
        centerText(items[sel].name .. " #" .. tostring(items[sel].amount))
        term.setCursorPos(1, 3)
        if items[sel].nbt ~= nil then
            term.setBackgroundColor(colors.red)
            centerText("Show NBT tags")
            term.setBackgroundColor(colors.green)
        end
        term.setCursorPos(1, (height * .25) + 4)
        centerText("Amount to request")
        term.setCursorPos(width, 1)
        term.setBackgroundColor(colors.red)
        term.write("x")
        term.setBackgroundColor(colors.green)
        term.setCursorPos((width * .25), (height * .25) + 5)
        term.write("<")
        term.setCursorPos((width * .50), (height * .25) + 5)
        centerText(tostring(amount))
        term.setCursorPos(width - (width * .25), (height * .25) + 5)
        term.write(">")
        term.setCursorPos((width * .25), (height * .25) + 7)
        term.write("+64")
        term.setCursorPos((width * .25) * 2 - 1, (height * .25) + 7)
        term.write("-64")
        term.setCursorPos((width * .25) * 3, (height * .25) + 7)
        term.write("1")

        term.setBackgroundColor(colors.red)
        term.setCursorPos(1, height - (height * .25) + 4)
        centerText("Request")

        local event, button, x, y

        if debug then
            term.setCursorPos((width * .25) + 2, (height * .25) + 4)
            term.write("X")
            term.setCursorPos((width * .25) - 2, (height * .25) + 6)
            term.write("Y")

            term.setCursorPos(width - (width * .25) + 2, ((height * .25) + 4))
            term.write("X")
            term.setCursorPos((width - (width * .25)) - 2, (height * .25) + 6)
            term.write("Y")

            event, button, x, y = os.pullEvent("mouse_click")
            term.setCursorPos(x, y)
            term.write("? " .. tostring(x) .. " " .. tostring(y))
            sleep(5)
        else
            event, button, x, y = os.pullEvent("mouse_click")
        end

        if
            (((x < (width * .25) + 2) and (x > (width * .25) - 2)) and
                ((y > (height * .25) + 4) and (y < (height * .25) + 6)))
         then
            if amount > 1 then
                amount = amount - 1
            end
        elseif
            (((x < (width - (width * .25)) + 2) and (x > (width - (width * .25)) - 2)) and
                ((y > (height * .25) + 4) and (y < (height * .25) + 6)))
         then
            if amount < items[sel].amount then
                amount = amount + 1
            end
        elseif
            (((x < (width * .25) + 2) and (x > (width * .25) - 2)) and
                ((y > (height * .25) + 6) and (y < (height * .25) + 10)))
         then
            if amount + 64 < items[sel].amount then
                amount = amount + 64
            else
                amount = items[sel].amount
            end
        elseif
            (((x < ((width * .25) * 2) + 3) and (x > ((width * .25) * 2) - 3)) and
                ((y > (height * .25) + 6) and (y < (height * .25) + 10)))
         then
            if amount > 1+64 then
                amount = amount - 64
            else
                amount = 1
            end
        elseif
            (((x < ((width * .25) * 3) + 3) and (x > ((width * .25) * 3) - 3)) and
                ((y > (height * .25) + 6) and (y < (height * .25) + 10)))
         then
             amount = 1
        elseif y == (height - 1) then
            done = true
            local result
            if items[sel].nbt == nil then
                result = Item:new(items[sel].name, amount, "", items[sel].tags)
            else
                result = Item:new(items[sel].name, amount, items[sel].fingerprint, items[sel].tags)
            end
            export(result)
        elseif y < 2 and x > width - 1 then
            done = true
        elseif y == 3  then
            drawNBTmenu(sel)
         end

        --sleep(5)
    end
end

local function drawList()
    if menu == false then
        items = getItems()
        table.sort(
            items,
            function(a, b)
                return a.amount > b.amount
            end
        )
        term.setBackgroundColor(colors.blue)
        for k = 1, height - 1, 1 do
            for i = 1, width, 1 do
                term.setCursorPos(i, k)
                term.write(" ")
            end
        end
        for k, v in pairs(items) do
            if k < height then
                local text = ""

                if v["nbt"] ~= nil then
                    text = v["displayName"] .. " #" .. v["amount"] .. " " .. dump(v["nbt"])
                elseif v["tags"] ~= nil then
                    text = v["displayName"] .. " #" .. v["amount"] .. " " .. v["tags"][1]
                else
                    text = v["displayName"] .. " #" .. v["amount"]
                end

                term.setCursorPos(1, k)
                term.write(text)
                term.setCursorPos(1, height)
            end
        end
        --import
        term.setCursorPos(width-5,height-1)
        term.setBackgroundColor(colors.red)
        term.write("Import")
        term.setBackgroundColor(colors.blue)
    end

    --sleep(5)
end

local function inputHandler()
    while true do
        local event, key
        repeat
            event, key = os.pullEvent()
        until event ~= "char" or event ~= "key"
        if event == "char" or event == "key" then
            --term.setCursorPos(1,height)
            if event == "char" then
                search = search .. key
            elseif key == keys.backspace then
                search = search:sub(1, -2)
            elseif key == keys.enter then
                drawList()
            elseif key == keys.delete then
                search = ""
                drawList()
            end
        end

        term.setBackgroundColor(colors.black)
        for i = 1, width, 1 do
            term.setCursorPos(i, height)
            term.write(" ")
        end

        term.setCursorPos(1, height)
        term.write(search)
    end
end

local function touchHandler()
    local event, button, x, y = os.pullEvent("mouse_click")
    if y == height -1 and x > width - 6 then

        importAll()

    elseif items[y] ~= nil and y ~= height then
        menu = true
        drawMenu(y)
        menu = false
        term.clear()
        sleep(0.1)
        drawList()
    -- result = Item:new(items[y].name, 1, items[y].fingerprint, items[y].tags)
    -- export(result)
    end
end

broadcast()
term.clear()
term.setCursorPos(1, 1)
drawList()

term.setBackgroundColor(colors.black)
for i = 1, width, 1 do
    term.setCursorPos(i, height)
    term.write(" ")
end

while true do
    parallel.waitForAny(touchHandler, inputHandler)

    --inputHandler()
    sleep(1)
end
