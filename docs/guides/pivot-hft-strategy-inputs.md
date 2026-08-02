# Guia de inputs Pivot HFT

## Temporalidades

- `Pivot_HFT_Micro_Timeframe` (`M1`) define las bandas de Bollinger, los cierres
  micro y la vela origen de una campana. Un cambio de vela micro no termina una
  campana pendiente ni una cadena de retry elegible.
- `Pivot_HFT_Pivot_Timeframe` (`M30`) calcula pivotes clasicos desde la vela
  macro cerrada anterior. Debe ser igual o mayor que el timeframe micro.

El timeframe del chart o del Strategy Tester no participa en estas decisiones.
Puede usarse M1 como chart con micro M3: toda barra de estrategia se obtiene de
los dos inputs configurados.

## Pivotes y Bollinger

Las bandas son fijas: periodo `21`, desviacion `2.0`, `shift=1` y
`PRICE_CLOSE`. La deteccion compara `close_0` contra las bandas de la vela
micro cerrada anterior; no existen inputs para alterarlas. Esa comparacion
admite una campana nueva, pero no vuelve a validar una campana ya armada: entrar
de nuevo en la banda durante el retroceso no cancela la secuencia ni reinicia su
extremo seguido.

```text
P  = (H + L + C) / 3
R1 = 2P - L
R2 = P + H - L
R3 = H + 2(P - L)
S1 = 2P - H
S2 = P - H + L
S3 = L - 2(H - P)
```

`R1-R3` autorizan ventas y `S1-S3` compras. `P` es informativo.

## Validez de niveles

Cada conjunto de pivotes nace al abrir la vela macro actual. El EA reconstruye
desde esa apertura todas las velas micro cerradas, incluso si ocurrieron fuera
de las sesiones de entrada. Un nivel queda quemado cuando una vela micro
cerrada cumple `low <= nivel <= high` y no puede crear otra campana durante el
mismo conjunto macro.

El toque de la vela micro que aun esta abierta es provisional: el nivel sigue
disponible durante esa vela y se quema cuando abre la siguiente. Quemar el nivel
impide otra admision, pero no cancela la campana que ya lo reclamo: esa campana
mantiene su secuencia y extremo durante las velas micro siguientes hasta el
fill. El cierre de sesion/recursos o el rollover del conjunto macro son sus
fronteras terminales. Un nuevo conjunto macro reinicia la validez aunque alguno
de sus precios coincida con el conjunto anterior. Si el historial requerido no
esta sincronizado, no se admiten nuevas campanas hasta completar la
reconstruccion.

## Inputs de estrategia

| Input | Default | Funcion |
| --- | ---: | --- |
| `Pivot_HFT_Direction_Mode` | Ambas | Habilita compras, ventas o ambas. |
| `Pivot_HFT_Retracement_Points` | `25.0` | `0` intenta entrar inmediatamente al admitir el pivote; `> 0` espera retroceso desde el extremo Bid/Ask. |
| `Pivot_HFT_Start_Real_Retry` | `1` | Primer retry que abre en broker: `0` desactiva rearm, `1` abre retry `1` y posteriores, y `N >= 2` simula `1..N-1` antes de abrir retry `N` y posteriores. No es un maximo. |
| `Pivot_HFT_Local_SL_Bands_Width_Percent` | `25.0` | Porcentaje positivo del ancho superior-inferior usado siempre para el SL local. |
| `Pivot_HFT_TP_Step_SL_Ratio` | `1.0` | Multiplo positivo del SL inicial para el step de BE/trailing. |
| `Pivot_HFT_Fixed_TP_SL_Ratio` | `0.0` | `0` desactiva TP fijo; `> 0` crea un target como multiplo del SL inicial. |
| `Pivot_HFT_Lot_Size` | `0.01` | Volumen fijo normalizado al simbolo. |
| `Pivot_HFT_Enable_Visualization` | `true` | Muestra pivotes, bandas, campana y posiciones. |
| `Enable_Logs` | `false` | Mensajes compactos en Journal. |
| `Enable_File_Logs` | `false` | Auditoria persistente del lifecycle en `query_debug.txt`. |
| `Debug_Stop_On_Negative_Equity` | `false` | Detiene el tester segun el contrato de depuracion existente. |

Todos los campos de distancia usan puntos MQL5:

```text
distancia_precio = puntos * SYMBOL_POINT
```

No se aplica offset ni tolerancia adicional al pivote.

## Geometria local de salida

El EA reutiliza el unico snapshot Bollinger ya cargado desde la ultima vela
micro cerrada (`shift=1`) justo antes de enviar la orden. No crea ATR, Keltner,
otro Bollinger ni otro `CopyBuffer`. La distancia se congela por ticket y los
precios exactos se anclan al fill verificado del broker:

```text
ancho_bandas_puntos = (banda_superior - banda_inferior) / SYMBOL_POINT

sl_inicial_puntos = ancho_bandas_puntos
                    * Pivot_HFT_Local_SL_Bands_Width_Percent / 100

step_puntos = sl_inicial_puntos * Pivot_HFT_TP_Step_SL_Ratio

si Pivot_HFT_Fixed_TP_SL_Ratio > 0:
  tp_fijo_puntos = sl_inicial_puntos * Pivot_HFT_Fixed_TP_SL_Ratio
```

Con desviacion Bollinger fija `2.0`, el ancho completo es aproximadamente
`4 sigma`; por eso `25%` aproxima una escala de `1 sigma`. Es una normalizacion
de volatilidad, no una probabilidad estadistica ni una promesa de rendimiento.
El lote sigue fijo: ampliar el SL tambien amplia el riesgo monetario aproximado.

SL, BE, trailing y TP fijo son locales. La orden mantiene SL y TP servidor en
cero, por lo que terminal, EA, Algo Trading y conexion deben permanecer activos.

Antes de cada envio se refrescan `SYMBOL_TRADE_STOPS_LEVEL` y
`SYMBOL_TRADE_FREEZE_LEVEL`. El SL solicitado no se amplia; se bloquea el envio
si no cubre spread mas el piso broker con buffer de un tick:

```text
piso_broker_puntos = EffectiveBrokerDistancePoints(constraints, 0.0, 1.0)
sl_minimo_entrada_puntos = spread_actual_puntos + piso_broker_puntos
```

Si `sl_inicial_puntos < sl_minimo_entrada_puntos`, aparece
`ENTRY_RISK_DISTANCE_BLOCKED`, no existe `ORDER_SEND_RESULT`, no se crea estado
de posicion y no se consume inicio de senal diaria. El intento admitido vuelve
a `TRACKING` desde un extremo fresco.

## Flujo de ejecucion

1. Venta: `close_0 >= Rn` y `close_0 >= banda_superior`.
2. Compra: `close_0 <= Sn` y `close_0 <= banda_inferior`.
3. Con retracement `> 0`, venta sigue el maximo Bid y vende al retroceder la
   distancia configurada; compra sigue el minimo Ask y compra al rebotar.
4. Con retracement `0`, la admision cambia inmediatamente a intencion de orden
   y pasa por los mismos guards antes del market order.
5. Se resuelve y congela la geometria de salida; una geometria invalida bloquea
   la entrada.
6. Se refrescan stops/freeze y se exige
   `SL solicitado >= spread + piso broker`; el fallo bloquea antes del envio sin
   ampliar riesgo.
7. La entrada inicial siempre se envia sin SL/TP al servidor. En retries, la
   fuente se resuelve con `Pivot_HFT_Start_Real_Retry`: `BROKER` desde el
   threshold o `VIRTUAL` antes de el.
8. Cada fill real o virtual define SL local, step y TP fijo opcional. Un tick
   fresco compara Bid contra SL para BUY o SL contra Ask para SELL. Si el buffer
   restante es menor al piso broker, se cierra una vez por el lifecycle local
   con trigger `ENTRY_SAFETY`.
9. El TP fijo se evalua antes de avanzar trailing en el mismo tick favorable.
10. Neto positivo completa el intento. Neto `<= 0` puede rearmar en la misma
   vela micro o en velas posteriores mientras la sesion/recursos y el precio
   del nivel original sigan perteneciendo al mismo conjunto de pivotes. La
   admision queda heredada: no se exige que la cotizacion siga fuera de la banda
   ni del lado inicial del pivote. `Pivot_HFT_Start_Real_Retry=0` completa el
   nivel sin rearmar y emite `RETRY_DISABLED`; `1` abre retry `1` y posteriores
   en broker; `N >= 2` gestiona retries `1..N-1` como posiciones virtuales
   completas y abre retry `N` y posteriores en broker. Cada retry conserva
   secuencia, identidad origen, numero publico, ordinal interno y comienza desde
   un extremo direccional fresco. No existe maximo ni cooldown.
11. Un ganador exterior consume la escalera interior de esa misma direccion y
    vela: R2 consume R1+R2, R3 consume R1+R2+R3, con simetria S1-S3.

Solo hay una campana pendiente o una posicion real/virtual ocupando la ranura de
ejecucion. El ultimo pivote tocado puede reemplazar al anterior unicamente en la
vela donde se armo la campana; despues, la campana sigue el mismo nivel hasta el
fill o una cancelacion terminal. El reemplazo termina explicitamente la cadena
anterior con `latest_level_replaced`; no crea una cola ni deja un retry huerfano.
No se admite un nivel hermano mientras exista una ejecucion activa, cierre
pendiente o reintento pendiente. Un cierre externo o de proteccion tampoco
rearma esa campana; otro pivote puede iniciar una nueva solo cuando la ranura
queda libre.

### Modelo de retry virtual

El retry virtual no inventa un precio aleatorio. Justo al ejecutar toma un
`MqlTick` fresco, usa Ask para BUY o Bid para SELL, aplica el slippage firmado
observado entre quote y fill de la posicion real fuente, y normaliza al tick del
broker. Al cerrar toma Bid para BUY o Ask para SELL y aplica del mismo modo el
slippage de cierre observado. Spread, stops/freeze, volumen, margen, sesiones,
proteccion y estado del mercado siguen siendo guards obligatorios.

El bruto virtual se calcula con `OrderCalcProfit`. Comision, fee y swap no se
pueden consultar prospectivamente de forma generica; por eso se hereda el costo
neto por lote observado en la posicion real fuente. Si falta un modelo valido o
falla el calculo, el lifecycle virtual termina fail-closed y no avanza a una
orden real. Los retries virtuales no llaman `Buy`, `Sell`, `PositionClose` ni
historial broker, no afectan equity y no consumen contadores diarios. El primer
retry real vuelve a exigir y consumir el presupuesto diario normal.

La auditoria conserva tanto el predecesor inmediato como la ejecucion broker
original que calibro el modelo. Slippage de entrada, slippage de cierre y costo
por lote se etiquetan como `OBSERVED_ZERO`, `OBSERVED_VALUE`, `FALLBACK_ZERO`,
`FALLBACK_VALUE` o `UNAVAILABLE`; un cero observado no se interpreta como dato
faltante y nunca se inventa ruido aleatorio.

## Lectura visual del lifecycle

En chart o Strategy Tester visual, los pivotes muestran su estado en la
descripcion: `UNTESTED`, `TEST OPEN`, `BURNED` o el estado de la campana. Cada
nivel quemado conserva un segmento corto sobre su primera vela micro de test.

Con retracement positivo, la campana activa dibuja tres lineas: pivote
seleccionado, extremo seguido y precio exacto que dispara la entrada. Con cero,
el panel muestra `Retrace IMMEDIATE` y no necesita una linea de distancia.
`ENTRY READY` usa una linea mas gruesa; una campana cancelada por sesion o
rollover macro aparece como invalidacion terminal y permanece atenuada
brevemente para facilitar el QA.

El panel separa posiciones activas `Broker`, activas `Virtual` y `CloseWait`.
Cada fila y campana muestra su fuente en texto. La politica visible declara
`initial BROKER`, virtual antes de retry `N`, broker desde retry `N` y sin
maximo mientras la cadena sea valida. Un reintento activo muestra
`RETRY N VIRTUAL TRACKING` o `RETRY N BROKER ENTRY READY`; un cierre elegible
muestra `PENDING` o `DEFERRED`, el proximo numero/fuente y la razon canonica.
Sesion, rollover/cambio de pivote, reemplazo y retries deshabilitados aparecen
como terminales distintos. La linea `Safety` muestra SL solicitado, SL
requerido, spread y piso broker; un intento bloqueado aparece como
`RISK BLOCKED` y nunca como posicion.

Cada posicion administrada usa nombres y lineas por ticket o id virtual:

- `BROKER FILL` o `VIRTUAL FILL`: precio de entrada segun la fuente.
- `LOCAL SL`: proteccion inicial local.
- `BE`: stop movido al precio de entrada.
- `TRAIL STEP N`: stop local vigente tras cada step del trailing.
- `FIXED TP`: target local opcional basado en el SL inicial.
- `ENTRY SAFETY CLOSE WAIT`: cierre local de un fill cuyo buffer real nacio por
  debajo del piso broker.

Las lineas se actualizan solo cuando cambia su precio o estado, se eliminan al
completar la ejecucion y no existen en tester no visual. Ningun objeto del chart
participa en la deteccion ni en la ejecucion.

Los nombres relevantes son deterministas:

- `PIVOT_HFT_TEST_<nivel>`: segmento de la primera vela que probo el nivel.
- `PIVOT_HFT_CAMPAIGN_PIVOT`: pivote de la campana visible.
- `PIVOT_HFT_CAMPAIGN_EXTREME`: maximo Bid o minimo Ask seguido.
- `PIVOT_HFT_CAMPAIGN_TRIGGER`: precio exacto del retroceso de entrada.
- `PIVOT_HFT_POSITION_<id>_ENTRY`: fill broker o virtual.
- `PIVOT_HFT_POSITION_<id>_STOP`: SL local, BE o trailing vigente.
- `PIVOT_HFT_POSITION_<id>_TP`: TP fijo local cuando esta habilitado.
- `PIVOT_HFT_RETRY_WAIT_<id>`: retry cerrado pendiente o diferido.
- `PIVOT_HFT_TERMINAL_CAMPAIGN_PIVOT`: cadena terminal concurrente con una
  campana nueva.

## Auditoria en archivo

Activar `Enable_File_Logs=true` para escribir el lifecycle en:

```text
TERMINAL_COMMONDATA_PATH\Files\query_debug.txt
```

El EA imprime en Journal la ruta absoluta resuelta y el `run` al inicializar.
El archivo usa `FILE_COMMON`, por lo que puede ser compartido por varias
instalaciones MT5. Cada fila incluye timestamp, evento, `run`, simbolo y magic;
usar esos campos para separar instancias y pruebas. El `run` combina el tiempo
simulado con tokens monotonicos y de chart para no colisionar al repetir el
mismo periodo del tester. El writer conserva un handle compartible, busca el
final y hace flush por evento; ante un fallo reabre una sola vez y avisa una
sola vez en Journal.

`RUN_START` declara `schema_version=2`. El modo visual real del tester usa
`tester_visual_mode` y el input usa `visualization_input`. Cada payload conserva
claves unicas dentro de su fila para que un parser no sobrescriba evidencia.

Para auditar niveles buscar `LEVEL_SCAN_START`, `LEVEL_SCAN_RESULT`,
`LEVEL_SCAN_FAILED`, `LEVEL_TOUCH_PROVISIONAL`, `LEVEL_BURNED` y
`LEVEL_CONTEXT_FINALIZED`. Para el lifecycle correlacionar `CAMPAIGN_*`,
`ENTRY_*`, `ORDER_SEND_RESULT`, `FILL_REGISTERED`, `VIRTUAL_FILL_REGISTERED`,
`FILL_ENTRY_DISTANCE_INVALID`, `LOCAL_SL_INITIALIZED`, `TRAILING_ADVANCED`,
`LOCAL_CLOSE_*`, `VIRTUAL_CLOSE_FILLED`, `POSITION_FINALIZED`, cierres de
proteccion y `DEBUG_STOP`.

`ENTRY_RISK_DISTANCE_BLOCKED` expone SL solicitado/requerido, spread, stops,
freeze, piso broker y tick. `FILL_ENTRY_DISTANCE_INVALID` expone fill, Bid/Ask
frescos, SL local, spread real, buffer restante y piso requerido. El primero no
debe tener envio/fill asociado; el segundo debe continuar con
`LOCAL_CLOSE_SENT|close_trigger=ENTRY_SAFETY` y una sola finalizacion.

`CAMPAIGN_CARRIED_FORWARD` registra una sola fila por cambio de vela mientras
una campana sigue pendiente. `CAMPAIGN_CANCELLED` identifica `session_closed`,
`pivot_set_rollover` o `pivot_set_refresh`. `CAMPAIGN_REPLACED` identifica
propietario anterior/nuevo y `terminal_reason=latest_level_replaced`. Cuando un
nivel tocado ya esta ocupado, `CAMPAIGN_LEVEL_OCCUPIED` registra la mascara y
el fallback una sola vez por firma unica vela/direccion/mascara/seleccion;
alternar entre firmas o salir y volver temporalmente a la banda no repite un
payload ya visto. Los reintentos conservan el nivel original aunque crucen una
o mas velas micro.

`POSITION_FINALIZED` separa `close_trigger` (`INITIAL_SL`, `BREAK_EVEN`,
`TRAILING`, `FIXED_TP`, `ENTRY_SAFETY` o `EXTERNAL`) de `net_class` (`PROFIT`, `LOSS` o
`FLAT`). Tambien incluye ancho de bandas, SL inicial, step resuelto, ratios,
`trigger_time`, `trigger_quote`, `trigger_stop`, `trigger_target`,
`trigger_step`, el ultimo `exit_deal`, el numero de deals de salida y
`close_price` ponderado por volumen. Asi un BE o trailing con neto positivo
conserva su causa real sin etiquetarse falsamente como TP fijo.

`ENTRY_TRIGGERED` distingue `mode=IMMEDIATE` de `mode=RETRACEMENT`.
`REARM_PENDING`, `REARM_DEFERRED`, `POSITION_REARMED`, `RETRY_DISABLED` y
`REARM_INVALIDATED` registran transiciones acotadas, no una fila por tick.
Incluyen secuencia, identidad origen, numero/ordinal actual y siguiente,
`source_execution_source`, `next_execution_source` y razon canonica.
`POSITION_REARMED` agrega `start_real_retry`, extremo, proximo threshold y
`admission=latched`. `ENTRY_TRIGGERED`, bloqueos, envio y fills conservan numero
publico, ordinal interno y fuente para correlacion.
`VIRTUAL_FILL_REGISTERED` expone Bid/Ask, spread, entry quote/fill y el modelo;
`VIRTUAL_CLOSE_FILLED` expone quote ejecutable, slippage aplicado, bruto, costo
estimado y neto. El modelo identifica predecesor y calibrador broker, con
provenance observada/fallback incluso cuando el valor es cero. `RETRY_DISABLED`
identifica un threshold `0`; `REARM_INVALIDATED` identifica `session_closed`,
`pivot_set_rollover` o `pivot_set_changed`. Los bloqueos temporales conservan
numero/fuente mediante `REARM_DEFERRED`.
`WINNING_LEVELS_CONSUMED` registra ticket, ganador, vela, mascara y niveles
consumidos para auditar el caso R1 fallido seguido por R2 ganador.

Rotar o vaciar el archivo antes de una sesion QA enfocada. No usar un log viejo
como evidencia de la compilacion o del run actual.

## Controles conservados

- Cuenta hedging obligatoria.
- Magic live entregado por licencia y magic determinista en tester.
- Spread maximo, margen, sesiones, limite diario, drawdown y estado del broker.
- Cierres forzados filtrados por simbolo y magic.
- Stops/freeze se usan como piso conservador del EA local; no crean SL/TP de
  servidor.
- `Pivot_HFT_Start_Real_Retry` cambia la fuente virtual/real, no limita la
  cantidad. Los retries pueden seguir siendo rapidos porque no hay cooldown.
- Los virtuales no afectan equity ni contadores diarios; cada retry broker
  conserva limite diario, magic, simbolo, margen y guards normales.

El perfil backend conserva deliberadamente la identidad Pandora. No se cambia
`ea_id`, contrato de licencia, secretos ni payloads de resultados diarios.

## Optimizacion del Strategy Tester

- Separar retracement `0` como escenario inmediato discreto de las corridas con
  retracement positivo; no mezclar el cero dentro de un step numerico continuo.
- Tratar `Pivot_HFT_Start_Real_Retry` como entero discreto. Comparar al menos
  `0`, `1` y `3`; `retry_number=0` identifica la entrada inicial real y no debe
  contarse como reintento en estadisticas.
- Fuera del entero de reintentos, optimizar el porcentaje de ancho de bandas y
  el ratio positivo del step; ya no existen dimensiones inactivas de modo SL,
  SL fijo o step fijo.
- Para una corrida sin TP fijo, dejar `Pivot_HFT_Fixed_TP_SL_Ratio=0`. Para
  estudiar R fijo, optimizar solo ese ratio como una dimension adicional.
- El criterio `OnTester()` usa `STAT_PROFIT / STAT_INITIAL_DEPOSIT`, Sharpe no
  negativo y el componente logaritmico de cantidad de trades. Un stop forzado
  conserva score cero.
- La ventana de sesion se recalcula una vez por minuto, no por tick.
- El handle de Bollinger se crea solo dentro de una ventana de entrada activa y
  se libera al salir; una posicion ya abierta conserva su gestion local.
- Los buffers superior/inferior se copian una vez por nueva vela micro cerrada.
- El tester no visual omite objetos de chart y actualizaciones de `Comment`.
- Fuera de sesion y sin posiciones vivas se omiten datos de entrada, spread,
  deteccion y frontend. Licencia, proteccion y cierres forzados siguen activos.

## Validacion manual

Usar `Every tick based on real ticks` sobre la variante US30 del broker. Antes
de iniciar, activar `Enable_File_Logs`, conservar `Pivot_HFT_Enable_Visualization`
y limpiar o rotar `query_debug.txt`:

1. Rechazo de cuenta netting durante `OnInit`.
2. Con pivotes H1 y sesion `13:30`, confirmar que un nivel probado antes de la
   sesion llega quemado y que un nivel hermano no probado sigue disponible.
3. Toque provisional utilizable durante su vela micro y cambio a `BURNED` solo
   al abrir la vela siguiente; la campana ya armada debe continuar siguiendo el
   mismo extremo durante cinco o mas velas M3 hasta el retroceso.
4. Con chart M1 y micro M3, confirmar que pivotes, bandas, burns y carry-forward
   ocurren solo en fronteras M3. Multiples niveles pueden reemplazarse dentro de
   la vela origen, pero no despues de que la campana cruza a otra vela.
5. Rollover macro: el conjunto anterior se finaliza y el nuevo conjunto inicia
   su propia validez aunque repita un precio.
6. Reinicio o re-attach dentro del mismo H1: la reconstruccion debe producir la
   misma lista de niveles quemados antes de admitir una campana.
7. Riesgo por bandas con varios porcentajes representativos; correlacionar la
   ultima vela micro cerrada, ancho completo, SL inicial congelado, fill real y
   SL/TP servidor en cero.
8. Retracement `0`: confirmar intencion `IMMEDIATE` y fill en el primer tick
   permitido por guards. Comparar contra valores positivos que deban esperar el
   retroceso direccional.
9. Comparar varios ratios positivos de step. El primer step debe ir a BE y los
   posteriores solo pueden avanzar, tanto en BUY como en SELL.
10. Comparar TP fijo `0` contra ratios positivos para BUY/SELL; validar target,
    prioridad sobre trailing en el mismo tick y reintento tras rechazo/delay.
11. Lineas de pivote, extremo y trigger antes del fill; despues, lineas
    `BROKER FILL` o `VIRTUAL FILL`, `LOCAL SL`, `BE`, `TRAIL STEP N` y
    `FIXED TP` por identidad.
12. SL local, BE, steps posteriores, TP fijo, cierre neto y eliminacion visual
    por ticket. Bajo delay de broker no debe existir mas de una posicion
    administrada activa; verificar que `close_trigger`, `trigger_target`,
    `exit_deal`, `close_price` y `net_class` coincidan con el historial.
13. Con start real `2`, cerrar la entrada broker inicial en negativo despues de
    cruzar al menos una frontera M3. Debe conservar `RETRY 1 VIRTUAL` pendiente
    o diferido y luego rearmar con `admission=latched`, sin exigir otro toque.
    Cerrar ese virtual en negativo tras otra frontera M3: retry `2` debe ser
    `BROKER`. Tras una nueva perdida tardia, retry `3` tambien debe ser `BROKER`.
14. Repetir una cadena representativa BUY y SELL con start real `1` y `3`.
    Con `1`, retry `1` y posteriores son `BROKER`; con `3`, retries `1-2` son
    `VIRTUAL` y retry `3` y posteriores son `BROKER`.
15. Con start real `0`, una perdida elegible debe emitir `RETRY_DISABLED`,
    mostrar terminal `RETRY DISABLED`, completar el nivel y no producir
    `POSITION_REARMED` ni orden de retry.
16. Cerrar la sesion con un retry pendiente o diferido. Debe existir una sola
    invalidacion `session_closed`, ninguna reactivacion nocturna y ningun estado
    visual obsoleto despues de la ventana terminal.
17. Forzar rollover macro con retry pendiente y exigir `pivot_set_rollover`.
    Repetir con precio/snapshot original incompatible y exigir
    `pivot_set_changed`; ambos conservan el numero/fuente que fue invalidado.
18. Dentro de la vela origen, hacer que un nivel mas reciente reemplace una
    campana inicial o retry. `CAMPAIGN_REPLACED` debe identificar propietario
    anterior/nuevo, `latest_level_replaced` y dejar una sola campana sin retry
    huerfano.
19. Forzar temporalmente slot ocupado, lifecycle ocupado, posicion broker,
    proteccion, limite diario, estado de mercado, indicadores o quote no
    disponible. `REARM_DEFERRED` debe emitirse solo cuando cambia la razon y
    conservar el mismo proximo retry/fuente hasta rearmar o invalidarse.
20. Forzar spread excesivo y distancia de entrada insuficiente por separado.
    El primero debe bloquear el contexto de ejecucion sin terminar la cadena;
    el segundo debe emitir `ENTRY_RISK_DISTANCE_BLOCKED` y devolver la campana
    a tracking sin envio ni consumo diario.
21. Neto positivo completa la campana y no rearma. En una vela que alcance R1 y
    R2, forzar R1 no positivo y R2 positivo: `WINNING_LEVELS_CONSUMED` debe
    incluir R1,R2 y no puede reaparecer R1. Repetir con S1,S2.
22. Con el perfil estrecho del 6 de enero, forzar
    `SL solicitado < spread + piso broker`: debe aparecer
    `ENTRY_RISK_DISTANCE_BLOCKED` sin `ORDER_SEND_RESULT`, `FILL_REGISTERED` ni
    consumo de senal diaria para ese intento.
23. Caso seguro: confirmar fill normal y una sola evaluacion post-fill. Si se
    logra reproducir slippage/gap, exigir `FILL_ENTRY_DISTANCE_INVALID`,
    `ENTRY_SAFETY`, un solo cierre/finalizacion y ningun reemplazo durante
    `CloseWait`.
24. Para un virtual BUY y SELL, verificar Ask/Bid de entrada, Bid/Ask de cierre,
    tick normalization, slippage heredado, `OrderCalcProfit`, costo por lote y
    neto. Verificar predecesor inmediato, calibrador broker original y
    provenance `OBSERVED_ZERO`/observada/fallback. Forzar SL, TP, BE, trailing,
    `ENTRY_SAFETY` y force-close `EXTERNAL`.
25. Capturar en texto, sin depender del color: idle, retry pending/deferred,
    virtual activo, broker activo, `CloseWait`, tracking y terminal. Verificar
    objetos `RETRY_WAIT_<id>` y terminales, luego limpieza de handles,
    comentario y objetos `PIVOT_HFT_` al retirar o re-adjuntar el EA.
26. Para cada escenario, correlacionar chart, historial y filas del mismo `run`.
    Al terminar, reconciliar un `POSITION_FINALIZED` por cada
    `FILL_REGISTERED` o `VIRTUAL_FILL_REGISTERED`, sin identidad duplicada ni
    estado local pendiente. Confirmar que filas virtuales no cambian contadores
    diarios ni historial broker, y que ninguna fila del schema `2` repita una
    clave antes de `=`.

El baseline de cierre fue validado el 2026-08-01 con chart M1, micro M3 y
pivotes H1: 210 fills y finalizaciones correlacionadas, BUY/SELL, maximo de un
ticket administrado, escaneo historico, burns, carry-forward, reintentos,
SL/trailing y 33 firmas de ocupacion sin duplicados. El plan de implementacion
queda archivado en `docs/plans/archive/pivot-hft-strategy-plan.md`.

Repetir los controles relevantes al cambiar broker, simbolo o parametros antes
de live. El SL, trailing y TP fijo son locales: terminal, EA, Algo Trading y
conexion deben permanecer activos para ejecutar el cierre.
