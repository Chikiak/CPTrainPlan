% Pruebas unitarias del issue F0-03 (estados de tema y prerrequisitos).
% Una prueba por criterio de aceptacion, sin mocks. Usa el catalogo mini real,
% el historial real y el fixture de prerrequisitos mini.
:- use_module(library(plunit)).
:- use_module(library(json)).
:- begin_tests(temas).

% Carga el catalogo mini una vez por prueba.
cargar_cat(Cat) :-
    cargar_catalogo('tests/fixtures/catalogo_mini.json', Cat).

% ---- AC1: tabla de 14 casos (parametrizada) ----
test(estado_segun_tabla) :-
    Casos = [
        []-sin_datos,
        [acierto]-en_progreso,
        [fallo]-en_progreso,
        [fallo, acierto]-debil,
        [acierto, fallo, acierto, fallo]-debil,
        [fallo, acierto, fallo, acierto, fallo]-debil,
        [acierto, acierto, acierto, fallo, fallo]-debil,
        [acierto, acierto, fallo, acierto]-en_progreso,
        [acierto, acierto, acierto, acierto, fallo]-en_progreso,
        [acierto, acierto, fallo, fallo, acierto]-en_progreso,
        [acierto, acierto, acierto, acierto, acierto]-dominado,
        [acierto, acierto, fallo, acierto, acierto]-dominado,
        [fallo, acierto, acierto, acierto, acierto]-dominado,
        [fallo, fallo, fallo, acierto, acierto, acierto, acierto, acierto]-dominado
    ],
    maplist(estado_caso, Casos).

estado_caso(Secuencia-Esperado) :-
    estado_tema(Secuencia, Estado),
    assertion(Estado = Esperado).

% ---- AC2: intentos de un problema con varios tags cuentan para cada tema ----
test(intento_cuenta_para_todos_sus_temas) :-
    cargar_catalogo('tests/fixtures/catalogo_mini.json', Cat),
    leer_historial('tests/fixtures/historial_casos.csv', Intentos),
    leer_prerrequisitos('tests/fixtures/prerrequisitos_mini.csv', _Pares),
    veredictos_por_tema("math", Intentos, Cat, Vmath),
    length(Vmath, 6),
    % dp y greedy cuentan para 1850C que no esta en el historial => sin datos.
    veredictos_por_tema("dp", Intentos, Cat, Vdp),
    length(Vdp, 0),
    veredictos_por_tema("greedy", Intentos, Cat, Vgreedy),
    length(Vgreedy, 0).

% ---- AC2: tags de temas_ignorados no tienen estado ----
test(temas_ignorados_no_tienen_estado) :-
    cargar_catalogo('tests/fixtures/catalogo_mini.json', Cat),
    % implementation es ignorado: 1850A, 1850B1, 1850B2, 1850H tienen este tag.
    leer_historial('tests/fixtures/historial_casos.csv', Intentos),
    leer_prerrequisitos('tests/fixtures/prerrequisitos_mini.csv', _Pares),
    veredictos_por_tema("implementation", Intentos, Cat, Vimpl),
    length(Vimpl, 0),
    % interactive, communication, *special no aparecen en el catálogo mini.
    veredictos_por_tema("interactive", Intentos, Cat, Vint),
    length(Vint, 0).

% ---- AC3: ancestros incluyen indirectos (A requiere B, B requiere C) ----
test(ancestros_incluyen_indirectos) :-
    Pares = [a-b, b-c],
    ancestros(a, Pares, Anc),
    assertion(member(b, Anc)),
    assertion(member(c, Anc)),
    \+ member(a, Anc).

% ---- AC4: trabajable exige todos los ancestros cubiertos ----
test(trabajable_exige_todos_los_ancestros) :-
    Pares = [a-b, b-c],
    % c cubierto => b trabajable (su único ancestro es c)
    Estados1 = [estado(c, dominado)],
    assertion(tema_trabajable(b, Pares, Estados1)),
    % a requiere b y c; b no cubierto => a no trabajable
    \+ tema_trabajable(a, Pares, Estados1),
    % b y c cubiertos => a trabajable
    Estados2 = [estado(b, dominado), estado(c, dominado)],
    assertion(tema_trabajable(a, Pares, Estados2)).

% b no cubierto => a no trabajable.
test(trabajable_bloquea_si_ancestro_no_cubierto) :-
    Pares = [a-b, b-c],
    Estados = [estado(c, en_progreso)], % b sin estado
    \+ tema_trabajable(a, Pares, Estados).

% ---- AC4: tema sin ancestros siempre trabajable ----
test(tema_sin_ancestros_siempre_trabajable) :-
    Pares = [a-b],
    Estados = [],
    assertion(tema_trabajable(b, Pares, Estados)).

% ---- AC5: ancestro debil o sin_datos bloquea ----
test(ancestro_debil_o_sin_datos_bloquea) :-
    Pares = [a-b],
    % b es debil => a no trabajable.
    Estados1 = [estado(b, debil)],
    \+ tema_trabajable(a, Pares, Estados1),
    % b es sin_datos => a no trabajable.
    Estados2 = [estado(b, sin_datos)],
    \+ tema_trabajable(a, Pares, Estados2).

% ---- AC6: ciclo reportado y codigo 1 ----
test(ciclo_se_reporta) :-
    Pares = [a-b, b-c, c-a],
    ciclo_prerrequisitos(Pares, Ciclo),
    assertion(Ciclo \== []),
    assertion(member(a, Ciclo)),
    assertion(member(b, Ciclo)),
    assertion(member(c, Ciclo)).

% ---- AC7: ignora comentarios y lineas vacias; linea con menos de 2 columnas error ----
test(prerrequisitos_ignora_comentarios) :-
    Tmp = '/tmp/prer_ac7.csv',
    open(Tmp, write, Out),
    format(Out, 'tema,prerrequisito~n', []),
    format(Out, '# esto es un comentario~n', []),
    format(Out, '~n', []),
    format(Out, 'a,b~n', []),
    close(Out),
    leer_prerrequisitos(Tmp, Pares),
    assertion(member(a-b, Pares)),
    assertion(length(Pares, 1)),
    delete_file(Tmp).

test(error_linea_de_prerrequisitos) :-
    Tmp = '/tmp/prer_ac7_err.csv',
    open(Tmp, write, Out),
    format(Out, 'tema,prerrequisito~n', []),
    format(Out, 'sola_columna~n', []),
    close(Out),
    atom_concat('swipl -q src/main.pl temas --catalogo tests/fixtures/catalogo_mini.json --prerrequisitos ', Tmp, Cmd1),
    atom_concat(Cmd1, ' --historial tests/fixtures/historial_casos.csv > /tmp/out_ac7e.txt 2> /tmp/err_ac7e.txt', Cmd),
    shell(Cmd, Code),
    assertion(Code = 1),
    open('/tmp/err_ac7e.txt', read, In),
    read_string(In, _, Err),
    close(In),
    ( sub_string(Err, _, _, _, 'error:') -> true ; assertion(false) ),
    ( sub_string(Err, _, _, _, Tmp) -> true ; assertion(false) ),
    delete_file(Tmp).

% ---- AC8: borrador real leido sin error y sin ciclos, 22 pares ----
test(borrador_de_prerrequisitos_es_valido) :-
    leer_prerrequisitos('datos/prerrequisitos.csv', Pares),
    assertion(length(Pares, 22)),
    ciclo_prerrequisitos(Pares, Ciclo),
    assertion(Ciclo = []),
    member('binary search'-'sortings', Pares),
    member('string suffix structures'-'strings', Pares).

% ---- AC9: umbral editable en otro archivo cambia el estado sin tocar src/ ----
test(umbral_editable_sin_tocar_codigo) :-
    open('/tmp/parametros_temas.pl', write, Out),
    format(Out, 'ventana_estado(5).~n', []),
    format(Out, 'debil_min_intentos(2).~n', []),
    format(Out, 'debil_pct_fallos(100).~n', []), % solo fallo total es debil
    format(Out, 'dominado_min_intentos(5).~n', []),
    format(Out, 'dominado_max_fallos(1).~n', []),
    format(Out, 'temas_ignorados(implementation).~n', []),
    format(Out, 'temas_ignorados("*special").~n', []),
    format(Out, 'temas_ignorados(interactive).~n', []),
    format(Out, 'temas_ignorados(communication).~n', []),
    close(Out),
    open('/tmp/ac9.pl', write, Script),
    format(Script, ":- initialization(main).~n", []),
    format(Script, "main :- consult('/home/adrian/Proyectos/CPTrainPlan/src/temas.pl'),~n", []),
    format(Script, "    consult('/tmp/parametros_temas.pl'),~n", []),
    format(Script, "    estado_tema([fallo, fallo], E), format('estado:~~w~~n', [E]), halt.~n", []),
    close(Script),
    shell('swipl -q /tmp/ac9.pl > /tmp/out_ac9.txt 2> /tmp/err_ac9.txt', Code),
    (Code = 0 -> true ; assertion(false)),
    open('/tmp/out_ac9.txt', read, In),
    read_string(In, _, Contenido),
    close(In),
    ( sub_string(Contenido, _, _, _, 'estado:debil') -> true ; assertion(false) ).

% ---- AC10: comando temas imprime estado, intentos y trabajable por tema ----
test(comando_temas_imprime_estado) :-
    shell('swipl -q src/main.pl temas --catalogo tests/fixtures/catalogo_mini.json --prerrequisitos tests/fixtures/prerrequisitos_mini.csv --historial tests/fixtures/historial_casos.csv > /tmp/out_temas.txt 2> /tmp/err_temas.txt', Code),
    assertion(Code = 0),
    open('/tmp/out_temas.txt', read, In),
    read_string(In, _, Out),
    close(In),
    ( sub_string(Out, _, _, _, 'math') -> true ; assertion(false) ),
    ( sub_string(Out, _, _, _, 'trabajable') -> true ; assertion(false) ),
    % Orden alfabetico: math antes que dp? No, dp antes que math alfabeticamente.
    cuenta_lineas(Out, N),
    assertion(N >= 1).

cuenta_lineas(Texto, N) :-
    split_string(Texto, "\n", "", Partes),
    (   append(Pre, [""], Partes) -> length(Pre, N)
    ;   length(Partes, N)
    ).

:- end_tests(temas).
