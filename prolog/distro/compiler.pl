:- module(symac_distro_compiler,
    [ compile_host/3,
      choose_backend/3,
      override_backend/4
    ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(schema).

compile_host(Facts, Host, IR) :-
    validate_facts(Facts),
    ( memberchk(host(Host), Facts) ->
        true
    ; throw(error(existence_error(symac_distro_host, Host), _))
    ),
    choose_backend(Facts, Host, Backend),
    host_roles(Facts, Host, Roles),
    host_features(Facts, Host, Features),
    host_packages(Facts, Host, Roles, Features, LogicalPackages),
    maplist(resolve_package(Facts, Backend), LogicalPackages, Packages),
    host_services(Facts, Host, Roles, Services),
    host_environment(Facts, Host, Environment),
    host_secrets(Facts, Host, Secrets),
    IR = distro_ir(Host, Backend, Packages, Services, Environment,
                   Features, Roles, Secrets).

override_backend(Facts, Host, Backend, Overridden) :-
    memberchk(Backend, [auto, nix, guix]),
    exclude(is_backend_for(Host), Facts, Without),
    Overridden = [backend(Host, Backend)|Without].

is_backend_for(Host, backend(Host, _)).

choose_backend(Facts, Host, Backend) :-
    ( memberchk(backend(Host, Explicit), Facts) ->
        choose_backend_value(Explicit, Facts, Host, Backend)
    ; choose_backend_value(auto, Facts, Host, Backend)
    ).

choose_backend_value(nix, _, _, nix).
choose_backend_value(guix, _, _, guix).
choose_backend_value(auto, Facts, Host, Backend) :-
    ( requires_nix(Facts, Host) ->
        Backend = nix
    ; memberchk(prefers(Host, fully_free_system), Facts) ->
        Backend = guix
    ; Backend = nix
    ).

requires_nix(Facts, Host) :-
    member(Capability, [proprietary_nvidia, nix_flake]),
    memberchk(requires(Host, Capability), Facts),
    !.

host_roles(Facts, Host, Roles) :-
    findall(Role, member(role(Host, Role), Facts), Roles0),
    sort(Roles0, Roles).

host_features(Facts, Host, Features) :-
    findall(Feature-State,
            member(feature(Host, Feature, State), Facts),
            Features0),
    collapse_states(feature, Features0, Features).

host_packages(Facts, Host, Roles, Features, Packages) :-
    findall(Package, member(package(Host, Package), Facts), Direct),
    findall(Package,
            ( member(Role, Roles),
              member(role_package(Role, Package), Facts)
            ),
            RolePackages),
    findall(Package,
            ( member(Feature-enabled, Features),
              feature_package(Feature, Package)
            ),
            FeaturePackages),
    append([Direct, RolePackages, FeaturePackages], All),
    sort(All, Packages).

feature_package(prolog, swi_prolog).
feature_package(common_lisp, sbcl).
feature_package(git, git).
feature_package(search, ripgrep).

host_services(Facts, Host, Roles, Services) :-
    findall(Service-State,
            member(service(Host, Service, State), Facts),
            Direct),
    findall(Service-State,
            ( member(Role, Roles),
              member(role_service(Role, Service, State), Facts)
            ),
            RoleServices),
    append(Direct, RoleServices, All),
    collapse_states(service, All, Services).

host_environment(Facts, Host, Environment) :-
    findall(Key-Value,
            member(session_variable(Host, Key, Value), Facts),
            Environment0),
    collapse_values(session_variable, Environment0, Environment).

host_secrets(Facts, Host, Secrets) :-
    findall(Name-Source,
            member(secret_source(Host, Name, Source), Facts),
            Secrets0),
    collapse_values(secret_source, Secrets0, Secrets).

collapse_states(Kind, Pairs, Collapsed) :-
    collapse_values(Kind, Pairs, Collapsed).

collapse_values(Kind, Pairs, Collapsed) :-
    findall(Key, member(Key-_, Pairs), Keys0),
    sort(Keys0, Keys),
    maplist(collapse_key(Kind, Pairs), Keys, Collapsed).

collapse_key(Kind, Pairs, Key-Value) :-
    findall(V, member(Key-V, Pairs), Values0),
    sort(Values0, Values),
    ( Values = [Value] ->
        true
    ; throw(error(permission_error(resolve, conflicting_fact, Kind-Key-Values), _))
    ).

resolve_package(Facts, Backend, Logical, package(Logical, Name)) :-
    ( memberchk(backend_package(Backend, Logical, Custom), Facts) ->
        Name = Custom
    ; builtin_package(Backend, Logical, Name) ->
        true
    ; throw(error(existence_error(backend_package, Backend-Logical), _))
    ).

builtin_package(nix, git, "git").
builtin_package(nix, swi_prolog, "swi-prolog").
builtin_package(nix, sbcl, "sbcl").
builtin_package(nix, ripgrep, "ripgrep").
builtin_package(nix, fd, "fd").
builtin_package(nix, emacs, "emacs").
builtin_package(nix, jq, "jq").
builtin_package(nix, curl, "curl").
builtin_package(nix, openssh, "openssh").

builtin_package(guix, git, "git").
builtin_package(guix, swi_prolog, "swi-prolog").
builtin_package(guix, sbcl, "sbcl").
builtin_package(guix, ripgrep, "ripgrep").
builtin_package(guix, fd, "fd").
builtin_package(guix, emacs, "emacs").
builtin_package(guix, jq, "jq").
builtin_package(guix, curl, "curl").
builtin_package(guix, openssh, "openssh").
