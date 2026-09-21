:- module(symac_distro_agent,
    [ apply_action/4,
      apply_actions/4,
      canonical_facts/2,
      write_fact_file/2
    ]).

:- use_module(library(error)).
:- use_module(library(lists)).
:- use_module(schema).

apply_actions(Facts0, Host, Actions, Facts) :-
    must_be(list, Actions),
    foldl(apply_action_for(Host), Actions, Facts0, Facts),
    validate_facts(Facts).

apply_action_for(Host, Action, Facts0, Facts) :-
    apply_action(Facts0, Host, Action, Facts).

apply_action(Facts0, Host, Action, Facts) :-
    validate_facts(Facts0),
    require_host(Facts0, Host),
    action_update(Action, Facts0, Host, Facts1),
    canonical_facts(Facts1, Facts),
    validate_facts(Facts).

action_update(ensure_package(Package), Facts0, Host, Facts) :-
    must_be(atom, Package),
    add_unique(package(Host, Package), Facts0, Facts).
action_update(remove_package(Package), Facts0, Host, Facts) :-
    must_be(atom, Package),
    exclude(==(package(Host, Package)), Facts0, Facts).
action_update(set_service(Service, State), Facts0, Host, Facts) :-
    must_be(atom, Service),
    state(State),
    replace_matching(service(Host, Service, _),
                     service(Host, Service, State), Facts0, Facts).
action_update(set_feature(Feature, State), Facts0, Host, Facts) :-
    must_be(atom, Feature),
    state(State),
    replace_matching(feature(Host, Feature, _),
                     feature(Host, Feature, State), Facts0, Facts).
action_update(set_backend(Backend), Facts0, Host, Facts) :-
    memberchk(Backend, [auto, nix, guix]),
    replace_matching(backend(Host, _), backend(Host, Backend), Facts0, Facts).
action_update(prefer(Preference), Facts0, Host, Facts) :-
    must_be(atom, Preference),
    add_unique(prefers(Host, Preference), Facts0, Facts).
action_update(require(Capability), Facts0, Host, Facts) :-
    must_be(atom, Capability),
    add_unique(requires(Host, Capability), Facts0, Facts).
action_update(set_session_variable(Key, Value), Facts0, Host, Facts) :-
    replace_matching(session_variable(Host, Key, _),
                     session_variable(Host, Key, Value), Facts0, Facts).
action_update(set_secret_source(Name, Source), Facts0, Host, Facts) :-
    replace_matching(secret_source(Host, Name, _),
                     secret_source(Host, Name, Source), Facts0, Facts).
action_update(Action, _, _, _) :-
    throw(error(domain_error(symac_distro_agent_action, Action), _)).

state(enabled).
state(disabled).

require_host(Facts, Host) :-
    ( memberchk(host(Host), Facts) ->
        true
    ; throw(error(existence_error(symac_distro_host, Host), _))
    ).

add_unique(Fact, Facts, Facts) :-
    memberchk(Fact, Facts),
    !.
add_unique(Fact, Facts, [Fact|Facts]).

replace_matching(Pattern, Replacement, Facts0, Facts) :-
    exclude(matches(Pattern), Facts0, Rest),
    Facts = [Replacement|Rest].

matches(Pattern, Fact) :-
    copy_term(Pattern, Copy),
    Copy = Fact.

canonical_facts(Facts0, Facts) :-
    sort(Facts0, Facts).

write_fact_file(Path, Facts0) :-
    validate_facts(Facts0),
    canonical_facts(Facts0, Facts),
    setup_call_cleanup(
        open(Path, write, Stream, [encoding(utf8)]),
        forall(member(Fact, Facts),
               write_term(Stream, Fact,
                          [ quoted(true),
                            fullstop(true),
                            nl(true)
                          ])),
        close(Stream)).
