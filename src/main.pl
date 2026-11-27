% Punto de entrada del proyecto CPTrainPlan.
% Uso: swipl src/main.pl <subcomando> <opciones>
% Subcomando F0: catalogo (--catalogo, --problema, --parametros).
% Las rutas de config/ y datos/ se resuelven desde la raíz del proyecto.
% Todo error escribe en stderr una línea que empieza por 'error:' y termina con código 1.
% Éxito termina con código 0, sin dejar el intérprete interactivo.

:- use_module(library(lists)).
:- use_module(library(json)).

dummy.

% Carga los módulos de catálogo y límites una sola vez al iniciar.
:- initialization((
    project_root(Root),
    atom_concat(Root, "/", Pre),
    atom_concat(Pre, "src/catalogo.pl", CatSrc),
    atom_concat(Pre, "src/limites.pl", LimSrc),
    consult(CatSrc),
    consult(LimSrc)
)).

:- initialization(main).

main :-
    current_prolog_flag(argv, Argv),
    dispatch(Argv).

dispatch([]) :-
    format(user_error, 'error: se espera un subcomando: catalogo~n'),
    halt(1).
dispatch([Sub|Opts]) :-
    (   Sub = catalogo -> cmd_catalogo(Opts)
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
