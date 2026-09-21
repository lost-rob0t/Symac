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
            runtimeInputs = [ pkgs.swi-prolog ];
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
          { nativeBuildInputs = [ pkgs.swi-prolog pkgs.guile_3_0 ]; }
          ''
            swipl -q -s ${./prolog/distro}/tests.pl -g run_tests,halt
            ${self.packages.${pkgs.system}.symac-distro}/bin/symac-distro \
              render nix ${./examples/distro/workstation.pl} workstation > nix-module.nix
            ${self.packages.${pkgs.system}.symac-distro}/bin/symac-distro \
              render guix ${./examples/distro/workstation.pl} workstation > guix-fragment.scm
            grep -q 'environment.systemPackages' nix-module.nix
            grep -q '%symac-packages' guix-fragment.scm
            guile -c '
              (call-with-input-file "guix-fragment.scm"
                (lambda (port)
                  (let loop ()
                    (let ((form (read port)))
                      (unless (eof-object? form)
                        (loop))))))
            '
            touch "$out"
          '';
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
