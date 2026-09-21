:- module(symac_distro_cli, [main/0]).

:- use_module(schema).
:- use_module(compiler).
:- use_module(render).

:- initialization(main, main).

main :-
    current_prolog_flag(argv, Argv),
    catch(dispatch(Argv), Error, fail_with(Error)).

dispatch(["check", Path]) :-
    !,
    read_fact_file(Path, Facts),
    validate_facts(Facts),
    format("ok ~w facts=~d~n", [Path, len(Facts)]).
dispatch(["plan", Path, Host0]) :-
    !,
    atom_string(Host, Host0),
    read_fact_file(Path, Facts),
    compile_host(Facts, Host, IR),
    write_term(IR, [quoted(true), portray(true)]),
    nl.
dispatch(["render", Backend0, Path, Host0]) :-
    !,
    atom_string(Backend, Backend0),
    atom_string(Host, Host0),
    memberchk(Backend, [nix, guix]),
    read_fact_file(Path, Facts0),
    override_backend(Facts0, Host, Backend, Facts),
    compile_host(Facts, Host, IR),
    render_ir(IR, Text),
    format("~s", [Text]).
dispatch(_) :-
    usage,
    halt(64).

fail_with(Error) :-
    print_message(error, Error),
    halt(1).

usage :-
    format(user_error,
           "usage: symac-distro check FACTS | plan FACTS HOST | render (nix|guix) FACTS HOST~n",
           []).

len(List, Length) :-
    length(List, Length).
