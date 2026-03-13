{
  description = "Kubernetes cluster";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      flake-parts,
      git-hooks-nix,
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
          ...
        }:
        {
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

          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              config.pre-commit.settings.enabledPackages
              ansible
              opentofu
              just
              kubectl
            ];

            shellHook = ''
              ${config.pre-commit.shellHook}
              export KUBECONFIG="./kubeconfig"
              alias kwatch="watch -- kubectl get all -o wide --all-namespaces"
              echo 1>&2 "Welcome to the development shell!"
            '';
          };
        };

      flake = { };
    };
}
