% Pruebas unitarias del issue F0-05 (generar plan válido con restricciones).
% Una prueba por criterio de aceptacion, sin mocks.
:- use_module(library(plunit)).
:- use_module(library(json)).

% ---- Cargar modulos necesarios para que plunit los vea ----
dummy.
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

:- begin_tests(plan).

% ---- Predicado auxiliar para generar catalogo sintetico (dentro de begin_tests) ----
gen_probs(N, Max, Out) :-
    N =< Max ->
    Rating is 800 + (N mod 2201),
    TagIdx is (N mod 30) + 1,
    number_chars(TagIdx, TagChars),
    atom_chars(TagStr, TagChars),
    atom_concat('tag', TagStr, TagFull),
    (   N = Max ->
        format(Out, '{"contestId":4000,"index":"~w","name":"P~w","rating":~w,"tags":["~s"]}', [N, N, Rating, TagFull])
    ;
        format(Out, '{"contestId":4000,"index":"~w","name":"P~w","rating":~w,"tags":["~s"]},', [N, N, Rating, TagFull])
    ),
    N1 is N + 1,
    gen_probs(N1, Max, Out).
gen_probs(_N, Max, _) :- _N > Max, !.

% ---- AC1: carga no excede disponibilidad ----
test(carga_no_excede_disponibilidad) :-
    cargar_catalogo('tests/fixtures/catalogo_plan.json', Cat),
    Pares = [(dp-math), (graphs-dp), (greedy-math)],
    Intentos = [intento('2004A', '2026-11-20', 15, 'no', 'si', 1)],
    Resueltos = [],
    Disponibles = [30, 120, 0, 60, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90],
    Fechas = ['2026-11-23','2026-11-24','2026-11-25','2026-11-26','2026-11-27','2026-11-28','2026-11-29','2026-11-30','2026-12-01','2026-12-02','2026-12-03','2026-12-04','2026-12-05','2026-12-06'],
    length(Fechas, N),
    problemas_candidatos(Cat, Intentos, Resueltos, Pares, [], 1200, Candidatos),
    construir_plan(N, Fechas, Disponibles, Candidatos, PlanDias),
    maplist(carga_ok_con_disp, PlanDias, Disponibles).
carga_ok_con_disp(dia(_D, _F, Disponible, Carga, _I), Disponible) :-
    Carga =< Disponible.

% ---- AC2: dia con disponibilidad 0 queda vacio ----
test(dia_sin_disponibilidad_queda_vacio) :-
    cargar_catalogo('tests/fixtures/catalogo_plan.json', Cat),
    Pares = [(dp-math), (graphs-dp), (greedy-math)],
    Intentos = [intento('2004A', '2026-11-20', 15, 'no', 'si', 1)],
    Resueltos = [],
    Disponibles = [30, 120, 0, 60, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90],
    Fechas = ['2026-11-23','2026-11-24','2026-11-25','2026-11-26','2026-11-27','2026-11-28','2026-11-29','2026-11-30','2026-12-01','2026-12-02','2026-12-03','2026-12-04','2026-12-05','2026-12-06'],
    length(Fechas, N),
    problemas_candidatos(Cat, Intentos, Resueltos, Pares, [], 1200, Candidatos),
    construir_plan(N, Fechas, Disponibles, Candidatos, PlanDias),
    member(dia(3, '2026-11-25', 0, Carga, Items), PlanDias),
    Carga =:= 0,
    Items = [].

% ---- AC3: ningun problema se repite ----
test(ningun_problema_se_repite) :-
    cargar_catalogo('tests/fixtures/catalogo_plan.json', Cat),
    Pares = [(dp-math), (graphs-dp), (greedy-math)],
    Intentos = [intento('2004A', '2026-11-20', 15, 'no', 'si', 1)],
    Resueltos = [],
    Disponibles = [30, 120, 0, 60, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90],
    Fechas = ['2026-11-23','2026-11-24','2026-11-25','2026-11-26','2026-11-27','2026-11-28','2026-11-29','2026-11-30','2026-12-01','2026-12-02','2026-12-03','2026-12-04','2026-12-05','2026-12-06'],
    length(Fechas, N),
    problemas_candidatos(Cat, Intentos, Resueltos, Pares, [], 1200, Candidatos),
    construir_plan(N, Fechas, Disponibles, Candidatos, PlanDias),
    maplist(ids_de_dia, PlanDias, TodasIds),
    append(TodasIds, Todos),
    length(Todos, Total),
    list_to_set(Todos, SinDups),
    length(SinDups, Total).
ids_de_dia(dia(_D, _F, _Dis, _C, Items), Ids) :-
    maplist(id_de_item, Items, Ids).
id_de_item(candidato(Id, _R, _M, _T, _G), Id).
unique([], []).
unique([H|T], [H|U]) :- \+ member(H, T), unique(T, U).
unique([_H|T], U) :- unique(T, U).

% ---- AC4: todos los problemas son candidatos validos ----
test(solo_asigna_candidatos_validos) :-
    cargar_catalogo('tests/fixtures/catalogo_plan.json', Cat),
    Pares = [(dp-math), (graphs-dp), (greedy-math)],
    Intentos = [intento('2004A', '2026-11-20', 15, 'no', 'si', 1)],
    Resueltos = [],
    Disponibles = [30, 120, 0, 60, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90],
    Fechas = ['2026-11-23','2026-11-24','2026-11-25','2026-11-26','2026-11-27','2026-11-28','2026-11-29','2026-11-30','2026-12-01','2026-12-02','2026-12-03','2026-12-04','2026-12-05','2026-12-06'],
    length(Fechas, N),
    problemas_candidatos(Cat, Intentos, Resueltos, Pares, [], 1200, Candidatos),
    construir_plan(N, Fechas, Disponibles, Candidatos, PlanDias),
    maplist(ids_de_dia, PlanDias, TodasIds),
    append(TodasIds, Todos),
    problemas_candidatos(Cat, Intentos, [], Pares, [], 1200, CandidatosValidos),
    maplist(id_de_item, CandidatosValidos, CandidatoIdsValidos),
    forall(member(Id, Todos), member(Id, CandidatoIdsValidos)).

% ---- AC5: ningun candidato sin asignar cabe en el hueco de algun dia ----
test(plan_no_deja_huecos_aprovechables) :-
    cargar_catalogo('tests/fixtures/catalogo_plan.json', Cat),
    Pares = [(dp-math), (graphs-dp), (greedy-math)],
    Intentos = [intento('2004A', '2026-11-20', 15, 'no', 'si', 1)],
    Resueltos = [],
    Disponibles = [30, 120, 0, 60, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90],
    Fechas = ['2026-11-23','2026-11-24','2026-11-25','2026-11-26','2026-11-27','2026-11-28','2026-11-29','2026-11-30','2026-12-01','2026-12-02','2026-12-03','2026-12-04','2026-12-05','2026-12-06'],
    length(Fechas, N),
    problemas_candidatos(Cat, Intentos, Resueltos, Pares, [], 1200, Candidatos),
    construir_plan(N, Fechas, Disponibles, Candidatos, PlanDias),
    ids_asignados(PlanDias, IdsAsignados),
    exclude(es_asignado(IdsAsignados), Candidatos, NoAsignados),
    % Ningun candidato sin asignar cabe en el hueco restante de ningun dia.
    forall((member(candidato(_Id, _R, M, _T, _G), NoAsignados),
            member(dia(_D, _F, Disponible, Carga, _Items), PlanDias)),
           M > Disponible - Carga).

ids_asignados(PlanDias, Ids) :-
    maplist(items_ids, PlanDias, Listas),
    append(Listas, Todos),
    list_to_set(Todos, Ids).

items_ids(dia(_D, _F, _Dis, _C, Items), Ids) :-
    maplist(id_de_item, Items, Ids).

es_asignado(IdsAsignados, candidato(Id, _R, _M, _T, _G)) :-
    member(Id, IdsAsignados).

% ---- AC6: dia de 120 recibe mas carga que el de 30, dia de 0 vacio ----
test(dias_con_mas_tiempo_reciben_mas_carga) :-
    cargar_catalogo('tests/fixtures/catalogo_plan.json', Cat),
    Pares = [(dp-math), (graphs-dp), (greedy-math)],
    Intentos = [intento('2004A', '2026-11-20', 15, 'no', 'si', 1)],
    Resueltos = [],
    Disponibles = [30, 120, 0, 60, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90],
    Fechas = ['2026-11-23','2026-11-24','2026-11-25','2026-11-26','2026-11-27','2026-11-28','2026-11-29','2026-11-30','2026-12-01','2026-12-02','2026-12-03','2026-12-04','2026-12-05','2026-12-06'],
    length(Fechas, N),
    problemas_candidatos(Cat, Intentos, Resueltos, Pares, [], 1200, Candidatos),
    construir_plan(N, Fechas, Disponibles, Candidatos, PlanDias),
    member(dia(1, _, 30, C1, _), PlanDias),
    member(dia(2, _, 120, C2, _), PlanDias),
    member(dia(3, _, 0, C3, _), PlanDias),
    C3 =:= 0,
    C2 >= C1.

% ---- AC7: plan determinista ----
test(plan_determinista) :-
    cargar_catalogo('tests/fixtures/catalogo_plan.json', Cat),
    Pares = [(dp-math), (graphs-dp), (greedy-math)],
    Intentos = [intento('2004A', '2026-11-20', 15, 'no', 'si', 1)],
    Resueltos = [],
    Disponibles = [30, 120, 0, 60, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90],
    Fechas = ['2026-11-23','2026-11-24','2026-11-25','2026-11-26','2026-11-27','2026-11-28','2026-11-29','2026-11-30','2026-12-01','2026-12-02','2026-12-03','2026-12-04','2026-12-05','2026-12-06'],
    length(Fechas, N),
    problemas_candidatos(Cat, Intentos, Resueltos, Pares, [], 1200, Candidatos),
    construir_plan(N, Fechas, Disponibles, Candidatos, Plan1),
    construir_plan(N, Fechas, Disponibles, Candidatos, Plan2),
    Plan1 = Plan2.

% ---- AC8: usa library(clpfd) ----
test(modelo_usa_clpfd) :-
    shell('grep -q clpfd src/plan.pl', Code),
    Code =:= 0.

% ---- AC9: falta fecha de disponibilidad -> error ----
test(error_falta_disponibilidad_de_un_dia) :-
    cargar_catalogo('tests/fixtures/catalogo_plan.json', Cat),
    Pares = [(dp-math), (graphs-dp), (greedy-math)],
    Intentos = [intento('2004A', '2026-11-20', 15, 'no', 'si', 1)],
    Resueltos = [],
    DisponiblesCortos = [30, 120, 0],
    Fechas = ['2026-11-23','2026-11-24','2026-11-25','2026-11-26','2026-11-27','2026-11-28','2026-11-29','2026-11-30','2026-12-01','2026-12-02','2026-12-03','2026-12-04','2026-12-05','2026-12-06'],
    problemas_candidatos(Cat, Intentos, Resueltos, Pares, [], 1200, Candidatos),
    (   construir_plan(14, Fechas, DisponiblesCortos, Candidatos, _Plan) ->
        assertion(false)
    ;   true
    ).

% ---- AC10: escala con catalogo sintetico de 3000 problemas ----
test(plan_14_dias_catalogo_sintetico) :-
    Generado = '/tmp/catalogo_3000_plan.json',
    open(Generado, write, Out),
    format(Out, '{"status":"OK","result":{"problems":[', []),
    gen_probs(1, 3000, Out),
    format(Out, ']}}', []),
    close(Out),
    cargar_catalogo(Generado, CatSintetico),
    Pares = [(dp-math), (graphs-dp), (greedy-math)],
    leer_historial('tests/fixtures/historial_candidatos.csv', Intentos),
    Resueltos = [],
    Disponibles = [30, 120, 0, 60, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90],
    Fechas = ['2026-11-23','2026-11-24','2026-11-25','2026-11-26','2026-11-27','2026-11-28','2026-11-29','2026-11-30','2026-12-01','2026-12-02','2026-12-03','2026-12-04','2026-12-05','2026-12-06'],
    problemas_candidatos(CatSintetico, Intentos, Resueltos, Pares, [], 1200, Candidatos),
    length(Candidatos, NCand),
    NCand =< 200,
    construir_plan(14, Fechas, Disponibles, Candidatos, PlanDias),
    maplist(carga_ok_con_disp, PlanDias, Disponibles),
    delete_file(Generado).

:- end_tests(plan).
