# flake-claude-code

A Nix flake for [Claude Code](https://code.claude.com) that follows
Anthropic's releases closely, where nixpkgs trails by weeks.

It packages Anthropic's own native binary. Nothing is rebuilt or modified
beyond what Nix needs:

- The binary is downloaded from `downloads.claude.ai` and verified against the
  SHA-256 that Anthropic publishes in each release's `manifest.json`.
- On Linux, `autoPatchelfHook` points it at the Nix dynamic loader and glibc.
- A wrapper sets `DISABLE_AUTOUPDATER=1`, so versions change only through Nix,
  and on Linux adds `bubblewrap` and `socat` (used by Claude Code's sandboxing)
  to the end of `PATH`.

Supported systems: `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`,
`aarch64-darwin`.

## Use

Try it without installing:

```sh
nix run github:gaveezy/flake-claude-code -- --version
```

As a flake input, replacing `pkgs.claude-code` everywhere through the overlay:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    claude-code = {
      url = "github:gaveezy/flake-claude-code";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, claude-code, ... }: {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        (
          { pkgs, lib, ... }:
          {
            nixpkgs.overlays = [ claude-code.overlays.default ];
            nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "claude-code";
            environment.systemPackages = [ pkgs.claude-code ];
          }
        )
      ];
    };
  };
}
```

Or take the package directly: `claude-code.packages.${system}.claude-code`.

Claude Code is unfree. The flake's own `packages` output allows it; with the
overlay, your nixpkgs configuration must allow `claude-code`.

## Updates

`.github/workflows/update.yml` checks Anthropic's `latest` channel every six
hours. When there is a new release, it regenerates `sources.json`, builds and
tests it, and commits. Consumers move to it with:

```sh
nix flake update claude-code
```

To pin something else by hand:

```sh
./update.sh            # newest release
./update.sh stable     # Anthropic's stable channel
./update.sh 2.1.300    # an exact version
```

## License

The Nix code in this repository is MIT licensed. Claude Code itself is
proprietary software from Anthropic, subject to
[Anthropic's terms](https://www.anthropic.com/legal/commercial-terms).
