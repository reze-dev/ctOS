{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation {
    pname = "ctos-shell";
    version = "0.1.0";
    src = ./..;

    dontBuild = true;

    installPhase = ''
        runHook preInstall
        mkdir -p "$out/share/ctos"
        cp -R . "$out/share/ctos/"
        rm -rf "$out/share/ctos/.git" "$out/share/ctos/nix"
        runHook postInstall
    '';

    meta = {
        description = "ctOS Quickshell desktop shell";
        license = lib.licenses.mit;
        mainProgram = "ctos-shell";
        platforms = lib.platforms.linux;
    };
}
