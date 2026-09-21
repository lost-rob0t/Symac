:- module(symac_distro_diagnostics,
    [ normalize_diagnostic/3,
      normalize_diagnostic_file/3
    ]).

:- use_module(library(error)).
:- use_module(library(pcre)).

normalize_diagnostic_file(Backend, Path, Diagnostic) :-
    read_file_to_string(Path, Text, []),
    normalize_diagnostic(Backend, Text, Diagnostic).

normalize_diagnostic(Backend, Text0, Diagnostic) :-
    must_be(atom, Backend),
    memberchk(Backend, [nix, guix]),
    text_string(Text0, Text),
    ( backend_diagnostic(Backend, Text, Diagnostic0) ->
        Diagnostic = Diagnostic0
    ; Diagnostic = diagnostic(Backend, unclassified, Text)
    ).

backend_diagnostic(nix, Text, diagnostic(nix, undefined_attribute, Name)) :-
    re_matchsub("undefined variable ['\"](?<name>[^'\"]+)['\"]",
                Text, Match, [caseless(true)]),
    get_dict(name, Match, Name).
backend_diagnostic(nix, Text, diagnostic(nix, missing_attribute, Name)) :-
    re_matchsub("attribute ['\"](?<name>[^'\"]+)['\"] missing",
                Text, Match, [caseless(true)]),
    get_dict(name, Match, Name).
backend_diagnostic(guix, Text, diagnostic(guix, unknown_package, Name)) :-
    re_matchsub("unknown package(?:[: ]+)(?<name>[^\n ]+)",
                Text, Match, [caseless(true)]),
    get_dict(name, Match, Name).
backend_diagnostic(guix, Text, diagnostic(guix, unbound_variable, Name)) :-
    re_matchsub("unbound variable[: ]+(?<name>[^\n ]+)",
                Text, Match, [caseless(true)]),
    get_dict(name, Match, Name).

text_string(Text, Text) :-
    string(Text),
    !.
text_string(Text, String) :-
    atom(Text),
    !,
    atom_string(Text, String).
