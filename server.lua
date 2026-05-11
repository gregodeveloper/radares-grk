local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")

Radar = {}
Tunnel.bindInterface("radar",Radar)

local Radars    = {}
local Cooldowns = {}

vRP.Prepare("sradar/CreateTable", "CREATE TABLE IF NOT EXISTS sradar_radars (id INT AUTO_INCREMENT PRIMARY KEY, speedType INT NOT NULL, speedLimit INT DEFAULT 80, propX FLOAT NOT NULL, propY FLOAT NOT NULL, propZ FLOAT NOT NULL, propHeading FLOAT NOT NULL, zoneX FLOAT NOT NULL, zoneY FLOAT NOT NULL, zoneZ FLOAT NOT NULL, zoneHeading FLOAT NOT NULL, zoneWidth FLOAT NOT NULL, zoneDepth FLOAT NOT NULL, active TINYINT(1) DEFAULT 1)")
vRP.Prepare("sradar/SelectAll", "SELECT * FROM sradar_radars")
vRP.Prepare("sradar/Insert", "INSERT INTO sradar_radars (speedType, speedLimit, propX, propY, propZ, propHeading, zoneX, zoneY, zoneZ, zoneHeading, zoneWidth, zoneDepth, active) VALUES (@speedType, @speedLimit, @propX, @propY, @propZ, @propHeading, @zoneX, @zoneY, @zoneZ, @zoneHeading, @zoneWidth, @zoneDepth, @active)")
vRP.Prepare("sradar/Update", "UPDATE sradar_radars SET zoneX = @zoneX, zoneY = @zoneY, zoneZ = @zoneZ, zoneHeading = @zoneHeading, zoneWidth = @zoneWidth, zoneDepth = @zoneDepth, active = @active WHERE id = @id")
vRP.Prepare("sradar/Delete", "DELETE FROM sradar_radars WHERE id = @id")
vRP.Prepare("sradar/GetLastInsertId", "SELECT LAST_INSERT_ID() as lastId")

local function HasPermission(source)
	if not Config.AdminGroup then return true end
	local Passport = vRP.Passport(source)
	if not Passport then return false end
	return vRP.HasService(Passport, Config.AdminGroup)
end

local function CalcFine(speedType, speed)
	local cfg = Config.RadarTypes[speedType]
	if not cfg then return 500 end

	local limit = cfg.speedLimit
	local excess = speed - limit
	if excess <= 0 then return cfg.fineBase end

	local steps = math.max(0, math.floor(excess / 10))
	local multiplier = (1 + cfg.fineStepPct / 100) ^ steps
	return math.floor(cfg.fineBase * multiplier)
end

local function InCooldown(passport, radarId)
	if not Cooldowns[passport] or not Cooldowns[passport][radarId] then return false end
	return (os.time() - Cooldowns[passport][radarId]) < Config.Cooldown
end

local function SetCooldown(passport, radarId)
	if not Cooldowns[passport] then Cooldowns[passport] = {} end
	Cooldowns[passport][radarId] = os.time()
end

local function NormalizeQueryResult(result)
	if not result then return {} end
	if result[1] then return result end
	if result.id then return { result } end
	return {}
end

CreateThread(function()
	Wait(2000)

	vRP.Query("sradar/CreateTable", {})

	local result = vRP.Query("sradar/SelectAll", {})
	local rows = NormalizeQueryResult(result)
	local count = 0

	for _, v in ipairs(rows) do
		if v.id and not Radars[v.id] then
			local speedType = v.speedType
			local radarCfg = Config.RadarTypes[speedType]
			local isActive = (v.active == 1 or v.active == nil or v.active == true)
			Radars[v.id] = {
				id          = v.id,
				speedType   = speedType,
				speedLimit  = v.speedLimit or (radarCfg and radarCfg.speedLimit) or 80,
				x           = v.zoneX,
				y           = v.zoneY,
				z           = v.zoneZ,
				heading     = v.zoneHeading,
				width       = v.zoneWidth,
				depth       = v.zoneDepth,
				propX       = v.propX,
				propY       = v.propY,
				propZ       = v.propZ,
				propHeading = v.propHeading,
				active      = isActive,
				creator     = 0
			}
			count = count + 1
		end
	end

	TriggerClientEvent("radar:SyncAll", -1, Radars)
end)

function Radar.CreateRadar(speedType, propX, propY, propZ, propHeading, zoneX, zoneY, zoneZ, zoneHeading, zoneWidth, zoneDepth, speedLimit)
	local source = source

	if not source or source == 0 then return end

	local radarCfg = Config.RadarTypes[speedType]
	if not radarCfg then return end

	if not HasPermission(source) then
		TriggerClientEvent("Notify", source, "Erro", "Sem permissão.", "vermelho", 5000)
		return
	end

	local finalSpeedLimit = speedLimit or radarCfg.speedLimit

	vRP.Query("sradar/Insert", {
		speedType    = speedType,
		speedLimit   = finalSpeedLimit,
		propX        = propX,
		propY        = propY,
		propZ        = propZ,
		propHeading  = propHeading,
		zoneX        = zoneX,
		zoneY        = zoneY,
		zoneZ        = zoneZ,
		zoneHeading  = zoneHeading,
		zoneWidth    = zoneWidth,
		zoneDepth    = zoneDepth,
		active       = 1
	})

	local rawId = vRP.Scalar("sradar/GetLastInsertId", {})
	local newId

	if type(rawId) == "number" then
		newId = math.floor(rawId)
	elseif type(rawId) == "table" then
		newId = tonumber(rawId.lastId) or nil
	else
		newId = tonumber(rawId)
	end

	if not newId or newId <= 0 then
		TriggerClientEvent("Notify", source, "Radar", "Erro ao salvar radar.", "vermelho", 5000)
		return
	end

	if Radars[newId] then
		return
	end

	Radars[newId] = {
		id          = newId,
		speedType   = speedType,
		speedLimit  = finalSpeedLimit,
		x           = zoneX,
		y           = zoneY,
		z           = zoneZ,
		heading     = zoneHeading,
		width       = zoneWidth,
		depth       = zoneDepth,
		propX       = propX,
		propY       = propY,
		propZ       = propZ,
		propHeading = propHeading,
		active      = true,
		creator     = source
	}

	TriggerClientEvent("radar:AddMarker", -1, newId, Radars[newId])
	TriggerClientEvent("Notify", source, "Radar", "Radar #"..newId.." ("..finalSpeedLimit.." km/h) criado!", "verde", 5000)
end

function Radar.Remove(id)
	local source = source
	id = tonumber(id)

	if not id or not Radars[id] then
		TriggerClientEvent("Notify", source, "Erro", "Radar #"..tostring(id).." não encontrado.", "vermelho", 5000)
		return
	end

	local radar = Radars[id]
	local passport = vRP.Passport(source)
	if not HasPermission(source) and radar.creator ~= passport then
		TriggerClientEvent("Notify", source, "Erro", "Sem permissão.", "vermelho", 5000)
		return
	end

	vRP.Query("sradar/Delete", { id = id })
	Radars[id] = nil
	TriggerClientEvent("radar:RemoveMarker", -1, id)
	TriggerClientEvent("Notify", source, "Radar", "Radar #"..id.." removido.", "amarelo", 5000)
end

function Radar.GetAll()
	return Radars
end

function Radar.GetList()
	local list = {}
	local count = 0
	for id, radar in pairs(Radars) do
		count = count + 1
		local radarCfg = Config.RadarTypes[radar.speedType]
		table.insert(list, {
			id        = id,
			speedType = radar.speedType,
			speedLimit = radar.speedLimit,
			speedName = radarCfg and radarCfg.name or "Desconhecido",
			x         = radar.x,
			y         = radar.y,
			z         = radar.z,
			active    = radar.active
		})
	end
	return list
end

function Radar.Fine(radarId, speed)
	local source  = source
	radarId = tonumber(radarId)
	speed   = tonumber(speed)

	if not Radars[radarId] or not Radars[radarId].active then return end

	local radar = Radars[radarId]
	local radarCfg = Config.RadarTypes[radar.speedType]
	if not radarCfg then return end

	local limit = radar.speedLimit or radarCfg.speedLimit
	local tolerance = radarCfg.tolerance or 10
	local threshold = limit * (1 + tolerance / 100)

	if not speed or speed < threshold then return end

	local Passport = vRP.Passport(source)
	if not Passport then return end
	if InCooldown(Passport, radarId) then return end

	local fineAmount = CalcFine(radar.speedType, speed)

	if vRP.PaymentFull(Passport, fineAmount, true) then
		SetCooldown(Passport, radarId)
		local msg = string.format(
			"Multa de trânsito! Velocidade: %.0f km/h (limite %d + %d%% tolerância). -$%d",
			speed, limit, tolerance, fineAmount
		)
		TriggerClientEvent("Notify", source, "aviso", msg, "vermelho", 8000)
	else
		TriggerClientEvent("Notify", source, "Multa de Trânsito", "Saldo insuficiente para pagar a multa de $"..fineAmount.."!", "vermelho", 5000)
	end
end

RegisterNetEvent("radar:CmdRemove")
AddEventHandler("radar:CmdRemove", function(id)
	Radar.Remove(tonumber(id))
end)

RegisterCommand("radarclear", function(source, args)
	if not HasPermission(source) then
		TriggerClientEvent("Notify", source, "Erro", "Sem permissão.", "vermelho", 5000)
		return
	end

	local count = 0
	for id, _ in pairs(Radars) do
		vRP.Query("sradar/Delete", { id = id })
		Radars[id] = nil
		count = count + 1
	end

	TriggerClientEvent("radar:ClearAll", -1)
	TriggerClientEvent("Notify", source, "Radar", count.." radares removidos.", "amarelo", 5000)
end, false)
