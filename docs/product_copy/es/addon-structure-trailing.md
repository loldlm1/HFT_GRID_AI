# Copy de Producto - Structure Trailing

## Producto
- Nombre: `Structure Trailing`
- Tipo: `Addon`
- SKU: `addon_structure_trailing`

## Bloque Corto
`Desbloquea un trailing guiado por estructura para que cada senal pueda proteger ganancias y tomar parciales locales a medida que el mercado confirma nuevos maximos o minimos.`

## Bloque Medio
`Este addon agrega una capa de trailing adaptativo basada en estructura estocastica cerrada. En lugar de usar SL/TP server-side fijos, el EA sigue picos y fondos confirmados de forma local y actualiza la proteccion de la senal conforme evoluciona la estructura.`

`Para usuarios no traders: significa que la estrategia puede "mover la proteccion con el mercado" y tomar ganancias por partes en lugar de cerrar toda la senal de una sola vez.`

## Inputs Explicados (Lenguaje Simple)
- `Trailing_Structure_Mode`: activa el trailing estructural y permite usar la variante protegida por TP/BE.
- `Trailing_TP_Close_Percent`: porcentaje del tamano original de la senal que se cierra en cada nuevo evento TP valido.

## Configuracion Recomendada Inicial
- `Trailing_Structure_Mode = TRAILING_BY_STRUCTURE`
- `Trailing_TP_Close_Percent = 25.0`

## Regla de Acceso
- Requiere entitlement cuando `Trailing_Structure_Mode != TRAILING_OFF`.

## Si Falta el Addon
- Se bloquea el inicio cuando se selecciona un modo trailing.
- El EA no hace fallback a SL/TP server-side.
