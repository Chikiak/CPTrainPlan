% Lectura del catálogo de Codeforces: identificadores, enlaces y excluir
% problemas sin rating.
% Forma esperada del JSON: {"status":"OK","result":{"problems":[...]}}
% Los JSON se leen como dicts (json_read_dict/2).
% Por problema se usan: contestId, index, name, rating (opcional), tags.

:- use_module(library(json)).
:- use_module(library(lists)).

% Carga el catálogo desde Archivo y devuelve el diccionario raíz del JSON.
% Si el archivo no existe, escribe un error y termina con código 1.
cargar_catalogo(Archivo, Catalogo) :-
    (   exists_file(Archivo) ->
        open(Archivo, read, In),
        json_read_dict(In, Catalogo),
        close(In)
    ;
        format(user_error, 'error: no se encuentra el archivo de catálogo: ~s~n', [Archivo]),
        halt(1)
    ).

% Un problema es un diccionario del array "result.problems".

problema_id(P, Id) :-
    get_dict(contestId, P, Cid),
    atom_number(CidAtom, Cid),
    get_dict(index, P, Index),
    atom_concat(CidAtom, Index, Id).

problema_enlace(P, Enlace) :-
    get_dict(contestId, P, Cid),
    atom_number(CidAtom, Cid),
    atom_concat('https://codeforces.com/problemset/problem/', CidAtom, Parte1),
    atom_concat(Parte1, '/', Parte2),
    get_dict(index, P, Index),
    atom_concat(Parte2, Index, Enlace).

problema_rating(P, Rating) :-
    get_dict(rating, P, Rating).

problema_tags(P, Tags) :-
    get_dict(tags, P, Tags).

problema_nombre(P, Nombre) :-
    get_dict(name, P, Nombre).

% Tiene rating (no se excluye)
tiene_rating(P) :-
    get_dict(rating, P, _).

problemas_lista(Catalogo, Lista) :-
    get_dict(result, Catalogo, Result),
    get_dict(problems, Result, Lista).

problemas_con_rating(Catalogo, Problemas) :-
    problemas_lista(Catalogo, Lista),
    include(tiene_rating, Lista, Problemas).

problemas_sin_rating(Catalogo, Problemas) :-
    problemas_lista(Catalogo, Lista),
    exclude(tiene_rating, Lista, Problemas).

resumen_catalogo(Catalogo, ConRating, SinRating, min_max(Min, Max)) :-
    problemas_con_rating(Catalogo, ConLista),
    problemas_sin_rating(Catalogo, SinLista),
    length(ConLista, ConRating),
    length(SinLista, SinRating),
    maplist(problema_rating, ConLista, Ratings),
    list_min_max(Ratings, Min, Max).

list_min_max([H|T], Min, Max) :-
    list_min_max(T, H, H, Min, Max).

list_min_max([], MinAcc, MaxAcc, MinAcc, MaxAcc).
list_min_max([H|T], MinAcc, MaxAcc, Min, Max) :-
    (   H < MinAcc -> NewMin = H ; NewMin = MinAcc ),
    (   H > MaxAcc -> NewMax = H ; NewMax = MaxAcc ),
    list_min_max(T, NewMin, NewMax, Min, Max).

% Busca un problema por identificador (concurso+índice, sin separador).
find_problema(Catalogo, Id, P) :-
    problemas_lista(Catalogo, Lista),
    member(P, Lista),
    problema_id(P, Id),
    !.  % ids unicos: una sola solucion, sin choicepoints residuales

% Límite de tiempo por rating con cobertura de huecos de la tabla.
% Si el rating cae en alguna fila de limite_tiempo/3 se usa ese límite;
% si cae en un hueco entre filas se usa el límite del tramo inmediatamente
% inferior (mayor rating_min que no exceda el rating), de modo que
% limite_por_rating/2 nunca falle para un rating razonable.
limite_por_rating(Rating, Minutos) :-
    (   limite_tiempo(Min, Max, Minutos),
        (   Max = inf -> Min =< Rating
        ;   Min =< Rating, Rating =< Max
        )
    ;   findall(Min0-Minutos0,
                (   limite_tiempo(Min0, _Max0, Minutos0),
                    Min0 =< Rating
                ),
                Tramos),
        Tramos \== [],
        keysort(Tramos, Ordenados),
        last(Ordenados, _-Minutos)
    ).
