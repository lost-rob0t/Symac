:- module(symac_distro_schema,
    [ read_fact_file/2,
      read_fact_stream/2,
      validate_facts/1
    ]).

:- use_module(library(error)).
:- use_module(library(lists)).

read_fact_file(Path, Facts) :-
    setup_call_cleanup(
        open(Path, read, Stream, [encoding(utf8)]),
        read_fact_stream(Stream, Facts),
        close(Stream)).

read_fact_stream(Stream, Facts) :-
    read_term(Stream, Term, [syntax_errors(error)]),
    ( Term == end_of_file ->
        Facts = []
    ; Facts = [Term|Rest],
      read_fact_stream(Stream, Rest)
    ).

validate_facts(Facts) :-
    must_be(list, Facts),
    maplist(validate_ground_fact, Facts),
    findall(Host, member(host(Host), Facts), Hosts0),
    sort(Hosts0, Hosts),
    ( Hosts == [] ->
        throw(error(existence_error(symac_distro_host, host), _))
    ; true
    ),
    maplist(validate_host_reference(Hosts), Facts),
    maplist(validate_backend_uniqueness(Facts), Hosts),
    validate_backend_package_uniqueness(Facts),
    maplist(validate_secret_policy, Facts).

validate_ground_fact(Fact) :-
    ( ground(Fact) ->
        true
    ; throw(error(instantiation_error, Fact))
    ),
    ( valid_fact(Fact) ->
        true
    ; throw(error(domain_error(symac_distro_fact, Fact), _))
    ).

valid_fact(host(Host)) :-
    atom(Host).
valid_fact(backend(Host, Backend)) :-
    atom(Host),
    memberchk(Backend, [auto, nix, guix]).
valid_fact(package(Host, Package)) :-
    atom(Host),
    atom(Package).
valid_fact(service(Host, Service, State)) :-
    atom(Host),
    atom(Service),
    state(State).
valid_fact(feature(Host, Feature, State)) :-
    atom(Host),
    atom(Feature),
    state(State).
valid_fact(role(Host, Role)) :-
    atom(Host),
    atom(Role).
valid_fact(role_package(Role, Package)) :-
    atom(Role),
    atom(Package).
valid_fact(role_service(Role, Service, State)) :-
    atom(Role),
    atom(Service),
    state(State).
valid_fact(session_variable(Host, Key, Value)) :-
    atom(Host),
    textish(Key),
    textish(Value).
valid_fact(secret_source(Host, Name, Source)) :-
    atom(Host),
    textish(Name),
    valid_secret_source(Source).
valid_fact(prefers(Host, Preference)) :-
    atom(Host),
    atom(Preference).
valid_fact(requires(Host, Capability)) :-
    atom(Host),
    atom(Capability).
valid_fact(backend_package(Backend, Logical, Name)) :-
    memberchk(Backend, [nix, guix]),
    atom(Logical),
    textish(Name).

state(enabled).
state(disabled).

textish(Value) :- atom(Value), !.
textish(Value) :- string(Value), !.
textish(Value) :- number(Value).

valid_secret_source(environment(Name)) :- textish(Name).
valid_secret_source(wallet(Name)) :- textish(Name).
valid_secret_source(auth_source(Name)) :- textish(Name).

validate_host_reference(Hosts, Fact) :-
    ( fact_host(Fact, Host) ->
        ( memberchk(Host, Hosts) ->
            true
        ; throw(error(existence_error(symac_distro_host, Host), Fact))
        )
    ; true
    ).

fact_host(backend(Host, _), Host).
fact_host(package(Host, _), Host).
fact_host(service(Host, _, _), Host).
fact_host(feature(Host, _, _), Host).
fact_host(role(Host, _), Host).
fact_host(session_variable(Host, _, _), Host).
fact_host(secret_source(Host, _, _), Host).
fact_host(prefers(Host, _), Host).
fact_host(requires(Host, _), Host).

validate_backend_uniqueness(Facts, Host) :-
    findall(Backend, member(backend(Host, Backend), Facts), Backends0),
    sort(Backends0, Backends),
    ( Backends = [] ->
        true
    ; Backends = [_] ->
        true
    ; throw(error(permission_error(select, multiple_backends, Host-Backends), _))
    ).

validate_backend_package_uniqueness(Facts) :-
    findall(Backend-Logical,
            member(backend_package(Backend, Logical, _), Facts),
            Keys0),
    sort(Keys0, Keys),
    maplist(validate_backend_package_key(Facts), Keys).

validate_backend_package_key(Facts, Backend-Logical) :-
    findall(Name,
            member(backend_package(Backend, Logical, Name), Facts),
            Names0),
    sort(Names0, Names),
    ( Names = [_] ->
        true
    ; throw(error(permission_error(map, backend_package, Backend-Logical-Names), _))
    ).

validate_secret_policy(session_variable(_, Key, _)) :-
    sensitive_name(Key),
    !,
    throw(error(permission_error(store, secret_value, Key),
                'Use secret_source/3 with environment, wallet, or auth_source instead.')).
validate_secret_policy(_).

sensitive_name(Key) :-
    text_to_string(Key, String),
    string_upper(String, Upper),
    member(Fragment, ["TOKEN", "PASSWORD", "SECRET", "API_KEY", "PRIVATE_KEY"]),
    sub_string(Upper, _, _, _, Fragment),
    !.

text_to_string(Value, String) :-
    ( string(Value) ->
        String = Value
    ; atom(Value) ->
        atom_string(Value, String)
    ; number_string(Value, String)
    ).
