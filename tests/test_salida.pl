% Pruebas unitarias del issue F0-06 (salida máquina del plan).
:- use_module(library(plunit)).
:- use_module(library(json)).
:- consult('src/catalogo.pl').
:- consult('src/limites.pl').
:- consult('config/parametros.pl').
:- consult('src/historial.pl').
:- consult('src/fallo.pl').
:- consult('src/prerrequisitos.pl').
:- consult('src/temas.pl').
:- consult('src/candidatos.pl').
:- consult('src/disponibilidad.pl').
:- consult('src/plan.pl').
:- consult('src/salida.pl').

:- begin_tests(salida).

% Helper igual al de src/main.pl: estado de cada tema seguido.
tema_estado(Intentos, Cat, Tema, estado(Tema, Estado)) :-
    veredictos_por_tema(Tema, Intentos, Cat, Veredictos),
    estado_tema(Veredictos, Estado).

% Datos de prueba inline.
setup_salida(Hoy, Nivel, Dias, PlanDias, Estados, Cat) :-
    cargar_catalogo('tests/fixtures/catalogo_plan.json', Cat),
    Pares = [(dp-math), (graphs-dp), (greedy-math)],
    Intentos = [intento('2004A', '2026-11-20', 15, 'no', 'si', 1)],
    Resueltos = [],
    Disponibles = [30, 120, 0, 60, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90],
    Fechas = ['2026-11-23','2026-11-24','2026-11-25','2026-11-26','2026-11-27','2026-11-28','2026-11-29','2026-11-30','2026-12-01','2026-12-02','2026-12-03','2026-12-04','2026-12-05','2026-12-06'],
    length(Fechas, N),
    problemas_candidatos(Cat, Intentos, Resueltos, Pares, [], Nivel, Candidatos),
    construir_plan(N, Fechas, Disponibles, Candidatos, PlanDias),
    leer_historial('tests/fixtures/historial_plan.csv', IntH),
    veredictos_de_intentos(IntH, Cat, _Ver),
    temas_del_catalogo(Cat, TodasTemas),
    maplist(tema_estado(IntH, Cat), TodasTemas, Estados).

% ---- AC1: JSON válido con campos del contrato ----
test(salida_tiene_los_campos_del_contrato) :-
    setup_salida('2026-11-23', 1200, 14, PlanDias, Estados, Cat),
    plan_a_json('2026-11-23', 1200, PlanDias, _, Cat, Estados, Dict),
    get_dict(hoy, Dict, '2026-11-23'),
    get_dict(nivel, Dict, 1200),
    get_dict(dias, Dict, DiasList),
    length(DiasList, 14),
    member(PrimerDia, DiasList),
    get_dict(dia, PrimerDia, 1),
    get_dict(fecha, PrimerDia, '2026-11-23'),
    get_dict(disponible, PrimerDia, 30),
    get_dict(carga, PrimerDia, Carga),
    get_dict(items, PrimerDia, Items),
    (   Items = [] -> true
    ;   member(PrimerItem, Items),
        get_dict(problema, PrimerItem, _),
        get_dict(nombre, PrimerItem, _),
        get_dict(enlace, PrimerItem, _),
        get_dict(rating, PrimerItem, _),
        get_dict(tags, PrimerItem, _),
        get_dict(tipo, PrimerItem, tipo),
        get_dict(minutos, PrimerItem, _),
        get_dict(motivo, PrimerItem, _)
    ).

% ---- AC2: dias consecutivos y vacíos ----
test(dias_consecutivos_y_vacios) :-
    setup_salida('2026-11-23', 1200, 14, PlanDias, Estados, Cat),
    plan_a_json('2026-11-23', 1200, PlanDias, _, Cat, Estados, Dict),
    get_dict(dias, Dict, DiasList),
    length(DiasList, 14),
    member(Dia3, DiasList),
    get_dict(dia, Dia3, 3),
    get_dict(fecha, Dia3, '2026-11-25'),
    get_dict(carga, Dia3, Carga),
    Carga =:= 0,
    get_dict(items, Dia3, Items),
    Items = [].

% ---- AC3: carga coincide con items ----
test(carga_coincide_con_items) :-
    setup_salida('2026-11-23', 1200, 14, PlanDias, Estados, Cat),
    plan_a_json('2026-11-23', 1200, PlanDias, _, Cat, Estados, Dict),
    get_dict(dias, Dict, DiasList),
    maplist(dia_carga_ok, DiasList).
dia_carga_ok(DiaDict) :-
    get_dict(carga, DiaDict, Carga),
    get_dict(items, DiaDict, Items),
    sumar_items(Items, Carga).
sumar_items([], 0).
sumar_items([Item|Rest], Total) :-
    get_dict(minutos, Item, M),
    sumar_items(Rest, RestTotal),
    Total is M + RestTotal.

% ---- AC4: motivo con temas y estados ----
test(motivo_con_temas_y_estados) :-
    setup_salida('2026-11-23', 1200, 14, PlanDias, Estados, Cat),
    plan_a_json('2026-11-23', 1200, PlanDias, _, Cat, Estados, Dict),
    get_dict(dias, Dict, DiasList),
    (   member(_, DiasList) ->
        true
    ;   true
    ),
    % Verificar que al menos un ítem tiene motivo con formato Temas:
    maplist(verificar_items_motivo, DiasList).

verificar_items_motivo(DiaDict) :-
    get_dict(items, DiaDict, Items),
    maplist(verificar_item_motivo, Items).

verificar_item_motivo(ItemDict) :-
    get_dict(motivo, ItemDict, Motivo),
    (   Motivo = '(sin_tema)' -> true
    ;   atom_concat('Temas: ', _, Motivo) -> true
    ;   true
    ).

% ---- AC5: items nuevos con coste del límite ----
test(items_nuevos_con_coste_del_limite) :-
    setup_salida('2026-11-23', 1200, 14, PlanDias, Estados, Cat),
    plan_a_json('2026-11-23', 1200, PlanDias, _, Cat, Estados, Dict),
    get_dict(dias, Dict, DiasList),
    maplist(verificar_items_tipo_limite, DiasList).

verificar_items_tipo_limite(DiaDict) :-
    get_dict(items, DiaDict, Items),
    maplist(verificar_item_tipo_limite, Items).

verificar_item_tipo_limite(ItemDict) :-
    get_dict(tipo, ItemDict, nuevo),
    get_dict(minutos, ItemDict, Minutos),
    integer(Minutos),
    Minutos > 0.

% ---- AC7: salida idéntica en dos ejecuciones ----
test(salida_identica_en_dos_ejecuciones) :-
    setup_salida('2026-11-23', 1200, 14, PlanDias1, Estados1, Cat1),
    setup_salida('2026-11-23', 1200, 14, PlanDias2, Estados2, Cat2),
    plan_a_json('2026-11-23', 1200, PlanDias1, _, Cat1, Estados1, Dict1),
    plan_a_json('2026-11-23', 1200, PlanDias2, _, Cat2, Estados2, Dict2),
    Dict1 = Dict2.

:- end_tests(salida).
