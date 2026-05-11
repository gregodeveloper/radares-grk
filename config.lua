Config = {}

-- Grupo de admin necessário para criar/remover radares (nil = todos podem)
Config.AdminGroup = nil

-- Cooldown em segundos entre multas do mesmo radar para o mesmo jogador
Config.Cooldown = 4

-- ─────────────────────────────────────────────────────────────────────────────
-- TIPOS DE RADAR
--
-- Para cada tipo:
--   name         → label exibido na NUI e notificações
--   prop         → modelo 3D colocado no mundo
--   speedLimit   → limite de velocidade (km/h)
--   tolerance    → tolerância em % ACIMA do limite antes de multar
--                  ex: 10 = só multa acima de limit * 1.10
--   fineBase     → valor base da multa (R$)
--   fineStepPct  → % de aumento do valor base a cada 10 km/h acima do limite
--                  ex: 20 = +20% do valor base por cada faixa de 10 km/h
-- ─────────────────────────────────────────────────────────────────────────────
Config.RadarTypes = {
    [50] = {
        name        = "50 km/h",
        prop        = "prop_traffic_50sign_warning_1a",
        speedLimit  = 50,
        tolerance   = 10,   -- só multa acima de 55 km/h
        fineBase    = 300,  -- R$ 300 de multa base
        fineStepPct = 20    -- +20% a cada 10 km/h acima do limite
                            -- ex: 56-65 km/h → R$300  |  66-75 → R$360  |  76-85 → R$432 ...
    },
    [60] = {
        name        = "60 km/h",
        prop        = "prop_traffic_60sign_warning_1a",
        speedLimit  = 60,
        tolerance   = 10,   -- só multa acima de 66 km/h
        fineBase    = 400,
        fineStepPct = 15    -- +15% a cada 10 km/h acima do limite
    },
    [80] = {
        name        = "80 km/h",
        prop        = "prop_traffic_80sign_warning_1b",
        speedLimit  = 80,
        tolerance   = 10,   -- só multa acima de 88 km/h
        fineBase    = 500,
        fineStepPct = 12    -- +12% a cada 10 km/h acima do limite
    },
    [110] = {
        name        = "110 km/h",
        prop        = "prop_traffic_80sign_warning_1b", -- mesma prop do 80 por enquanto
        speedLimit  = 110,
        tolerance   = 10,   -- só multa acima de 121 km/h
        fineBase    = 700,
        fineStepPct = 10    -- +10% a cada 10 km/h acima do limite
    }
}