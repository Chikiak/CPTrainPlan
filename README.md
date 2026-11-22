# CPTrainPlan

Proyecto de Programación Declarativa: una aplicación que crea planes de entrenamiento de programación competitiva a partir de un perfil que se va actualizando (historial de intentos y disponibilidad) y de un catálogo de problemas de Codeforces con sus etiquetas y dificultad. El catálogo guarda solo metadatos y enlaces, no los enunciados.

El núcleo está en Prolog (SWI-Prolog, con CLP(FD)) y funciona sin conexión una vez descargado el catálogo.

## Documentos

- `PROYECTO_BASE.md`: ideas y requisitos del proyecto base.
- `MEJORAS.md`: ideas para después de terminar el base.
- `plan/MASTER.md`: plan de implementación por fases.
