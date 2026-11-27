% Pruebas unitarias del issue F0-04 (seleccionar candidatos acotados).
% Una prueba por criterio de aceptacion, sin mocks. Usa el catalogo de candidatos,
% el historial de candidatos y el fixture de prerrequisitos mini.
:- use_module(library(plunit)).
:- use_module(library(json)).
:- use_module(library(time)).
:- begin_tests(candidatos).

% ---- Auxiliar: carga todo y devuelve los candidatos para un nivel ----
setup_candidatos(Nivel, Candidatos) :-
    leer_historial('tests/fixtures/historial_candidatos.csv', Intentos),
    cargar_catalogo('tests/fixtures/catalogo_candidatos.json', Cat),
    leer_prerrequisitos('tests/fixtures/prerrequisitos_mini.csv', Pares),
    temas_del_catalogo(Cat, TodosTemas),
    maplist(estado_de_tema(Intentos, Cat), TodosTemas, Estados),
    problemas_candidatos(Cat, Intentos, [], Pares, Estados, Nivel, Candidatos).

estado_de_tema(Intentos, Cat, Tema, Estado) :-
    veredictos_por_tema(Tema, Intentos, Cat, Veredictos),
    estado_tema(Veredictos, Estado).

setup_candidatos_con_resueltos(Nivel, ResueltosFile, Candidatos) :-
    leer_historial('tests/fixtures/historial_candidatos.csv', Intentos),
    cargar_catalogo('tests/fixtures/catalogo_candidatos.json', Cat),
    leer_prerrequisitos('tests/fixtures/prerrequisitos_mini.csv', Pares),
    leer_resueltos(ResueltosFile, Resueltos),
    temas_del_catalogo(Cat, TodosTemas),
    maplist(estado_de_tema(Intentos, Cat), TodosTemas, Estados),
    problemas_candidatos(Cat, Intentos, Resueltos, Pares, Estados, Nivel, Candidatos).

% ids de una lista de candidatos.
ids_candidatos(Candidatos, Ids) :-
    maplist(id_de, Candidatos, Ids).

id_de(candidato(Id, _R, _M, _T, _G), Id).

% rating de un candidato.
rating_de(candidato(_I, R, _M, _T, _G), R).

% temas de un candidato.
temas_de(candidato(_I, _R, _M, T, _G), T).

% ---- AC1: excluye intentos y resueltos previos ----
test(excluye_intentados_y_resueltos) :-
    % 1008A esta en el historial => no candidato.
    setup_candidatos(1200, Cand),
    \+ member(candidato('1008A', _, _, _, _), Cand),
    % 1008B es resuelto previo => no candidato (con archivo de resueltos).
    open('/tmp/resueltos_cand.txt', write, Out),
    format(Out, '1008B~n', []),
    close(Out),
    setup_candidatos_con_resueltos(1200, '/tmp/resueltos_cand.txt', Cand2),
    \+ member(candidato('1008B', _, _, _, _), Cand2),
    delete_file('/tmp/resueltos_cand.txt').

% ---- AC2: respeta la banda de nivel (nivel 1200 -> [1300, 1400]) ----
test(respeta_banda_de_nivel) :-
    setup_candidatos(1200, Cand),
    maplist(rating_de, Cand, Ratings),
    % 1300 y 1400 entran; 1200 y 1500 no.
    (   member(1300, Ratings) -> true ; assertion(false) ),
    (   member(1400, Ratings) -> true ; assertion(false) ),
    \+ member(1200, Ratings),
    \+ member(1500, Ratings),
    \+ member(800, Ratings),
    % Todos los ratings en [1300, 1400].
    maplist(entre_1300_y_1400, Ratings).

entre_1300_y_1400(R) :- R >= 1300, R =< 1400.

% ---- AC3: excluye problemas con algun tema seguido no trabajable ----
test(excluye_problemas_con_tema_bloqueado) :-
    % 1009A tiene tag "a", que no es trabajable (ancestro require_c sin datos).
    setup_candidatos(1200, Cand),
    \+ member(candidato('1009A', _, _, _, _), Cand).

% ---- AC4: problema cuyos tags son todos ignorados es candidato (sin_tema) ----
test(problema_sin_tema_seguido_es_candidato) :-
    setup_candidatos(1200, Cand),
    % 1005A: tags [implementation, *special] (ambos ignorados) => sin_tema.
    member(candidato('1005A', 1300, _, [], sin_tema), Cand),
    % 1005B: tag [communication] (ignorado) => sin_tema.
    member(candidato('1005B', 1350, _, [], sin_tema), Cand).

% ---- AC5: tope_por_tema y orden por cercania ----
test(tope_por_tema_y_orden) :-
    setup_candidatos(1200, Cand),
    % Tema graphs: orden esperado por cercania a 1350, desempate id alfabetico.
    % 1004B(0), 1004A(10), 1010B(20), 1010H(20), 1011D(20) ...
    ids_de_tema(Cand, graphs, GraphIds),
    (   GraphIds = ['1004B', '1004A', '1010B', '1010H', '1011D'] -> true
    ;   GraphIds = ['1004B', '1004A', '1010B', '1010H', '1011D'|_] -> true
    ;   assertion(false)
    ),
    length(GraphIds, Lg),
    Lg =< 5,
    % Tema math: maximo 5.
    ids_de_tema(Cand, math, MathIds),
    length(MathIds, Lm),
    Lm =< 5.

ids_de_tema(Candidatos, Tema, Ids) :-
    findall(Id, (member(candidato(Id, _R, _M, Temas, _G), Candidatos), member(Tema, Temas)), Ids).

% ---- AC6: tope_total con catalogo sintetico (ver AC7) ----
% AC6 se cubre en escala_catalogo_sintetico (verifica <= 200).

% ---- AC7: escala con catalogo sintetico de 3000 problemas ----
test(escala_catalogo_sintetico) :-
    Generado = '/tmp/catalogo_3000.json',
    generar_catalogo_3000(Generado),
    get_time(T0),
    leer_historial('tests/fixtures/historial_candidatos.csv', Intentos),
    cargar_catalogo(Generado, Cat),
    leer_prerrequisitos('tests/fixtures/prerrequisitos_mini.csv', Pares),
    temas_del_catalogo(Cat, TodosTemas),
    maplist(estado_de_tema(Intentos, Cat), TodosTemas, Estados),
    problemas_candidatos(Cat, Intentos, [], Pares, Estados, 1200, Cand),
    get_time(T1),
    Ms is (T1 - T0) * 1000,
    length(Cand, Total),
    (   Ms < 5000 -> true ; assertion(false) ),
    (   Total =< 200 -> true ; assertion(false) ),
    delete_file(Generado).

% Genera 3000 problemas deterministas, ratings 800-3000, tags de una lista de 30.
generar_catalogo_3000(Path) :-
    open(Path, write, Out),
    format(Out, '{"status":"OK","result":{"problems":[', []),
    generar_problemas(1, 3000, Out),
    format(Out, ']}}', []),
    close(Out).

generar_problemas(N, Max, Out) :-
    N > Max, !.
generar_problemas(N, Max, Out) :-
    N =< Max ->
    Rating is 800 + (N mod 2201),
    TagIdx is (N mod 30) + 1,
    atom_concat('tag', TagIdx, TagStr),
    (   N = Max ->
        format(Out, '{"contestId":3000,"index":"~w","name":"P~w","rating":~w,"tags":["~s"]}', [N, N, Rating, TagStr])
    ;
        format(Out, '{"contestId":3000,"index":"~w","name":"P~w","rating":~w,"tags":["~s"]},', [N, N, Rating, TagStr])
    ),
    N1 is N + 1,
    generar_problemas(N1, Max, Out).

% ---- AC8: seleccion determinista ----
test(seleccion_determinista) :-
    setup_candidatos(1200, Cand1),
    setup_candidatos(1200, Cand2),
    Cand1 = Cand2.

:- end_tests(candidatos).
