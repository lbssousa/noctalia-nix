{
  description = "Noctalia, Noctalia Greeter, Umbriel, Luciole e secret-prompts com os patches de lbssousa, num só nixpkgs e no Cachix lbssousa-noctalia";

  # Os hosts que consomem este flake devem seguir o nixpkgs dele
  # (`nixpkgs.follows = "noctalia-nix/nixpkgs"`): assim as derivações são as
  # mesmas que o CI compilou e publicou no Cachix.
  nixConfig = {
    extra-substituters = [ "https://lbssousa-noctalia.cachix.org" ];
    extra-trusted-public-keys = [
      "lbssousa-noctalia.cachix.org-1:pzuER80zi7qmrqjkVy/2sifDJogy+QR9F9z/p4CBjF4="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Forks com os patches como commits no branch nix-config, rebaseado sobre
    # as releases (Noctalia, greeter) ou o main (Umbriel) do upstream pelo
    # workflow daily.yml.
    noctalia = {
      url = "github:lbssousa/noctalia/nix-config";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia-greeter = {
      url = "github:lbssousa/noctalia-greeter/nix-config";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    umbriel = {
      url = "github:lbssousa/umbriel/nix-config";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.xdg-desktop-portal-umbriel.inputs.nixpkgs.follows = "nixpkgs";
    };

    # Sem patches, no mesmo nixpkgs e no mesmo cache.
    luciole = {
      url = "github:noctalia-dev/luciole";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia-secret-prompts = {
      url = "github:lbssousa/noctalia-secret-prompts";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      noctalia,
      noctalia-greeter,
      umbriel,
      luciole,
      noctalia-secret-prompts,
      ...
    }:
    let
      systems = [ "x86_64-linux" ];
      forEachSystem = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      packagesFor =
        pkgs:
        let
          inherit (pkgs.stdenv.hostPlatform) system;
        in
        {
          noctalia = noctalia.packages.${system}.default;
          noctalia-greeter = noctalia-greeter.packages.${system}.default;
          umbriel = umbriel.packages.${system}.default;
          xdg-desktop-portal-umbriel = umbriel.packages.${system}.xdg-desktop-portal-umbriel;
          luciole = luciole.packages.${system}.default;
          noctalia-secret-prompts = pkgs.callPackage "${noctalia-secret-prompts}/nix/package.nix" { };
        };
    in
    {
      # Os pacotes vêm deste flake (do nixpkgs dele), não do conjunto de quem
      # aplica o overlay: com o nixpkgs seguido, são as mesmas derivações do
      # cache.
      overlays.default =
        final: _prev: packagesFor nixpkgs.legacyPackages.${final.stdenv.hostPlatform.system};

      packages = forEachSystem (
        pkgs:
        let
          pkgs' = packagesFor pkgs;
        in
        pkgs'
        // {
          all = pkgs.linkFarm "noctalia-nix-all" (
            nixpkgs.lib.mapAttrsToList (name: path: { inherit name path; }) pkgs'
          );
          default = self.packages.${pkgs.stdenv.hostPlatform.system}.all;
        }
      );

      checks = forEachSystem (pkgs: packagesFor pkgs);

      formatter = forEachSystem (pkgs: pkgs.nixfmt-tree);
    };
}
