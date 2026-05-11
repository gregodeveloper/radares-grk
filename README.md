# 👮‍♂️ Sistema de Radar Avançado (vRP)

Este é um sistema de fiscalização eletrônica completo para FiveM, permitindo que administradores posicionem radares fixos no mapa com zonas de detecção personalizáveis, props automáticas e sistema de multas escalonável.

---

## 🚀 Funcionalidades

* **Criação In-Game:** Interface NUI para posicionar a placa e a zona de detecção em tempo real.
* **Duas Etapas de Configuração:** 1. Posicionamento e rotação da **Prop (Placa)**.
  2. Ajuste de localização e tamanho da **Zona de Detecção** (caixa invisível).
* **Multas Dinâmicas:** Valor da multa aumenta progressivamente conforme o excesso de velocidade.
* **Persistência em Banco de Dados:** Todos os radares são salvos via `vRP.Prepare` para carregar automaticamente após restarts.
* **Otimização:** Sincronização via `SyncAll` para garantir que as props sejam renderizadas corretamente para todos os jogadores próximos.

---

## 📦 Conteúdo de Stream e Props

O script já inclui o gerenciamento de props (modelos 3D das placas).
* **Arquivos Inclusos:** O diretório `stream/` contém as definições de props (`props.ytyp`).
* **Nota Importante:** Como as props são customizadas, podem ocorrer pequenas falhas visuais ou de colisão dependendo da build do seu servidor ou conflitos de mapeamento. Caso a placa fique cinza ou invertida, verifique o carregamento do `ytyp` no `fxmanifest.lua`.

---

## 🛠️ Integração com vRP

O script utiliza a infraestrutura padrão da base **vRP**:

* **Permissões:** Controlado pelo `Config.AdminGroup` no `config.lua`. Se definido como `nil`, o acesso é liberado.
* **Sistema de Multas:** Utiliza `vRP.PaymentFull` para retirar o dinheiro diretamente do banco/carteira do jogador.
* **Identificação:** Usa o sistema de `Passport` (ou ID) para aplicar as punições e evitar conflitos entre jogadores.

---

## ⚙️ Configuração (config.lua)

Você pode personalizar os limites e valores no arquivo de configuração:

```lua
Config.RadarTypes = {
    [80] = {
        name        = "80 km/h",
        prop        = "prop_traffic_80sign_warning_1b",
        speedLimit  = 80,
        tolerance   = 10,   -- Multa apenas 10% acima do limite (88 km/h)
        fineBase    = 500,  -- Valor inicial da multa
        fineStepPct = 12    -- Aumento de 12% a cada 10km/h de excesso
    }
}
🕹️ Comandos e Operação
1. Criar um Radar
Digite /radar no chat.

Clique em "+ Novo Radar" e selecione a velocidade.

Etapa 1: Use as teclas (W, A, S, D, Q, E) ou os botões na tela para posicionar a placa. Clique em Confirmar.

Etapa 2: Ajuste a zona verde no chão (onde o carro será detectado) e os sliders de largura/profundidade.

Clique em Confirmar para salvar no banco de dados.

2. Gerenciar Radares
O comando /radar abre a lista de todos os radares ativos, permitindo ver as coordenadas e excluir radares existentes.

/radarclear: Remove todos os radares do servidor de uma vez (requer permissão de admin).

📋 Requisitos
vRP Framework

MySQL-Async ou OxMySQL (Configurado para as queries do vRP)

PolyZone (Opcional, dependendo da sua versão do client-side)

Desenvolvido por: Georgios Antonios (GrK)
