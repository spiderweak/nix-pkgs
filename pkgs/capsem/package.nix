{
  lib,
  stdenv,
  fetchurl,
  fetchFromGitHub,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  cairo,
  dbus,
  gdk-pixbuf,
  glib,
  glib-networking,
  gtk3,
  libsoup_3,
  webkitgtk_4_1,
  xdotool,
}:

let
  # version and hash are written by ./update.sh; don't edit them by hand.
  sources = lib.importJSON ./sources.json;

  # capsem-tray is linked against libxdo.so.3 (xdotool 3.x, what Ubuntu 24.04
  # ships). xdotool 4 renamed the library to libxdo.so.4, so where nixpkgs has
  # 4.x (nixos-unstable as of 2026-11) the tray gets its own 3.20211022.1, the
  # version nixos-26.05 ships. Delete once upstream links libxdo.so.4.
  libxdo3 =
    if lib.versionOlder xdotool.version "4" then
      xdotool
    else
      xdotool.overrideAttrs {
        version = "3.20211022.1";
        src = fetchFromGitHub {
          owner = "jordansissel";
          repo = "xdotool";
          rev = "v3.20211022.1";
          hash = "sha256-XFiaiHHtUSNFw+xhUR29+2RUHOa+Eyj1HHfjCUjwd9k=";
        };
      };
in
stdenv.mkDerivation {
  pname = "capsem";
  inherit (sources) version;

  # Upstream's Ubuntu/Debian package. The VM kernel, initrd and rootfs are not
  # in it: `capsem update --assets` downloads them into ~/.capsem/assets.
  src = fetchurl {
    url = "https://github.com/google/capsem/releases/download/v${sources.version}/Capsem_${sources.version}_amd64.deb";
    inherit (sources) hash;
  };

  # Upstream release builds; leave the bytes alone apart from patchelf.
  dontStrip = true;

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
  ];

  # Libraries the binaries link against (from the .deb's Depends and
  # `patchelf --print-needed`). glib-networking gives WebKit TLS support.
  buildInputs = [
    stdenv.cc.cc.lib
    cairo
    dbus
    gdk-pixbuf
    glib
    glib-networking
    gtk3
    libsoup_3
    webkitgtk_4_1
    libxdo3
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  # The .deb's maintainer scripts are not run. postinst links the binaries into
  # ~/.capsem/bin, downloads the VM assets and writes a systemd user unit;
  # preinst stops a running service before an upgrade. On NixOS the consumer
  # does those steps itself (see the home-manager service in ~/.config/nixos).
  installPhase = ''
    runHook preInstall

    mkdir -p $out/share $out/lib
    cp -r usr/bin $out/
    cp -r usr/share/applications usr/share/icons $out/share/
    cp -r usr/lib/udev $out/lib/

    # Before a VM boots, capsem-process checks its own sandbox by exec'ing
    # /usr/bin/true and requiring a permission error. NixOS has no
    # /usr/bin/true, so the exec fails with ENOENT instead and every VM is
    # refused ("VM owner sandbox returned No such file or directory").
    # /usr/bin//env has the same length (the string's length is compiled in)
    # and exists on NixOS (environment.usrbinenv); like true, it only runs if
    # the sandbox failed to block exec, which the check reports as a failure.
    # The asserts fail the build once upstream changes the probe; then delete.
    probe_before=$(grep -c -a -o /usr/bin/true $out/bin/capsem-process)
    size_before=$(stat -c %s $out/bin/capsem-process)
    sed -i 's|/usr/bin/true|/usr/bin//env|g' $out/bin/capsem-process
    [ "$probe_before" -gt 0 ] \
      && [ "$(grep -c -a -o /usr/bin/true $out/bin/capsem-process)" -eq 0 ] \
      && [ "$(stat -c %s $out/bin/capsem-process)" -eq "$size_before" ] \
      || { echo "capsem: the /usr/bin/true probe patch no longer applies" >&2; exit 1; }

    # Records which release channel this build belongs to. `capsem update`
    # refuses to pick a channel without it in ~/.capsem/assets.
    install -Dm644 usr/share/capsem/assets/manifest-metadata.json \
      $out/share/capsem/assets/manifest-metadata.json

    runHook postInstall
  '';

  # Only the GTK programs get a wrapper. The service starts its helpers by
  # absolute path and matches running helpers by executable name, so the
  # command-line binaries must stay unwrapped under their own names.
  dontWrapGApps = true;
  postFixup = ''
    wrapGApp $out/bin/capsem-app
    wrapGApp $out/bin/capsem-tray
  '';

  meta = {
    description = "Sandbox AI coding agents in hardware-isolated Linux VMs";
    homepage = "https://github.com/google/capsem";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "capsem";
  };
}
