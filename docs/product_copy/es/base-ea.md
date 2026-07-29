# Copy de Producto - Base EA

## Producto

- Nombre: `HFT Grid AI - Market Data Executor`
- Tipo: `Recolector de datos de mercado y ejecutor para MT5`
- SKU: `base_ea`

## Copy Corto

`HFT Grid AI convierte el flujo fijo de extremos Stoch Structure en M1 en datos deterministas schema v8, evidencia de seguridad del broker y una ruta opcional de una posicion con proteccion del broker.`

## Copy Medio

`El EA funciona de forma continua, observa cada revision PEAK y BOTTOM en M1 y registra las condiciones del broker necesarias para saber si un intento podia ejecutarse. Conserva la hora cruda del broker junto con una hora de analisis normalizada para comparar sesiones Exness que cambian por DST.`

`Cuando la ejecucion es elegible, el EA puede enviar una posicion en una cuenta hedging con stop estructural y take profit fijo de 1R. La sesion real del mercado, permisos, stops y freeze, volumen, margen, OrderCheck, resultado de envio y reconciliacion del ticket siguen siendo obligatorios.`

## Inputs Explicados

- `Broker_Session`: conserva la hora del broker o agrega una hora de analisis
  normalizada para Exness sin cambiar el momento de ejecucion.
- `Lot_Type`: lote fijo o riesgo porcentual sobre el balance.
- `Lot_Strategy_Size`: lotes solicitados en modo fijo; porcentaje de riesgo en
  modo balance.
- Campos de estadistica: habilitan persistencia schema v8 e identifican el run.
- Campos ML: deshabilitado, scoring shadow pasivo o filtro solo en Strategy
  Tester.
- Campos de pattern audit: playback local solo en Strategy Tester.
- Campos debug: diagnostico opcional en terminal y archivo.

## Limite De Seguridad

Las cuentas que no son hedging solo recolectan datos. El spread se registra
como dato y no se compara con un limite configurable. El contrato no incluye
licencia, horario de usuario, panel de drawdown, grid multi-leg, TP parcial ni
magic number publico.

## Modelo De Validacion

El proyecto usa revision estatica durante los sprints, una compilacion real de
MetaEditor al final y aceptacion humana en Strategy Tester/grafico. No mantiene
harnesses custom de tests MQL5 ni CI de MQL5.
