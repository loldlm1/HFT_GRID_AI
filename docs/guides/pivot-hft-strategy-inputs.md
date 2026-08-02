# Guia de inputs Pivot HFT

## Temporalidades

- `Pivot_HFT_Micro_Timeframe` (`M1`) define las bandas de Bollinger, los cierres
  micro y la ventana de reintento de la vela que contiene el fill. No limita la
  duracion de una campana pendiente ya armada.
- `Pivot_HFT_Pivot_Timeframe` (`M30`) calcula pivotes clasicos desde la vela
  macro cerrada anterior. Debe ser igual o mayor que el timeframe micro.

El timeframe del chart o del Strategy Tester no participa en estas decisiones.
Puede usarse M1 como chart con micro M3: toda barra de estrategia se obtiene de
los dos inputs configurados.

## Pivotes y Bollinger

Las bandas son fijas: periodo `21`, desviacion `2.0`, `shift=1` y
`PRICE_CLOSE`. La deteccion compara `close_0` contra las bandas de la vela
micro cerrada anterior; no existen inputs para alterarlas.

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

## Flujo de ejecucion

1. Venta: `close_0 >= Rn` y `close_0 >= banda_superior`.
2. Compra: `close_0 <= Sn` y `close_0 <= banda_inferior`.
3. Con retracement `> 0`, venta sigue el maximo Bid y vende al retroceder la
   distancia configurada; compra sigue el minimo Ask y compra al rebotar.
4. Con retracement `0`, la admision cambia inmediatamente a intencion de orden
   y pasa por los mismos guards antes del market order.
5. Se resuelve y congela la geometria de salida; una geometria invalida bloquea
   la entrada.
6. La orden se envia sin SL/TP al servidor.
7. El fill real define SL local, step y TP fijo opcional.
8. El TP fijo se evalua antes de avanzar trailing en el mismo tick favorable.
9. Neto positivo completa el intento. Neto `<= 0` puede rearmar dentro de la
   vela micro que contiene el fill si el nivel original y Bollinger siguen
   validos para ese reintento heredado.
10. Un ganador exterior consume la escalera interior de esa misma direccion y
    vela: R2 consume R1+R2, R3 consume R1+R2+R3, con simetria S1-S3.

Solo hay una campana pendiente o una posicion administrada ocupando la ranura de
ejecucion. El ultimo pivote tocado puede reemplazar al anterior unicamente en la
vela donde se armo la campana; despues, la campana sigue el mismo nivel hasta el
fill o una cancelacion terminal. No se admite un nivel hermano mientras exista
un ticket activo, cierre pendiente o reintento pendiente. Un cierre externo o
de proteccion tampoco rearma esa campana; otro pivote puede iniciar una nueva
solo cuando la ranura queda libre.

## Lectura visual del lifecycle

En chart o Strategy Tester visual, los pivotes muestran su estado en la
descripcion: `UNTESTED`, `TEST OPEN`, `BURNED` o el estado de la campana. Cada
nivel quemado conserva un segmento corto sobre su primera vela micro de test.

Con retracement positivo, la campana activa dibuja tres lineas: pivote
seleccionado, extremo seguido y precio exacto que dispara la entrada. Con cero,
el panel muestra `Retrace IMMEDIATE` y no necesita una linea de distancia.
`ENTRY READY` usa una linea mas gruesa; una campana cancelada por sesion o
rollover macro aparece como `CANCELLED` y permanece atenuada durante una vela
micro para facilitar el QA.

Cada posicion administrada usa nombres y lineas por ticket:

- `ACTUAL FILL`: precio real de entrada.
- `LOCAL SL`: proteccion inicial local.
- `BE`: stop movido al precio de entrada.
- `TRAIL STEP N`: stop local vigente tras cada step del trailing.
- `FIXED TP`: target local opcional basado en el SL inicial.

Las lineas se actualizan solo cuando cambia su precio o estado, se eliminan al
completar el ticket y no existen en tester no visual. Ningun objeto del chart
participa en la deteccion ni en la ejecucion.

Los nombres relevantes son deterministas:

- `PIVOT_HFT_TEST_<nivel>`: segmento de la primera vela que probo el nivel.
- `PIVOT_HFT_CAMPAIGN_PIVOT`: pivote de la campana visible.
- `PIVOT_HFT_CAMPAIGN_EXTREME`: maximo Bid o minimo Ask seguido.
- `PIVOT_HFT_CAMPAIGN_TRIGGER`: precio exacto del retroceso de entrada.
- `PIVOT_HFT_POSITION_<ticket>_ENTRY`: fill real del broker.
- `PIVOT_HFT_POSITION_<ticket>_STOP`: SL local, BE o trailing vigente.
- `PIVOT_HFT_POSITION_<ticket>_TP`: TP fijo local cuando esta habilitado.

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

Para auditar niveles buscar `LEVEL_SCAN_START`, `LEVEL_SCAN_RESULT`,
`LEVEL_SCAN_FAILED`, `LEVEL_TOUCH_PROVISIONAL`, `LEVEL_BURNED` y
`LEVEL_CONTEXT_FINALIZED`. Para el lifecycle correlacionar `CAMPAIGN_*`,
`ENTRY_*`, `ORDER_SEND_RESULT`, `FILL_REGISTERED`, `LOCAL_SL_INITIALIZED`,
`TRAILING_ADVANCED`, `LOCAL_CLOSE_*`, `POSITION_FINALIZED`, cierres de
proteccion y `DEBUG_STOP`.

`CAMPAIGN_CARRIED_FORWARD` registra una sola fila por cambio de vela mientras
una campana sigue pendiente. `CAMPAIGN_CANCELLED` identifica `session_closed`,
`pivot_set_rollover` o una reconstruccion terminal del conjunto. Cuando un
nivel tocado ya esta ocupado, `CAMPAIGN_LEVEL_OCCUPIED` registra la mascara y
el fallback una sola vez por firma unica vela/direccion/mascara/seleccion;
alternar entre firmas o salir y volver temporalmente a la banda no repite un
payload ya visto. Los reintentos usan el nivel original dentro de la vela real
del fill.

`POSITION_FINALIZED` separa `close_trigger` (`INITIAL_SL`, `BREAK_EVEN`,
`TRAILING`, `FIXED_TP` o `EXTERNAL`) de `net_class` (`PROFIT`, `LOSS` o
`FLAT`). Tambien incluye ancho de bandas, SL inicial, step resuelto, ratios,
`trigger_time`, `trigger_quote`, `trigger_stop`, `trigger_target`,
`trigger_step`, el ultimo `exit_deal`, el numero de deals de salida y
`close_price` ponderado por volumen. Asi un BE o trailing con neto positivo
conserva su causa real sin etiquetarse falsamente como TP fijo.

`ENTRY_TRIGGERED` distingue `mode=IMMEDIATE` de `mode=RETRACEMENT`.
`WINNING_LEVELS_CONSUMED` registra ticket, ganador, vela, mascara y niveles
consumidos para auditar el caso R1 fallido seguido por R2 ganador.

Rotar o vaciar el archivo antes de una sesion QA enfocada. No usar un log viejo
como evidencia de la compilacion o del run actual.

## Controles conservados

- Cuenta hedging obligatoria.
- Magic live entregado por licencia y magic determinista en tester.
- Spread maximo, margen, sesiones, limite diario, drawdown y estado del broker.
- Cierres forzados filtrados por simbolo y magic.

El perfil backend conserva deliberadamente la identidad Pandora. No se cambia
`ea_id`, contrato de licencia, secretos ni payloads de resultados diarios.

## Optimizacion del Strategy Tester

- Separar retracement `0` como escenario inmediato discreto de las corridas con
  retracement positivo; no mezclar el cero dentro de un step numerico continuo.
- Optimizar solo el porcentaje de ancho de bandas y el ratio positivo del step;
  ya no existen dimensiones inactivas de modo SL, SL fijo o step fijo.
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
    `ACTUAL FILL`, `LOCAL SL`, `BE`, `TRAIL STEP N` y `FIXED TP` por ticket.
12. SL local, BE, steps posteriores, TP fijo, cierre neto y eliminacion visual
    por ticket. Bajo delay de broker no debe existir mas de una posicion
    administrada activa; verificar que `close_trigger`, `trigger_target`,
    `exit_deal`, `close_price` y `net_class` coincidan con el historial.
13. Reintento tras perdida o BE solo dentro de la vela micro que contiene el
    fill; neto positivo completa la campana y no rearma.
14. En una vela que alcance R1 y R2, forzar R1 no positivo y R2 positivo:
    `WINNING_LEVELS_CONSUMED` debe incluir R1,R2 y no puede reaparecer R1. Repetir
    el caso simetrico con S1,S2.
15. Bloqueos por spread, margen, sesion, limite diario, proteccion y estado del
    broker, mas cierre de proteccion y `Debug_Stop_On_Negative_Equity`.
16. Limpieza de handles, comentario y objetos `PIVOT_HFT_` al cancelar, cerrar,
    retirar o re-adjuntar el EA.
17. Para cada escenario, correlacionar el chart, historial de ordenes/deals y
    las filas del mismo `run` en `query_debug.txt`.

El baseline de cierre fue validado el 2026-08-01 con chart M1, micro M3 y
pivotes H1: 210 fills y finalizaciones correlacionadas, BUY/SELL, maximo de un
ticket administrado, escaneo historico, burns, carry-forward, reintentos,
SL/trailing y 33 firmas de ocupacion sin duplicados. El plan de implementacion
queda archivado en `docs/plans/archive/pivot-hft-strategy-plan.md`.

Repetir los controles relevantes al cambiar broker, simbolo o parametros antes
de live. El SL, trailing y TP fijo son locales: terminal, EA, Algo Trading y
conexion deben permanecer activos para ejecutar el cierre.
