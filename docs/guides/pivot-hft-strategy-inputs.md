# Guia de inputs Pivot HFT

## Temporalidades

- `Pivot_HFT_Micro_Timeframe` (`M1`) define las bandas de Bollinger, la vela de
  campana y la ventana de reintentos.
- `Pivot_HFT_Pivot_Timeframe` (`M30`) calcula pivotes clasicos desde la vela
  macro cerrada anterior. Debe ser igual o mayor que el timeframe micro.

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
disponible durante esa vela y se quema cuando abre la siguiente. Esto conserva
los reintentos por perdida o BE dentro de la vela original. Un nuevo conjunto
macro reinicia la validez aunque alguno de sus precios coincida con el conjunto
anterior. Si el historial requerido no esta sincronizado, no se admiten nuevas
campanas hasta completar la reconstruccion.

## Inputs de estrategia

| Input | Default | Funcion |
| --- | ---: | --- |
| `Pivot_HFT_Direction_Mode` | Ambas | Habilita compras, ventas o ambas. |
| `Pivot_HFT_Retracement_Points` | `25.0` | Retroceso desde el extremo Bid/Ask antes de la entrada. |
| `Pivot_HFT_Local_SL_Points` | `25.0` | Distancia del SL local desde el fill real. |
| `Pivot_HFT_TP_Step_Points` | `25.0` | Step 1 a BE y steps posteriores avanzan el SL. |
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

## Flujo de ejecucion

1. Venta: `close_0 >= Rn` y `close_0 >= banda_superior`.
2. Compra: `close_0 <= Sn` y `close_0 <= banda_inferior`.
3. Venta: sigue el maximo Bid y vende al retroceder la distancia configurada.
4. Compra: sigue el minimo Ask y compra al rebotar la distancia configurada.
5. La orden se envia sin SL/TP al servidor.
6. El fill real define SL local, BE y trailing.
7. Neto positivo completa el intento. Neto `<= 0` puede rearmar dentro de la
   misma vela micro si el mismo nivel sigue valido.

Solo hay una campana pendiente; el ultimo pivote tocado reemplaza al anterior.
Las posiciones abiertas no se reemplazan y pueden coexistir en hedging.
Un nivel no se arma por duplicado dentro de la misma vela mientras su posicion
siga activa o despues de completarse con neto positivo. Un cierre externo o de
proteccion tampoco rearma esa campana; otro pivote si puede iniciar una nueva.

## Lectura visual del lifecycle

En chart o Strategy Tester visual, los pivotes muestran su estado en la
descripcion: `UNTESTED`, `TEST OPEN`, `BURNED` o el estado de la campana. Cada
nivel quemado conserva un segmento corto sobre su primera vela micro de test.

La campana activa dibuja tres lineas: pivote seleccionado, extremo seguido y
precio exacto que dispara la entrada por retroceso. `ENTRY READY` usa una linea
mas gruesa; una campana expirada permanece atenuada durante una vela micro para
facilitar el QA.

Cada posicion administrada usa nombres y lineas por ticket:

- `ACTUAL FILL`: precio real de entrada.
- `LOCAL SL`: proteccion inicial local.
- `BE`: stop movido al precio de entrada.
- `TRAIL STEP N`: stop local vigente tras cada step del trailing.

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

Cuando un nivel tocado ya esta ocupado por una posicion o una finalizacion de
la misma vela, `CAMPAIGN_LEVEL_OCCUPIED` registra una mascara acotada y el
nivel alternativo seleccionado. La campana pendiente se conserva si no hay un
fallback elegible; los reintentos de una posicion cerrada siguen usando su
nivel original dentro de la misma vela micro.

`POSITION_FINALIZED` separa `close_trigger` (`INITIAL_SL`, `BREAK_EVEN`,
`TRAILING` o `EXTERNAL`) de `net_class` (`PROFIT`, `LOSS` o `FLAT`). Tambien
incluye `trigger_time`, `trigger_quote`, `trigger_stop`, `trigger_step`, el
ultimo `exit_deal`, el numero de deals de salida y `close_price` ponderado por
volumen. Asi un BE o trailing con neto positivo conserva su causa real sin
etiquetarse falsamente como TP.

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
   al abrir la vela siguiente; no debe rearmarse durante el mismo conjunto H1.
4. Multiples niveles tocados, seleccion del ultimo pivote valido y exclusion de
   cualquier nivel ya quemado.
5. Rollover macro: el conjunto anterior se finaliza y el nuevo conjunto inicia
   su propia validez aunque repita un precio.
6. Reinicio o re-attach dentro del mismo H1: la reconstruccion debe producir la
   misma lista de niveles quemados antes de admitir una campana.
7. Entradas BUY/SELL con SL y TP servidor en cero, y coincidencia entre
   `ORDER_SEND_RESULT`, `FILL_REGISTERED` e historial del broker.
8. Lineas de pivote, extremo y trigger antes del fill; despues, lineas
   `ACTUAL FILL`, `LOCAL SL`, `BE` y `TRAIL STEP N` por ticket.
9. SL local, BE, steps posteriores, cierre neto y eliminacion visual por ticket
   independiente, incluyendo multiples posiciones hedging simultaneas. Verificar
   que `close_trigger`, `exit_deal`, `close_price` y `net_class` coincidan con
   el historial aunque exista delay de ejecucion del broker.
10. Reintento tras perdida o BE solo dentro de la vela micro original; neto
    positivo completa la campana y no rearma.
11. Bloqueos por spread, margen, sesion, limite diario, proteccion y estado del
    broker, mas cierre de proteccion y `Debug_Stop_On_Negative_Equity`.
12. Limpieza de handles, comentario y objetos `PIVOT_HFT_` al expirar, cerrar,
    retirar o re-adjuntar el EA.
13. Para cada escenario, correlacionar el chart, historial de ordenes/deals y
    las filas del mismo `run` en `query_debug.txt`.

No promover el EA a demo prolongada o live hasta registrar esta evidencia
manual. El SL y el trailing son locales: terminal, EA, Algo Trading y conexion
deben permanecer activos para ejecutar el cierre.
