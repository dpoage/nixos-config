# Drata Agent — SOC2 evidence collector required by Pattern. Drata only ships
# an Ubuntu deb (github.com/drata/agent-releases), so repackage it:
#
# * Keep the deb's bundled Electron. Stable nixpkgs electron is EOL and refused
#   as insecure (see the heroic note in ./default.nix), and the bundled binary
#   is what Drata QAs against.
# * autoPatchelfHook fixes up the Electron binary and the bundled osqueryi.
# * The load-bearing fix is the asar patch below. The agent resolves its
#   bundled osqueryi as
#     app.isPackaged ? path.join(process.resourcesPath, 'lib/linux/bin/osqueryi')
#                    : path.join(__dirname, '..', 'lib/linux/bin/osqueryi')
#   On repackaged installs the resolution lands inside app.asar and Electron
#   throws `Invalid package .../app.asar`, so EVERY osquery-backed compliance
#   field silently reports empty (ddlees/drata.flake#1). Following the AUR
#   precedent we rewrite process.resourcesPath to the literal store resources
#   dir, and additionally pin the __dirname fallback branch so the exec path
#   is correct no matter how isPackaged evaluates. Both substitutions use
#   --replace-fail: a version bump that changes the minified shape must fail
#   the build, not silently regress compliance evidence.
# * The wrapper provides gsettings + compiled schemas + the dconf GIO module:
#   the agent shells out to `gsettings get org.gnome.desktop.screensaver
#   lock-enabled` (and friends) for its screen-lock checks, and that has to
#   work from a bare systemd user unit under Hyprland — no GNOME session
#   environment to inherit.
# * Known gaps (documented, not bugs): the deb ships no augeas lenses, so the
#   agent's firewall check (`SELECT ... FROM augeas WHERE path =
#   '/etc/ufw/ufw.conf'`) reports passed=0 on every install regardless of the
#   host firewall — networking.firewall is the real control, so firewall stays
#   a manual-evidence item in Drata. Likewise hardware_serial and disk
#   encryption read empty for the unprivileged agent (manual evidence).
# * The app self-installs ~/.config/autostart/drata-agent.desktop pointing at
#   the UNWRAPPED lib/drata-agent. It is inert here (no XDG-autostart executor
#   in this compositor setup) and the supported autostart path is the systemd
#   user unit in profiles/work.nix — but if an XDG autostart executor is ever
#   added, that desktop file would bypass this wrapper's env.

{
  lib,
  stdenv,
  fetchurl,
  asar,
  autoPatchelfHook,
  dpkg,
  makeWrapper,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  dconf,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  hicolor-icon-theme,
  libappindicator-gtk3,
  libdbusmenu,
  libdbusmenu-gtk3,
  libdrm,
  libgbm,
  libGL,
  libnotify,
  libxkbcommon,
  nspr,
  nss,
  pango,
  systemd,
  xdg-utils,
  xorg,
  zlib,
}:

let
  runtimeLibs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gsettings-desktop-schemas
    gtk3
    hicolor-icon-theme
    libappindicator-gtk3
    libdbusmenu
    libdbusmenu-gtk3
    libdrm
    libgbm
    libGL
    libnotify
    libxkbcommon
    nspr
    nss
    pango
    systemd
    xdg-utils
    zlib
    xorg.libX11
    xorg.libXScrnSaver
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libXtst
    xorg.libxcb
    xorg.libxshmfence
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "drata-agent";
  version = "3.9.0";

  src = fetchurl {
    url = "https://github.com/drata/agent-releases/releases/download/${finalAttrs.version}/Drata-Agent-linux.deb";
    hash = "sha256-eNs+iHsUAkz1uxJ8zA84lSGlYsS6jKxYf+FaB2qiSiw=";
  };

  nativeBuildInputs = [
    asar
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  buildInputs = runtimeLibs;

  dontConfigure = true;
  dontBuild = true;
  # Prebuilt binaries (Electron, osqueryi) — patch interpreters/rpaths only.
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share
    cp -r "opt/Drata Agent" $out/lib
    cp -r usr/share/applications usr/share/icons $out/share/

    # asar surgery: make osqueryi resolution point at the real store path.
    asar extract "$out/lib/resources/app.asar" unpacked-app
    # 1. The isPackaged=false fallback resolves relative to __dirname, which
    #    lives *inside* app.asar. Pin it to the store resources dir.
    substituteInPlace unpacked-app/dist/main.js --replace-fail \
      'electron_1.app.isPackaged?path_1.default.join(process.resourcesPath,UbuntuSystemQueryService.RESOURCES_PATH):path_1.default.join(__dirname,"..",UbuntuSystemQueryService.RESOURCES_PATH)' \
      "path_1.default.join(\"$out/lib/resources\",UbuntuSystemQueryService.RESOURCES_PATH)"
    # 2. Every remaining process.resourcesPath -> literal store resources dir.
    substituteInPlace unpacked-app/dist/main.js --replace-fail \
      'process.resourcesPath' "'$out/lib/resources'"
    if grep -qF 'process.resourcesPath' unpacked-app/dist/main.js; then
      echo "ERROR: process.resourcesPath survived the asar patch" >&2
      exit 1
    fi
    echo "asar patch: $(grep -oF "$out/lib/resources" unpacked-app/dist/main.js | wc -l) store-path references in dist/main.js"
    asar pack unpacked-app "$out/lib/resources/app.asar"
    rm -rf unpacked-app

    substituteInPlace $out/share/applications/drata-agent.desktop \
      --replace-fail '"/opt/Drata Agent/drata-agent"' "$out/bin/drata-agent"

    # PATH: gsettings (glib.bin) + xdg-open for the screen-lock probes and
    # magic-link handling. XDG_DATA_DIRS: compiled gsettings schemas so those
    # probes work headless. GIO_EXTRA_MODULES: dconf backend so gsettings
    # reads the user's real dconf db instead of schema defaults.
    makeWrapper "$out/lib/drata-agent" "$out/bin/drata-agent" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}" \
      --prefix PATH : "${
        lib.makeBinPath [
          glib
          xdg-utils
        ]
      }" \
      --prefix GIO_EXTRA_MODULES : "${lib.getLib dconf}/lib/gio/modules" \
      --prefix XDG_DATA_DIRS : "${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}:${gtk3}/share/gsettings-schemas/${gtk3.name}:${hicolor-icon-theme}/share:$out/share"

    runHook postInstall
  '';

  meta = {
    description = "Drata compliance agent (repackaged from the official Ubuntu deb)";
    homepage = "https://github.com/drata/drata-agent";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "drata-agent";
  };
})
