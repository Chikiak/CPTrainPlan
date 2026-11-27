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
