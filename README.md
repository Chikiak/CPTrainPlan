# CPTrainPlan

Proyecto de Programación Declarativa: una aplicación que crea planes de entrenamiento de programación competitiva a partir de un perfil que se va actualizando (historial de intentos y disponibilidad) y de un catálogo de problemas de Codeforces con sus etiquetas y dificultad. El catálogo guarda solo metadatos y enlaces, no los enunciados.

El núcleo está en Prolog (SWI-Prolog, con CLP(FD)) y funciona sin conexión una vez descargado el catálogo.

## Documentos

- `PROYECTO_BASE.md`: ideas y requisitos del proyecto base.
- `MEJORAS.md`: ideas para después de terminar el base.
- `plan/MASTER.md`: plan de implementación por fases.

## Ejecutar

El núcleo está en SWI-Prolog. Desde la raíz del proyecto:

- Pruebas unitarias (plunit), termina con código 0 si todo pasa:
  `swipl -q -g run_tests -t halt tests/all.pl`
- Subcomando `catalogo`: lee el catálogo, excluye problemas sin rating y resume:
  `swipl src/main.pl catalogo [--catalogo datos/catalogo.json] [--problema <id>] [--parametros config/parametros.pl]`

Sin `--problema` imprime el resumen (con rating, excluidos sin rating, rating min/max). Con `--problema <id>` imprime nombre, rating, tags, enlace y límite de ese problema. Las rutas de `config/` y `datos/` se resuelven desde la raíz del proyecto. Todo error escribe en stderr una línea que empieza por `error:` y termina con código 1.

- Subcomando `intentos`: lee el catálogo y el historial, deduce el veredicto de cada intento y lo imprime:
  `swipl src/main.pl intentos --catalogo <archivo> --historial <archivo> [--parametros <archivo>]`
- Subcomando `temas`: lee el catálogo, prerrequisitos e historial, deduce el estado de cada tema e imprime si es trabajable:
  `swipl src/main.pl temas --catalogo <archivo> --prerrequisitos <archivo> --historial <archivo> [--parametros <archivo>]`
- Subcomando `candidatos`: selecciona problemas candidatos acotados para el plan:
  `swipl src/main.pl candidatos --catalogo <archivo> --prerrequisitos <archivo> --historial <archivo> --nivel <nivel> [--parametros <archivo>]`
- Subcomando `plan`: genera un plan de N días válido con restricciones CLP(FD):
  `swipl src/main.pl plan --catalogo <archivo> --prerrequisitos <archivo> --historial <archivo> --disponibilidad <archivo> --nivel <nivel> --hoy <fecha> [--dias <N>] [--parametros <archivo>] [--salida <archivo>]`

## Cómo usar

1. Descarga `datos/catalogo.json` desde la API de Codeforces:
   `https://codeforces.com/api/problemset.problems`
2. Edita `datos/prerrequisitos.csv` con las relaciones tema → prerrequisito (cabecera: `tema,prerrequisito`; comentarios con `#`).
3. Anota intentos en `datos/historial.csv` con las cinco columnas: `problema,fecha,minutos,ayuda,resuelto`.
4. Declara `datos/disponibilidad.csv` con las columnas `fecha,minutos` (una por día del plan).
5. Ejecuta el plan:
   `swipl src/main.pl plan --nivel <nivel> --hoy <fecha> [--dias <N>] [--salida <archivo.json>]`
