:- module(symac_distro_cli, [main/0]).

:- use_module(schema).
:- use_module(compiler).
:- use_module(render).
:- use_module(agent).
:- use_module(diagnostics).
:- use_module(repair).

:- initialization(main, main).

main :-
    current_prolog_flag(argv, Argv),
    catch(dispatch(Argv), Error, fail_with(Error)).

dispatch([check, Path]) :-
    !,
    read_fact_file(Path, Facts),
    validate_facts(Facts),
    length(Facts, Count),
    format("ok ~w facts=~d~n", [Path, Count]).
dispatch([plan, Path, Host]) :-
    !,
    read_fact_file(Path, Facts),
    compile_host(Facts, Host, IR),
    write_term(IR, [quoted(true), portray(true)]),
    nl.
dispatch([render, Backend, Path, Host]) :-
    !,
    memberchk(Backend, [nix, guix]),
    read_fact_file(Path, Facts0),
    override_backend(Facts0, Host, Backend, Facts),
    compile_host(Facts, Host, IR),
    render_ir(IR, Text),
    format("~s", [Text]).
dispatch([agent, Path, Host, Verb, Arg, Output]) :-
    !,
    agent_action(Verb, Arg, Action),
    run_agent(Path, Host, Action, Output).
dispatch([agent, Path, Host, set-variable, Key, Value, Output]) :-
    !,
    run_agent(Path, Host, set_session_variable(Key, Value), Output).
dispatch([agent, Path, Host, secret-env, Name, EnvName, Output]) :-
    !,
    run_agent(Path, Host,
              set_secret_source(Name, environment(EnvName)), Output).
dispatch([repair, Backend, Path, Host, DiagnosticPath, Output]) :-
    !,
    memberchk(Backend, [nix, guix]),
    read_fact_file(Path, Facts0),
    normalize_diagnostic_file(Backend, DiagnosticPath, Diagnostic),
    repair_facts(Facts0, Host, Diagnostic, Facts, Repair),
    write_fact_file(Output, Facts),
    format("repair=~q diagnostic=~q output=~w~n",
           [Repair, Diagnostic, Output]).
dispatch(_) :-
    usage,
    halt(64).

run_agent(Path, Host, Action, Output) :-
    read_fact_file(Path, Facts0),
    apply_action(Facts0, Host, Action, Facts),
    write_fact_file(Output, Facts),
    format("action=~q output=~w~n", [Action, Output]).

agent_action(ensure-package, Package, ensure_package(Package)).
agent_action(remove-package, Package, remove_package(Package)).
agent_action(enable-feature, Feature, set_feature(Feature, enabled)).
agent_action(disable-feature, Feature, set_feature(Feature, disabled)).
agent_action(enable-service, Service, set_service(Service, enabled)).
agent_action(disable-service, Service, set_service(Service, disabled)).
agent_action(backend, Backend, set_backend(Backend)).
agent_action(prefer, Preference, prefer(Preference)).
agent_action(require, Capability, require(Capability)).
agent_action(Verb, _, _) :-
    throw(error(domain_error(symac_distro_agent_verb, Verb), _)).

fail_with(Error) :-
    print_message(error, Error),
    halt(1).

usage :-
    format(user_error,
"usage:
  symac-distro check FACTS
  symac-distro plan FACTS HOST
  symac-distro render (nix|guix) FACTS HOST
  symac-distro agent FACTS HOST ensure-package PACKAGE OUT
  symac-distro agent FACTS HOST remove-package PACKAGE OUT
  symac-distro agent FACTS HOST (enable-feature|disable-feature) FEATURE OUT
  symac-distro agent FACTS HOST (enable-service|disable-service) SERVICE OUT
  symac-distro agent FACTS HOST backend (auto|nix|guix) OUT
  symac-distro agent FACTS HOST (prefer|require) VALUE OUT
  symac-distro agent FACTS HOST set-variable KEY VALUE OUT
  symac-distro agent FACTS HOST secret-env NAME ENV_NAME OUT
  symac-distro repair (nix|guix) FACTS HOST DIAGNOSTIC_LOG OUT~n",
           []).
