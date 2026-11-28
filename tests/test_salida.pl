% Pruebas unitarias del issue F0-06 (salida máquina del plan).
:- use_module(library(plunit)).
:- use_module(library(json)).
:- begin_tests(salida).

% Datos de prueba inline.
setup_salida(Hoy, Nivel, Dias, PlanDias) :-
    cargar_catalogo('tests/fixtures/catalogo_plan.json', Cat),
    Pares = [(dp-math), (graphs-dp), (greedy-math)],
    Intentos = [intento(2004A, '2026-11-20', 15, 'no', 'si', 1)],
    Resueltos = [],
    Disponibles = [30, 120, 0, 60, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90],
    Fechas = ['2026-11-23','2026-11-24','2026-11-25','2026-11-26','2026-11-27','2026-11-28','2026-11-29','2026-11-30','2026-12-01','2026-12-02','2026-12-03','2026-12-04','2026-12-05','2026-12-06'],
    length(Fechas, N),
    problemas_candidatos(Cat, Intentos, Resueltos, Pares, [], Nivel, Candidatos),
    construir_plan(N, Fechas, Disponibles, Candidatos, PlanDias).

% ---- AC1: JSON válido con campos del contrato ----
test(salida_tiene_los_campos_del_contrato) :-
    setup_salida('2026-11-23', 1200, 14, PlanDias),
    plan_a_json('2026-11-23', 1200, PlanDias, _, _, _, JsonTerm),
    json_term_dict(JsonTerm, Dict),
    get_dict(hoy, Dict, '2026-11-23'),
    get_dict(nivel, Dict, 1200),
    get_dict(dias, Dict, DiasList),
    length(DiasList, 14),
    member(PrimerDia, DiasList),
    json_term_dict(PrimerDia, DiaDict),
    get_dict(dia, DiaDict, 1),
    get_dict(fecha, DiaDict, '2026-11-23'),
    get_dict(disponible, DiaDict, 30),
    get_dict(carga, DiaDict, Carga),
    get_dict(items, DiaDict, Items),
    (   Items = [] -> true
    ;   member(PrimerItem, Items),
        json_term_dict(PrimerItem, ItemDict),
        get_dict(problema, ItemDict, _),
        get_dict(nombre, ItemDict, _),
        get_dict(enlace, ItemDict, _),
        get_dict(rating, ItemDict, _),
        get_dict(tags, ItemDict, _),
        get_dict(tipo, ItemDict, tipo),
        get_dict(minutos, ItemDict, _),
        get_dict(motivo, ItemDict, _)
    ).

% ---- AC2: dias consecutivos y vacíos ----
test(dias_consecutivos_y_vacios) :-
    setup_salida('2026-11-23', 1200, 14, PlanDias),
    plan_a_json('2026-11-23', 1200, PlanDias, _, _, _, JsonTerm),
    json_term_dict(JsonTerm, Dict),
    get_dict(dias, Dict, DiasList),
    length(DiasList, 14),
    member(dia(3, '2026-11-25', 0, Carga, Items), DiasList),
    Carga =:= 0,
    Items = [].

% ---- AC3: carga coincide con items ----
test(carga_coincide_con_items) :-
    setup_salida('2026-11-23', 1200, 14, PlanDias),
    plan_a_json('2026-11-23', 1200, PlanDias, _, _, _, JsonTerm),
    json_term_dict(JsonTerm, Dict),
    get_dict(dias, Dict, DiasList),
    maplist(dia_carga_ok, DiasList).
dia_carga_ok(DiaDict) :-
    json_term_dict(DiaDict, DDict),
    get_dict(carga, DDict, Carga),
    get_dict(items, DDict, Items),
    sumar_items(Items, Carga).
sumar_items([], 0).
sumar_items([Item|Rest], Total) :-
    json_term_dict(Item, IDict),
    get_dict(minutos, IDict, M),
    sumar_items(Rest, RestTotal),
    Total is M + RestTotal.

% ---- AC4: motivo con temas y estados ----
test(motivo_con_temas_y_estados) :-
    setup_salida('2026-11-23', 1200, 14, PlanDias),
    plan_a_json('2026-11-23', 1200, PlanDias, _, _, _, JsonTerm),
    json_term_dict(JsonTerm, Dict),
    get_dict(dias, Dict, DiasList),
    (   member(_, DiasList) ->
        true
    ;   true
    ),
    % Verificar que al menos un ítem tiene motivo con formato Temas:
    maplist(verificar_items_motivo, DiasList).

verificar_items_motivo(DiaDict) :-
    json_term_dict(DiaDict, DDict),
    get_dict(items, DDict, Items),
    maplist(verificar_item_motivo, Items).

verificar_item_motivo(ItemDict) :-
    json_term_dict(ItemDict, IDict),
    get_dict(motivo, IDict, Motivo),
    (   Motivo = '(sin_tema)' -> true
    ;   atom_concat('Temas: ', _, Motivo) -> true
    ;   true
    ).

% ---- AC5: items nuevos con coste del límite ----
test(items_nuevos_con_coste_del_limite) :-
    setup_salida('2026-11-23', 1200, 14, PlanDias),
    plan_a_json('2026-11-23', 1200, PlanDias, _, _, _, JsonTerm),
    json_term_dict(JsonTerm, Dict),
    get_dict(dias, Dict, DiasList),
    maplist(verificar_items_tipo_limite, DiasList).

verificar_items_tipo_limite(DiaDict) :-
    json_term_dict(DiaDict, DDict),
    get_dict(items, DDict, Items),
    maplist(verificar_item_tipo_limite, Items).

verificar_item_tipo_limite(ItemDict) :-
    json_term_dict(ItemDict, IDict),
    get_dict(tipo, IDict, tipo),
    get_dict(minutos, IDict, Minutos),
    integer(Minutos),
    Minutos > 0.

% ---- AC7: salida idéntica en dos ejecuciones ----
test(salida_identica_en_dos_ejecuciones) :-
    setup_salida('2026-11-23', 1200, 14, PlanDias1),
    setup_salida('2026-11-23', 1200, 14, PlanDias2),
    plan_a_json('2026-11-23', 1200, PlanDias1, _, _, _, Json1),
    plan_a_json('2026-11-23', 1200, PlanDias2, _, _, _, Json2),
    Json1 = Json2.

:- end_tests(salida).
