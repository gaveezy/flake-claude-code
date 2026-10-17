{
  description = "Claude Code, packaged from Anthropic's native release binaries";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      # Claude Code is unfree. Allow exactly it, so building this flake's own
      # outputs works without a global allowUnfree.
      forAllSystems =
        f:
        lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              config.allowUnfreePredicate = pkg: lib.getName pkg == "claude-code";
            }
          )
        );
    in
    {
      packages = forAllSystems (pkgs: {
        claude-code = pkgs.callPackage ./package.nix { };
        default = self.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
      });

      # Replaces pkgs.claude-code. The consumer's nixpkgs config decides whether
      # unfree packages are allowed.
      overlays.default = final: _prev: {
        claude-code = final.callPackage ./package.nix { };
      };

      checks = forAllSystems (pkgs: {
        inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) claude-code;
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
