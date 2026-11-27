% Lectura del archivo de prerrequisitos (CSV con cabecera: tema, prerrequisito),
% cierre transitivo (ancestros) y detección de ciclos.
% Una línea que empieza por # es comentario; las líneas vacías se ignoran.
% Una línea con menos de dos columnas produce error: con archivo y línea,
% y termina con código 1.

:- use_module(library(lists)).

% Cabecera esperada del archivo de prerrequisitos.
cabecera_prerrequisitos(["tema", "prerrequisito"]).

% Lee el archivo de prerrequisitos y devuelve lista de pares tema-prerrequisito.
% Cualquier error de datos escribe 'error:' en stderr con archivo y línea
% y termina con código 1.
leer_prerrequisitos(Archivo, Pares) :-
    (   exists_file(Archivo) ->
        open(Archivo, read, In),
        leer_lineas_prer(In, Archivo, 0, [], false, Pares),
        close(In)
    ;
        format(user_error, 'error: no se encuentra el archivo de prerrequisitos: ~s~n', [Archivo]),
        halt(1)
    ).

% Lee líneas: salta comentarios y vacías, valida la cabecera (primera línea
% no vacía ni comentario), luego lee pares tema-prerrequisito.
% Lee líneas: salta comentarios y vacías, valida la cabecera (primera línea
% no vacía ni comentario), luego lee pares tema-prerrequisito.
leer_lineas_prer(In, Archivo, N, Acum, HeaderSeen, Salida) :-
    read_line_to_string(In, Linea),
    (   Linea = end_of_file -> Salida = Acum
    ;   N1 is N + 1,
        (   linea_blanca(Linea) ->
            leer_lineas_prer(In, Archivo, N1, Acum, HeaderSeen, Salida)
        ;   atom_chars(Linea, ['#'|_]) ->
            leer_lineas_prer(In, Archivo, N1, Acum, HeaderSeen, Salida)
        ;   HeaderSeen = false ->
            (   es_cabecera_prer(Linea) ->
                leer_lineas_prer(In, Archivo, N1, Acum, true, Salida)
            ;
                format(user_error, 'error: cabecera de prerrequisitos invalida en ~s: ~s~n', [Archivo, Linea]),
                halt(1)
            )
        ;   HeaderSeen = true ->
            linea_a_par(Linea, Archivo, N1, Par),
            leer_lineas_prer(In, Archivo, N1, [Par|Acum], true, Salida)
        )
    ).

es_cabecera_prer(Linea) :-
    split_string(Linea, ",", "", Partes),
    Partes = ["tema", "prerrequisito"].

linea_a_par(Linea, _Archivo, LineaNum, Tema-Prerrequisito) :-
    atom_chars(Linea, Chars),
    split_string(Chars, ",", "", Partes),
    (   length(Partes, 2) ->
        [TParte, PParte] = Partes,
        atom_string(Tema, TParte),
        atom_string(Prerrequisito, PParte),
        (   Tema = "" ->
            format(user_error, 'error: linea mal formada en ~s: línea ~w~n', [_Archivo, LineaNum]),
            halt(1)
        ;   true
        )
    ;
        format(user_error, 'error: linea mal formada en ~s: línea ~w~n', [_Archivo, LineaNum]),
        halt(1)
    ).

linea_blanca(Linea) :-
    (   Linea = "" -> true
    ;   atom_chars(Linea, Chars),
        maplist(espacio, Chars)
    ).

espacio(C) :- char_type(C, space).

% Ancestros directos e indirectos de un tema (cierre transitivo).
% Devuelve lista de temas ancestros, sin duplicados, sin el tema mismo.
ancestros(Tema, Pares, Ancestros) :-
    ancestros_visitado(Tema, Pares, [], Visitados),
    list_to_set(Visitados, Set),
    (   member(Tema, Set) -> delete(Set, Tema, Ancestros) ; Ancestros = Set ).

ancestros_visitado(Tema, _Pares, Visitados, Visitados) :-
    member(Tema, Visitados).
ancestros_visitado(Tema, Pares, Visitados, Salida) :-
    \+ member(Tema, Visitados),
    findall(Pre, (member(Tema-Pre, Pares), Pre \= ""), Pres),
    anc_lista(Pres, Pares, [Tema|Visitados], Salida).

anc_lista([], _Pares, Visitados, Visitados).
anc_lista([Pre|Rest], Pares, Visitados, Salida) :-
    ancestros_visitado(Pre, Pares, Visitados, V1),
    anc_lista(Rest, Pares, V1, Salida).

% Detecta un ciclo en los pares de prerrequisitos.
% Devuelve la lista de temas que forman el ciclo, o [] si no hay ninguno.
ciclo_prerrequisitos(Pares, Ciclo) :-
    findall(T, member(T-_, Pares), Temas),
    list_to_set(Temas, TSet),
    buscar_ciclo_desde(TSet, Pares, Ciclo).

buscar_ciclo_desde([], _Pares, []).
buscar_ciclo_desde([T|Rest], Pares, Ciclo) :-
    (   dfs_ciclo(T, Pares, [T], Ciclo) -> true
    ;   buscar_ciclo_desde(Rest, Pares, Ciclo)
    ).

dfs_ciclo(Tema, Pares, Camino, Ciclo) :-
    findall(Pre, (member(Tema-Pre, Pares), Pre \= ""), Pres),
    (   Pres = [] -> fail
    ;   member(Pre, Pres),
        (   member(Pre, Camino) ->
            extraer_ciclo(Camino, Pre, Ciclo)
        ;   dfs_ciclo(Pre, Pares, [Pre|Camino], Ciclo)
        )
    ;   false
    ).

extraer_ciclo(Camino, Nodo, Ciclo) :-
    append(Prefix, [Nodo|_Resto], Camino),
    reverse(Prefix, Ruta),
    append([Nodo], Ruta, Ciclo).
