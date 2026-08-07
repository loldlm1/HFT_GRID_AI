# Copy De Producto - Base EA

## Producto

- Nombre: `HFT Grid AI - Macro/Micro Pivot Market Data Executor`
- Tipo: `Recolector de datos de mercado y ejecutor para MT5`
- SKU: `base_ea`

## Copy Corto

`HFT Grid AI convierte una ventana pivot Macro completada y el contexto Micro de Bandas ponderadas en datos deterministas schema V10, evidencia de seguridad del broker y una ruta opcional de ejecucion 1R inmutable.`

## Copy Medio

`El EA calcula una escalera pivot clasica usando la vela Macro anterior completada por el broker, H1 por defecto. Observa el Bid en vivo para compras en soportes y ventas en resistencias, mientras un contexto M3 de Bandas ponderadas captura la volatilidad actual y la estructura causal de %B.`

`Cuando la ejecucion es elegible, el EA puede enviar una posicion de mercado FOK en una cuenta hedging con stop estructural en el broker y objetivo 1R calculado desde la cotizacion fresca. La sesion real, permisos, geometria Bid/Ask, stops y freeze, volumen, margen, OrderCheck, resultado del envio, SL/TP inmutables y reconciliacion por ticket siguen siendo obligatorios.`

## Inputs Explicados

- `Broker_Session`: conserva la hora del broker o agrega una hora de analisis
  normalizada para Exness solo en la exportacion.
- `Macro_Timeframe`, `Micro_Timeframe`: horizontes H1/M3 por defecto.
- `Lot_Type`: lote fijo o riesgo porcentual sobre un balance de referencia fijo.
- `Lot_Strategy_Size`: lotes solicitados en modo fijo; porcentaje de riesgo en
  modo referencia. El valor `0.01` solicita un presupuesto de 100 unidades
  usando la referencia interna fija de `1,000,000`, sin depender del balance
  actual de la cuenta.
- Campos de estadistica: habilitan persistencia schema V10 e identifican el run.
- Campos debug: diagnostico opcional en terminal y archivo.

## Limite De Investigacion Y Resultados

Schema V10 registra `%B` Micro y Macro por pivot, ancho normalizado de Bandas,
checks del broker, geometria inmutable, slippage, costos y resultados
confirmados. Un 1R exacto por distancia de precio no promete un neto exacto de
`+100` o `-100`: los pasos de volumen, conversion del instrumento, ejecucion,
comision, swap y fees se reportan por separado.

Solo posiciones completas, con features validos y una razon consistente TP/SL
del broker entran al target binario. Los modelos son offline y no autorizan
operaciones.

## Limite De Seguridad

Las cuentas que no son hedging solo recolectan datos. El spread se registra y
no se compara con un limite configurable. El contrato no incluye licencia,
horario de usuario, panel de drawdown, trailing, grid multi-leg, TP parcial,
control de modelos runtime, pattern playback ni magic number publico.

## Modelo De Validacion

El proyecto usa revision estatica durante los sprints, una compilacion real de
MetaEditor al final y aceptacion humana con ticks reales en Strategy Tester y
grafico. No mantiene harnesses custom de tests MQL5 ni CI de MQL5.
