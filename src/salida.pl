% Salida del plan en formato máquina (JSON) con motivo en cada ítem.
% Usa library(json) para serializar el plan a un archivo.

:- use_module(library(lists)).
:- use_module(library(json)).

% escribir_plan(+Hoy, +Nivel, +Dias, +PlanDias, +Candidatos, +Cat, +Estados, +Ruta)
%   Escribe el plan en formato JSON en la ruta indicada.
%   El archivo se escribe completo o no se escribe.
escribir_plan(Hoy, Nivel, Dias, PlanDias, Candidatos, Cat, Estados, Ruta) :-
    plan_a_json(Hoy, Nivel, PlanDias, Candidatos, Cat, Estados, JsonTerm),
    (   existe_directorio_padre(Ruta) ->
        open(Ruta, write, Out),
        json_write(Out, JsonTerm, [width(0)]),
        close(Out)
    ;
        format(user_error, 'error: no se encuentra la carpeta de salida: ~s~n', [Ruta]),
        halt(1)
    ).

% Verifica que el directorio padre de la ruta exista.
existe_directorio_padre(Ruta) :-
    file_directory_name(Ruta, Dir),
    (   Dir = '', Dir = '.' -> true
    ;   exists_directory(Dir)
    ).

% Construye el término JSON del plan completo (diccionario nativo).
plan_a_json(Hoy, Nivel, PlanDias, Candidatos, Cat, Estados, Dict) :-
    maplist(dia_a_json(Candidatos, Cat, Estados), PlanDias, DiasJson),
    dict_create(Dict, json, [hoy=Hoy, nivel=Nivel, dias=DiasJson]).

% Construye el término JSON de un día (diccionario nativo).
dia_a_json(Candidatos, Cat, Estados, dia(Dia, Fecha, Disponible, Carga, Items), Dict) :-
    maplist(item_a_json(Candidatos, Cat, Estados), Items, ItemsJson),
    dict_create(Dict, json, [dia=Dia, fecha=Fecha, disponible=Disponible, carga=Carga, items=ItemsJson]).

% Construye el término JSON de un ítem (diccionario nativo).
item_a_json(Candidatos, Cat, Estados, candidato(Id, _Rating, Minutos, _Temas, _Grupo), Dict) :-
    find_problema(Cat, Id, P),
    problema_nombre(P, Nombre),
    problema_enlace(P, Enlace),
    problema_rating(P, Rating),
    problema_tags(P, Tags),
    motivo_de_item(Tags, Estados, Motivo),
    dict_create(Dict, json, [problema=Id, nombre=Nombre, enlace=Enlace, rating=Rating, tags=Tags, tipo=nuevo, minutos=Minutos, motivo=Motivo]).

% Construye el motivo de un ítem (formato: "Temas: tema=estado, ..." o "(sin_tema)").
motivo_de_item(Tags, Estados, Motivo) :-
    temas_ignorados_lista(Ignorados),
    maplist(string_to_atom, Tags, TagsAtom),
    maplist(string_to_atom, Ignorados, IgnoradosAtom),
    include(tema_no_ignorado(IgnoradosAtom), TagsAtom, TemasSeguidos),
    % Solo se reportan temas que tienen estado registrado; un tema sin estado
    % se omite (nunca falla, para evitar que el planificador se buclee).
    include(tema_tiene_estado(Estados), TemasSeguidos, TemasConEstado),
    (   TemasConEstado = [] ->
        Motivo = '(sin_tema)'
    ;
        maplist(tema_estado_str(Estados), TemasConEstado, EstadoStrs),
        lista_a_string(EstadoStrs, MotivoStr),
        atom_concat('Temas: ', MotivoStr, Motivo)
    ).

% Cierto si Tema tiene un estado registrado en Estados.
tema_tiene_estado(Estados, Tema) :-
    member(estado(Tema, _), Estados).

tema_estado_str(Estados, Tema, TemaEstadoStr) :-
    member(estado(Tema, Estado), Estados),
    !,
    atom_concat(Tema, '=', TemaEstadoStr).

lista_a_string([], '').
lista_a_string([H|T], S) :-
    lista_a_string(T, ST),
    (   ST = '' -> S = H
    ;   atom_concat(H, ', ', S1),
        atom_concat(S1, ST, S)
    ).
