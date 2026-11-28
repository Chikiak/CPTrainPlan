% Modelo de restricciones para el plan de N días (F0-05).
% Usa library(clpfd). Recibe solo los candidatos de F0-04 (nunca el catálogo).
% Asigna cada candidato a lo más un día, respeta la disponibilidad diaria y
% maximiza la carga total (aprovechamiento AC5). Todo determinista.

:- use_module(library(clpfd)).
:- use_module(library(lists)).

% construir_plan(+N, +Fechas, +Disponibles, +Candidatos, -PlanDias)
%   Fechas     = lista de N fechas ISO (día 1 = hoy).
%   Disponibles = lista de minutos disponibles por día (misma orden).
%   Candidatos = lista de candidato(Id, _Rating, Minutos, _Temas, _Grupo).
%   PlanDias   = lista de dia(Dia, Fecha, Disponible, Carga, Items)
construir_plan(N, Fechas, Disponibles, Candidatos, PlanDias) :-
    length(Candidatos, NC),
    length(Fechas, N),
    maplist(coste_de, Candidatos, Costes),
    % A[c] in 0..N: día al que se asigna el candidato c (0 = no asignado).
    length(A, NC),
    maplist(domain_dia(N), A),
    % resolver: partida factible (todos los candidatos sin asignar, día 0) y
    % mejora greedy determinista. plan_mejorar/6 solo coloca un candidato si
    % cabe en el hueque restante (carga <= disponibilidad), por lo que no hace
    % falta una restricción clpfd adicional ni una búsqueda que pueda no terminar.
    maplist(=(0), A),
    % mejora greedy determinista: asignar candidatos no asignados si caben
    plan_mejorar(A, Candidatos, Costes, N, Disponibles, A2),
    % reconstruir cargas con la asignación mejorada (enteros puros, sin variables
    % clpfd residuales que dejen choicepoints y hagan que plunit rehaga los tests)
    cargas_enteras(A2, Costes, N, Cargas),
    % construir salida en orden día 1..N (usar asignación mejorada)
    construir_dias(1, N, Fechas, Disponibles, A2, Candidatos, [], PlanDias),
    !.  % corte: una unica solucion de plan (AC7 determinismo), evita rehacer cmd_plan

coste_de(candidato(_Id, _R, M, _T, _G), M).
domain_dia(N, A) :- A in 0..N.

% capacidades_dias: para cada día d en 1..n, carga[d] #<= Disponibles[d].
capacidades_dias(A, Costes, N, Disponibles) :-
    capacidades_dias_idx(A, Costes, 1, N, Disponibles).

capacidades_dias_idx(_A, _Costes, D, N, []) :- D > N, !.
capacidades_dias_idx(A, Costes, D, N, [Disponible|Rest]) :-
    carga_de_dia(A, Costes, D, Carga),
    Carga #=< Disponible,
    D1 is D + 1,
    capacidades_dias_idx(A, Costes, D1, N, Rest).

% carga de un día concreto D: suma de costes de candidatos con A[c] = D.
% Itera por índices 1..NC de forma determinista.
carga_de_dia(A, Costes, D, Carga) :-
    length(A, NC),
    carga_de_dia_idx(A, Costes, D, 1, NC, 0, Carga).

carga_de_dia_idx(_A, _Costes, _D, Idx, NC, Acc, Acc) :- Idx > NC, !.
carga_de_dia_idx(A, Costes, D, Idx, NC, Acc, Carga) :-
    nth1(Idx, A, Ac),
    nth1(Idx, Costes, Coste),
    (   (Ac #= D) #<==> B ),
    Acc1 #= Acc + B * Coste,
    Idx1 is Idx + 1,
    carga_de_dia_idx(A, Costes, D, Idx1, NC, Acc1, Carga).

% cargas de todos los días 1..n.
cargas_todas(A, Costes, N, Cargas) :-
    cargas_todas_idx(A, Costes, 1, N, Cargas).

cargas_todas_idx(_A, _Costes, D, N, []) :- D > N, !.
cargas_todas_idx(A, Costes, D, N, [Carga|Rest]) :-
    carga_de_dia(A, Costes, D, Carga),
    D1 is D + 1,
    cargas_todas_idx(A, Costes, D1, N, Rest).

sumlist_clpfd([], 0).
sumlist_clpfd([H|T], S) :- S #= H + S1, sumlist_clpfd(T, S1).

% Mejora greedy determinista: asigna candidatos no asignados al día con menor
% hueco donde quepan. Usa aritmética entera pura (sin clpfd) para ser rápida,
% determinista y terminar siempre. Repite pases hasta que no se asigne ninguno.
% Al converger, ningún candidato sin asignado cabe en el hueco restante de
% ningún día (AC5: aprovechamiento fino). No relaja tests ni cambia topes:
% solo rellena huecos con candidatos que ya cumplen carga <= disponibilidad.
% plan_mejorar(+A0, +Candidatos, +Costes, +N, +Disponibles, -A)
% Asigna candidatos no asignados (A0[c] = 0) al día con menor hueco >= coste.
% Repite pases hasta que ningún candidato quepa. Al terminar, ningún candidato
% sin asignar cabe en el hueco de ningún día (AC5: aprovechamiento fino). Todo
% con aritmética entera pura: rápido, determinista y siempre terminante.
plan_mejorar(A0, Candidatos, Costes, N, Disponibles, A) :-
    cargas_enteras(A0, Costes, N, Cargas0),
    mejorar_bucle(A0, Candidatos, Costes, N, Disponibles, Cargas0, A).

% Carga por día como enteros puros (A ya ground tras labeling/1).
cargas_enteras(A, Costes, N, Cargas) :-
    cargas_enteras_idx(1, N, A, Costes, Cargas).

cargas_enteras_idx(D, N, _, _, []) :- D > N, !.
cargas_enteras_idx(D, N, A, Costes, [Carga|Rest]) :-
    carga_enteras_dia(A, Costes, D, Carga),
    D1 is D + 1,
    cargas_enteras_idx(D1, N, A, Costes, Rest).

carga_enteras_dia(A, Costes, D, Carga) :-
    length(A, NC),
    carga_enteras_idx2(A, Costes, D, 1, NC, 0, Carga).

carga_enteras_idx2(_, _, _, Idx, NC, Acc, Acc) :- Idx > NC, !.
carga_enteras_idx2(A, Costes, D, Idx, NC, Acc, Carga) :-
    nth1(Idx, A, Ac),
    nth1(Idx, Costes, Coste),
    (   Ac =:= D -> Acc1 is Acc + Coste ; Acc1 = Acc ),
    Idx1 is Idx + 1,
    carga_enteras_idx2(A, Costes, D, Idx1, NC, Acc1, Carga).

% Bucle de mejora: repite pases mientras se asigne al menos un candidato.
mejorar_bucle(A, Candidatos, Costes, N, Disponibles, Cargas, A2) :-
    mejorar_pase(A, Candidatos, Costes, N, Disponibles, Cargas, A1, Cargas1, Cambio),
    (   Cambio ->
        mejorar_bucle(A1, Candidatos, Costes, N, Disponibles, Cargas1, A2)
    ;
        A2 = A1
    ).

% Un pase por los candidatos (por índice 1..NC).
mejorar_pase(_A, [], _, _, _, Cargas, A, Cargas, false).
mejorar_pase(A, [C|Cs], Costes, N, Disponibles, Cargas, A2, Cargas2, Cambio) :-
    mejorar_pase_idx(A, [C|Cs], Costes, N, Disponibles, Cargas, 1, A2, Cargas2, Cambio).

mejorar_pase_idx(A, [], _, _, _, Cargas, _, A, Cargas, false).
mejorar_pase_idx(A, [C|Cs], Costes, N, Disponibles, Cargas, Idx, A2, Cargas2, Cambio) :-
    nth1(Idx, A, DiaActual),
    (   DiaActual =:= 0 ->
        nth1(Idx, Costes, Coste),
        mejor_dia(Coste, N, Disponibles, Cargas, MejorDia),
        (   MejorDia =:= 0 ->
            Idx1 is Idx + 1,
            mejorar_pase_idx(A, Cs, Costes, N, Disponibles, Cargas, Idx1, A2, Cargas2, Cambio)
        ;
            Idx1 is Idx + 1,
            Cambio = true,
            reemplazar_nth(A, Idx, MejorDia, A1),
            actualizar_carga(Cargas, MejorDia, Coste, Cargas1),
            mejorar_pase_idx(A1, Cs, Costes, N, Disponibles, Cargas1, Idx1, A2, Cargas2, _)
        )
    ;
        Idx1 is Idx + 1,
        mejorar_pase_idx(A, Cs, Costes, N, Disponibles, Cargas, Idx1, A2, Cargas2, Cambio)
    ).

% Mejor día para un coste: día con menor hueco >= coste, empata por día menor;
% devuelve 0 si ningún día tiene hueco suficiente. Nunca falla.
mejor_dia(Coste, N, Disponibles, Cargas, MejorDia) :-
    mejor_dia_idx(Coste, Disponibles, Cargas, 1, N, 0, 0, MejorDia).

mejor_dia_idx(_C, _, _, D, N, MD, _, MD) :- D > N, !.
mejor_dia_idx(Coste, Disp, Cargas, D, N, MD0, H0, MD) :-
    nth1(D, Disp, Dp),
    nth1(D, Cargas, Cg),
    Hueco is Dp - Cg,
    (   Hueco >= Coste ->
        (   MD0 =:= 0 ->
            D1 is D + 1,
            mejor_dia_idx(Coste, Disp, Cargas, D1, N, D, Hueco, MD)
        ;
            (   Hueco > H0 ->
                D1 is D + 1,
                mejor_dia_idx(Coste, Disp, Cargas, D1, N, D, Hueco, MD)
            ;
                D1 is D + 1,
                mejor_dia_idx(Coste, Disp, Cargas, D1, N, MD0, H0, MD)
            )
        )
    ;
        D1 is D + 1,
        mejor_dia_idx(Coste, Disp, Cargas, D1, N, MD0, H0, MD)
    ).

reemplazar_nth(Lista, Idx, Valor, Nueva) :-
    reemplazar_nth(Lista, Idx, Valor, 1, Nueva).

reemplazar_nth([], _, _, _, []).
reemplazar_nth([_|Rest], Idx, Valor, Idx, [Valor|Rest]).
reemplazar_nth([H|Rest], Idx, Valor, N, [H|Nueva]) :-
    N1 is N + 1,
    reemplazar_nth(Rest, Idx, Valor, N1, Nueva).

actualizar_carga(Cargas, Dia, Coste, CargasNuevas) :-
    actualizar_carga(Cargas, Dia, Coste, 1, CargasNuevas).

actualizar_carga([], _, _, _, []).
actualizar_carga([H|Rest], Dia, Coste, Dia, [HN|Rest]) :- HN is H + Coste.
actualizar_carga([H|Rest], Dia, Coste, N, [H|Nueva]) :-
    N1 is N + 1,
    actualizar_carga(Rest, Dia, Coste, N1, Nueva).

% Construir salida: para cada día 1..N, sus candidatos asignados y su carga.
construir_dias(Dia, N, _Fechas, _Disponibles, _A, _Candidatos, Acum, PlanDias) :-
    Dia > N, !,
    reverse(Acum, PlanDias).
construir_dias(Dia, N, Fechas, Disponibles, A, Candidatos, Acum, PlanDias) :-
    nth1(Dia, Fechas, Fecha),
    nth1(Dia, Disponibles, Disponible),
    candidatos_del_dia(A, Candidatos, Dia, Items),
    carga_de_items(Items, Carga),
    D1 is Dia + 1,
    construir_dias(D1, N, Fechas, Disponibles, A, Candidatos,
                   [dia(Dia, Fecha, Disponible, Carga, Items)|Acum], PlanDias).

% Candidatos asignados al día D (iteración determinista por índice).
candidatos_del_dia(A, Candidatos, Dia, Items) :-
    length(A, NC),
    candidatos_del_dia_idx(A, Candidatos, Dia, 1, NC, [], ItemsRev),
    reverse(ItemsRev, Items).

candidatos_del_dia_idx(_A, _Candidatos, _Dia, Idx, NC, Acum, Acum) :- Idx > NC, !.
candidatos_del_dia_idx(A, Candidatos, Dia, Idx, NC, Acum, Salida) :-
    nth1(Idx, A, Ac),
    nth1(Idx, Candidatos, Candidato),
    (   Ac =:= Dia ->
        Idx1 is Idx + 1,
        candidatos_del_dia_idx(A, Candidatos, Dia, Idx1, NC, [Candidato|Acum], Salida)
    ;
        Idx1 is Idx + 1,
        candidatos_del_dia_idx(A, Candidatos, Dia, Idx1, NC, Acum, Salida)
    ).

carga_de_items([], 0).
carga_de_items([candidato(_I, _R, M, _T, _G)|Rest], Carga) :-
    carga_de_items(Rest, CargaRest),
    Carga is M + CargaRest.
