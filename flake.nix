{
  description = "Symac agentic Common Lisp workstation";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system:
        f (import nixpkgs { inherit system; }));
    in
    {
      packages = forAllSystems (pkgs:
        let
          symac-distro = pkgs.writeShellApplication {
            name = "symac-distro";
            runtimeInputs = [ pkgs.swiProlog ];
            text = ''
              exec swipl -q -s ${./prolog/distro}/cli.pl -- "$@"
            '';
          };
        in
        {
          inherit symac-distro;
          default = symac-distro;
        });

      apps = forAllSystems (pkgs: {
        symac-distro = {
          type = "app";
          program = "${self.packages.${pkgs.system}.symac-distro}/bin/symac-distro";
        };
        default = self.apps.${pkgs.system}.symac-distro;
      });

      checks = forAllSystems (pkgs: {
        distro-prolog = pkgs.runCommand "symac-distro-prolog-tests"
          { nativeBuildInputs = [ pkgs.swiProlog ]; }
          ''
            swipl -q -s ${./prolog/distro}/tests.pl -g run_tests,halt
            ${self.packages.${pkgs.system}.symac-distro}/bin/symac-distro \
              render nix ${./examples/distro/workstation.pl} workstation > nix-module.nix
            ${self.packages.${pkgs.system}.symac-distro}/bin/symac-distro \
              render guix ${./examples/distro/workstation.pl} workstation > guix-fragment.scm
            grep -q 'environment.systemPackages' nix-module.nix
            grep -q '%symac-packages' guix-fragment.scm
            touch "$out"
          '';
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
