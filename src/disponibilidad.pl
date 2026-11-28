% Lectura de la disponibilidad y fechas de los días para el plan.
% Una fila por día: fecha (ISO, YYYY-MM-DD) y minutos disponibles.
% La cabecera es "fecha,minutos". Las líneas en blanco y los comentarios
% (empiezan por #) se ignoran. Una fecha de más en el archivo se ignora.

:- use_module(library(lists)).
:- use_module(library(time)).

% Cabecera esperada del archivo de disponibilidad.
cabecera_disponibilidad(["fecha", "minutos"]).

% Lee el archivo de disponibilidad y devuelve lista de pares Fecha-Minutos.
% Cualquier error de datos escribe 'error:' en stderr con archivo y línea
% y termina con código 1.
leer_disponibilidad(Archivo, Disponibilidad) :-
    (   exists_file(Archivo) ->
        open(Archivo, read, In),
        leer_lineas_disp(In, Archivo, 0, [], Linas),
        close(In),
        reverse(Linas, EnOrden),
        Disponibilidad = EnOrden
    ;
        format(user_error, 'error: no se encuentra el archivo de disponibilidad: ~s~n', [Archivo]),
        halt(1)
    ).

% Lee líneas: salta comentarios y vacías, valida la cabecera (primera línea
% no vacía ni comentario), luego lee pares fecha-minutos.
leer_lineas_disp(In, Archivo, N, Acum, Salida) :-
    read_line_to_string(In, Linea),
    (   Linea = end_of_file -> Salida = Acum
    ;   N1 is N + 1,
        (   linea_blanca(Linea) ->
            leer_lineas_disp(In, Archivo, N1, Acum, Salida)
        ;   es_comentario(Linea) ->
            leer_lineas_disp(In, Archivo, N1, Acum, Salida)
        ;   N1 =:= 1 ->
            (   es_cabecera_disp(Linea) ->
                leer_lineas_disp(In, Archivo, N1, Acum, Salida)
            ;
                format(user_error, 'error: cabecera de disponibilidad invalida en ~s: ~s~n', [Archivo, Linea]),
                halt(1)
            )
        ;   linea_a_par_disp(Linea, Archivo, N1, Par),
            leer_lineas_disp(In, Archivo, N1, [Par|Acum], Salida)
        )
    ).

es_comentario(Linea) :-
    atom_string(Atom, Linea),
    sub_atom(Atom, 0, 1, _, "#").

es_cabecera_disp(Linea) :-
    split_string(Linea, ",", "", Partes),
    Partes = ["fecha", "minutos"].

linea_a_par_disp(Linea, Archivo, LineaNum, Fecha-Minutos) :-
    split_string(Linea, ",", "", Partes),
    (   length(Partes, 2) ->
        [FParte, MParte] = Partes,
        atom_string(FechaStr, FParte),
        validar_fecha_disp(FechaStr, Archivo, LineaNum),
        Fecha = FechaStr,
        validar_minutos_disp(Minutos, MParte, Archivo, LineaNum)
    ;
        format(user_error, 'error: linea mal formada en ~s: línea ~w~n', [Archivo, LineaNum]),
        halt(1)
    ).

validar_fecha_disp(FechaStr, Archivo, LineaNum) :-
    split_string(FechaStr, "-", "", [A, M, D]),
    atom_string(AAtom, A), atom_number(AAtom, Ano),
    atom_string(MAtom, M), atom_number(MAtom, Mes),
    atom_string(DAtom, D), atom_number(DAtom, Dia),
    integer(Ano), integer(Mes), integer(Dia),
    Mes >= 1, Mes =< 12,
    Dia >= 1, Dia =< 31,
    !.
validar_fecha_disp(FechaStr, Archivo, LineaNum) :-
    format(user_error, 'error: fecha no ISO en ~s: línea ~w: ~s~n', [Archivo, LineaNum, FechaStr]),
    halt(1).

validar_minutos_disp(Minutos, MinStr, Archivo, LineaNum) :-
    atom_string(MinAtom, MinStr),
    atom_number(MinAtom, Minutos),
    integer(Minutos),
    !.
validar_minutos_disp(_Minutos, MinStr, Archivo, LineaNum) :-
    format(user_error, 'error: minutos no numericos en ~s: línea ~w: ~s~n', [Archivo, LineaNum, MinStr]),
    halt(1).

% La fecha del día d es Hoy más d-1 días. Devuelve lista de fechas ISO.
% Implementación manual y determinista (sin zona horaria, para reproducibilidad).
fechas_de_plan(Hoy, N, Fechas) :-
    parse_fecha(Hoy, A, M, D),
    fechas_desde(A, M, D, 1, N, [], Acum),
    reverse(Acum, Fechas).

fechas_desde(_A, _M, _Dia, D, N, Acum, Acum) :- D > N, !.
fechas_desde(A, M, Dia, D, N, Acum, Salida) :-
    formato_fecha(A, M, Dia, Fecha),
    D1 is D + 1,
    sumar_un_dia(A, M, Dia, A1, M1, Dia1),
    fechas_desde(A1, M1, Dia1, D1, N, [Fecha|Acum], Salida).

% parse_fecha("YYYY-MM-DD", Ano, Mes, Dia).
parse_fecha(Fecha, A, M, D) :-
    split_string(Fecha, "-", "", [A0, M0, D0]),
    number_string(A, A0),
    number_string(M, M0),
    number_string(D, D0).

% sumar_un_dia(A,M,D, A1,M1,D1): avanza un día calendario.
sumar_un_dia(A, M, D, A1, M1, D1) :-
    dias_mes(A, M, DiasMes),
    (   D < DiasMes ->
        A1 = A, M1 = M, D1 is D + 1
    ;   M < 12 ->
        A1 = A, M1 is M + 1, D1 = 1
    ;   A1 is A + 1, M1 = 1, D1 = 1
    ).

dias_mes(A, 2, 29) :- bisiesto(A), !.
dias_mes(_A, 2, 28).
dias_mes(_A, 1, 31). dias_mes(_A, 3, 31). dias_mes(_A, 4, 30).
dias_mes(_A, 5, 31). dias_mes(_A, 6, 30). dias_mes(_A, 7, 31).
dias_mes(_A, 8, 31). dias_mes(_A, 9, 30). dias_mes(_A, 10, 31).
dias_mes(_A, 11, 30). dias_mes(_A, 12, 31).

bisiesto(A) :-
    A mod 4 =:= 0,
    (   A mod 100 =:= 0 -> A mod 400 =:= 0 ; true ).

formato_fecha(A, M, D, Fecha) :-
    numero_a_atomo_dos_digitos(M, Ms),
    numero_a_atomo_dos_digitos(D, Ds),
    number_chars(A, Ac),
    atomic_list_concat(Ac, "", As),
    atom_concat(As, "-", P1),
    atom_concat(P1, Ms, P2),
    atom_concat(P2, "-", P3),
    atom_concat(P3, Ds, Fecha).

numero_a_atomo_dos_digitos(N, S) :-
    (   N < 10 ->
        number_chars(N, [C]),
        atom_concat("0", C, S)
    ;
        number_chars(N, Chars),
        atomic_list_concat(Chars, "", S)
    ).

% Busca los minutos disponibles de una fecha. Devuelve Minutos o falla si la
% fecha no está en el archivo (una fecha de más se ignora).
minutos_de_fecha(Fecha, Disponibilidad, Minutos) :-
    member(Fecha-Minutos, Disponibilidad).
