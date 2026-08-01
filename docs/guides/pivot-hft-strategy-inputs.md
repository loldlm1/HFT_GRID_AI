# Guia de inputs Pivot HFT

## Temporalidades

- `Pivot_HFT_Micro_Timeframe` (`M1`) define las bandas de Bollinger, la vela de
  campana y la ventana de reintentos.
- `Pivot_HFT_Pivot_Timeframe` (`M30`) calcula pivotes clasicos desde la vela
  macro cerrada anterior. Debe ser igual o mayor que el timeframe micro.

## Pivotes y Bollinger

Las bandas son fijas: periodo `21`, desviacion `2.0`, shift `0` y
`PRICE_CLOSE`. No existen inputs para alterarlas.

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

## Inputs de estrategia

| Input | Default | Funcion |
| --- | ---: | --- |
| `Pivot_HFT_Direction_Mode` | Ambas | Habilita compras, ventas o ambas. |
| `Pivot_HFT_Retracement_Points` | `25.0` | Retroceso desde el extremo Bid/Ask antes de la entrada. |
| `Pivot_HFT_Local_SL_Points` | `25.0` | Distancia del SL local desde el fill real. |
| `Pivot_HFT_TP_Step_Points` | `25.0` | Step 1 a BE y steps posteriores avanzan el SL. |
| `Pivot_HFT_Lot_Size` | `0.01` | Volumen fijo normalizado al simbolo. |
| `Pivot_HFT_Enable_Visualization` | `true` | Muestra pivotes, bandas, campana y posiciones. |

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

## Controles conservados

- Cuenta hedging obligatoria.
- Magic live entregado por licencia y magic determinista en tester.
- Spread maximo, margen, sesiones, limite diario, drawdown y estado del broker.
- Cierres forzados filtrados por simbolo y magic.

El perfil backend conserva deliberadamente la identidad Pandora. No se cambia
`ea_id`, contrato de licencia, secretos ni payloads de resultados diarios.

## Validacion manual

Usar `Every tick based on real ticks` sobre la variante US30 del broker:

1. Rechazo de cuenta netting durante `OnInit`.
2. Reemplazo del pivote pendiente por el ultimo nivel tocado.
3. Entradas BUY/SELL con SL y TP servidor en cero.
4. SL local, BE, steps posteriores y cierre por ticket independiente.
5. Reintento en perdida/BE solo dentro de la vela micro original.
6. Multiples tickets activos en velas o niveles posteriores.
7. Bloqueos por spread, margen, sesion, limite diario y proteccion.
8. Limpieza de handles, lineas y comentario al retirar el EA.
