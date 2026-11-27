% Consulta del límite de tiempo por rating, según la tabla editable
% limite_tiempo en config/parametros.pl (consultada en el contexto de usuario).

% limite_por_rating(+Rating, -Minutos): busca la fila cuyo rango contenga
% el rating; la última fila no tiene tope superior (inf).
limite_por_rating(Rating, Minutos) :-
    limite_tiempo(Min, Max, Minutos),
    (   Max = inf -> Min =< Rating
    ;   Min =< Rating, Rating =< Max
    ).
