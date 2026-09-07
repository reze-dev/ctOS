{ lib, pkgs, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "ctos-shell";
  version = "0.1.0";
  src = ./..;

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    
    # Copy assets
    mkdir -p "$out/share/ctos"
    cp -R . "$out/share/ctos/"
    rm -rf "$out/share/ctos/.git" "$out/share/ctos/nix"
    
    # Create executable wrapper
    mkdir -p "$out/bin"
    cat << BIN > "$out/bin/ctos-shell"
#!/bin/sh
exec ${pkgs.quickshell}/bin/quickshell "$out/share/ctos/shell.qml" "\$@"
BIN
    chmod +x "$out/bin/ctos-shell"

    # Create IPC message wrapper
    cat << BIN > "$out/bin/ctos-shell-msg"
#!/bin/sh
exec ${pkgs.quickshell}/bin/quickshell ipc -p "$out/share/ctos/shell.qml" call ctos "\$@"
BIN
    chmod +x "$out/bin/ctos-shell-msg"
    
    runHook postInstall
  '';

  meta = {
    description = "ctOS Quickshell desktop shell";
    license = lib.licenses.mit;
    mainProgram = "ctos-shell";
    platforms = lib.platforms.linux;
  };
}
