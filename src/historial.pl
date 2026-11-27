% Lectura del historial de intentos (CSV con cabecera) y de problemas
% resueltos previos (texto, un identificador por línea, # comentario).

:- use_module(library(lists)).

% Cabecera esperada del historial CSV.
cabecera_historial(["problema", "fecha", "minutos", "ayuda", "resuelto"]).

% Intento leído del historial: intento(Problema, Fecha, Minutos, Ayuda, Resuelto, Linea).
% Linea es el número de línea en el archivo (cabecera = línea 1).
% Ayuda y Resuelto son los átomos si/no.

% Lee el archivo de historial CSV y devuelve una lista de intento/6,
% ordenada por fecha y, a igual fecha, por orden en el archivo.
% Cualquier error de datos escribe 'error:' en stderr con archivo y línea
% y termina con código 1.
leer_historial(Archivo, Intentos) :-
    (   exists_file(Archivo) ->
        open(Archivo, read, In),
        leer_lineas(In, Archivo, 0, [], Linas),
        close(In),
        reverse(Linas, EnOrden),            % orden de archivo
        keysort(EnOrden, Ordenados),        % estable: a igual fecha conserva el archivo
        maplist(snd, Ordenados, Intentos)
    ;
        format(user_error, 'error: no se encuentra el archivo de historial: ~s~n', [Archivo]),
        halt(1)
    ).

% Lee una línea, valida que sea la cabecera esperada y sigue con las siguientes.
% Cada línea se lee una sola vez (la comprobación de fin de fichero no consume).
leer_lineas(In, Archivo, N, Acum, Salida) :-
    read_line_to_string(In, Linea),
    (   Linea = end_of_file -> Salida = Acum
    ;   N1 is N + 1,
        (   N1 =:= 1 ->
            (   es_cabecera(Linea) ->
                leer_lineas(In, Archivo, N1, Acum, Salida)
            ;
                format(user_error, 'error: cabecera de historial invalida en ~s: ~s~n', [Archivo, Linea]),
                halt(1)
            )
        ;   linea_blanca(Linea) ->
            leer_lineas(In, Archivo, N1, Acum, Salida)
        ;   leer_intento_linea(Linea, Archivo, N1, Intento),
            intento_fecha(Intento, Fecha),
            leer_lineas(In, Archivo, N1, [Fecha-Intento|Acum], Salida)
        )
    ).

% La primera linea no vacia debe ser la cabecera valida.
es_cabecera(Linea) :-
    split_string(Linea, ",", "", Partes),
    Partes = ["problema", "fecha", "minutos", "ayuda", "resuelto"].

linea_blanca(Linea) :-
    (   Linea = "" -> true
    ;   atom_chars(Linea, Chars),
        maplist(espacio, Chars)
    ).

espacio(C) :- char_type(C, space).

% Parsea una línea de datos: problema,fecha,minutos,ayuda,resuelto.
leer_intento_linea(Linea, Archivo, LineaNum, intento(Problema, Fecha, Minutos, Ayuda, Resuelto, LineaNum)) :-
    atom_chars(Linea, Chars),
    split_string(Chars, ",", "", Partes),
    (   length(Partes, 5) ->
        [PParte, FParte, MParte, AParte, RParte] = Partes,
        atom_string(Problema, PParte),
        atom_string(FechaStr, FParte),
        validar_fecha(FechaStr, Archivo, LineaNum),
        Fecha = FechaStr,
        validar_minutos(Minutos, MParte, Archivo, LineaNum),
        validar_si_no(Ayuda, AParte, Archivo, LineaNum),
        validar_si_no(Resuelto, RParte, Archivo, LineaNum)
    ;
        format(user_error, 'error: linea mal formada en ~s: línea ~w~n', [Archivo, LineaNum]),
        halt(1)
    ).

% Fecha ISO: YYYY-MM-DD.
validar_fecha(FechaStr, Archivo, LineaNum) :-
    split_string(FechaStr, "-", "", [A, M, D]),
    atom_string(AAtom, A), atom_number(AAtom, Ano),
    atom_string(MAtom, M), atom_number(MAtom, Mes),
    atom_string(DAtom, D), atom_number(DAtom, Dia),
    integer(Ano), integer(Mes), integer(Dia),
    Mes >= 1, Mes =< 12,
    Dia >= 1, Dia =< 31,
    !.
validar_fecha(FechaStr, Archivo, LineaNum) :-
    format(user_error, 'error: fecha no ISO en ~s: línea ~w: ~s~n', [Archivo, LineaNum, FechaStr]),
    halt(1).

validar_minutos(Minutos, MinStr, Archivo, LineaNum) :-
    atom_string(MinAtom, MinStr),
    atom_number(MinAtom, Minutos),
    integer(Minutos),
    !.
validar_minutos(_Minutos, MinStr, Archivo, LineaNum) :-
    format(user_error, 'error: minutos no numericos en ~s: línea ~w: ~s~n', [Archivo, LineaNum, MinStr]),
    halt(1).

validar_si_no(Valor, Str, Archivo, LineaNum) :-
    atom_string(ValorAtom, Str),
    (   ValorAtom = si -> Valor = si
    ;   ValorAtom = no -> Valor = no
    ;
        format(user_error, 'error: valor no si/no en ~s: línea ~w: ~s~n', [Archivo, LineaNum, Str]),
        halt(1)
    ).

intento_fecha(intento(_P, F, _M, _A, _R, _L), F).
intento_problema(intento(P, _F, _M, _A, _R, _L), P).
intento_minutos(intento(_P, _F, M, _A, _R, _L), M).
intento_ayuda(intento(_P, _F, _M, A, _R, _L), A).
intento_resuelto(intento(_P, _F, _M, _A, R, _L), R).
intento_linea(intento(_P, _F, _M, _A, _R, L), L).
snd(_-V, V).

% keysort es estable para claves iguales y leemos en orden de archivo, con lo que
% a igual fecha se conserva el orden de aparicion en el fichero.

% Lee problemas resueltos previos: un identificador por línea; # abre comentario;
% líneas vacías ignoradas. Devuelve lista de identificadores (átomos), sin duplicados.
leer_resueltos(Archivo, Resueltos) :-
    (   exists_file(Archivo) ->
        open(Archivo, read, In),
        leer_resueltos_stream(In, [], Acum),
        close(In),
        reverse(Acum, Rev),
        list_to_set(Rev, Resueltos)
    ;
        Resueltos = []
    ).

leer_resueltos_stream(In, Acum, Salida) :-
    read_line_to_string(In, Linea),
    (   Linea = end_of_file -> Salida = Acum
    ;   linea_blanca(Linea) ->
        leer_resueltos_stream(In, Acum, Salida)
    ;   atom_chars(Linea, ['#'|_]) ->
        leer_resueltos_stream(In, Acum, Salida)
    ;   atom_string(Id, Linea),
        leer_resueltos_stream(In, [Id|Acum], Salida)
    ).
