# Copy De Producto - Base EA

## Producto

- Nombre: `HFT Grid AI - Macro/Micro Pivot Market Data Executor`
- Tipo: `Recolector de datos de mercado y ejecutor para MT5`
- SKU: `base_ea`

## Copy Corto

`HFT Grid AI convierte una ventana pivot Macro completada y el contexto Micro de Bandas ponderadas en datos deterministas schema V11, una ruta opcional de ejecucion 1R inmutable y una matriz virtual de SL/TP para investigacion offline.`

## Copy Medio

`El EA calcula una escalera pivot clasica usando la vela Macro anterior completada por el broker, H1 por defecto. Observa el Bid en vivo para compras en soportes y ventas en resistencias, mientras un contexto M3 de Bandas ponderadas captura la volatilidad actual y la estructura causal de %B.`

`Cuando la ejecucion es elegible, el EA puede enviar una posicion de mercado FOK en una cuenta hedging con stop estructural en el broker y objetivo 1R calculado desde la cotizacion fresca. La sesion real, permisos, geometria Bid/Ask, stops y freeze, volumen, margen, OrderCheck, resultado del envio, SL/TP inmutables y reconciliacion por ticket siguen siendo obligatorios.`

`Cuando la exportacion estadistica esta activa, el mismo origen pivot tambien crea dieciseis trials virtuales con stops estructurales y de volatilidad Micro, combinados con objetivos 1R, 2R, 3R y 5R. Las cadenas de volatilidad pueden reingresar despues de su propio stop dentro de limites pivot estrictos. Estos trials nunca crean ordenes del broker ni cambian la decision real.`

## Inputs Explicados

- `Broker_Session`: conserva la hora del broker o agrega una hora de analisis
  normalizada para Exness solo en la exportacion.
- `Macro_Timeframe`, `Micro_Timeframe`: horizontes H1/M3 por defecto.
- `Lot_Type`: lote fijo o riesgo porcentual sobre un balance de referencia fijo.
- `Lot_Strategy_Size`: lotes solicitados en modo fijo; porcentaje de riesgo en
  modo referencia. El valor `0.01` solicita un presupuesto de 100 unidades
  usando la referencia interna fija de `1,000,000`, sin depender del balance
  actual de la cuenta.
- Campos de estadistica: habilitan persistencia schema V11, trials virtuales e
  identifican el run.
- Campos debug: diagnostico opcional en terminal y archivo.

## Limite De Investigacion Y Resultados

Schema V11 registra `%B` Micro y Macro por pivot, ancho normalizado de Bandas,
dieciseis politicas virtuales iniciales, reingresos limitados por volatilidad,
checks del broker, geometria inmutable, resultados reales y calibracion parity.
El R virtual por primer toque y el gross calculado son contrafactuales; comision,
swap, fee y net profit siguen siendo datos exclusivos del broker.

Los trials virtuales TP/SL elegibles y con features completos forman el target
principal de politicas. El rendimiento TP/SL del broker queda separado y cada
request aceptado recibe un shadow parity solo para calibracion. Los modelos son
offline y no autorizan operaciones.

## Limite De Seguridad

Las cuentas que no son hedging solo recolectan datos. El spread se registra y
no se compara con un limite configurable. El contrato no incluye licencia,
horario de usuario, panel de drawdown, trailing, grid multi-leg, TP parcial,
control de modelos runtime, pattern playback ni magic number publico.

## Modelo De Validacion

El proyecto usa revision estatica durante los sprints, una compilacion real de
MetaEditor al final y aceptacion humana con ticks reales en Strategy Tester y
grafico. No mantiene harnesses custom de tests MQL5 ni CI de MQL5.
