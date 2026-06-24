# **Pandora Box: Guía de Instalación y Manual de Usuario**

## 1. Introducción
Bienvenido a la guía oficial de instalación y uso de **Pandora Box**, un EA (Expert Advisor) para MetaTrader 5 enfocado en ejecuciones por ruptura con control de riesgo y validación de licencia en línea.

---

## 2. Video de Instalación

Antes de continuar, recomendamos ver el siguiente video de instalación, que explica paso a paso cómo configurar **Pandora Box** en tu plataforma:

[[youtube:https://youtu.be/UtQj0znIjoY]]

---

## 3. Guía de Instalación

Sigue estos pasos detallados para instalar y configurar **Pandora Box** en MetaTrader 5:

### 1. **Descarga Pandora Box EA**
   - Descarga el archivo de **Pandora Box EA** desde el sitio oficial o la fuente proporcionada.

### 2. **Copia Pandora Box EA**
   - Una vez descargado, cópialo al portapapeles.

### 3. **Abre MetaTrader 5 (MT5)**
   - Abre tu plataforma **MetaTrader 5**.

### 4. **Abre la Carpeta de Datos**
   - Haz clic en "Archivo" en la barra superior de MetaTrader 5 y selecciona "Abrir carpeta de datos".

### 5. **Accede a MQL5**
   - En la ventana emergente, abre la carpeta **MQL5**.

### 6. **Accede a Experts**
   - Dentro de la carpeta **MQL5**, abre la carpeta **Experts**.

### 7. **Pega Pandora Box EA**
   - Pega el archivo de **Pandora Box EA** que copiaste previamente en esa carpeta.

### 8. **Cierra la Carpeta de Datos**
   - Cierra la ventana de la carpeta de datos.

### 9. **Actualiza Expert Advisors**
   - Regresa al Navegador de MetaTrader 5, haz clic derecho y selecciona "Actualizar" en la sección **Expert Advisors**.

### 10. **Habilita WebRequest para la Validación de Licencia en Línea**
   - En MT5, ve a **Herramientas -> Opciones -> Asesores Expertos**.
   - Habilita **Permitir WebRequest para la URL indicada**.
   - Agrega esta URL exacta a la lista permitida: `https://tradingsniperpanel.com`.

### 11. **Arrastra Pandora Box EA al Gráfico**
   - Busca **Pandora Box EA** en la lista de Expert Advisors y arrástralo al gráfico de tu preferencia.

### 12. **Ingresa la Licencia**
   - Se solicitará la clave de licencia. Pégala exactamente como fue proporcionada.

### 13. **Listo para Operar**
   - **Pandora Box** ya está instalado y listo para operar.

---

## 4. Guía de Usuario: Parámetros Configurables

**Pandora Box** utiliza entradas configurables para controlar la construcción del box, las rupturas, la gestión de riesgo y la ejecución.

### **Cómo Funciona Pandora Box**
- El EA construye un box diario de precio usando `Pandora_Box_Time_Range`.
- Las ventanas del mismo día usan inicio `<` fin; las ventanas nocturnas usan inicio `>` fin, pertenecen al día en que cierran y empiezan desde el día de la última vela D1 cerrada conocida. Valores iguales de inicio/fin son inválidos.
- Después de cerrar la ventana, calcula precios de ruptura con `Pandora_Box_Offset_Points`.
- `Pandora_Box_Entry_Type = ENTRY_WICK_TYPE` conserva la ruptura actual por tick/precio. `ENTRY_BODY_TYPE` espera que la última vela cerrada del timeframe seleccionado cierre fuera del nivel de ruptura con offset.
- Las entradas por cuerpo usan validaciones inclusivas (`close_1 >= breakout_high_price` alcista, `close_1 <= breakout_low_price` bajista) y consumen cada vela cerrada válida una sola vez por dirección, aunque una validación posterior bloquee la orden.
- Si el disparador seleccionado rompe por arriba/abajo y todas las validaciones locales se cumplen (direccion, sesion, limites diarios, concurrencia), Pandora reserva el presupuesto de entrada. La entrada local activa se ancla a ejecucion broker-realistic: fill real del broker primero, o Bid/Ask ejecutable cuando el spread vuelve a rango.
- `Pandora_First_Entry_Mode` es un input entero de profundidad que controla cuando se admite la primera entrada real al mercado. `0` conserva la entrada default en breakout. `-1` crea una entrada solo local y nunca llama `OrderSend`.
- Los valores `1`, `2` y superiores prueban entradas profundas en la misma direccion (`SL1`, `SL2`, `SLN`, con clamp a `20`). Si la observacion local del breakout toca TP antes del nivel profundo solicitado, la oportunidad se descarta como win local. Si el nivel profundo se toca primero, inicia el flujo normal broker-realistic.
- Los `.set` existentes que usaban los labels enum anteriores requieren migracion manual: `First_Entry_Breakout` -> `0`, `First_Entry_Sl_1` -> `1`, `First_Entry_Sl_2` -> `2`, `First_Entry_Off` -> `-1`.
- Las observaciones profundas usan un TP fijo de invalidacion. En modo TP fijo usa `Pandora_Points_TP`; en step trailing usa la misma distancia resuelta que `Pandora_Points_SL`. El trailing solo aplica despues de admitir una entrada real al mercado.
- Las compuertas de performance son internas. En Strategy Tester, el refresh idle de grafico/comentario se limita a nuevas velas del chart, mientras observaciones Pandora activas, retries broker, posiciones, cierres, force-close y transiciones de ventana operativa siguen usando checks por tick.
- La reentrada por cada lado se rearma solo cuando `close_1` vuelve dentro del box sin offset. En modo wick usa el timeframe del box Pandora; en modo body usa `Pandora_Box_Entry_Body_Timeframe`.
- `Pandora_Box_Max_Entries` controla el presupuesto de entradas Pandora (`0` significa ilimitado). Una ruptura con spread alto puede reservar el presupuesto mientras espera que el spread vuelva a rango.
- Si el presupuesto se alcanza con entradas locales aun abiertas, el estado muestra `PANDORA WAIT_CLOSE`; al cerrarse localmente, pasa a `PANDORA DONE`.
- `Pandora_Box_Entry_Count_Mode` solo controla el contador analítico `counted`; no reemplaza el presupuesto de entradas abiertas.
- `Pandora_Box_Set_Broker_SLTP` es una capa extra de proteccion del lado del broker despues del fill. El SL/TP exacto de Pandora sigue siendo local y se calcula desde la entrada broker-realistic activa.
- El SL/TP del broker inicia pendiente/ausente despues del fill, y luego puede quedar exacto, mas amplio o fallido mientras apliquen las reglas de stops/freeze del broker.
- Si el spread esta fuera de rango en la ruptura, Pandora espera antes de crear la entrada local activa. Las aperturas broker se envian sin SL/TP inicial para que invalid stops no bloquee la entrada al mercado. El volumen se repara una vez; fallos de `OrderSend` se reintentan en ticks elegibles hasta agotar el presupuesto.
- Un retry exitoso reemplaza cualquier anchor local simulado por el fill real del broker, recalcula SL/TP/trailing local y redibuja el marker desde la entrada real.
- Los marcadores del grafico dibujan entradas broker-realistic activas. Entradas ejecutadas por broker usan etiquetas como `20$ (Posicion ejecutada)`; entradas bloqueadas/rechazadas usan etiquetas como `10$ (Posicion local - ERR_Stops)`, `ERR_Volumen` o `ERR_Margen`.

### **Identidad de Ejecución, Comentarios y Panel de Estado**
- En modo live, Pandora Box usa el magic de operación aprobado por el backend para esa instancia del EA después de validar la licencia. `Custom_Magic` sigue siendo útil para Strategy Tester, pero el live no depende de magic aleatorio.
- `EA_Instance_Id` puede dejarse vacío para que el EA persista localmente un id de instancia del gráfico. Defínelo manualmente solo si necesitas conservar la misma identidad tras reinstalar o migrar.
- Cada gráfico de producción debe operar como su propia instancia del EA. Dos gráficos en el mismo terminal deben mostrar magic runtime distintos y no deben gestionar posiciones del otro.
- Los nuevos comentarios del broker usan el formato en minúsculas `pandora_box_pos_n`, por ejemplo `pandora_box_pos_1`.
- Las entradas `local_rejected` son estado local del EA, no posiciones del broker. Conserva el motivo de rechazo en reportes locales y no infieras ejecucion broker desde un marcador local.
- Si MT5 Algo Trading, el permiso de trading del EA o el permiso experto de la cuenta están desactivados, el EA muestra estado disabled/platform y omite acciones de broker hasta que el permiso vuelva. El SL/TP del broker queda como única protección activa mientras está desactivado.
- El panel y el comentario del Strategy Tester muestran `Error: OK`, `Error: ACTIVE ...` o `Last error: ...`. Esta etiqueta es solo informativa y no cambia las decisiones de trading.

---

### **Parámetros de Entrada**

| **Parámetro** | **Valor por Defecto** | **Descripción** | **Uso Recomendado** |
|---|---:|---|---|
| `Pandora_Box_Time_Range` | `"12:00-13:30"` | Ventana de construcción del box. Formato: `HH:MM-HH:MM`; usa inicio `<` fin para el mismo día o inicio `>` fin para ventanas nocturnas como `23:00-00:10`. | Usa ventanas líquidas (60-180 minutos). |
| `Pandora_Box_Stop_On_First_Win` | `true` | Finaliza Pandora por el día tras el primer cierre con beneficio. | Mantén `true` para un ritmo conservador. |
| `Pandora_Box_Direction_Mode` | `BOTH_DIRECTION` | Lado(s) permitidos de ruptura: ambos, solo alcista o solo bajista. | Restringe a un lado solo con sesgo direccional claro. |
| `Pandora_Box_Use_Session_Filter` | `true` | Aplica filtros horarios de sesión a intentos Pandora. | Mantén `true` cuando la política de sesión sea parte del riesgo. |
| `Pandora_Box_Enable_Visualization` | `true` | Dibuja el frontend visual de Pandora: box actual, guías de ruptura y hasta 8 zonas diarias (día actual + 7 días previos de trading). Los días históricos inválidos conservan el relleno DimGray y muestran una etiqueta simple. | Mantén activo durante configuración/ajuste. |
| `Pandora_Box_Set_Broker_SLTP` | `true` | Agrega proteccion SL/TP del lado del broker despues del fill y durante modificaciones posteriores. Las aperturas market se envian sin SL/TP inicial; el SL/TP exacto de Pandora sigue validandose localmente desde la entrada broker-realistic activa. | Manten `true` para proteccion extra del servidor, pero valida el SL/TP source-of-truth en tester. |
| `Pandora_Box_Entry_Type` | `ENTRY_WICK_TYPE` | Estilo de disparo de entrada. `ENTRY_WICK_TYPE` usa ruptura por tick/precio actual; `ENTRY_BODY_TYPE` exige una vela cerrada fuera del nivel de ruptura con offset. | Mantén `WICK` para comportamiento legacy; usa `BODY` para reducir rupturas solo por mecha. |
| `Pandora_Box_Entry_Body_Timeframe` | `PERIOD_M5` | Timeframe estándar de MT5 usado por `ENTRY_BODY_TYPE` para ruptura por vela cerrada y rearme. `PERIOD_CURRENT` se resuelve con el fallback Pandora/estrategia. | Empieza con `PERIOD_M5` para confirmación determinística por cuerpo. |
| `Enable_Chart_Levels` | `true` | Habilita el frontend visual fijo. Cuando `Enable_Chart_Summary` tambien esta activo, el grafico en vivo usa el panel compacto en la esquina superior izquierda en lugar del `Comment()` en vivo; el Strategy Tester mantiene el fallback por comentario. El refresh del tester se limita mientras esta idle y vuelve inmediatamente para lifecycle Pandora activo. Los marcadores Pandora dibujan entradas locales y ejecutadas por broker. | Manten activo para monitoreo manual. |
| `Pandora_Risk_Trailing_Mode` | `PANDORA_RISK_TRAILING_OFF` | Comportamiento de trailing: `OFF` o `PANDORA_RISK_TRAILING_STEP_TP`. | Comienza con `OFF`; usa `STEP_TP` tras validar en tester. |
| `Pandora_Lot_Type` | `PANDORA_LOT_SIZE` | Modo de lote: fijo, basado en porcentaje o basado en moneda. | Usa lote fijo al inicio; los modos por presupuesto requieren calibración. |
| `Pandora_Lot_Strategy_Size` | `0.01` | Tamaño usado por el modo de lote seleccionado. | Empieza pequeño y aumenta gradualmente. |
| `Pandora_Box_Max_Range_Points` | `0.0` | Rango máximo permitido del box en puntos (`0` desactiva filtro). | Define un tope para saltar días con rango excesivo. |
| `Pandora_Points_Value_Mode` | `PANDORA_VALUE_MODE_POINTS` | Interpreta offset/SL/TP como puntos o `%` del rango del box. | Prefiere puntos primero; usa `%` para escalado adaptativo. |
| `Pandora_Box_Offset_Points` | `1.0` | Distancia buffer de ruptura desde el high/low del box. | Mantén valor distinto de cero para reducir rupturas falsas. |
| `Pandora_Points_SL` | `100.0` | Distancia de stop para entradas Pandora. | Debe ser `> 0`; ajusta por símbolo. |
| `Pandora_Points_TP` | `100.0` | Distancia de take profit para entradas Pandora. En step trailing, la invalidacion de observacion profunda usa `Pandora_Points_SL` en su lugar. | Mantén positivo salvo que quieras salida solo por trailing. |
| `Pandora_Box_Entry_Count_Mode` | `COUNT_BOX_ENTRY_OFF` | Controla la analítica `counted`: todo (`SL/TP/BE`), `SL+BE` o `TP+BE`. | Usa `OFF` para diagnóstico completo. |
| `Pandora_Box_Max_Entries` | `2` | Presupuesto de entradas Pandora broker-realistic por dia/ventana (`0` = ilimitado). Entradas pending por spread y bloqueadas/rechazadas por broker tambien cuentan. | Manten bajo (`1-2`) salvo que tus protecciones globales sean estrictas. |
| `Pandora_First_Entry_Mode` | `0` | Profundidad de primera entrada: `-1` local-only/sin mercado broker, `0` breakout default, `1` SL1, `2` SL2, `N` hasta `20` para niveles mas profundos en la misma direccion. | Manten `0` como default; usa `1+` para investigacion en Strategy Tester. |

---

## 5. Perfiles de Configuración Rápida

### **Perfil A: Intradía Conservador**
- `Pandora_Box_Time_Range = "08:00-09:30"`
- `Pandora_Box_Max_Range_Points = 180`
- `Pandora_Points_Value_Mode = PANDORA_VALUE_MODE_POINTS`
- `Pandora_Box_Offset_Points = 20`
- `Pandora_Points_SL = 120`
- `Pandora_Points_TP = 120`
- `Pandora_Risk_Trailing_Mode = PANDORA_RISK_TRAILING_OFF`
- `Pandora_Box_Stop_On_First_Win = true`
- `Pandora_Box_Entry_Count_Mode = COUNT_BOX_ENTRY_OFF`
- `Pandora_Box_Max_Entries = 2`
- `Pandora_Box_Direction_Mode = BOTH_DIRECTION`

### **Perfil B: Sesión con Sesgo de Tendencia**
- `Pandora_Box_Time_Range = "12:00-13:30"`
- `Pandora_Box_Max_Range_Points = 0`
- `Pandora_Points_Value_Mode = PANDORA_VALUE_MODE_BOX_PERCENT`
- `Pandora_Box_Offset_Points = 10` (10% del rango del box)
- `Pandora_Points_SL = 40` (40% del rango del box)
- `Pandora_Points_TP = 70` (70% del rango del box)
- `Pandora_Risk_Trailing_Mode = PANDORA_RISK_TRAILING_STEP_TP`
- `Pandora_Box_Stop_On_First_Win = false`
- `Pandora_Box_Entry_Count_Mode = COUNT_BOX_ENTRY_ON_SL`
- `Pandora_Box_Max_Entries = 2`
- `Pandora_Box_Direction_Mode = BULLISH_DIRECTION` (o `BEARISH_DIRECTION`)

---

## 6. Pandora XBoost Robust Forward Scoring v4

Pandora XBoost es una capa opcional de arbol de progresion para Pandora Box.
Se basa en la primera senal Pandora del dia y puede evaluar hasta
`Pandora_XBoost_Max_Depth` decisiones secuenciales de rama.

### Modos Operativos
- `PANDORA_XBOOST_DISABLED`: XBoost esta apagado y Pandora conserva su
  comportamiento normal.
- `PANDORA_XBOOST_TRAINING`: registra estadisticas de ramas locales solamente;
  XBoost no abre trades reales al broker.
- `PANDORA_XBOOST_INFERENCE`: registra estadisticas locales y puede abrir un
  trade real broker cuando un candidato esta `READY` y pasan todas las
  compuertas normales de broker. En live/real este modo es adaptativo: sigue
  aprendiendo mientras decide si abre operaciones reales.

### Metodologia del Modelo
- El arbol local de progresion es el modelo de descubrimiento porque observa
  todas las ramas, incluso las que no se abren en broker.
- El score base sigue usando Bayesian shrinkage para acercar ramas con pocas
  muestras al prior global de la estrategia.
- El score v4 agrega credito limitado por payoff trailing cuando los ganadores
  grandes parecen repetibles.
- El score v4 resta penalizaciones por fragilidad de distribucion, mediana
  negativa, dependencia de pocos outliers y degradacion forward.
- La estabilidad forward se calcula por segmentos de muestras disponibles, no
  por una ventana anual fija. Si no hay suficientes muestras, queda neutral.
- El ledger real broker degrada por nodo exacto o familia de path. Ya no actua
  como bloqueo global ruidoso de toda la estrategia.
- El filtro de regimen se deja para un feature futuro para no fragmentar
  muestras demasiado temprano.
- En v4 no hay un kill switch global separado de XBoost. Si ningun candidato
  llega a `READY`, XBoost no abre trade real y continua generando estadisticas
  locales.

### Estados de Candidato
- `READY`: el candidato paso muestras locales, score robusto v4, edge,
  estabilidad forward, degradacion broker por nodo/path y presupuesto/guards
  normales.
- `WATCH`: el candidato tiene informacion util pero no es suficientemente fuerte
  para ejecucion real broker.
- `BLOCK`: el candidato queda bloqueado por score robusto, degradacion rolling,
  degradacion broker por nodo/path u otra compuerta XBoost.

### Archivos CSV
XBoost v4 escribe archivos CSV separados en Common storage bajo la carpeta
existente `PandoraXBoost`:

- `*_stats.csv`: estadisticas agregadas del modelo local por nodo.
- `*_samples.csv`: samples locales idempotentes por dia/sample id.
- `*_broker_trades.csv`: trades reales cerrados que fueron seleccionados por
  XBoost solamente.

### Ejemplo de Panel

```text
XBOOST INFERENCE v4 root=L day=2026.06.23 d=2 broker=1/3
XB data stats=86 samples=4417 broker=184 pend=0/0 Common\mt5_xxx\us_30_v1
XB1 L-TTPL2 READY n=72 v4=0.08 p=0.18 med=-0.02 pf=1.42 brn=0.06
XB2 S-TTPL2 WATCH n=41 v4=0.01 p=0.04 med=-0.98 pf=0.91 reason=EDGE
XB3 L-TBES BLOCK n=56 v4=-0.04 p=0.09 med=-1.00 pf=1.04 reason=ROBUST_SCORE
```

`p` es posterior R, `v4` es el score robusto final, `med` es la mediana R,
`pf` es profit factor local y `brn` es evidencia broker del nodo exacto cuando
existe.

### Workflow de QA Manual
- Corre una prueba corta de 5 dias en inferencia con `Enable_File_Logs = true`.
- Confirma que existan archivos v4 `stats`, `samples` y `broker_trades` en
  Common storage despues de que cierre al menos un trade real XBoost broker.
- Confirma que `query_debug.txt` incluya `PANDORA_XBOOST_DRYRUN`,
  `PANDORA_XBOOST_BROKER_SELECTED` y diagnosticos de save/load del ledger.
- Confirma que `PANDORA_XBOOST_DRYRUN` muestre `score_v4`, `med`, `wr`, `pf`,
  `frag`, `fwd`, `brnode` y `brpath`.
- Confirma que repetir el mismo rango de fechas no duplique sample ids ni
  broker trade ids.
- Confirma que dias con solo candidatos `WATCH`/`BLOCK` no abran trades reales,
  pero sigan generando estadisticas locales.
- Confirma que XBoost no abra posiciones reales simultaneas en broker.
- Trata pruebas largas de inferencia como integracion adaptativa. El objetivo
  principal de v4 es aumentar trades reales sin volver a aceptar ramas fragiles
  que solo se ven positivas por pocos outliers de trailing.

---

## 7. Checklist de Validación Antes de Operar en Vivo
Antes de ejecutar **Pandora Box** en una cuenta real, verifica:

- El formato de horario es válido (`HH:MM-HH:MM`), usando inicio `<` fin para boxes del mismo día o inicio `>` fin para boxes nocturnos.
- `Pandora_Points_SL > 0`.
- Si usas modo `%`, que offset/SL/TP sean porcentajes realistas para el símbolo.
- Que el modo de dirección coincida con tu sesgo de mercado.
- Que `Pandora_Box_Max_Entries` coincida con tu presupuesto de entradas Pandora.
- Que las lineas de modo profundo (`TP obs`, `SLN entry`) coincidan con los niveles esperados antes de evaluar resultados del tester.
- En Strategy Tester, recuerda que las actualizaciones idle de grafico/comentario pueden aparecer por nueva vela del chart en vez de cada tick; entradas, observaciones, retries y cierres activos deben seguir actualizando inmediatamente.
- Que los escenarios `local_rejected` esten claros: rechazo por stops/volumen/margen puede dejar una entrada broker-realistic local viva hasta cierre local por SL/TP/BE/trailing.
- Que el SL/TP broker se valide como proteccion extra despues del fill; el SL/TP local exacto se basa en el fill real o anchor simulado activo aunque los stops broker esten temporalmente mas amplios, pendientes, fallidos o ausentes tras una apertura valida sin SL/TP inicial.
- Que los filtros de sesión estén configurados si `Pandora_Box_Use_Session_Filter = true`.
- Que `Permitir WebRequest para la URL indicada` esté activo con `https://tradingsniperpanel.com`.
- Que cada gráfico de producción muestre su propio magic runtime aprobado por backend y no gestione posiciones de otros gráficos/símbolos.
- Que las nuevas operaciones muestren comentarios como `pandora_box_pos_1`.
- Que al apagar MT5 Algo Trading se muestre estado disabled/platform y se detengan intentos de orden, cierre, cierre parcial, hedge y modificación SL/TP.
- Que el panel/comentario del tester muestre `Error: OK` en operación normal y un error activo/histórico útil después de una prueba segura de rechazo.
- Que el estado del gráfico no muestre `PANDORA INVALID WINDOW` ni `PANDORA INVALID BOX`.

---

## 8. Solución de Problemas de Licencia y WebRequest
Si WebRequest no está configurado, la validación de licencia en línea puede fallar y el EA puede retirarse después de los chequeos de inicialización/refresh.

### Síntomas comunes
- La validación de licencia falla inmediatamente al adjuntar el EA.
- El EA deja de ejecutarse y muestra error de conexión/validación de licencia en logs.

### Ruta de corrección (MT5)
1. Abre **Herramientas -> Opciones -> Asesores Expertos**.
2. Activa **Permitir WebRequest para la URL indicada**.
3. Agrega exactamente: `https://tradingsniperpanel.com`.
4. Vuelve a adjuntar el EA e ingresa de nuevo la clave de licencia.
