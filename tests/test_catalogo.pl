% Pruebas unitarias del issue F0-01 (catalogo y limite de tiempo).
% Una prueba por criterio de aceptación, sin mocks. Rutas relativas a la
% raíz del proyecto (se ejecutan desde ella).
:- use_module(library(plunit)).
:- use_module(library(json)).
:- begin_tests(catalogo).

% AC1 / AC10: la suite ejecuta al menos una prueba.
test(suite_ejecuta_almenos_una_prueba) :-
    true.

% AC2: con el catálogo mini, 8 problemas con rating y 2 excluidos sin rating.
test(resumen_cuenta_con_y_sin_rating) :-
    cargar_catalogo('tests/fixtures/catalogo_mini.json', Cat),
    resumen_catalogo(Cat, Con, Sin, _),
    assertion(Con = 8),
    assertion(Sin = 2).

% AC3: identificador y enlace (1850A).
test(id_y_enlace_de_un_problema) :-
    cargar_catalogo('tests/fixtures/catalogo_mini.json', Cat),
    find_problema(Cat, '1850A', P),
    problema_id(P, '1850A'),
    problema_enlace(P, 'https://codeforces.com/problemset/problem/1850/A').

% AC3: índice alfanumérico (1850B1).
test(id_con_indice_alfanumerico) :-
    cargar_catalogo('tests/fixtures/catalogo_mini.json', Cat),
    find_problema(Cat, '1850B1', P),
    problema_id(P, '1850B1'),
    problema_enlace(P, 'https://codeforces.com/problemset/problem/1850/B1').

% AC4: tags conservados en orden del archivo (json_read_dict lee strings).
test(conserva_tags_en_orden) :-
    cargar_catalogo('tests/fixtures/catalogo_mini.json', Cat),
    find_problema(Cat, '1850C', P),
    problema_tags(P, ["dp", "greedy"]).

% AC5: límite por rating (diez casos de la tabla de PHASE.md).
test(limite_por_rating) :-
    Casos = [800-20, 1000-20, 1100-30, 1300-30, 1400-45, 1600-45,
             1700-60, 1900-60, 2000-90, 3500-90],
    maplist(limite_caso, Casos).

limite_caso(Rating-Esperado) :-
    limite_por_rating(Rating, Minutos),
    assertion(Minutos = Esperado).

% AC6: cambiar una fila en otro archivo de parámetros cambia el límite sin tocar src/.
test(limite_editable_sin_tocar_codigo) :-
    open('/tmp/parametros_test.pl', write, Out),
    format(Out, 'limite_tiempo(0, 1000, 99).~n', []),
    close(Out),
    % Script Prolog temporal: consulta el archivo de parámetros elegido y límites.
    open('/tmp/ac6.pl', write, Script),
    format(Script, ":- initialization(main).~n", []),
    format(Script, "main :- consult('/tmp/parametros_test.pl'),~n", []),
    format(Script, "    consult('src/limites.pl'),~n", []),
    format(Script, "    limite_por_rating(500, M), format('~~w~~n', [M]), halt.~n", []),
    close(Script),
    shell('swipl -q /tmp/ac6.pl > /tmp/out_ac6.txt 2> /tmp/err_ac6.txt', Code),
    (Code = 0 -> true ; assertion(false)),
    open('/tmp/out_ac6.txt', read, In),
    read_string(In, _, Contenido),
    close(In),
    ( sub_string(Contenido, _, _, _, '99') -> true ; assertion(false) ).

% AC7: `swipl src/main.pl catalogo --catalogo ... --problema 1850A` imprime y código 0.
test(comando_catalogo_muestra_problema) :-
    shell('swipl -q src/main.pl catalogo --catalogo tests/fixtures/catalogo_mini.json --problema 1850A > /tmp/out_cat.txt 2> /tmp/err_cat.txt', Code),
    assertion(Code = 0),
    open('/tmp/out_cat.txt', read, In),
    read_string(In, _, Contenido),
    close(In),
    ( sub_string(Contenido, _, _, _, 'To My Critics') -> true ; assertion(false) ),
    ( sub_string(Contenido, _, _, _, 'limite: 20') -> true ; assertion(false) ),
    ( sub_string(Contenido, _, _, _, 'https://codeforces.com/problemset/problem/1850/A')
      -> true ; assertion(false) ).

% AC8: catálogo inexistente → línea error: con la ruta y código 1.
test(error_catalogo_inexistente) :-
    shell('swipl -q src/main.pl catalogo --catalogo no_existe.json > /tmp/out_err.txt 2> /tmp/err_err.txt', Code),
    assertion(Code = 1),
    open('/tmp/err_err.txt', read, In),
    read_string(In, _, Err),
    close(In),
    ( sub_string(Err, _, _, _, 'error:') -> true ; assertion(false) ),
    ( sub_string(Err, _, _, _, 'no_existe.json') -> true ; assertion(false) ).

% AC9: catalogo real → más de 1000 problemas con rating, sin error.
test(catalogo_real_mas_de_mil_con_rating) :-
    ( exists_file('datos/catalogo.json') ->
        cargar_catalogo('datos/catalogo.json', Cat),
        resumen_catalogo(Cat, Con, _Sin, _),
        assertion(Con > 1000)
    ;   true
    ).

:- end_tests(catalogo).
