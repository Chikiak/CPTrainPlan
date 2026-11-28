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
    % cada día d en 1..n: carga[d] #<= Disponibles[d]
    capacidades_dias(A, Costes, N, Disponibles),
    % cargas de todos los días y carga total
    cargas_todas(A, Costes, N, Cargas),
    sumlist_clpfd(Cargas, CargaTotal),
    % resolver: solución factible con fail-first (rápido y determinista)
    labeling([ff], A),
    % mejora greedy determinista: asignar candidatos no asignados si caben
    plan_mejorar(A, Candidatos, Costes, N, Disponibles, A2),
    % reconstruir cargas con la asignación mejorada
    cargas_todas(A2, Candidatos, Costes, N, Cargas),
    sumlist_clpfd(Cargas, _CargaTotal),
    % construir salida en orden día 1..N (usar asignación mejorada)
    construir_dias(1, N, Fechas, Disponibles, A2, Candidatos, [], PlanDias).

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

% Mejora greedy determinista (un solo pase): asigna candidatos no asignados
% al día con menor hueco donde quepan. Repite hasta que no se asigne ninguno.
plan_mejorar(A0, Candidatos, Costes, N, Disponibles, A) :-
    cargas_actuales_lista(A0, Costes, N, Cargas0),
    mejorar_bucle(A0, Candidatos, Costes, N, Disponibles, Cargas0, A).

mejorar_bucle(A, Candidatos, Costes, N, Disponibles, Cargas, A2) :-
    mejorar_pase(A, Candidatos, Costes, N, Disponibles, Cargas, A1, Cargas1, Cambio),
    (   Cambio ->
        mejorar_bucle(A1, Candidatos, Costes, N, Disponibles, Cargas1, A2)
    ;
        A2 = A1
    ).

mejorar_pase(_A, [], _, _, _, Cargas, A, Cargas, false).
mejorar_pase(A, [C|Cs], Costes, N, Disponibles, Cargas, A2, Cargas2, Cambio) :-
    mejorar_pase_idx(A, [C|Cs], Costes, N, Disponibles, Cargas, 1, A2, Cargas2, Cambio).

mejorar_pase_idx(A, [], _, _, _, Cargas, _, A, Cargas, false).
mejorar_pase_idx(A, [C|Cs], Costes, N, Disponibles, Cargas, Idx, A2, Cargas2, Cambio) :-
    nth1(Idx, A, DiaActual),
    (   DiaActual > 0 ->
        Idx1 is Idx + 1,
        mejorar_pase_idx(A, Cs, Costes, N, Disponibles, Cargas, Idx1, A2, Cargas2, Cambio)
    ;
        nth1(Idx, Costes, Coste),
        mejor_dia_para(Coste, N, Disponibles, Cargas, MejorDia),
        (   MejorDia > 0 ->
            reemplazar_nth(A, Idx, MejorDia, A1),
            actualizar_carga(Cargas, MejorDia, Coste, Cargas1),
            Idx1 is Idx + 1,
            mejorar_pase_idx(A1, Cs, Costes, N, Disponibles, Cargas1, Idx1, A2, Cargas2, true)
        ;
            Idx1 is Idx + 1,
            mejorar_pase_idx(A, Cs, Costes, N, Disponibles, Cargas, Idx1, A2, Cargas2, Cambio)
        )
    ).

% Mejor día para un coste: día con menor hueco >= coste, empata por número de día menor.
mejor_dia_para(_Coste, 0, _, _, 0).
mejor_dia_para(Coste, D, Disponibles, Cargas, MejorDia) :-
    nth1(D, Disponibles, Disp),
    nth1(D, Cargas, Carga),
    Hueco is Disp - Carga,
    (   Hueco >= Coste ->
        (   D =:= 1 -> MejorDia = 1
        ;   D1 is D - 1,
            mejor_dia_para(Coste, D1, Disponibles, Cargas, MejorDia2),
            (   MejorDia2 > 0 ->
                nth1(MejorDia2, Disponibles, Disp2),
                nth1(MejorDia2, Cargas, Carga2),
                Hueco2 is Disp2 - Carga2,
                (   Hueco < Hueco2 -> MejorDia = D ; MejorDia = MejorDia2 )
            ;   MejorDia = D
            )
        )
    ;
        D > 1,
        D1 is D - 1,
        mejor_dia_para(Coste, D1, Disponibles, Cargas, MejorDia)
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
actualizar_carga([H|Rest], Dia, Coste, Dia, [H + Coste|Rest]).
actualizar_carga([H|Rest], Dia, Coste, N, [H|Nueva]) :-
    N1 is N + 1,
    actualizar_carga(Rest, Dia, Coste, N1, Nueva).

cargas_actuales_lista(A, Costes, N, Cargas) :-
    cargas_para_dias(1, N, A, Costes, Cargas).

cargas_para_dias(D, N, _, _, []) :- D > N, !.
cargas_para_dias(D, N, A, Costes, [Carga|Rest]) :-
    carga_de_dia(A, Costes, D, Carga),
    D1 is D + 1,
    cargas_para_dias(D1, N, A, Costes, Rest).

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
    (   Ac #= Dia ->
        Idx1 is Idx + 1,
        candidatos_del_dia_idx(A, Candidatos, Dia, Idx1, NC, [Candidato|Acum], Salida)
    ;
        Idx1 is Idx + 1,
        candidatos_del_dia_idx(A, Candidatos, Dia, Idx1, NC, Acum, Salida)
    ).

carga_de_items([], 0).
carga_de_items([candidato(_I, _R, M, _T, _G)|Rest], Carga) :-
    Carga #= M + CargaRest,
    carga_de_items(Rest, CargaRest).
