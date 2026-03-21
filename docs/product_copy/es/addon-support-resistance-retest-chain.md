# Copy de Producto - Support Resistance Retest Chain

## Producto
- Nombre: `Support Resistance Retest Chain`
- Tipo: `Addon`
- SKU: `addon_support_resistance_retest_chain`

## Bloque Corto
`Agrega una capa recursiva de confirmacion por soporte y resistencia para que las entradas solo se activen cuando la estructura actual retestea zonas historicas relevantes.` 

## Bloque Medio
`Este addon agrega una validacion dura previa a la entrada basada en cadenas de retest de soporte y resistencia. El EA primero resuelve la entrada real de estructura y luego valida si ese precio cae dentro de la zona historica mas reciente y si los extremos mas antiguos confirman la misma area de forma recursiva.` 

`Para usuarios no traders: es una puerta de confluencia. El EA pregunta "esta entrada esta retesteando un area que el mercado ya respeto antes?". Si la respuesta es no, la operacion se descarta.` 

## Inputs Explicados (Lenguaje Simple)
- `Support_Resistance_Retest_Chain_Enabled`: activa o desactiva el addon.
- `Support_Resistance_Retest_Chain_Count`: profundidad minima requerida de la cadena.
- `Support_Resistance_Retest_Chain_Range_Percent`: ancho de la zona alrededor de cada extremo historico.

## Configuracion Recomendada Inicial
- `Support_Resistance_Retest_Chain_Enabled = true`
- `Support_Resistance_Retest_Chain_Count = 3`
- `Support_Resistance_Retest_Chain_Range_Percent = 10.0`

## Regla de Acceso
- Requiere entitlement cuando `Support_Resistance_Retest_Chain_Enabled = true`.

## Si Falta el Addon
- El EA bloquea el inicio cuando el addon esta habilitado.
