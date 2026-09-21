:- begin_tests(symac_distro).

:- use_module(schema).
:- use_module(compiler).
:- use_module(render).
:- use_module(agent).
:- use_module(diagnostics).
:- use_module(repair).

base_facts([
    host(workstation),
    backend(workstation, auto),
    role(workstation, developer),
    role_package(developer, git),
    role_package(developer, fd),
    feature(workstation, prolog, enabled),
    feature(workstation, common_lisp, enabled),
    feature(workstation, search, enabled),
    service(workstation, openssh, enabled),
    session_variable(workstation, "STAR_PROFILE", "developer"),
    secret_source(workstation, "OPENROUTER_API_KEY",
                  environment("OPENROUTER_API_KEY"))
]).

test(data_only_reader_rejects_rules,
     [throws(error(domain_error(symac_distro_fact, _), _))]) :-
    open_string("host(x).\nfoo :- bar.\n", Stream),
    call_cleanup(read_fact_stream(Stream, Facts), close(Stream)),
    validate_facts(Facts).

test(secret_values_fail_closed,
     [throws(error(permission_error(store, secret_value, _), _))]) :-
    validate_facts([
        host(x),
        session_variable(x, "OPENROUTER_API_KEY", "plaintext")
    ]).

test(auto_backend_defaults_to_nix) :-
    base_facts(Facts),
    compile_host(Facts, workstation,
                 distro_ir(workstation, nix, _, _, _, _, _, _)).

test(auto_backend_can_choose_guix) :-
    base_facts(Facts0),
    select(backend(workstation, auto), Facts0, Facts1),
    Facts = [prefers(workstation, fully_free_system),
             backend(workstation, auto)|Facts1],
    compile_host(Facts, workstation,
                 distro_ir(workstation, guix, _, _, _, _, _, _)).

test(nix_requirement_beats_free_preference) :-
    base_facts(Facts0),
    Facts = [prefers(workstation, fully_free_system),
             requires(workstation, proprietary_nvidia)|Facts0],
    compile_host(Facts, workstation,
                 distro_ir(workstation, nix, _, _, _, _, _, _)).

test(features_and_roles_derive_packages) :-
    base_facts(Facts),
    compile_host(Facts, workstation,
                 distro_ir(_, _, Packages, _, _, _, _, _)),
    memberchk(package(git, "git"), Packages),
    memberchk(package(fd, "fd"), Packages),
    memberchk(package(swi_prolog, "swi-prolog"), Packages),
    memberchk(package(sbcl, "sbcl"), Packages),
    memberchk(package(ripgrep, "ripgrep"), Packages).

test(nix_render_is_deterministic_and_secret_safe) :-
    base_facts(Facts),
    compile_host(Facts, workstation, IR),
    render_ir(IR, Text),
    once(sub_string(Text, _, _, _, "environment.systemPackages")),
    once(sub_string(Text, _, _, _, "\"swi-prolog\"")),
    once(sub_string(Text, _, _, _, "services.openssh.enable = true;")),
    once(sub_string(Text, _, _, _, "\"STAR_PROFILE\" = \"developer\";")),
    once(sub_string(Text, _, _, _, "OPENROUTER_API_KEY <- environment")),
    \+ sub_string(Text, _, _, _, "plaintext").

test(guix_render_uses_same_semantic_facts) :-
    base_facts(Facts0),
    override_backend(Facts0, workstation, guix, Facts),
    compile_host(Facts, workstation, IR),
    render_ir(IR, Text),
    once(sub_string(Text, _, _, _, "specification->package")),
    once(sub_string(Text, _, _, _, "\"swi-prolog\"")),
    once(sub_string(Text, _, _, _, "(service openssh-service-type)")),
    once(sub_string(Text, _, _, _, "%symac-environment")).

test(custom_backend_package_is_fact_driven) :-
    base_facts(Facts0),
    Facts = [package(workstation, custom_tool),
             backend_package(nix, custom_tool, "myCustomTool")|Facts0],
    compile_host(Facts, workstation,
                 distro_ir(_, nix, Packages, _, _, _, _, _)),
    memberchk(package(custom_tool, "myCustomTool"), Packages).

test(unknown_backend_package_fails_closed,
     [throws(error(existence_error(backend_package, nix-unknown_pkg), _))]) :-
    base_facts(Facts0),
    Facts = [package(workstation, unknown_pkg)|Facts0],
    compile_host(Facts, workstation, _).


test(agent_ensure_package_is_idempotent) :-
    base_facts(Facts0),
    apply_action(Facts0, workstation, ensure_package(emacs), Facts1),
    apply_action(Facts1, workstation, ensure_package(emacs), Facts2),
    findall(emacs, member(package(workstation, emacs), Facts2), Matches),
    Matches = [emacs].

test(agent_replaces_feature_state) :-
    base_facts(Facts0),
    apply_action(Facts0, workstation,
                 set_feature(prolog, disabled), Facts),
    memberchk(feature(workstation, prolog, disabled), Facts),
    \+ memberchk(feature(workstation, prolog, enabled), Facts).

test(agent_secret_value_still_fails_closed,
     [throws(error(permission_error(store, secret_value, _), _))]) :-
    base_facts(Facts0),
    apply_action(Facts0, workstation,
                 set_session_variable("API_TOKEN", "plaintext"), _).

test(nix_diagnostic_normalizes) :-
    normalize_diagnostic(nix,
                         "error: undefined variable 'swiProlog'",
                         diagnostic(nix, undefined_attribute, "swiProlog")).

test(guix_diagnostic_normalizes) :-
    normalize_diagnostic(guix,
                         "guix package: error: unknown package: swipl",
                         diagnostic(guix, unknown_package, "swipl")).

test(repair_expert_rewrites_known_nix_alias) :-
    base_facts(Facts0),
    repair_facts(Facts0, workstation,
                 diagnostic(nix, undefined_attribute, "swiProlog"),
                 Facts, Repair),
    Repair = backend_package(nix, swi_prolog, "swi-prolog"),
    memberchk(backend_package(nix, swi_prolog, "swi-prolog"), Facts),
    compile_host(Facts, workstation,
                 distro_ir(_, nix, Packages, _, _, _, _, _)),
    memberchk(package(swi_prolog, "swi-prolog"), Packages).

test(unknown_diagnostic_has_no_automatic_repair,
     [throws(error(existence_error(safe_repair, _), _))]) :-
    base_facts(Facts),
    normalize_diagnostic(nix, "some new failure",
                         Diagnostic),
    repair_facts(Facts, workstation, Diagnostic, _, _).

:- end_tests(symac_distro).
