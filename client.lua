local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP          = Proxy.getInterface("vRP")
vSERVER      = Tunnel.getInterface("radar")

local DEBUG = true

local function Log(...)
	if DEBUG then print("[RADAR][CLIENT]", ...) end
end

local DrawConfig = {
	DrawDepth    = 3.0,
	MarkerHeight = 0.25
}

local RadarTypes = {
	{ type = 50,  name = "50 km/h",  prop = "prop_traffic_50sign_warning_1a" },
	{ type = 60,  name = "60 km/h",  prop = "prop_traffic_60sign_warning_1a" },
	{ type = 80,  name = "80 km/h",  prop = "prop_traffic_80sign_warning_1b" },
	{ type = 110, name = "110 km/h", prop = "prop_traffic_80sign_warning_1b" }
}

local Markers       = {}
local Reported      = {}
local DrawMode      = false
local DrawStage     = 0
local TempProp      = nil
local TempData      = {}
local RadarList     = {}
local Synced        = false

local function InBox(px, py, cx, cy, heading, width, depth)
	local dx, dy = px - cx, py - cy
	local rad = math.rad(-heading)
	local lx = dx * math.cos(rad) - dy * math.sin(rad)
	local ly = dx * math.sin(rad) + dy * math.cos(rad)
	return math.abs(lx) <= (width / 2) and math.abs(ly) <= (depth / 2)
end

local function GetRadarType(speedType)
	for _, t in ipairs(RadarTypes) do
		if t.type == speedType then return t end
	end
	return nil
end

local function SpawnPropAsync(radarType, x, y, z, heading, onDone)
	CreateThread(function()
		local hash = GetHashKey(radarType.prop)
		RequestModel(hash)
		local timeout = 0
		while not HasModelLoaded(hash) do
			Wait(10)
			timeout = timeout + 10
			if timeout > 5000 then
				Log("WARN: timeout ao carregar modelo " .. radarType.prop)
				return
			end
		end
		local prop = CreateObject(hash, x, y, z, true, true, false)
		SetEntityHeading(prop, heading or 0.0)
		FreezeEntityPosition(prop, true)
		SetModelAsNoLongerNeeded(hash)
		Log("Prop criada handle=" .. tostring(prop) .. " tipo=" .. radarType.prop)
		if onDone then onDone(prop) end
	end)
end

local function SafeDeleteProp(markerId)
	local m = Markers[markerId]
	if m and m.propEntity then
		if DoesEntityExist(m.propEntity) then
			Log("Deletando prop handle=" .. tostring(m.propEntity) .. " radarId=" .. tostring(markerId))
			DeleteEntity(m.propEntity)
		end
		m.propEntity = nil
	end
end

RegisterNUICallback('getList', function(data, cb)
	RadarList = vSERVER.GetList()
	cb(RadarList or {})
end)

RegisterNUICallback('selectType', function(data, cb)
	if DrawMode then
		DrawMode  = false
		DrawStage = 0
		if TempProp and DoesEntityExist(TempProp) then
			DeleteEntity(TempProp)
			TempProp = nil
		end
	end

	local ped     = PlayerPedId()
	local pos     = GetEntityCoords(ped)
	local heading = GetEntityHeading(ped)

	local forwardX = math.cos(math.rad(heading)) * 3.0
	local forwardY = math.sin(math.rad(heading)) * 3.0

	local speedType  = data.speedType
	local speedLimit = data.speedLimit or speedType

	DrawMode  = true
	DrawStage = 1
	TempData  = {
		speedType   = speedType,
		speedLimit  = speedLimit,
		propX       = pos.x + forwardX,
		propY       = pos.y + forwardY,
		propZ       = pos.z - 1.0,
		propHeading = heading,
		zoneX       = pos.x + forwardX,
		zoneY       = pos.y + forwardY,
		zoneZ       = pos.z - 1.0,
		zoneHeading = heading,
		zoneWidth   = 8.0,
		zoneDepth   = 8.0,
	}

	local radarType = GetRadarType(speedType)
	if radarType then
		SpawnPropAsync(radarType, TempData.propX, TempData.propY, TempData.propZ, TempData.propHeading, function(prop)
			TempProp = prop
		end)
		SendNUIMessage({ action = 'showCreator' })
		TriggerEvent("Notify", "Radar", "Criando radar de " .. radarType.name, "azul", 5000)
	end

	cb({})
end)

RegisterNUICallback('move', function(data, cb)
	local speed = 0.15
	if DrawStage == 1 then
		if     data.direction == 'forward' then
			TempData.propX = TempData.propX + math.cos(math.rad(TempData.propHeading)) * speed
			TempData.propY = TempData.propY + math.sin(math.rad(TempData.propHeading)) * speed
		elseif data.direction == 'back' then
			TempData.propX = TempData.propX - math.cos(math.rad(TempData.propHeading)) * speed
			TempData.propY = TempData.propY - math.sin(math.rad(TempData.propHeading)) * speed
		elseif data.direction == 'left' then
			TempData.propX = TempData.propX - math.sin(math.rad(TempData.propHeading)) * speed
			TempData.propY = TempData.propY + math.cos(math.rad(TempData.propHeading)) * speed
		elseif data.direction == 'right' then
			TempData.propX = TempData.propX + math.sin(math.rad(TempData.propHeading)) * speed
			TempData.propY = TempData.propY - math.cos(math.rad(TempData.propHeading)) * speed
		elseif data.direction == 'up'   then TempData.propZ = TempData.propZ + speed
		elseif data.direction == 'down' then TempData.propZ = TempData.propZ - speed
		end
		if TempProp and DoesEntityExist(TempProp) then
			SetEntityCoords(TempProp, TempData.propX, TempData.propY, TempData.propZ)
			SetEntityHeading(TempProp, TempData.propHeading)
		end

	elseif DrawStage == 2 then
		if     data.direction == 'forward' then
			TempData.zoneX = TempData.zoneX + math.cos(math.rad(TempData.zoneHeading)) * speed
			TempData.zoneY = TempData.zoneY + math.sin(math.rad(TempData.zoneHeading)) * speed
		elseif data.direction == 'back' then
			TempData.zoneX = TempData.zoneX - math.cos(math.rad(TempData.zoneHeading)) * speed
			TempData.zoneY = TempData.zoneY - math.sin(math.rad(TempData.zoneHeading)) * speed
		elseif data.direction == 'left' then
			TempData.zoneX = TempData.zoneX - math.sin(math.rad(TempData.zoneHeading)) * speed
			TempData.zoneY = TempData.zoneY + math.cos(math.rad(TempData.zoneHeading)) * speed
		elseif data.direction == 'right' then
			TempData.zoneX = TempData.zoneX + math.sin(math.rad(TempData.zoneHeading)) * speed
			TempData.zoneY = TempData.zoneY - math.cos(math.rad(TempData.zoneHeading)) * speed
		elseif data.direction == 'up'   then TempData.zoneZ = TempData.zoneZ + speed
		elseif data.direction == 'down' then TempData.zoneZ = TempData.zoneZ - speed
		end
	end
	cb({})
end)

RegisterNUICallback('rotate', function(data, cb)
	local speed = 3.0
	if DrawStage == 1 then
		if data.direction == 'left'  then TempData.propHeading = TempData.propHeading - speed
		elseif data.direction == 'right' then TempData.propHeading = TempData.propHeading + speed end
		if TempProp and DoesEntityExist(TempProp) then SetEntityHeading(TempProp, TempData.propHeading) end
	elseif DrawStage == 2 then
		if data.direction == 'left'  then TempData.zoneHeading = TempData.zoneHeading - speed
		elseif data.direction == 'right' then TempData.zoneHeading = TempData.zoneHeading + speed end
	end
	cb({})
end)

RegisterNUICallback('updateSize', function(data, cb)
	TempData.zoneWidth = data.width
	TempData.zoneDepth = data.depth
	cb({})
end)

RegisterNUICallback('confirm', function(data, cb)
	if DrawStage == 1 then
		DrawStage = 2
		SendNUIMessage({ action = 'showCreator', stage = 2 })
	else
		if TempProp and DoesEntityExist(TempProp) then
			DeleteEntity(TempProp)
			TempProp = nil
		end
		FreezeEntityPosition(PlayerPedId(), false)

		vSERVER.CreateRadar(
			TempData.speedType,
			TempData.propX, TempData.propY, TempData.propZ, TempData.propHeading,
			TempData.zoneX, TempData.zoneY, TempData.zoneZ, TempData.zoneHeading,
			TempData.zoneWidth, TempData.zoneDepth,
			TempData.speedLimit
		)

		DrawMode  = false
		DrawStage = 0
		SendNUIMessage({ action = 'close' })
		SetNuiFocus(false, false)
	end
	cb({})
end)

RegisterNUICallback('cancel', function(data, cb)
	if TempProp and DoesEntityExist(TempProp) then
		DeleteEntity(TempProp)
		TempProp = nil
	end
	FreezeEntityPosition(PlayerPedId(), false)
	DrawMode  = false
	DrawStage = 0
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'close' })
	cb({})
end)

RegisterNUICallback('closeUI', function(data, cb)
	DrawMode  = false
	DrawStage = 0
	TempData  = {}
	if TempProp and DoesEntityExist(TempProp) then
		DeleteEntity(TempProp)
		TempProp = nil
	end
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'close' })
	cb({})
end)

RegisterNUICallback('deleteRadar', function(data, cb)
	local radarId = tonumber(data.id)
	Log("Delete solicitado para ID=" .. tostring(radarId))

	DrawMode  = false
	DrawStage = 0
	TempData  = {}
	if TempProp and DoesEntityExist(TempProp) then
		DeleteEntity(TempProp)
		TempProp = nil
	end

	SafeDeleteProp(radarId)

	if radarId and radarId > 0 then
		vSERVER.Remove(radarId)
	end

	Log("Delete enviado ao server")
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'close' })
	cb({})
end)

RegisterNetEvent("radar:AddMarker")
AddEventHandler("radar:AddMarker", function(id, data)
	SafeDeleteProp(id)

	Markers[id] = {
		id          = data.id or id,
		speedType   = data.speedType,
		speedLimit  = data.speedLimit,
		x           = data.x,
		y           = data.y,
		z           = data.z,
		heading     = data.heading,
		width       = data.width,
		depth       = data.depth,
		propX       = data.propX,
		propY       = data.propY,
		propZ       = data.propZ,
		propHeading = data.propHeading,
		active      = data.active,
		propEntity  = nil
	}

	if data.propX then
		local radarType    = GetRadarType(data.speedType)
		local capturedId   = id
		if radarType then
			SpawnPropAsync(radarType, data.propX, data.propY, data.propZ, data.propHeading, function(prop)
				if Markers[capturedId] then
					Markers[capturedId].propEntity = prop
					Log("AddMarker: prop OK radarId=" .. tostring(capturedId) .. " handle=" .. tostring(prop))
				else
					Log("AddMarker: marker " .. tostring(capturedId) .. " removido durante load, deletando prop")
					DeleteEntity(prop)
				end
			end)
		end
	end
end)

RegisterNetEvent("radar:RemoveMarker")
AddEventHandler("radar:RemoveMarker", function(id)
	Log("RemoveMarker radarId=" .. tostring(id))
	SafeDeleteProp(id)
	Markers[id] = nil
end)

RegisterNetEvent("radar:ClearAll")
AddEventHandler("radar:ClearAll", function()
	Log("ClearAll recebido")
	for id, _ in pairs(Markers) do
		SafeDeleteProp(id)
	end
	Markers = {}
end)

RegisterNetEvent("radar:SyncAll")
AddEventHandler("radar:SyncAll", function(list)
	Log("SyncAll recebido, limpando " .. tostring(#Markers) .. " markers anteriores")

	for id, _ in pairs(Markers) do
		SafeDeleteProp(id)
	end
	Markers = {}

	if not list then
		Log("SyncAll: lista vazia ou nil")
		return
	end

	local count = 0
	for id, data in pairs(list) do
		local capturedId = id

		Markers[capturedId] = {
			id          = data.id or capturedId,
			speedType   = data.speedType,
			speedLimit  = data.speedLimit,
			x           = data.x,
			y           = data.y,
			z           = data.z,
			heading     = data.heading,
			width       = data.width,
			depth       = data.depth,
			propX       = data.propX,
			propY       = data.propY,
			propZ       = data.propZ,
			propHeading = data.propHeading,
			active      = data.active,
			propEntity  = nil
		}

		if data.propX then
			local radarType = GetRadarType(data.speedType)
			if radarType then
				SpawnPropAsync(radarType, data.propX, data.propY, data.propZ, data.propHeading, function(prop)
					if Markers[capturedId] then
						Markers[capturedId].propEntity = prop
						Log("SyncAll: prop OK radarId=" .. tostring(capturedId) .. " handle=" .. tostring(prop))
					else
						Log("SyncAll: marker " .. tostring(capturedId) .. " removido durante load, deletando prop")
						DeleteEntity(prop)
					end
				end)
			end
		end

		count = count + 1
	end

	Synced = true
	Log("SyncAll: " .. count .. " radares carregados")
end)

RegisterCommand("radar", function(source, args)
	Log("/radar command executed")
	if DrawMode then
		Log("DrawMode is true, returning")
		return
	end
	CreateThread(function()
		if not Synced then
			Log("/radar: waiting for sync...")
			local attempts = 0
			while not Synced and attempts < 20 do
				Wait(200)
				attempts = attempts + 1
			end
			Log("/radar: sync complete, attempts="..attempts)
		end

		RadarList = vSERVER.GetList()
		Log("/radar: GetList returned "..tostring(#RadarList).." radars")

		SetNuiFocus(true, true)
		SendNUIMessage({ action = 'showList', radars = RadarList or {} })
	end)
end, false)

CreateThread(function()
	while true do
		local hasMarkers = next(Markers) ~= nil

		if not hasMarkers and not DrawMode then
			Wait(2000)
		else
			Wait(0)

			local ped   = PlayerPedId()
			local pos   = GetEntityCoords(ped)
			local inVeh = IsPedInAnyVehicle(ped, false)
			local speed = 0.0

			if DrawMode and DrawStage == 1 and TempProp and DoesEntityExist(TempProp) then
				local dist = #(pos - GetEntityCoords(TempProp))
				if dist < 100.0 then
					DrawMarker(43,
						TempData.propX, TempData.propY, TempData.propZ,
						0.0, 0.0, 0.0, 0.0, 0.0, TempData.propHeading,
						1.5, 1.5, 0.3, 220, 30, 30, 160,
						false, false, 2, false, nil, nil, false)
				end
			elseif DrawMode and DrawStage == 2 then
				local dist = #(pos - vector3(TempData.zoneX, TempData.zoneY, TempData.zoneZ))
				if dist < 100.0 then
					DrawMarker(43,
						TempData.zoneX, TempData.zoneY, TempData.zoneZ,
						0.0, 0.0, 0.0, 0.0, 0.0, TempData.zoneHeading,
						TempData.zoneWidth, TempData.zoneDepth, 0.2,
						0, 200, 100, 180,
						false, false, 2, false, nil, nil, false)
				end
			end

			if inVeh then
				speed = GetEntitySpeed(GetVehiclePedIsIn(ped, false)) * 3.6
			end

			Reported = {}

			for id, data in pairs(Markers) do
				if inVeh and not Reported[id] then
					local dist = #(pos - vector3(data.x, data.y, data.z))
					if dist < (data.width or 10.0) + 10.0 then
						local W      = data.width  or 10.0
						local D      = data.depth  or DrawConfig.DrawDepth
						local inside = InBox(pos.x, pos.y, data.x, data.y, data.heading, W, D + 8.0)

						if inside then
							local limit     = data.speedLimit or data.speedType or 80
							local threshold = limit * 1.1
							if speed > threshold then
								Reported[id] = true
								Log("Fine disparado radarId=" .. tostring(id) .. " speed=" .. string.format("%.1f", speed) .. " limit=" .. tostring(limit))
								vSERVER.Fine(id, speed)
							end
						end
					end
				end
			end
		end
	end
end)

AddEventHandler("playerSpawned", function()
	CreateThread(function()
		Wait(3000)
		Log("playerSpawned: solicitando GetAll")
		local all = vSERVER.GetAll()
		if all then
			Log("playerSpawned: Got "..tostring(#all).." radars")
			TriggerEvent("radar:SyncAll", all)
		else
			Log("playerSpawned: GetAll retornou nil/vazio, tentando novamente...")
			local all2 = vSERVER.GetAll()
			if all2 then
				TriggerEvent("radar:SyncAll", all2)
			end
		end
	end)
end)

AddEventHandler("onClientResourceStart", function(res)
	if res ~= GetCurrentResourceName() then return end
	Synced = false
	CreateThread(function()
		Wait(3000)
		Log("onClientResourceStart: solicitando SyncAll")
		local all = vSERVER.GetAll()
		if all then TriggerEvent("radar:SyncAll", all) end
	end)
end)

print("[RADAR][CLIENT] Script carregado!")
