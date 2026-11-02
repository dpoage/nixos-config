# Bend 2 (bun-compiled; dontStrip keeps the .bun payload). It finds bend2/ and
# guide/ beside its real path; clang on PATH serves `-o` native builds.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  clang,
  runCommand,
  cudaPackages,
  cudaSupport ? false,
}:

let
  version = "2.0.39";
  arch = { x86_64-linux = "x64"; aarch64-linux = "arm64"; }.${stdenv.hostPlatform.system};
  hashes = {
    x64 = "sha256-bPRi/Y9wsJSklQ67cJqcT/2PHRGJ2c7fH9Y81dBBx6s=";
    arm64 = "sha256-cbQ+G7kxPdFKwrBVO4VOQcOdZeyqRwQHluv/Skb1Spc=";
  };

  # CUDA_HOME for `!` builds. libcuda points at the host driver, not the stub,
  # so the rpath ld-wrapper adds for this dir resolves the real driver at runtime.
  cudaHome = runCommand "bend-cuda-home" { } ''
    mkdir -p $out/include $out/lib
    ln -s ${cudaPackages.cuda_cudart}/include/* ${cudaPackages.cuda_nvrtc.include}/include/* $out/include/
    ln -s ${cudaPackages.cuda_nvrtc.lib}/lib/* $out/lib/
    ln -s /run/opengl-driver/lib/libcuda.so.1 $out/lib/libcuda.so.1
    ln -s /run/opengl-driver/lib/libcuda.so.1 $out/lib/libcuda.so
  '';
in
stdenv.mkDerivation {
  pname = "bend";
  inherit version;
  src = fetchurl {
    url = "https://github.com/bendlang/bend/releases/download/v${version}/bend-${version}-linux-${arch}.tar.gz";
    hash = hashes.${arch};
  };
  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  dontStrip = true;
  installPhase = ''
    mkdir -p $out/libexec/bend
    cp -r bin bend2 guide $out/libexec/bend/
    makeWrapper $out/libexec/bend/bin/bend $out/bin/bend \
      --prefix PATH : ${lib.makeBinPath [ clang ]} \
      --set-default BEND_NO_TELEMETRY 1 ${lib.optionalString cudaSupport "\\
      --set-default CUDA_HOME ${cudaHome}"}
  '';
  meta = {
    description = "Bend 2: dependently typed, parallel functional language";
    homepage = "https://bend-lang.com";
    license = lib.licenses.asl20;
    mainProgram = "bend";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
}
