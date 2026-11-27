% Estado de tema y tema trabajable.
% Estados: sin_datos, debil, en_progreso, dominado.
% Un tema es trabajable si todos sus ancestros (prerrequisitos directos e
% indirectos) están cubiertos (dominado o en_progreso); un tema sin ancestros
% siempre es trabajable.

:- use_module(library(lists)).

% Carga los parámetros de estado desde el archivo de parámetros (consultado).
ventana_estado_param(N) :- ventana_estado(N).
debil_min_param(N) :- debil_min_intentos(N).
debil_pct_param(P) :- debil_pct_fallos(P).
dominado_min_param(N) :- dominado_min_intentos(N).
dominado_max_param(N) :- dominado_max_fallos(N).

% Estado de un tema a partir de sus veredictos ordenados (más antiguo primero).
estado_tema(Veredictos, Estado) :-
    length(Veredictos, Total),
    (   Total = 0 -> Estado = sin_datos
    ;   es_debil(Veredictos) -> Estado = debil
    ;   es_dominado(Veredictos) -> Estado = dominado
    ;   Estado = en_progreso
    ).

% Últimos N intentos del tema (ventana), o todos si hay menos.
ventana_estado_lista(Veredictos, Ventana) :-
    ventana_estado_param(N),
    length(Veredictos, L),
    (   L =< N -> Ventana = Veredictos
    ;   append(_, Ventana, Veredictos),
        length(Ventana, N)
    ).

es_debil(Veredictos) :-
    debil_min_param(Min),
    length(Veredictos, Total),
    Total >= Min,
    ventana_estado_lista(Veredictos, Ventana),
    fallos_en(Ventana, NF),
    length(Ventana, NV),
    debil_pct_param(P),
    NF * 100 >= P * NV.
es_debil(Veredictos) :-
    debil_min_param(Min),
    length(Veredictos, Total),
    Total >= Min,
    dos_ultimos_fallos(Veredictos).

fallos_en([], 0).
fallos_en([fallo|T], N) :- !, fallos_en(T, N1), N is N1 + 1.
fallos_en([_|T], N) :- fallos_en(T, N).

dos_ultimos_fallos(Veredictos) :-
    append(_, [fallo, fallo], Veredictos).

es_dominado(Veredictos) :-
    dominado_min_param(Min),
    length(Veredictos, Total),
    Total >= Min,
    ventana_estado_lista(Veredictos, Ventana),
    fallos_en(Ventana, NF),
    dominado_max_param(Max),
    NF =< Max,
    ultimo_veredicto(Veredictos, acierto).

ultimo_veredicto([V], V).
ultimo_veredicto([_|T], V) :- ultimo_veredicto(T, V).

% Tema cubierto: dominado o en_progreso.
tema_cubierto(dominado).
tema_cubierto(en_progreso).

% Ancestros de un tema (delegado a prerrequisitos.pl).
tema_ancestros(Tema, Pares, Ancestros) :- ancestros(Tema, Pares, Ancestros).

% Un tema es trabajable si todos sus ancestros están cubiertos.
tema_trabajable(Tema, Pares, Estados) :-
    tema_ancestros(Tema, Pares, Ancestros),
    (   Ancestros = [] -> true
    ;   maplist(ancestro_cubierto(Estados), Ancestros)
    ).

ancestro_cubierto(Estados, Ancestro) :-
    member(estado(Ancestro, E), Estados),
    tema_cubierto(E).

% Lista de temas del catálogo (tags menos ignorados), ordenados alfabéticamente,
% sin duplicados.
temas_del_catalogo(Catalogo, Temas) :-
    problemas_lista(Catalogo, Lista),
    maplist(problema_tags, Lista, TagListas),
    append(TagListas, Todos),
    temas_ignorados_lista(Ignorados),
    include(tema_no_ignorado(Ignorados), Todos, Filtrados),
    list_to_set(Filtrados, Temas).

tema_no_ignorado(Ignorados, Tema) :-
    \+ member(Tema, Ignorados).

temas_ignorados_lista(Ignorados) :-
    findall(T, temas_ignorados(T), Ignorados).

% El problema (por identificador) tiene el tema entre sus tags seguidos.
problema_tiene_tema(Catalogo, ProblemaId, Tema) :-
    find_problema(Catalogo, ProblemaId, P),
    problema_tags(P, Tags),
    temas_ignorados_lista(Ignorados),
    \+ member(Tema, Ignorados),
    member(Tema, Tags).

% Veredictos (ordenados por fecha y línea) de los intentos de un tema.
veredictos_por_tema(Tema, Intentos, Catalogo, Veredictos) :-
    include(intento_de_tema(Tema, Catalogo), Intentos, Filtrados),
    maplist(veredicto_de_intento_intento(Catalogo), Filtrados, Veredictos).

intento_de_tema(Tema, Catalogo, Intento) :-
    intento_problema(Intento, ProblemaId),
    problema_tiene_tema(Catalogo, ProblemaId, Tema).

veredicto_de_intento_intento(Catalogo, Intento, Veredicto) :-
    veredicto_intento(Intento, Catalogo, Veredicto, _).

% Veredictos de un intento (delega en fallo.pl).
veredicto_de_intento(Intento, Catalogo, Veredicto) :-
    veredicto_intento(Intento, Catalogo, Veredicto, _Motivos).
