% Punto de entrada del proyecto CPTrainPlan.
% Uso: swipl src/main.pl <subcomando> <opciones>
% Subcomando F0: catalogo (--catalogo, --problema, --parametros).
% Subcomando F0-02: intentos (--catalogo, --historial, --parametros).
% Las rutas de config/ y datos/ se resuelven desde la raíz del proyecto.
% Todo error escribe en stderr una línea que empieza por 'error:' y termina con código 1.
% Éxito termina con código 0, sin dejar el intérprete interactivo.

:- use_module(library(lists)).
:- use_module(library(json)).
:- use_module(library(clpfd)).

dummy.

% Carga los módulos de catálogo, límites, historial, fallo, prerrequisitos,
% temas, candidatos, disponibilidad, plan y salida una sola vez al iniciar.
:- initialization((
    project_root(Root),
    atom_concat(Root, "/", Pre),
    atom_concat(Pre, "src/catalogo.pl", CatSrc),
    atom_concat(Pre, "src/limites.pl", LimSrc),
    atom_concat(Pre, "src/historial.pl", HisSrc),
    atom_concat(Pre, "src/fallo.pl", FalSrc),
    atom_concat(Pre, "src/prerrequisitos.pl", PreSrc),
    atom_concat(Pre, "src/temas.pl", TemSrc),
    atom_concat(Pre, "src/candidatos.pl", CanSrc),
    atom_concat(Pre, "src/disponibilidad.pl", DispSrc),
    atom_concat(Pre, "src/plan.pl", PlanSrc),
    atom_concat(Pre, "src/salida.pl", SalSrc),
    consult(CatSrc),
    consult(LimSrc),
    consult(HisSrc),
    consult(FalSrc),
    consult(PreSrc),
    consult(TemSrc),
    consult(CanSrc),
    consult(DispSrc),
    consult(PlanSrc),
    consult(SalSrc)
)).

:- initialization(main).

main :-
    current_prolog_flag(argv, Argv),
    catch(dispatch(Argv), E, (print_message(error, E), throw(E))).

dispatch([]) :-
    format(user_error, 'error: se espera un subcomando: catalogo~n'),
    halt(1).
dispatch([Sub|Opts]) :-
    (   Sub = catalogo -> cmd_catalogo(Opts)
    ;   Sub = intentos -> cmd_intentos(Opts)
    ;   Sub = temas -> cmd_temas(Opts)
    ;   Sub = candidatos -> cmd_candidatos(Opts)
    ;   Sub = plan -> cmd_plan(Opts)
    ;   format(user_error, 'error: subcomando desconocido: ~s~n', [Sub]),
        halt(1)
    ).

% Raíz del proyecto: directorio que contiene src/ (padre del directorio de este archivo).
project_root(Root) :-
    source_file(dummy, SrcFile),
    absolute_file_name(SrcFile, AbsFile),
    file_directory_name(AbsFile, SrcDir),
    file_directory_name(SrcDir, Root).

% Resuelve Path contra la raíz del proyecto, salvo que ya sea absoluta.
resolve(Path, Full) :-
    project_root(Root),
    (   sub_atom(Path, 0, 1, _, "/") -> Full = Path
    ;   atom_concat(Root, "/", Prefix),
        atom_concat(Prefix, Path, Full)
    ).

parse_opts([], []).
parse_opts([ '--catalogo', V|R], [catalogo=V|KV]) :- parse_opts(R, KV).
parse_opts([ '--problema', V|R], [problema=V|KV]) :- parse_opts(R, KV).
parse_opts([ '--parametros', V|R], [parametros=V|KV]) :- parse_opts(R, KV).
parse_opts([ '--historial', V|R], [historial=V|KV]) :- parse_opts(R, KV).
parse_opts([ '--prerrequisitos', V|R], [prerrequisitos=V|KV]) :- parse_opts(R, KV).
parse_opts([ '--nivel', V|R], [nivel=V|KV]) :- parse_opts(R, KV).
parse_opts([ '--hoy', V|R], [hoy=V|KV]) :- parse_opts(R, KV).
parse_opts([ '--dias', V|R], [dias=V|KV]) :- parse_opts(R, KV).
parse_opts([ '--disponibilidad', V|R], [disponibilidad=V|KV]) :- parse_opts(R, KV).
parse_opts([ '--salida', V|R], [salida=V|KV]) :- parse_opts(R, KV).
parse_opts([_|R], KV) :- parse_opts(R, KV). % ignora opciones desconocidas

opt_default(Key, KV, Def, Value) :-
    (   member(Key=Value, KV) -> true
    ;   Value = Def
    ).

cmd_catalogo(Opts) :-
    parse_opts(Opts, KV),
    opt_default(catalogo, KV, 'datos/catalogo.json', CatPath0),
    opt_default(problema, KV, none, Problema),
    opt_default(parametros, KV, 'config/parametros.pl', ParamPath0),
    resolve(CatPath0, CatPath),
    resolve(ParamPath0, ParamPath),
    % Carga la tabla de límites desde el archivo de parámetros elegido.
    (   exists_file(ParamPath) ->
        consult(ParamPath)
    ;
        format(user_error, 'error: no se encuentra el archivo de parámetros: ~s~n', [ParamPath]),
        halt(1)
    ),
    % Carga el catálogo.
    cargar_catalogo(CatPath, Cat),
    (   Problema \== none ->
        (   find_problema(Cat, Problema, P) ->
            problema_nombre(P, Nombre),
            problema_rating(P, Rating),
            problema_tags(P, Tags),
            problema_enlace(P, Enlace),
            limite_por_rating(Rating, Limite),
            format('nombre: ~s~nrating: ~w~ntags: ~w~nenlace: ~s~nlimite: ~w~n', [Nombre, Rating, Tags, Enlace, Limite]),
            halt(0)
        ;
            format(user_error, 'error: problema no encontrado en el catálogo: ~s~n', [Problema]),
            halt(1)
        )
    ;
        resumen_catalogo(Cat, ConRating, SinRating, min_max(Min, Max)),
        format('problemas con rating: ~w~nexcluidos sin rating: ~w~nrating min: ~w~nrating max: ~w~n', [ConRating, SinRating, Min, Max]),
        halt(0)
    ).

% Subcomando `intentos`: lee el catalogo, el historial y deduce el veredicto
% de cada intento. Imprime una linea por intento: fecha, identificador,
% veredicto y, si es fallo, los motivos separados por coma.
cmd_intentos(Opts) :-
    parse_opts(Opts, KV),
    opt_default(catalogo, KV, 'datos/catalogo.json', CatPath0),
    opt_default(historial, KV, 'datos/historial.csv', HisPath0),
    opt_default(parametros, KV, 'config/parametros.pl', ParamPath0),
    resolve(CatPath0, CatPath),
    resolve(HisPath0, HisPath),
    resolve(ParamPath0, ParamPath),
    (   exists_file(ParamPath) ->
        consult(ParamPath)
    ;
        format(user_error, 'error: no se encuentra el archivo de parametros: ~s~n', [ParamPath]),
        halt(1)
    ),
    cargar_catalogo(CatPath, Cat),
    leer_historial(HisPath, Intentos),
    veredictos_de_intentos(Intentos, Cat, Veredictos),
    maplist(imprimir_veredicto, Veredictos),
    halt(0).

imprimir_veredicto(veredicto(Fecha, Problema, acierto, _Motivos)) :-
    format('~s, ~s, acierto~n', [Fecha, Problema]).
imprimir_veredicto(veredicto(Fecha, Problema, fallo, Motivos)) :-
    motivos_string(Motivos, MotivosStr),
    (   MotivosStr = "" ->
        format('~s, ~s, fallo~n', [Fecha, Problema])
    ;
        format('~s, ~s, fallo, ~s~n', [Fecha, Problema, MotivosStr])
    ).

% Subcomando `temas`: imprime, por cada tema seguido del catálogo, su estado,
% el número de intentos y si es trabajable.
cmd_temas(Opts) :-
    parse_opts(Opts, KV),
    opt_default(catalogo, KV, 'datos/catalogo.json', CatPath0),
    opt_default(historial, KV, 'datos/historial.csv', HisPath0),
    opt_default(prerrequisitos, KV, 'datos/prerrequisitos.csv', PrePath0),
    opt_default(parametros, KV, 'config/parametros.pl', ParamPath0),
    resolve(CatPath0, CatPath),
    resolve(HisPath0, HisPath),
    resolve(PrePath0, PrePath),
    resolve(ParamPath0, ParamPath),
    (   exists_file(ParamPath) ->
        consult(ParamPath)
    ;
        format(user_error, 'error: no se encuentra el archivo de parametros: ~s~n', [ParamPath]),
        halt(1)
    ),
    cargar_catalogo(CatPath, Cat),
    leer_prerrequisitos(PrePath, Pares),
    (   ciclo_prerrequisitos(Pares, Ciclo),
        Ciclo \== [] ->
        format(user_error, 'error: ciclo detectado en prerrequisitos: ~w~n', [Ciclo]),
        halt(1)
    ;   true
    ),
    leer_historial(HisPath, Intentos),
    temas_del_catalogo(Cat, Temas),
    maplist(tema_estado(Intentos, Cat), Temas, Estados),
    maplist(tema_info(Pares, Estados, Intentos, Cat), Temas, Infos),
    maplist(imprimir_info, Infos),
    halt(0).

tema_estado(Intentos, Cat, Tema, estado(Tema, Estado)) :-
    veredictos_por_tema(Tema, Intentos, Cat, Veredictos),
    estado_tema(Veredictos, Estado).

tema_info(Pares, Estados, Intentos, Cat, Tema, info(Tema, Estado, N, Trab)) :-
    member(estado(Tema, Estado), Estados),
    veredictos_por_tema(Tema, Intentos, Cat, Veredictos),
    length(Veredictos, N),
    (   tema_trabajable(Tema, Pares, Estados) -> Trab = "trabajable" ; Trab = "no trabajable" ).

imprimir_info(info(Tema, Estado, N, Trab)) :-
    format('~s: ~s, ~w intentos, ~s~n', [Tema, Estado, N, Trab]).

% Subcomando `candidatos`: imprime los problemas candidatos acotados.
% Opciones: --catalogo, --prerrequisitos, --historial, --resueltos, --parametros, --nivel (obligatorio).
cmd_candidatos(Opts) :-
    parse_opts(Opts, KV),
    (   member(nivel=NivelStr, KV) ->
        (   atom_number(NivelStr, Nivel) -> true
        ;   atom_string(NivelAtom, NivelStr),
            atom_number(NivelAtom, Nivel)
        )
    ;
        format(user_error, 'error: --nivel es obligatorio en el subcomando candidatos~n'),
        halt(1)
    ),
    opt_default(catalogo, KV, 'datos/catalogo.json', CatPath0),
    opt_default(prerrequisitos, KV, 'datos/prerrequisitos.csv', PrePath0),
    opt_default(historial, KV, 'datos/historial.csv', HisPath0),
    opt_default(resueltos, KV, 'datos/resueltos.txt', ResPath0),
    opt_default(parametros, KV, 'config/parametros.pl', ParamPath0),
    resolve(CatPath0, CatPath),
    resolve(PrePath0, PrePath),
    resolve(HisPath0, HisPath),
    resolve(ResPath0, ResPath),
    resolve(ParamPath0, ParamPath),
    (   exists_file(ParamPath) ->
        consult(ParamPath)
    ;
        format(user_error, 'error: no se encuentra el archivo de parametros: ~s~n', [ParamPath]),
        halt(1)
    ),
    leer_historial(HisPath, Intentos),
    cargar_catalogo(CatPath, Cat),
    leer_prerrequisitos(PrePath, Pares),
    (   ciclo_prerrequisitos(Pares, Ciclo),
        Ciclo \== [] ->
        format(user_error, 'error: ciclo detectado en prerrequisitos: ~w~n', [Ciclo]),
        halt(1)
    ;   true
    ),
    leer_resueltos_opcional(ResPath, Resueltos),
    get_time(T0),
    veredictos_de_intentos(Intentos, Cat, _Veredictos),
    temas_del_catalogo(Cat, TodosTemas),
    maplist(tema_estado(Intentos, Cat), TodosTemas, Estados),
    problemas_candidatos(Cat, Intentos, Resueltos, Pares, Estados, Nivel, Candidatos),
    get_time(T1),
    Ms is (T1 - T0) * 1000,
    maplist(imprimir_candidato, Candidatos),
    length(Candidatos, Total),
    format('total: ~w~nmilisegundos: ~w~n', [Total, Ms]),
    halt(0).

imprimir_candidato(candidato(Id, Rating, Minutos, Temas, _Grupo)) :-
    temas_string(Temas, TemasStr),
    format('~s ~w ~w ~s~n', [Id, Rating, Minutos, TemasStr]).

temas_string([], "").
temas_string(Temas, S) :-
    atomic_list_concat(Temas, ",", S).

% Subcomando `plan`: genera un plan de N días válido con restricciones CLP(FD).
% Opciones: --catalogo, --prerrequisitos, --historial, --resueltos,
%           --disponibilidad, --parametros, --nivel (obligatorio),
%           --hoy (obligatorio), --dias (opcional, usa dias_por_defecto).
cmd_plan(Opts) :-
    parse_opts(Opts, KV),
    (   member(nivel=NivelStr, KV) ->
        atom_number(NivelStr, Nivel)
    ;
        format(user_error, 'error: --nivel es obligatorio en el subcomando plan~n'),
        halt(1)
    ),
    (   member(hoy=Hoy, KV) ->
        true
    ;
        format(user_error, 'error: --hoy es obligatorio en el subcomando plan~n'),
        halt(1)
    ),
    opt_default(catalogo, KV, 'datos/catalogo.json', CatPath0),
    opt_default(prerrequisitos, KV, 'datos/prerrequisitos.csv', PrePath0),
    opt_default(historial, KV, 'datos/historial.csv', HisPath0),
    opt_default(resueltos, KV, 'datos/resueltos.txt', ResPath0),
    opt_default(disponibilidad, KV, 'datos/disponibilidad.csv', DispPath0),
    opt_default(parametros, KV, 'config/parametros.pl', ParamPath0),
    opt_default(dias, KV, none, DiasStr0),
    opt_default(salida, KV, none, SalidaStr0),
    resolve(CatPath0, CatPath),
    resolve(PrePath0, PrePath),
    resolve(HisPath0, HisPath),
    resolve(ResPath0, ResPath),
    resolve(DispPath0, DispPath),
    resolve(ParamPath0, ParamPath),
    (   exists_file(ParamPath) ->
        consult(ParamPath)
    ;
        format(user_error, 'error: no se encuentra el archivo de parametros: ~s~n', [ParamPath]),
        halt(1)
    ),
    (   DiasStr0 = none ->
        dias_por_defecto(Dias)
    ;
        atom_number(DiasStr0, Dias)
    ),
    cargar_catalogo(CatPath, Cat),
    leer_prerrequisitos(PrePath, Pares),
    (   ciclo_prerrequisitos(Pares, Ciclo),
        Ciclo \== [] ->
        format(user_error, 'error: ciclo detectado en prerrequisitos: ~w~n', [Ciclo]),
        halt(1)
    ;   true
    ),
    leer_historial(HisPath, Intentos),
    leer_resueltos_opcional(ResPath, Resueltos),
    leer_disponibilidad(DispPath, DisponibilidadLista),
    fechas_de_plan(Hoy, Dias, Fechas),
    maplist(verificar_fecha_disponible(DisponibilidadLista), Fechas),
    obtener_disponibles(Fechas, DisponibilidadLista, Disponibles),
    veredictos_de_intentos(Intentos, Cat, _Veredictos),
    temas_del_catalogo(Cat, TodosTemas),
    maplist(tema_estado(Intentos, Cat), TodosTemas, Estados),
    problemas_candidatos(Cat, Intentos, Resueltos, Pares, Estados, Nivel, Candidatos),
    construir_plan(Dias, Fechas, Disponibles, Candidatos, PlanDias),
    maplist(imprimir_dia(Cat, Estados), PlanDias),
    (   SalidaStr0 = none ->
        true
    ;
        atom_number(SalidaStr0, Salida),
        escribir_plan(Hoy, Nivel, Dias, PlanDias, Candidatos, Cat, Estados, SalidaStr0)
    ),
    halt(0).

obtener_disponibles([], _, []).
obtener_disponibles([Fecha|Fechas], Disponibilidad, [Minutos|Rest]) :-
    minutos_de_fecha(Fecha, Disponibilidad, Minutos),
    obtener_disponibles(Fechas, Disponibilidad, Rest).

imprimir_dia(Cat, Estados, dia(Dia, Fecha, Disponible, Carga, Items)) :-
    format('Día ~w (~s): ~w/~w minutos~n', [Dia, Fecha, Carga, Disponible]),
    (   Items = [] ->
        format('  (sin problemas)~n')
    ;
        maplist(imprimir_item(Cat, Estados), Items)
    ).

imprimir_item(Cat, Estados, candidato(Id, Rating, Minutos, _Temas, _Grupo)) :-
    find_problema(Cat, Id, P),
    problema_nombre(P, Nombre),
    problema_enlace(P, Enlace),
    motivo_de_item(Cat, Estados, Id, Motivo),
    format('  ~s ~s ~w ~w ~s~n    ~s~n', [Id, Nombre, Rating, Minutos, Enlace, Motivo]).

verificar_fecha_disponible(Disponibilidad, Fecha) :-
    (   member(Fecha-_ , Disponibilidad) -> true
    ;
        format(user_error, 'error: fecha ~s no encontrada en el archivo de disponibilidad~n', [Fecha]),
        halt(1)
    ).

motivo_de_item(Cat, Estados, Id, Motivo) :-
    find_problema(Cat, Id, P),
    problema_tags(P, Tags),
    temas_ignorados_lista(Ignorados),
    maplist(string_to_atom, Tags, TagsAtom),
    maplist(string_to_atom, Ignorados, IgnoradosAtom),
    include(tema_no_ignorado(IgnoradosAtom), TagsAtom, Temas),
    sort(Temas, TemasOrd),
    maplist(estado_de_tema(Estados), TemasOrd, EstadosTema),
    pares_tema_estado(EstadosTema, Pares),
    atomic_list_concat(Pares, ", ", ParesStr),
    atom_concat("Temas: ", ParesStr, Motivo).

estado_de_tema(Estados, Tema, estado(Tema, Estado)) :-
    member(estado(Tema, Estado), Estados).

pares_tema_estado([], []).
pares_tema_estado([estado(Tema, Estado)|Rest], [Par|RestPares]) :-
    atom_concat(Tema, "=", Par1),
    atom_concat(Par1, Estado, Par),
    pares_tema_estado(Rest, RestPares).


