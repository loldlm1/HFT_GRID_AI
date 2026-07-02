# Copy de Producto - Session Time Filter

## Producto

- Nombre: `Session Time Filter`
- Tipo: `Control de fundacion`
- SKU: `addon_session_time_filter`

## Bloque Corto

`Controla cuando el EA puede evaluar o ejecutar logica de estrategia definiendo ventanas de Asia, Londres y Nueva York.`

## Bloque Medio

`Session Time Filter se conserva como comportamiento neutral de fundacion. Ayuda a evitar horarios no deseados del mercado permitiendo o restringiendo ejecucion durante ventanas configuradas.`

`Para usuarios no traders: funciona como horario laboral para el EA. Define cuando el sistema puede operar antes de que una futura estrategia continue hacia la ejecucion.`

## Inputs Explicados

- `Session_Asia_Filter_Mode`: comportamiento de la sesion Asia.
- `Session_Asia_Filter_Time_Range`: rango Asia en formato `HH:MM-HH:MM`.
- `Session_London_Filter_Mode`: comportamiento de la sesion Londres.
- `Session_London_Filter_Time_Range`: rango Londres.
- `Session_NewYork_Filter_Mode`: comportamiento de la sesion Nueva York.
- `Session_NewYork_Filter_Time_Range`: rango Nueva York.
- `Session_Time_Dst_Mode`: modo de manejo DST.
- `Session_Time_Dst_Manual_Offset_Minutes`: offset DST manual cuando aplica.

## Regla de Fundacion

Las reglas de sesion se evaluan antes de la ejecucion local simulada y antes de envios reales al broker.
