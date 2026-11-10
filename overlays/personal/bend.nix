# Bend 2 (bun-compiled; dontStrip keeps the .bun payload). It finds bend2/ and
# guide/ beside its real path; clang on PATH serves `-o` native builds.
# BENDTT points `--verdict` at a kernel built here, so Lean is build-time only.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  clang,
  runCommand,
  zstd,
  zlib,
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
  src = fetchurl {
    url = "https://github.com/bendlang/bend/releases/download/v${version}/bend-${version}-linux-${arch}.tar.gz";
    hash = hashes.${arch};
  };

  # The Lean release bend pins for its kernel (LEAN_VERSION in bend2/safe.ts).
  # nixpkgs' lean4 lags it; bump both together.
  leanVersion = "4.34.0";
  leanAsset = { x64 = "linux"; arm64 = "linux_aarch64"; }.${arch};
  leanHashes = {
    x64 = "sha256-yqqYNWCYyF3A/LvSjh7GbznrZVGCmXK3Uv8g4ShrZGs=";
    arm64 = "sha256-QLBP23+4SdPIDhDDu+68e3NUttPwdFC5FowhSbQNKoI=";
  };
  lean = stdenv.mkDerivation {
    pname = "lean4-bin";
    version = leanVersion;
    src = fetchurl {
      url = "https://github.com/leanprover/lean4/releases/download/v${leanVersion}/lean-${leanVersion}-${leanAsset}.tar.zst";
      hash = leanHashes.${arch};
    };
    nativeBuildInputs = [ autoPatchelfHook zstd ];
    buildInputs = [ stdenv.cc.cc.lib zlib ];
    dontStrip = true;
    installPhase = "cp -r . $out";
  };

  # --verdict's kernel, built as bend builds it (kernel_bin in bend2/safe.ts).
  bendtt = stdenv.mkDerivation {
    pname = "bendtt";
    inherit version src;
    nativeBuildInputs = [ lean autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib ];
    buildPhase = ''
      grep -aq 'LEAN_VERSION = "${leanVersion}"' bin/bend || {
        echo "bend ${version} pins a Lean other than ${leanVersion}; update leanVersion" >&2
        exit 1
      }
      lean -c bendtt.c bend2/bendtt.lean
      leanc -O3 -DNDEBUG bendtt.c -o bendtt
    '';
    installPhase = "install -Dm755 bendtt $out/bin/bendtt";
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
  inherit version src;
  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  dontStrip = true;
  installPhase = ''
    mkdir -p $out/libexec/bend
    cp -r bin bend2 guide $out/libexec/bend/
    makeWrapper $out/libexec/bend/bin/bend $out/bin/bend \
      --prefix PATH : ${lib.makeBinPath [ clang ]} \
      --set-default BENDTT ${bendtt}/bin/bendtt \
      --set-default BEND_NO_TELEMETRY 1 ${lib.optionalString cudaSupport "\\
      --set-default CUDA_HOME ${cudaHome}"}
  '';

  # --verdict must accept a true law through the wrapper, and the kernel must
  # reject the same proof with its claim falsified.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME=$TMPDIR
    mkdir $TMPDIR/verdict && cd $TMPDIR/verdict
    cat > LAWS.bend <<'EOF'
    import Base

    law add_zero:
      for x: Nat
      {Nat.add(x, 0n) == x : Nat}
    EOF
    cat > PROOF.bend <<'EOF'
    import Base
    import ./LAWS.bend as Laws

    def Laws.add_zero(x):
      match x:
        case 0n:
          {==}
        case 1n+p:
          %Laws.add_zero(p) : {1n+Nat.add(p, 0n) == 1n+_ : Nat}
          {==}
    EOF
    $out/bin/bend PROOF.bend --verdict | tee ok.log
    grep -qx 'ALL PROOFS CHECK' ok.log
    $out/bin/bend PROOF.bend -o PROOF.bendtt
    sed '1s/(Nat.add x0 (.Zero, ())) == x0/(Nat.add x0 (.Zero, ())) == (.Zero, ())/' \
      PROOF.bendtt > BAD.bendtt
    ! cmp -s PROOF.bendtt BAD.bendtt
    if ${bendtt}/bin/bendtt BAD.bendtt > bad.log; then
      echo "kernel accepted a false claim" >&2; exit 1
    fi
    grep -q '^SOME PROOFS FAIL' bad.log
    runHook postInstallCheck
  '';

  passthru = { inherit bendtt lean; };
  meta = {
    description = "Bend 2: dependently typed, parallel functional language";
    homepage = "https://bend-lang.com";
    license = lib.licenses.asl20;
    mainProgram = "bend";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
}
