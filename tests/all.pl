% Arnés de pruebas del proyecto CPTrainPlan.
% Carga todos los módulos de prueba.
:- initialization(run_tests, main).

:- use_module(library(plunit)).

% Módulos bajo prueba (F0-01) y hechos auxiliares.
dummy.
:- consult('src/catalogo.pl').
:- consult('src/limites.pl').
:- consult('config/parametros.pl').
:- consult('src/historial.pl').
:- consult('src/fallo.pl').
:- consult('src/prerrequisitos.pl').
:- consult('src/temas.pl').
:- consult('src/candidatos.pl').

:- consult('tests/test_catalogo.pl').
:- consult('tests/test_fallo.pl').
:- consult('tests/test_temas.pl').
:- consult('tests/test_candidatos.pl').

run_tests :- plunit:run_tests.
