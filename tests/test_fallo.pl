% Pruebas unitarias del issue F0-02 (deduccion del fallo del historial).
% Una prueba por criterio de aceptacion, sin mocks. Usa el catalogo mini real.
:- use_module(library(plunit)).
:- begin_tests(fallo).

% Carga el catalogo mini una vez por prueba.
cargar_cat(Cat) :-
    cargar_catalogo('tests/fixtures/catalogo_mini.json', Cat).

% ---- AC1: 15 min, resuelto, sin ayuda -> acierto ----
test(intento_resuelto_a_tiempo_es_acierto) :-
    cargar_cat(Cat),
    Intento = intento('1850A', '2026-11-20', 15, no, si, 1),
    veredicto_intento(Intento, Cat, Veredicto, Motivos),
    assertion(Veredicto = acierto),
    assertion(Motivos = []).

% ---- AC2: 25 min, resuelto, sin ayuda -> fallo: tiempo ----
test(intento_resuelto_tarde_es_fallo) :-
    cargar_cat(Cat),
    Intento = intento('1850A', '2026-11-21', 25, no, si, 2),
    veredicto_intento(Intento, Cat, Veredicto, Motivos),
    assertion(Veredicto = fallo),
    assertion(Motivos = [tiempo]).

% ---- AC3: 10 min, resuelto, con ayuda -> fallo: ayuda ----
test(intento_resuelto_con_ayuda_es_fallo) :-
    cargar_cat(Cat),
    Intento = intento('1850A', '2026-11-22', 10, si, si, 3),
    veredicto_intento(Intento, Cat, Veredicto, Motivos),
    assertion(Veredicto = fallo),
    assertion(Motivos = [ayuda]).

% ---- AC4: 20 min, no resuelto, sin ayuda -> fallo: no_resuelto ----
test(intento_no_resuelto_es_fallo) :-
    cargar_cat(Cat),
    Intento = intento('1850A', '2026-11-23', 20, no, no, 4),
    veredicto_intento(Intento, Cat, Veredicto, Motivos),
    assertion(Veredicto = fallo),
    assertion(Motivos = [no_resuelto]).

% ---- AC5: exactamente 20 min, resuelto, sin ayuda -> acierto ----
test(limite_exacto_no_es_fallo) :-
    cargar_cat(Cat),
    Intento = intento('1850A', '2026-11-24', 20, no, si, 5),
    veredicto_intento(Intento, Cat, Veredicto, Motivos),
    assertion(Veredicto = acierto),
    assertion(Motivos = []).

% ---- AC6: 30 min, ayuda y no resuelto -> motivos en orden no_resuelto, ayuda, tiempo ----
test(motivos_multiples_en_orden) :-
    cargar_cat(Cat),
    Intento = intento('1850A', '2026-11-25', 30, si, no, 6),
    veredicto_intento(Intento, Cat, Veredicto, Motivos),
    assertion(Veredicto = fallo),
    assertion(Motivos = [no_resuelto, ayuda, tiempo]).

% ---- AC7: fallo seguido de acierto posterior conserva ambos; el primero sigue siendo fallo ----
test(fallo_no_se_anula_por_acierto_posterior) :-
    cargar_cat(Cat),
    I1 = intento('1850A', '2026-11-20', 20, no, no, 1),
    I2 = intento('1850A', '2026-11-21', 15, no, si, 2),
    veredicto_intento(I1, Cat, V1, M1),
    veredicto_intento(I2, Cat, V2, M2),
    assertion(V1 = fallo),
    assertion(M1 = [no_resuelto]),
    assertion(V2 = acierto),
    assertion(M2 = []).

% ---- AC8: linea invalida (ayuda, minutos o fecha) -> error: con archivo y linea, codigo 1 ----
test(error_linea_invalida_nombra_linea) :-
    Casos = [
        '1850A,2026-11-20,15,maybe,si',
        '1850A,2026-11-20,abc,no,si',
        '1850A,2026-13-20,15,no,si'
    ],
    maplist(historial_linea_invalida_error, Casos).

historial_linea_invalida_error(LineaInvalida) :-
    TmpPath = '/tmp/hist_ac8.csv',
    open(TmpPath, write, Out),
    format(Out, 'problema,fecha,minutos,ayuda,resuelto~n', []),
    format(Out, '~s~n', [LineaInvalida]),
    close(Out),
    atom_concat('swipl -q src/main.pl intentos --catalogo tests/fixtures/catalogo_mini.json --historial ', TmpPath, Cmd1),
    atom_concat(Cmd1, ' > /tmp/out_ac8.txt 2> /tmp/err_ac8.txt', Cmd),
    shell(Cmd, Code),
    assertion(Code = 1),
    open('/tmp/err_ac8.txt', read, In),
    read_string(In, _, Err),
    close(In),
    ( sub_string(Err, _, _, _, 'error:') -> true ; assertion(false) ),
    ( sub_string(Err, _, _, _, TmpPath) -> true ; assertion(false) ),
    ( sub_string(Err, _, _, _, '2') -> true ; assertion(false) ),
    delete_file(TmpPath).

% ---- AC9: problema del historial no en el catalogo -> error: con id y linea ----
test(error_problema_fuera_del_catalogo) :-
    TmpPath = '/tmp/hist_ac9.csv',
    open(TmpPath, write, Out),
    format(Out, 'problema,fecha,minutos,ayuda,resuelto~n', []),
    format(Out, '~s~n', ['9999Z,2026-11-20,15,no,si']),
    close(Out),
    atom_concat('swipl -q src/main.pl intentos --catalogo tests/fixtures/catalogo_mini.json --historial ', TmpPath, Cmd1),
    atom_concat(Cmd1, ' > /tmp/out_ac9.txt 2> /tmp/err_ac9.txt', Cmd),
    shell(Cmd, Code),
    assertion(Code = 1),
    open('/tmp/err_ac9.txt', read, In),
    read_string(In, _, Err),
    close(In),
    ( sub_string(Err, _, _, _, 'error:') -> true ; assertion(false) ),
    ( sub_string(Err, _, _, _, '9999Z') -> true ; assertion(false) ),
    ( sub_string(Err, _, _, _, '2') -> true ; assertion(false) ),
    delete_file(TmpPath).

% ---- AC10: archivo de resueltos previos ignora comentarios y lineas vacias ----
test(resueltos_ignora_comentarios) :-
    leer_resueltos('tests/fixtures/resueltos_mini.txt', Resueltos),
    assertion(member('1850A', Resueltos)),
    assertion(member('1850B1', Resueltos)),
    assertion(length(Resueltos, 2)).

% ---- AC11: comando intentos imprime una linea por intento con veredicto ----
test(comando_intentos_imprime_veredictos) :-
    shell('swipl -q src/main.pl intentos --catalogo tests/fixtures/catalogo_mini.json --historial tests/fixtures/historial_casos.csv > /tmp/out_intentos.txt 2> /tmp/err_intentos.txt', Code),
    assertion(Code = 0),
    open('/tmp/out_intentos.txt', read, In),
    read_string(In, _, Out),
    close(In),
    ( sub_string(Out, _, _, _, '2026-11-20, 1850A, acierto') -> true ; assertion(false) ),
    ( sub_string(Out, _, _, _, '2026-11-21, 1850A, fallo, tiempo') -> true ; assertion(false) ),
    ( sub_string(Out, _, _, _, '2026-11-22, 1850A, fallo, ayuda') -> true ; assertion(false) ),
    ( sub_string(Out, _, _, _, '2026-11-23, 1850A, fallo, no_resuelto') -> true ; assertion(false) ),
    ( sub_string(Out, _, _, _, '2026-11-24, 1850A, acierto') -> true ; assertion(false) ),
    ( sub_string(Out, _, _, _, '2026-11-25, 1850A, fallo, no_resuelto,ayuda,tiempo') -> true ; assertion(false) ),
    % Seis intentos => seis líneas de salida (el texto termina en newline)
    cuenta_lineas(Out, 6).

cuenta_lineas(Texto, N) :-
    split_string(Texto, "\n", "", Partes),
    (   append(Pre, [""], Partes) -> length(Pre, N)   % termina en newline
    ;   length(Partes, N)                            % sin newline final
    ).

:- end_tests(fallo).
