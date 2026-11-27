% Tabla de parámetros del proyecto CPTrainPlan.
% Cada fila es editable y es usada por los issues que la crean.
% F0-01 crea la tabla limite_tiempo.
% Filas: rating_min, rating_max, minutos. La última fila no tiene tope superior (inf).

limite_tiempo(0, 1000, 20).       % hasta 1000 -> 20
limite_tiempo(1100, 1300, 30).    % 1100-1300 -> 30
limite_tiempo(1400, 1600, 45).    % 1400-1600 -> 45
limite_tiempo(1700, 1900, 60).    % 1700-1900 -> 60
limite_tiempo(2000, inf, 90).     % desde 2000 sin tope -> 90

% F0-03: estados de tema y prerrequisitos.
% ventana_estado: últimos N intentos del tema que se miran.
ventana_estado(5).
% debil_min_intentos: intentos mínimos para considerar débil.
debil_min_intentos(2).
% debil_pct_fallos: porcentaje de fallos en la ventana para ser débil.
debil_pct_fallos(50).
% dominado_min_intentos: intentos mínimos para considerar dominado.
dominado_min_intentos(5).
% dominado_max_fallos: fallos máximos en la ventana para ser dominado.
dominado_max_fallos(1).
% temas_ignorados: tags que no generan estado de tema (cadenas, como en el JSON).
temas_ignorados("implementation").
temas_ignorados("*special").
temas_ignorados("interactive").
temas_ignorados("communication").

% F0-04: selección de candidatos acotados.
% banda_nivel_min / banda_nivel_max: rating válido entre nivel+banda_nivel_min y nivel+banda_nivel_max, ambos incluidos.
banda_nivel_min(100).
banda_nivel_max(200).
% tope_por_tema: candidatos máximos por tema trabajable, los más cercanos a nivel+150.
tope_por_tema(5).
% tope_total_candidatos: total máximo de candidatos conservados, primeros por cercanía.
tope_total_candidatos(200).
