# Claude Code from Anthropic's native release binaries.
#
# The version and per-platform SHA-256 checksums live in sources.json, which
# update.sh generates from the manifest Anthropic publishes with each release.
# Nothing here is built from source: the download is Anthropic's own binary,
# byte-for-byte, verified against that checksum.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  bubblewrap,
  socat,
}:
let
  sources = lib.importJSON ./sources.json;

  # Nix system -> platform directory in Anthropic's release bucket.
  releasePlatforms = {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
    x86_64-darwin = "darwin-x64";
    aarch64-darwin = "darwin-arm64";
  };

  inherit (stdenv.hostPlatform) system isLinux;
  platform =
    releasePlatforms.${system} or (throw "claude-code: no Anthropic release binary for ${system}");

  # Updates come from Nix, never from the binary rewriting itself. On Linux,
  # Claude Code's sandboxing uses bubblewrap and socat; suffix them so any
  # system-provided versions still take precedence.
  wrapperArgs = [
    "--set"
    "DISABLE_AUTOUPDATER"
    "1"
  ]
  ++ lib.optionals isLinux [
    "--suffix"
    "PATH"
    ":"
    (lib.makeBinPath [
      bubblewrap
      socat
    ])
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "claude-code";
  inherit (sources) version;

  src = fetchurl {
    url = "${sources.baseUrl}/${finalAttrs.version}/${platform}/claude";
    sha256 = sources.platforms.${platform};
  };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  # A Bun single-file executable: the JavaScript bundle is appended to the
  # native image, and strip would discard it.
  dontStrip = true;

  # On Linux, point the glibc binary at the Nix dynamic loader and libc.
  nativeBuildInputs = [ makeBinaryWrapper ] ++ lib.optional isLinux autoPatchelfHook;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/libexec/claude-code/claude"

    makeBinaryWrapper "$out/libexec/claude-code/claude" "$out/bin/claude" \
      ${lib.escapeShellArgs wrapperArgs}

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    HOME="$TMPDIR" "$out/bin/claude" --version | grep -F "${finalAttrs.version}"
    runHook postInstallCheck
  '';

  meta = {
    description = "Anthropic's agentic coding tool for the terminal";
    homepage = "https://code.claude.com";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "claude";
    platforms = builtins.attrNames releasePlatforms;
  };
})
