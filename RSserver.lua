math.randomseed(os.time() + 7 * os.getComputerID());
local cryptoNetURL = "https://raw.githubusercontent.com/SiliconSloth/CryptoNet/master/cryptoNet.lua";
local modem = peripheral.find("modem", rednet.open);
local bridge = peripheral.find("rs_bridge");
local monitor = peripheral.find("monitor");
local enderChestSide = "top";
local clients = {};
local monitors = {}
local serverBootTime = os.epoch("utc") / 1000
local serverLAN, serverWireless


if not fs.exists("cryptoNet") then
	print("");
	print("cryptoNet API not found on disk, downloading...");
	local response = http.get(cryptoNetURL);
	if response then
		local file = fs.open("cryptoNet", "w");
		file.write(response.readAll());
		file.close();
		response.close();
		print("File downloaded as '" .. "cryptoNet" .. "'.");
	else
		print("Failed to download file from " .. cryptoNetURL);
	end;
end;
os.loadAPI("cryptoNet");
os.getComputerID = os.getComputerID;
os.epoch = os.epoch;
os.loadAPI = os.loadAPI;
os.queueEvent = os.queueEvent;
os.startThread = os.startThread;
os.pullEvent = os.pullEvent;
os.startTimer = os.startTimer;
os.reboot = os.reboot;
os.setComputerLabel = os.setComputerLabel;
utf8 = utf8;
cryptoNet = cryptoNet;

-- Settings
settings.define("serverName", {
    description = "The hostname of this server",
    "StorageServer" .. tostring(os.getComputerID()),
    type = "string"
})
settings.define("debug", {
    description = "Enables debug options",
    default = "false",
    type = "boolean"
})
settings.define("requireLogin", {
    description = "require a login for LAN clients",
    default = "false",
    type = "boolean"
})
-- Settings fails to load
if settings.load() == false then
    print("No settings have been found! Default values will be used!")
    settings.set("serverName", "StorageServer" .. tostring(os.getComputerID()))
    settings.set("debug", false)
    settings.set("requireLogin", false)
    print("Stop the server and edit .settings file with correct settings")
    settings.save()
    sleep(5)
end

if bridge == nil then
	bridge = peripheral.wrap("right");
end;
if bridge == nil then
	error("rs_bridge not found");
end;
local function log(text)
	local logFile = fs.open("logs/server.log", "a");
	if type(text) == "string" then
		logFile.writeLine(os.date("%A/%d/%B/%Y %I:%M%p") .. ", " .. text);
	else
		logFile.writeLine(os.date("%A/%d/%B/%Y %I:%M%p") .. ", " .. textutils.serialise(text));
	end;
	logFile.close();
end;
-- Dumps a table to string
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

local function debugLog(text)
	if settings.get("debug") then
		local logFile = fs.open("logs/serverDebug.log", "a");
		if type(text) == "string" then
			logFile.writeLine(os.date("%A/%d/%B/%Y %I:%M%p") .. ", " .. text);
		else
			logFile.writeLine(os.date("%A/%d/%B/%Y %I:%M%p") .. ", " .. textutils.serialise(text));
		end;
		logFile.close();
	end;
end;
local function dumpItems()
	for k, v in pairs(items) do
		debugLog("k: " .. tostring(k) .. " v: " .. textutils.serialize(v));
	end;
end;
local function printClients()
	print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
	local count = 0;
	for _ in pairs(clients) do
		count = count + 1;
	end;
	print("Clients: " .. tostring(count));
	for i in pairs(clients) do
		print(tostring(clients[i].username) .. ":" .. string.sub(tostring(clients[i].target), 1, 5) .. ":" .. tostring(clients[i].sender));
	end;
	print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
end;
local function pingClients(message)
	for k, v in pairs(clients) do
		cryptoNet.send(v, {
			message
		});
	end;
	if mainCraftingServer ~= nil then
		cryptoNet.send(mainCraftingServer, {
			message
		});
	end;
end;

local function draw()
	while true do
		local items = bridge.getItems();
		table.sort(items, function(a, b)
			return a.count > b.count;
		end);
		monitor.clear();
		monitor.setCursorPos(1, 1);
		for k, v in pairs(items) do
			monitor.setCursorPos(1, k);
			local text = v.displayName .. " #" .. v.count;
			centerText(text);
		end;
		os.sleep(5);
	end;
end;

local function onCryptoNetEvent(event)
	debugLog("onCryptoNetEvent: " .. textutils.serialise(event[1]));
    --print(textutils.serialise(event[1]))
	if event[1] == "login" or event[1] == "hash_login" then
		local username = event[2];
		local socket = event[3];
		print(socket.username .. " just logged in.");
	elseif event[1] == "encrypted_message" then
		local socket = event[3];
		if socket ~= nil and (socket.username ~= nil or not settings.get("requireLogin") and socket.sender == settings.get("serverName")) and event[2][1] ~= "hashLogin" then
			local message = event[2][1];
			local data = event[2][2];
			if socket.username == nil then
				socket.username = "LAN Host";
			end;
			log("User: " .. socket.username .. " Client: " .. socket.target .. " request: " .. tostring(message));
			if message == "storageServer" then
				cryptoNet.send(socket, {
					message,
					settings.get("serverName")
				});
				local uniq = true;
				for i in pairs(clients) do
					if clients[i] == socket then
						uniq = false;
					end;
				end;
				if uniq then
					clients[(#clients) + 1] = socket;
					cryptoNet.send(socket, {
						"isMainCraftingServer"
					});
				end;
				printClients();
			elseif message == "getServerType" then
				cryptoNet.send(socket, {
					message,
					"StorageServer"
				});
			elseif message == "isMainCraftingServer" then
				if data then
					cryptoNet.send(socket, {
						"storageCraftingServer"
					});
					cryptoNet.send(socket, {
						"watchCrafting"
					});
					mainCraftingServer = socket;
					craftingEnabled = true;
				end;
			elseif message == "storageCraftingServer" then
				mainCraftingServer.serverName = data;
			elseif message == "ping" then
				cryptoNet.send(socket, {
					"ping",
					"ack"
				});
			elseif message == "reloadStorageDatabase" then
				cryptoNet.send(socket, {
					message
				});
				reloadStorageDatabase();
			elseif message == "getItems" then
				cryptoNet.sendUnencrypted(socket, {
					"getItems",
					bridge.getItems()
				});
			elseif message == "getDetailDB" then
				cryptoNet.sendUnencrypted(socket, {
					"getDetailDB",
					detailDB
				});
			elseif message == "getItem" then
				if settings.get("debug") then
					print(dump(data));
				end;
				--local filteredTable = search(data, items);
				if filteredTable ~= nil then
					cryptoNet.send(socket, {
						message,
						bridge.getItem(message2)
					});
				end;
			elseif message == "getItemDetails" then
				if settings.get("debug") then
					print(dump(data));
				end;
				if type(data) == "table" then
					local details = (peripheral.wrap(data.chestName)).getItemDetail(data.slot);
					cryptoNet.send(socket, {
						message,
						details
					});
				end;
			elseif message == "export" then
				print(socket.username .. " requested: " .. tostring(message));
				print("Export: " .. data.item.name .. " #" .. tostring(data.item.count));
				log("Export: " .. dump(data.item));
				--getItem(data.item, data.chest);
				bridge.exportItem(data.item, enderChestSide)
				pingClients("databaseReload");
				--storageFreeSlots = calcFreeSlots();
			elseif message == "storageUsed" then
				cryptoNet.send(socket, {
					message,
					storageUsed
				});
			elseif message == "storageSize" then
				cryptoNet.send(socket, {
					message,
					storageSize
				});
			elseif message == "storageMaxSize" then
				cryptoNet.send(socket, {
					message,
					storageMaxSize
				});
			elseif message == "requireLogin" then
				cryptoNet.send(socket, {
					message,
					settings.get("requireLogin")
				});
			elseif message == "getCertificate" then
				local fileContents = nil;
				local filePath = socket.sender .. ".crt";
				if fs.exists(filePath) then
					local file = fs.open(filePath, "r");
					fileContents = file.readAll();
					file.close();
				end;
				cryptoNet.send(socket, {
					message,
					fileContents
				});
			elseif message == "getUserList" then
				local permissionLevel = cryptoNet.getPermissionLevel(socket.username, serverLAN);
				if tonumber(permissionLevel) >= 2 then
					cryptoNet.send(socket, {
						message,
						getUserList()
					});
				end;
			elseif message == "getPermissionLevel" then
				cryptoNet.send(socket, {
					message,
					cryptoNet.getPermissionLevel(data, serverLAN)
				});
			elseif message == "setPermissionLevel" then
				print(socket.username .. " requested: " .. tostring(message));
				local permissionLevel = cryptoNet.getPermissionLevel(socket.username, serverLAN);
				local userExists = cryptoNet.userExists(data.username, serverLAN);
				if permissionLevel >= 2 and userExists and type(data.permissionLevel) == "number" and data.permissionLevel < 3 then
					cryptoNet.setPermissionLevel(data.username, data.permissionLevel, serverLAN);
					cryptoNet.send(socket, {
						message,
						true
					});
				else
					cryptoNet.send(socket, {
						message,
						false
					});
				end;
			elseif message == "checkPasswordHashed" then
				local permissionLevel = cryptoNet.getPermissionLevel(socket.username, serverLAN);
				if not settings.get("requireLogin") and socket.sender == settings.get("serverName") or tonumber(permissionLevel) >= 2 then
					local check = cryptoNet.checkPasswordHashed(data.username, data.passwordHash, serverLAN);
					if check then
						permissionLevel = cryptoNet.getPermissionLevel(data.username, serverLAN);
						cryptoNet.send(socket, {
							message,
							true,
							permissionLevel
						});
					else
						cryptoNet.send(socket, {
							message,
							false,
							0
						});
					end;
				end;
			elseif message == "setPassword" then
				print(socket.username .. " requested: " .. tostring(message));
				local permissionLevel = cryptoNet.getPermissionLevel(socket.username, serverLAN);
				local userExists = cryptoNet.userExists(data.username, serverLAN);
				debugLog("setPassword:" .. socket.username .. ":" .. data.username .. ":" .. tostring(permissionLevel) .. ":" .. tostring(userExists));
				if tonumber(permissionLevel) >= 2 and userExists and type(data.password) == "string" then
					cryptoNet.setPassword(data.username, data.password, serverLAN);
					cryptoNet.send(socket, {
						message,
						true
					});
				elseif userExists and data.username == socket.username then
					cryptoNet.setPassword(data.username, data.password, serverLAN);
					cryptoNet.send(socket, {
						message,
						true
					});
				else
					cryptoNet.send(socket, {
						message,
						false
					});
				end;
			elseif message == "setPasswordHashed" then
				print(socket.username .. " requested: " .. tostring(message));
				local permissionLevel = cryptoNet.getPermissionLevel(socket.username, serverLAN);
				local userExists = cryptoNet.userExists(data.username, serverLAN);
				debugLog("setPassword:" .. socket.username .. ":" .. data.username .. ":" .. tostring(permissionLevel) .. ":" .. tostring(userExists));
				if tonumber(permissionLevel) >= 2 and userExists and type(data.passwordHash) == "string" then
					cryptoNet.setPasswordHashed(data.username, data.passwordHash, serverLAN);
					cryptoNet.send(socket, {
						message,
						true
					});
				elseif userExists and data.username == socket.username then
					cryptoNet.setPasswordHashed(data.username, data.passwordHash, serverLAN);
					cryptoNet.send(socket, {
						message,
						true
					});
				else
					cryptoNet.send(socket, {
						message,
						false
					});
				end;
			elseif message == "addUser" then
				print(socket.username .. " requested: " .. tostring(message));
				print("Request to add user: " .. data.username);
				log("Request to add user: " .. data.username);
				local permissionLevel = cryptoNet.getPermissionLevel(socket.username, serverLAN);
				local userExists = cryptoNet.userExists(data.username, serverLAN);
				if permissionLevel >= 2 and (not userExists) and type(data.password) == "string" then
					cryptoNet.addUser(data.username, data.password, data.permissionLevel, serverLAN);
					cryptoNet.send(socket, {
						message,
						true
					});
				else
					cryptoNet.send(socket, {
						message,
						false
					});
				end;
			elseif message == "addUserHashed" then
				print(socket.username .. " requested: " .. tostring(message));
				print("Request to add user: " .. data.username);
				log("Request to add user: " .. data.username);
				local permissionLevel = cryptoNet.getPermissionLevel(socket.username, serverLAN);
				local userExists = cryptoNet.userExists(data.username, serverLAN);
				if permissionLevel >= 2 and (not userExists) and type(data.passwordHash) == "string" then
					cryptoNet.addUserHashed(data.username, data.passwordHash, data.permissionLevel, serverLAN);
					cryptoNet.send(socket, {
						message,
						true
					});
				else
					cryptoNet.send(socket, {
						message,
						false
					});
				end;
			elseif message == "deleteUser" then
				print(socket.username .. " requested: " .. tostring(message));
				print("Request to delete user: " .. data.username);
				log("Request to delete user: " .. data.username);
				local permissionLevel = cryptoNet.getPermissionLevel(socket.username, serverLAN);
				local userExists = cryptoNet.userExists(data.username, serverLAN);
				if permissionLevel >= 2 and userExists then
					local userPermissionLevel = cryptoNet.getPermissionLevel(data.username, serverLAN);
					if userPermissionLevel < 3 then
						cryptoNet.deleteUser(data.username, serverLAN);
						cryptoNet.send(socket, {
							message,
							true
						});
					else
						cryptoNet.send(socket, {
							message,
							false
						});
					end;
				else
					cryptoNet.send(socket, {
						message,
						false
					});
				end;
			elseif message == "getCurrentlyCrafting" then
				debugLog("gotCurrentlyCrafting: " .. dump(data));
				os.queueEvent("gotCurrentlyCrafting", data);
			elseif message == "getCraftingQueue" then
				os.queueEvent("gotCraftingQueue", data);
			elseif message == "pushCurrentlyCrafting" then
				debugLog("gotCurrentlyCrafting: " .. dump(data));
				currentlyCrafting = data;
			elseif message == "pushCraftingQueue" then
				craftingQueue = data;
			elseif message == "getFreeSlots" then
				local tmp = {};
				tmp.freeSlots = storageFreeSlots;
				tmp.totalSlots = storageTotalSlots;
				cryptoNet.send(socket, {
					message,
					tmp
				});
			elseif message == "pullItems" then
				debugLog("pullItems:" .. dump(data));
				local itemsMoved = (peripheral.wrap(data.craftingChest)).pullItems(data.chestName, data.slot, data.moveCount);
				cryptoNet.send(socket, {
					message,
					itemsMoved
				});
				local patchstatus = patchStorageDatabase(data, (-1) * itemsMoved, data.chestName, data.slot);
			elseif message == "patchStorageDatabase" then
				local patchstatus = patchStorageDatabase(data, data.count, data.chestName, data.slot);
			end;
		elseif event[2] ~= nil then
			local message = event[2][1];
			local data = event[2][2];
			if message == "hashLogin" then
				print("User login request for: " .. data.username);
				log("User login request for: " .. data.username);
				local loginStatus = cryptoNet.checkPassword(data.username, data.password, serverLAN);
				data.password = nil;
				local permissionLevel = cryptoNet.getPermissionLevel(data.username, serverLAN);
				if loginStatus == true then
					cryptoNet.send(socket, {
						"hashLogin",
						true,
						permissionLevel
					});
					socket.username = data.username;
					socket.permissionLevel = permissionLevel;
					for k, v in pairs(serverLAN.sockets) do
						if v.target == socket.target then
							serverLAN.sockets[k] = socket;
							break;
						end;
					end;
					if type(serverWireless) == "table" then
						for k, v in pairs(serverWireless.sockets) do
							if v.target == socket.target then
								serverWireless.sockets[k] = socket;
								break;
							end;
						end;
					end;
					os.queueEvent("hash_login", socket.username, socket);
				else
					print("User: " .. data.username .. " failed to login");
					log("User: " .. data.username .. " failed to login");
					cryptoNet.send(socket, {
						"hashLogin",
						false
					});
				end;
			elseif message == "requireLogin" then
				cryptoNet.send(socket, {
					message,
					settings.get("requireLogin")
				});
			else
				debugLog("User is not logged in. Sender: " .. socket.sender .. " Target: " .. socket.target);
				cryptoNet.send(socket, {
					"requireLogin"
				});
				cryptoNet.send(socket, "Sorry, I only talk to logged in users");
			end;
		end;
	elseif event[1] == "connection_closed" then
		local socket = event[2];
		log("connection closed: " .. tostring(socket.username) .. ":" .. string.sub(tostring(socket.target), 1, 5) .. ":" .. tostring(socket.sender));
		for i in pairs(clients) do
			if clients[i].target == socket.target then
				if mainCraftingServer ~= nil and clients[i].target == mainCraftingServer.target then
					mainCraftingServer = nil;
				end;
				table.remove(clients, i);
				print("Client Disconnected: " .. tostring(socket.username) .. ":" .. string.sub(tostring(socket.target), 1, 5) .. ":" .. tostring(socket.sender));
			end;
		end;
		printClients();
	end;
end;
local function onStart()
	os.setComputerLabel(settings.get("serverName"));
	if fs.exists("logs/server.log") then
		fs.delete("logs/server.log");
	end;
	if fs.exists("logs/serverDebug.log") then
		fs.delete("logs/serverDebug.log");
	end;
	cryptoNet.closeAll();
	local wirelessModem = nil;
	local wiredModem = nil;
	print("Looking for connected modems...");
	debugLog("Looking for connected modems");
	for _, side in ipairs(peripheral.getNames()) do
		if peripheral.getType(side) == "modem" or peripheral.getType(side) == "peripheral_hub" then
			local modem = peripheral.wrap(side);
			if modem.isWireless() then
				wirelessModem = modem;
				wirelessModem.side = side;
				print("Wireless modem found on " .. side .. " side");
				debugLog("Wireless modem found on " .. side .. " side");
			else
				wiredModem = modem;
				wiredModem.side = side;
				print("Wired modem found on " .. side .. " side");
				debugLog("Wired modem found on " .. side .. " side");
			end;
		elseif peripheral.getType(side) == "monitor" then
			table.insert(monitors, side);
		end;
	end;
	if type(wiredModem) ~= "nil" then
		
		debugLog("Starting wired cryptoNet server on side " .. wiredModem.side);
		serverLAN = cryptoNet.host(settings.get("serverName", true, false, wiredModem.side));
	end;
	if type(wirelessModem) ~= "nil" then
		debugLog("Starting wireless cryptoNet server on side " .. wirelessModem.side);
		serverWireless = cryptoNet.host(settings.get("serverName") .. "_Wireless", true, false, wirelessModem.side);
	end;
	local speed = os.epoch("utc") / 1000 - serverBootTime;
	print("Boot time: " .. tostring(("%.3g"):format(speed) .. " seconds"));
	debugLog("Boot time: " .. tostring(("%.3g"):format(speed) .. " seconds"));
	if next(monitors) then
		os.startThread(draw);
	end;
	--importHandler();
end;
local function sendToClients(text)
	for i in pairs(clients) do
		rednet.send(clients[i], text);
	end;
end;
function centerText(text)
	x, y = monitor.getSize();
	x1, y1 = monitor.getCursorPos();
	monitor.setCursorPos(math.floor(x / 2) - math.floor((#text) / 2), y1);
	monitor.write(text);
end;

local function server()
	while true do
		local id, message = rednet.receive();
		print(("Computer %d sent message %s"):format(id, message));
		if message == "rsServer" then
			rednet.send(id, tostring(os.computerID()));
			local uniq = true;
			for i in pairs(clients) do
				if clients[i] == id then
					uniq = false;
				end;
			end;
			if uniq then
				clients[(#clients) + 1] = id;
			end;
			print("");
			print("clients: ");
			for i in pairs(clients) do
				print(tostring(clients[i]));
			end;
			print("");
		elseif message == "getItems" then
			print(bridge.getItems());
			rednet.send(id, bridge.getItems());
		elseif message == "getItem" then
			local id2, message2 = rednet.receive();
			print(bridge.listItem(message2));
			rednet.send(id, bridge.getItem(message2));
		elseif message == "import" then
			local id2, message2;
			repeat
				id2, message2 = rednet.receive();
			until id == id2;
			bridge.importItemFromPeripheral(message2, enderChestSide);
		elseif message == "importAll" then
			local list = (peripheral.wrap(enderChestSide)).list();
			for i in pairs(list) do
				bridge.importItemFromPeripheral(list[i], enderChestSide);
			end;
		elseif message == "export" then
			local id2, message2;
			repeat
				id2, message2 = rednet.receive();
			until id == id2;
			print("got");
			print(tostring(message2));
			print(message2.name);
			print(message2.count);
			local result = bridge.exportItem(message2, enderChestSide);
			print(result);
		end;
	end;
end;

--[[
while true do
	parallel.waitForAny(server, draw);
	sleep(1);
end;
]]

cryptoNet.setLoggingEnabled(true)
cryptoNet.startEventLoop(onStart, onCryptoNetEvent)

cryptoNet.closeAll()