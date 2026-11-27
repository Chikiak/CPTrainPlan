% Selección de candidatos acotada (F0-04).
% Un candidato es un problema del catálogo que cumple:
%   1. Tiene rating.
%   2. No aparece en el historial ni en resueltos previos.
%   3. Todos sus temas seguidos son trabajables.
%   4. Su rating está entre nivel+banda_nivel_min y nivel+banda_nivel_max, ambos incluidos.
% Los problemas sin ningún tema seguido son candidatos y forman el grupo (sin_tema).
% Selección: por cada tema trabajable en orden alfabético, los tope_por_tema
% candidatos más cercanos a nivel+150 (desempata el identificador en orden alfabético);
% se unen sin duplicados y, si pasan de tope_total_candidatos, se conservan los primeros
% en ese mismo orden de cercanía.

:- use_module(library(lists)).
:- use_module(library(json)).

% Parámetros de selección.
banda_nivel_min_param(N) :- banda_nivel_min(N).
banda_nivel_max_param(N) :- banda_nivel_max(N).
tope_por_tema_param(N) :- tope_por_tema(N).
tope_total_candidatos_param(N) :- tope_total_candidatos(N).
objetivo_dificultad(Nivel, Objetivo) :- Objetivo is Nivel + 150.

% Identificador del problema (concurso+índice sin separador).
problema_id(P, Id) :-
    get_dict(contestId, P, Cid),
    atom_number(CidAtom, Cid),
    get_dict(index, P, Index),
    atom_concat(CidAtom, Index, Id).

% Rating del problema (fallo si no lo tiene).
problema_rating(P, Rating) :-
    get_dict(rating, P, Rating).

% Tags del problema.
problema_tags(P, Tags) :-
    get_dict(tags, P, Tags).

% Lista de problemas del catálogo.
problemas_lista(Catalogo, Lista) :-
    get_dict(result, Catalogo, Result),
    get_dict(problems, Result, Lista).

% Temas seguidos de un problema: sus tags menos los ignorados, sin duplicados.
% Los tags del catálogo JSON llegan como strings y los parámetros
% (temas_ignorados, Pares de prerrequisitos) son átomos; se convierten ambos
% a átomo para poder compararlos correctamente.
temas_seguidos(P, Catalogo, Temas) :-
    problema_tags(P, Tags),
    temas_ignorados_lista(Ignorados),
    maplist(string_to_atom, Tags, TagsAtom),
    maplist(string_to_atom, Ignorados, IgnoradosAtom),
    include(tema_no_ignorado(IgnoradosAtom), TagsAtom, Filtrados),
    list_to_set(Filtrados, Temas).

tema_no_ignorado(Ignorados, Tema) :-
    \+ member(Tema, Ignorados).

temas_ignorados_lista(Ignorados) :-
    findall(T, temas_ignorados(T), Ignorados).

% Convierte un tema (puede ser string del JSON o átomo) a átomo.
string_to_atom(String, Atom) :-
    (   atom(String) -> Atom = String
    ;   string_chars(String, Chars),
        atom_chars(Atom, Chars)
    ).

% resueltos previos (opcional; si no hay archivo, lista vacía).
leer_resueltos_opcional(Archivo, Resueltos) :-
    (   exists_file(Archivo) ->
        leer_resueltos(Archivo, Resueltos)
    ;   Resueltos = []
    ).

% Problemas candidatos del catálogo.
% Devuelve lista de candidato(Id, Rating, Minutos, Temas, Grupo).
problemas_candidatos(Catalogo, Intentos, Resueltos, Pares, Estados, Nivel, Candidatos) :-
    problemas_lista(Catalogo, Lista),
    include(tiene_rating, Lista, ConRating),
    banda_nivel_min_param(Bmin),
    banda_nivel_max_param(Bmax),
    MinR is Nivel + Bmin,
    MaxR is Nivel + Bmax,
    intentos_ids(Intentos, IntentosIds),
    findall(candidato(Id, Rating, Minutos, Temas, Grupo),
        (   member(P, ConRating),
            problema_id(P, Id),
            problema_rating(P, Rating),
            Rating >= MinR, Rating =< MaxR,
            \+ member(Id, IntentosIds),
            \+ member(Id, Resueltos),
            temas_seguidos(P, Catalogo, Temas),
            (   Temas = [] ->
                Grupo = sin_tema
            ;
                todos_trabajables(Temas, Pares, Estados),
                Grupo = con_tema
            ),
            limite_por_rating(Rating, Minutos)
        ),
        Todos),
    list_to_set(Todos, TodosSinDups),
    ordenar_por_cercania(TodosSinDups, Nivel, Ordenados),
    seleccionar_por_tema_y_total(Catalogo, Ordenados, Pares, Estados, Nivel, Seleccionados),
    Seleccionados = Candidatos.

tiene_rating(P) :- get_dict(rating, P, _).

% Identificadores de problemas que aparecen en el historial.
intentos_ids(Intentos, Ids) :-
    maplist(intento_problema, Intentos, Ids).

% Todos los temas de la lista son trabajables.
todos_trabajables([], _, _).
todos_trabajables([T|Ts], Pares, Estados) :-
    tema_trabajable(T, Pares, Estados),
    todos_trabajables(Ts, Pares, Estados).

% Ordena candidatos por cercanía a nivel+150, desempate identificador alfabético.
ordenar_por_cercania(Candidatos, Nivel, Ordenados) :-
    objetivo_dificultad(Nivel, Objetivo),
    maplist(cercania_pair(Objetivo), Candidatos, ParesClave),
    keysort(ParesClave, OrdenadosPares),
    maplist(snd, OrdenadosPares, Ordenados).

cercania_pair(Objetivo, candidato(Id, Rating, Minutos, Temas, Grupo), (Clave)-candidato(Id, Rating, Minutos, Temas, Grupo)) :-
    Cercania is abs(Rating - Objetivo),
    Clave = clave(Cercania, Id).

snd(_-V, V).

% Selección: por cada tema trabajable en orden alfabético, tope_por_tema más cercanos;
% unión sin duplicados; tope_total_candidatos conservando primeros por cercanía.
% (sin_tema) es un grupo más, con los candidatos que no tienen tema.
% Un problema con varios temas cuenta para cada uno de sus temas, por lo que
% se lleva una lista Vistos para no repetir candidatos entre temas.
seleccionar_por_tema_y_total(Catalogo, Ordenados, Pares, Estados, Nivel, Seleccionados) :-
    tope_por_tema_param(TopeTema),
    tope_total_candidatos_param(TopeTotal),
    temas_trabajables_ordenados(Catalogo, Pares, Estados, TemasOrd),
    insertar_sin_tema(TemasOrd, TemasConSin),
    seleccionar_temas(Ordenados, TemasConSin, TopeTema, [], Acumulados, []),
    % Reordenar la unión por cercanía global, para que el tope_total conserve
    % los primeros por cercanía y la salida sea determinista.
    ordenar_por_cercania(Acumulados, Nivel, AcumuladosOrd),
    % Filtrar para que ningún tema supere tope_por_tema en el resultado final
    % (un problema con varios temas cuenta para cada uno de sus temas).
    filtrar_por_tope_tema(AcumuladosOrd, TopeTema, Filtrados),
    (   length(Filtrados, Len), Len =< TopeTotal ->
        Seleccionados = Filtrados
    ;
        length(Primera, TopeTotal),
        append(Primera, _, Filtrados),
        Seleccionados = Primera
    ).

% Descarta candidatos que harían exceder tope_por_tema para cualquiera de sus temas.
% Recorre en orden de cercanía y mantiene contadores por tema para ser eficiente.
filtrar_por_tope_tema(Lista, TopeTema, Salida) :-
    maplist(candidato_temas, Lista, TodasListas),
    append(TodasListas, Todos),
    list_to_set(Todos, TodosTemas),
    maplist(contador_cero, TodosTemas, Contadores0),
    filtrar_por_tope_tema(Lista, TopeTema, Contadores0, [], Temp),
    reverse(Temp, Salida).

filtrar_por_tope_tema([], _, _, Acumulados, Acumulados).
filtrar_por_tope_tema([C|Rest], TopeTema, Contadores, Acumulados, Salida) :-
    candidato_temas(C, TemasC),
    (   algun_tema_en_tope_cont(TemasC, Contadores, TopeTema) ->
        filtrar_por_tope_tema(Rest, TopeTema, Contadores, Acumulados, Salida)
    ;
        incrementar_contadores(TemasC, Contadores, ContadoresNuevos),
        filtrar_por_tope_tema(Rest, TopeTema, ContadoresNuevos, [C|Acumulados], Salida)
    ).

% Cierto si alguno de los temas de Temas ya tiene tope_por_tema candidatos (según contadores).
algun_tema_en_tope_cont([T|Ts], Contadores, TopeTema) :-
    contador_para(T, Contadores, N),
    N >= TopeTema.
algun_tema_en_tope_cont([_|Ts], Contadores, TopeTema) :-
    algun_tema_en_tope_cont(Ts, Contadores, TopeTema).

contador_cero(Tema, Tema-0).

contador_para(Tema, [Tema-N|_], N).
contador_para(Tema, [_|Rest], N) :- contador_para(Tema, Rest, N).
contador_para(_, [], 0).

% Incrementar el contador de cada tema en Temas.
incrementar_contadores([], Contadores, Contadores).
incrementar_contadores([T|Ts], Contadores, ContadoresNuevos) :-
    (   member(T-N, Contadores) ->
        N1 is N + 1,
        select(T-N, Contadores, Resto),
        append(Resto, [T-N1], Contadores1)
    ;
        append(Contadores, [T-1], Contadores1)
    ),
    incrementar_contadores(Ts, Contadores1, ContadoresNuevos).

% Temas de un candidato.
candidato_temas(candidato(_Id, _Rating, _Minutos, Temas, _Grupo), Temas).

% Procesa todos los temas en orden alfabético, eligiendo hasta tope_por_tema
% candidatos por tema. Vistos acumula los candidatos ya elegidos para evitar
% duplicados cuando un problema tiene varios temas.
seleccionar_temas(_Ordenados, [], _TopeTema, Acum, Acum, _Vistos).
seleccionar_temas(Ordenados, [Tema|Rest], TopeTema, Acum, Salida, Vistos) :-
    findall(C, (member(C, Ordenados), coincide_tema(C, Tema), \+ member(C, Vistos)), ParaTema),
    tomar_primeros(ParaTema, TopeTema, Elegidos),
    append(Acum, Elegidos, Acum1),
    append(Vistos, Elegidos, Vistos1),
    seleccionar_temas(Ordenados, Rest, TopeTema, Acum1, Salida, Vistos1).

% Toma los primeros N elementos de Lista, manteniendo el orden.
tomar_primeros([], _, []).
tomar_primeros([_|_], 0, []).
tomar_primeros([C|Cs], N, [C|Resto]) :-
    N > 0,
    N1 is N - 1,
    tomar_primeros(Cs, N1, Resto).

% Temas trabajables del catálogo, ordenados alfabéticamente, sin duplicados.
% Los temas del catálogo llegan como strings; se convierten a átomo para
% que tema_trabajable/3 (que consulta Pares de prerrequisitos, átomos)
% resuelva correctamente los ancestros.
temas_trabajables_ordenados(Catalogo, Pares, Estados, TemasOrd) :-
    temas_del_catalogo(Catalogo, Todos),
    maplist(string_to_atom, Todos, TodosAtom),
    include(tema_trabajable_para(Pares, Estados), TodosAtom, Trabajables),
    list_to_set(Trabajables, Set),
    sort(Set, TemasOrd).

tema_trabajable_para(Pares, Estados, Tema) :-
    tema_trabajable(Tema, Pares, Estados).

% (sin_tema) es un grupo más, al final del orden alfabético.
insertar_sin_tema(Temas, [sin_tema|Temas]).

coincide_tema(candidato(_Id, _Rating, _Minutos, Temas, sin_tema), sin_tema) :-
    Temas = [].
coincide_tema(candidato(_Id, _Rating, _Minutos, Temas, con_tema), Tema) :-
    Tema \= sin_tema,
    member(Tema, Temas).

% Redefinición de limite_por_rating/2 con cobertura de huecos: cuando un
% No altera los rangos ya cubiertos por la tabla (se prueban primero).
:- abolish(limite_por_rating/2).
:- asserta((limite_por_rating(Rating, Minutos) :-
             (   limite_tiempo(Min, Max, Minutos),
                 (   Max = inf -> Min =< Rating
                 ;   Min =< Rating, Rating =< Max
                 )
             )
             ;
                 findall(Min0-Minutos0,
                         (limite_tiempo(Min0, _Max0, Minutos0),
                          Min0 =< Rating),
                         Tramos),
                 Tramos \== [],
                 keysort(Tramos, Ordenados),
                 last(Ordenados, _-Minutos)
             )).
