:- module(symac_distro_repair,
    [ repair_facts/5,
      safe_repair/4
    ]).

:- use_module(schema).
:- use_module(agent).

repair_facts(Facts0, Host, Diagnostic, Facts, Repair) :-
    validate_facts(Facts0),
    safe_repair(Facts0, Host, Diagnostic, Repair),
    apply_repair(Repair, Facts0, Host, Facts1),
    canonical_facts(Facts1, Facts),
    validate_facts(Facts).

safe_repair(_, _, Diagnostic, Repair) :-
    repair_rule(Diagnostic, Repair),
    !.
safe_repair(_, _, Diagnostic, _) :-
    throw(error(existence_error(safe_repair, Diagnostic), _)).

repair_rule(diagnostic(nix, undefined_attribute, "swiProlog"),
            backend_package(nix, swi_prolog, "swi-prolog")).
repair_rule(diagnostic(nix, missing_attribute, "swiProlog"),
            backend_package(nix, swi_prolog, "swi-prolog")).
repair_rule(diagnostic(nix, undefined_attribute, "nixfmt-rfc-style"),
            backend_package(nix, nixfmt, "nixfmt")).
repair_rule(diagnostic(guix, unknown_package, "swipl"),
            backend_package(guix, swi_prolog, "swi-prolog")).

apply_repair(backend_package(Backend, Logical, Name), Facts0, _, Facts) :-
    exclude(backend_mapping_for(Backend, Logical), Facts0, Rest),
    Facts = [backend_package(Backend, Logical, Name)|Rest].

backend_mapping_for(Backend, Logical,
                    backend_package(Backend, Logical, _)).
