% Arnés de pruebas del proyecto CPTrainPlan.
% Carga todos los módulos de prueba.
:- initialization(run_tests, main).

:- use_module(library(plunit)).

% Módulos bajo prueba (F0-01) y hechos auxiliares.
dummy.
:- consult('src/catalogo.pl').
:- consult('src/limites.pl').
:- consult('config/parametros.pl').

:- consult('tests/test_catalogo.pl').

run_tests :- plunit:run_tests.
