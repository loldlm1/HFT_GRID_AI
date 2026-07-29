# Copy De Producto - Base EA

## Producto

- Nombre: `HFT Grid AI - Pivot Fractal Market Data Executor`
- Tipo: `Recolector de datos de mercado y ejecutor para MT5`
- SKU: `base_ea`

## Copy Corto

`HFT Grid AI convierte ventanas pivot multi-timeframe completadas y primeros toques en M1 en datos deterministas schema V9, evidencia de seguridad del broker y una ruta opcional de ejecucion con proteccion estructural.`

## Copy Medio

`El EA calcula continuamente pivots clasicos usando la vela anterior completada de M15, M30, H1, H4 y D1. Usa el cierre Bid anterior de M1 y el Bid en vivo para registrar un solo primer toque por timeframe, ventana activa y nivel, conservando la hora cruda del broker junto con una hora normalizada para investigacion.`

`Cuando la ejecucion es elegible, el EA puede enviar una posicion de mercado en una cuenta hedging con stop estructural en el broker, objetivo pivot terminal y trailing por ticket. La sesion real, permisos, geometria Bid/Ask, stops y freeze, volumen, margen, OrderCheck, resultado del envio y reconciliacion del broker siguen siendo obligatorios.`

## Inputs Explicados

- `Broker_Session`: conserva la hora del broker o agrega una hora de analisis
  normalizada para Exness solo en la exportacion.
- `Lot_Type`: lote fijo o riesgo porcentual sobre el balance.
- `Lot_Strategy_Size`: lotes solicitados en modo fijo; porcentaje de riesgo en
  modo balance.
- Campos de estadistica: habilitan persistencia schema V9 e identifican el run.
- Campos debug: diagnostico opcional en terminal y archivo.

## Limite De Seguridad

Las cuentas que no son hedging solo recolectan datos. El spread se registra y
no se compara con un limite configurable. El contrato no incluye licencia,
horario de usuario, panel de drawdown, grid multi-leg, TP parcial, control de
modelos runtime, pattern playback ni magic number publico.

## Modelo De Validacion

El proyecto usa revision estatica durante los sprints, una compilacion real de
MetaEditor al final y aceptacion humana en Strategy Tester/grafico. No mantiene
harnesses custom de tests MQL5 ni CI de MQL5.
