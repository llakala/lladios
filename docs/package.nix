{
  stdenvNoCC,
  mdbook,
}:
stdenvNoCC.mkDerivation {
  pname = "adios-docs";
  version = "0.1";
  src = ./.;
  nativeBuildInputs = [
    mdbook
  ];

  dontConfigure = true;
  dontFixup = true;

  env.RUST_BACKTRACE = 1;

  buildPhase = ''
    runHook preBuild

    mdbook build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mv book $out

    runHook postInstall
  '';
}
