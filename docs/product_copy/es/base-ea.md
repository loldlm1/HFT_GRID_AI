# Copy de Producto - Base EA

## Producto

- Nombre: `HFT Grid AI - Foundation EA`
- Tipo: `Producto base`
- SKU: `base_ea`

## Bloque Corto

`HFT Grid AI Foundation incluye la base principal del Expert Advisor para MT5: licencia, controles de cuenta, proteccion de riesgo, contexto Stoch Structure, limites de ejecucion con condiciones del broker y una base limpia para futuras estrategias.`

## Bloque Medio

`Foundation EA es la base refundada de HFT Grid AI. Su enfoque es un nucleo de ejecucion mas pequeno y limpio antes de agregar nuevas estrategias. El producto conserva controles esenciales como validacion de licencia, separacion por cuenta, guardas de spread, filtros de sesion, proteccion de riesgo y contexto de estrategia.`

`Para usuarios no traders: esta es la capa principal de la aplicacion. Prepara al EA para evaluar contexto de mercado y condiciones del broker antes de que una estrategia intente una ejecucion real. Las futuras estrategias se podran integrar sobre esta base sin cargar supuestos legacy.`

## Inputs Explicados

### Licencia y cuenta

- `EA_License_Key`: clave de activacion. Si es invalida o expirada, el EA no inicia.
- `Custom_Magic`: identificador unico para separar posiciones del broker de este EA.
- `Max_Spread`: bloquea ejecucion cuando el costo de trading es alto.
- `Min_Range_Points`: umbral minimo de movimiento para fundaciones de estrategia.

### Proteccion

- `Protection_Risk_Mode`: controla la proteccion de cuenta.
- `Protection_Risk_Drawdown_Type`: define como se mide el drawdown.
- `Protection_Risk_Drawdown_Value`: valor maximo permitido de drawdown.
- `Account_Size`: referencia de cuenta para calculos de riesgo.
- `Market_Close_Guard_Timeframe`: timeframe usado por la guarda de cierre de mercado.

### Contexto de estrategia

- `Strategy_Timeframe`: timeframe usado por el contexto de estrategia.
- `Stoch_Structure_Period_Type`: sensibilidad de Stoch Structure.
- `Strategy_Direction_Mode`: permite compras, ventas o ambas.
- `Signal_Concurrency_Mode`: controla si puede correr una o varias senales.

### Fundacion de riesgo y rango

- `Base_Strategy_Type`: placeholder de modelo de rango durante la refundacion.
- `Points_Range_Setup`: rango fijo en puntos para fundaciones basadas en rango.
- `Lot_Type`: metodo de tamano de lote, pendiente de renombrar fuera de terminos legacy de grid.
- `Lot_Strategy_Size`: lote base o presupuesto de riesgo segun el modo.
- `Signal_Lot_Strategy`: modo futuro-compatible de ajuste de lote por senal.
- `TP_Percent`: escala de objetivo mientras se simplifica riesgo/rango.
- `Daily_Signal_Limit`: maximo de senales diarias.
- `Daily_Signal_Limit_Mode`: modo de aplicar el limite diario.

## Regla de Acceso

- Los controles base no requieren add-ons legacy removidos.
- Siempre se requiere una clave valida con expiracion futura.

## Modelo de Validacion

Esta refundacion usa compilacion MT5 al cierre de fases de implementacion. Los harnesses custom de tests MQL5 no son parte del modelo activo.
