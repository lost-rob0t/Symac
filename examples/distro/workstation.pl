% Symac distro facts are data only. No rules or directives belong here.

host(workstation).
backend(workstation, auto).

role(workstation, developer).
role_package(developer, git).
role_package(developer, fd).
role_package(developer, jq).
role_package(developer, curl).

feature(workstation, prolog, enabled).
feature(workstation, common_lisp, enabled).
feature(workstation, search, enabled).

service(workstation, openssh, enabled).

session_variable(workstation, "STAR_PROFILE", "developer").

% Secret values never belong in this file.
secret_source(workstation, "OPENROUTER_API_KEY",
              environment("OPENROUTER_API_KEY")).
