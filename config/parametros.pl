% Tabla de parámetros del proyecto CPTrainPlan.
% Cada fila es editable y es usada por los issues que la crean.
% F0-01 crea la tabla limite_tiempo.
% Filas: rating_min, rating_max, minutos. La última fila no tiene tope superior (inf).

limite_tiempo(0, 1000, 20).       % hasta 1000 -> 20
limite_tiempo(1100, 1300, 30).    % 1100-1300 -> 30
limite_tiempo(1400, 1600, 45).    % 1400-1600 -> 45
limite_tiempo(1700, 1900, 60).    % 1700-1900 -> 60
limite_tiempo(2000, inf, 90).     % desde 2000 sin tope -> 90
