{
  description = "Kubernetes cluster";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    press = {
      url = "github:RossSmyth/press/48381e15558364748441b8b540a0734295f9663a";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      flake-parts,
      git-hooks-nix,
      press,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        git-hooks-nix.flakeModule
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        let
          mkScript =
            name: text:
            let
              script = pkgs.writeShellScriptBin name text;
            in
            script;
          scripts = [
            (mkScript "kwatch" ''
              watch -t -n5 '
                  printf " --- Pods ---\n"
                  ${pkgs.kubectl}/bin/kubectl get pods -o wide --all-namespaces
                  printf " --- Services ---\n"
                  ${pkgs.kubectl}/bin/kubectl get service --all-namespaces
                  printf " --- Daemonsets ---\n"
                  ${pkgs.kubectl}/bin/kubectl get daemonset --all-namespaces
                  printf " --- Deployments ---\n"
                  ${pkgs.kubectl}/bin/kubectl get deployment --all-namespaces
                  printf " --- Replicasets ---\n"
                  ${pkgs.kubectl}/bin/kubectl get replicaset --all-namespaces
                  printf " --- Jobs ---\n"
                  ${pkgs.kubectl}/bin/kubectl get job --all-namespaces
              '
            '')
            (mkScript "typstformat" ''
              echo "Formatting $PWD/docs/typst/"
              ${pkgs.typstyle}/bin/typstyle -v --wrap-text -i $PWD/docs/typst/
            '')
          ];
        in
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ (import press) ];
            config = { };
          };

          formatter = pkgs.nixfmt-tree;

          pre-commit = {
            check.enable = true;

            settings = {
              addGcRoot = true;

              hooks = {
                ansible-lint.enable = true;
                # Misc
                check-added-large-files.enable = true;
                check-yaml.enable = true;
                detect-private-keys.enable = true;
                end-of-file-fixer.enable = true;
                ripsecrets.enable = true;
                trim-trailing-whitespace.enable = true;
                # Nix
                deadnix.enable = true;
                nil.enable = true;
                nixfmt.enable = true;
                # Terraform
                terraform-format.enable = true;
              };
            };
          };

          packages = builtins.listToAttrs (
            map
              (lang: {
                name = "docs-${lang}";
                value = pkgs.buildTypstDocument {
                  name = "report-${lang}";
                  src = ./docs/typst;
                  file = "main.typ";
                  inputs."language" = "${lang}";
                  format = "pdf";
                  typstEnv = p: [ p.note-me ];
                };
              })
              [
                # "en"
                "it"
              ]
          );

          devShells.default = pkgs.mkShell {
            packages =
              with pkgs;
              [
                config.pre-commit.settings.enabledPackages
                ansible
                opentofu
                just
                kubectl
                k9s
                typstyle
              ]
              ++ scripts;

            shellHook = ''
              ${config.pre-commit.shellHook}
              export KUBECONFIG="./kubeconfig"
              echo 1>&2 "Welcome to the development shell!"
            '';
          };
        };

      flake = { };
    };
}
