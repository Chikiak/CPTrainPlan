% Deduccion del veredicto (acierto/fallo) y los motivos de cada intento
% del historial. Usa el catalogo real y los limites de src/limites.pl.

:- use_module(library(lists)).

% veredicto_intento(+Intento, +Catalogo, -Veredicto, -Motivos)
% Intento = intento(Problema, Fecha, Minutos, Ayuda, Resuelto, Linea)
% Veredicto = acierto | fallo
% Motivos = sublista, en orden, de [no_resuelto, ayuda, tiempo]
veredicto_intento(Intento, Catalogo, Veredicto, Motivos) :-
    intento_problema(Intento, Problema),
    intento_linea(Intento, Linea),
    intento_minutos(Intento, Minutos),
    intento_ayuda(Intento, Ayuda),
    intento_resuelto(Intento, Resuelto),
    (   find_problema_rating(Catalogo, Problema, Rating, Linea) ->
        true
    ;   false
    ),
    limite_por_rating(Rating, Limite),
    motivos(Resuelto, Ayuda, Minutos, Limite, Motivos),
    (   Motivos = [] -> Veredicto = acierto
    ;   Veredicto = fallo
    ).

% Busca el rating del problema en el catalogo. Si no esta (o no tiene
% rating), escribe 'error:' con identificador y linea y termina con codigo 1.
find_problema_rating(Catalogo, Problema, Rating, Linea) :-
    (   find_problema(Catalogo, Problema, P),
        problema_rating(P, Rating)
    ->
        true
    ;
        format(user_error, 'error: problema no encontrado en el catalogo: ~s en línea ~w~n', [Problema, Linea]),
        halt(1)
    ).

motivos(Resuelto, Ayuda, Minutos, Limite, Motivos) :-
    motivo_no_resuelto(Resuelto, M1),
    motivo_ayuda(Ayuda, M2),
    motivo_tiempo(Minutos, Limite, M3),
    append(M1, M2, M12),
    append(M12, M3, Motivos).

motivo_no_resuelto(no, [no_resuelto]).
motivo_no_resuelto(si, []).

motivo_ayuda(si, [ayuda]).
motivo_ayuda(no, []).

motivo_tiempo(Minutos, Limite, [tiempo]) :- Minutos > Limite.
motivo_tiempo(_Minutos, _Limite, []).

% veredictos_de_intentos(+Intentos, +Catalogo, -Veredictos)
% Veredictos = lista de veredicto(Fecha, Problema, Veredicto, Motivos),
% en el mismo orden que Intentos (ya ordenados por fecha).
veredictos_de_intentos([], _Catalogo, []).
veredictos_de_intentos([Intento|Rest], Catalogo, [veredicto(Fecha, Problema, Veredicto, Motivos)|RestV]) :-
    veredicto_intento(Intento, Catalogo, Veredicto, Motivos),
    intento_fecha(Intento, Fecha),
    intento_problema(Intento, Problema),
    veredictos_de_intentos(Rest, Catalogo, RestV).

% Motivos como cadena separada por comas, para imprimir.
motivos_string([], "").
motivos_string(Motivos, S) :-
    atomic_list_concat(Motivos, ",", S).
