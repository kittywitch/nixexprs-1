{
  rust-analyzer = { fetchFromGitHub, rustPlatform, lib, darwin, hostPlatform }: rustPlatform.buildRustPackage rec {
    pname = "rust-analyzer";
    version = "2019-09-16";
    src = fetchFromGitHub {
      owner = "rust-analyzer";
      repo = pname;
      rev = "8eb2697b7d2a98c952b3acd1711829a13e13cab1";
      sha256 = "0gg5mf2j5ly89hiffdhhlgnvw84wyargmjvapy4nzpqhv7byv4a8";
    };
    cargoBuildFlags = ["--features" "jemalloc" "-p" "ra_lsp_server"];
    buildInputs = lib.optionals hostPlatform.isDarwin [ darwin.cf-private darwin.apple_sdk.frameworks.CoreServices ];
    # darwin undefined symbol _CFURLResourceIsReachable: https://discourse.nixos.org/t/help-with-rust-linker-error-on-darwin-cfurlresourceisreachable/2657

    cargoSha256 = "093w2jmg9rdsdv246p4cs09am1igdnabv1x6l1nyjgfapjx3dbsj";
    meta.broken = lib.versionAtLeast "1.36.0" rustPlatform.rust.rustc.version;

    doCheck = false;
  };

  xargo-unwrapped = { fetchFromGitHub, rustPlatform, lib }: rustPlatform.buildRustPackage rec {
    pname = "xargo";
    version = "0.3.16";
    src = fetchFromGitHub {
      owner = "japaric";
      repo = pname;
      rev = "v${version}";
      sha256 = "019s7jd7k8r1r0iwd40113c56sfifrzz8i4lwh75n0fpnalpcnyb";
    };

    RUSTC_BOOTSTRAP = true;

    patches = [ ./xargo-stable.patch ];
    cargoSha256 = if lib.isNixpkgsStable
      then "07s2md5k9k0cgl3badhljmdd17151ysgcg5d8dm5a7p48yz2v2vm"
      else "0cmdi9dcdn2nzk1h5n764305h9nzk5qzzjwgq1k86mxsn49i5w8c";

    doCheck = false;
  };

  xargo = { stdenvNoCC, xargo-unwrapped, makeWrapper, rustPlatform, rustc, cargo, rustcSrc ? rustPlatform.rustcSrc }: stdenvNoCC.mkDerivation {
    inherit (xargo-unwrapped) pname version;
    xargo = xargo-unwrapped;
    inherit rustcSrc rustc cargo;

    nativeBuildInputs = [ makeWrapper ];

    buildCommand = ''
      mkdir -p $out/bin
      makeWrapper $xargo/bin/xargo $out/bin/xargo \
        --set-default XARGO_RUST_SRC "$rustcSrc" \
        --set-default CARGO "$cargo/bin/cargo" \
        --set-default RUSTC "$rustc/bin/rustc"
    '';
  };

  rnix-lsp = {
    lib, fetchFromGitHub, rustPlatform, hostPlatform, darwin
  }: rustPlatform.buildRustPackage rec {
    pname = "rnix-lsp";
    version = "2019-04-06";

    src = fetchFromGitHub {
      owner = "nix-community";
      repo = pname;
      rev = "3e6b015bb1fa2b1349519f56fbe0f4897a98ca69";
      sha256 = "01s1sywlv133xzakrp2mki1w14rkicsf0h0wbrn2nf2fna3vk5ln";
    };

    RUSTC_BOOTSTRAP = true; # whee unstable features
    cargoSha256 = "0j9swbh9iig9mimsy8kskzxqpwppp7jikd4cz2lz16jg7irvjq0w";

    buildInputs = lib.optional hostPlatform.isDarwin darwin.apple_sdk.frameworks.Security;

    meta.broken = !lib.rustVersionAtLeast rustPlatform "1.36";
  };

  rnix-lsp-server = { rnix-lsp, fetchurl, rustPlatform }: let
    patch = fetchurl {
      # https://github.com/nix-community/rnix-lsp/pull/2
      name = "rnix-lsp-server.patch";
      url = "https://patch-diff.githubusercontent.com/raw/nix-community/rnix-lsp/pull/2.patch";
      sha256 = "00l7la23mmlh7kq603lnn5qv5pr4lr6y018ddnrvxgbxdgvvxg94";
    };
  in rustPlatform.buildRustPackage rec {
    inherit (rnix-lsp) pname version src buildInputs RUSTC_BOOTSTRAP meta;

    cargoPatches = rnix-lsp.cargoPatches or [] ++ [ patch ];
    cargoSha256 = "1fk11q6pf31c5ri5zkarc3iqyc7jf3xyfvr8f6xxwqcn3h6kz4iw";
  };

  cargo-binutils-unwrapped = {
    lib, fetchFromGitHub, rustPlatform
  }: rustPlatform.buildRustPackage rec {
    pname = "cargo-binutils";
    version = "3d1d4a83a49f890a604c1c75d712402e6f457bff";
    src = fetchFromGitHub {
      owner = "rust-embedded";
      repo = pname;
      rev = version;
      sha256 = "14fkgfx9jbadm119f962yy46lbln7c42myrpapxw94nhrlw71h7n";
    };
    cargoPatches = [ ./cargo-binutils-lock.patch ];
    patches = [ ./cargo-binutils-path.patch ];

    cargoSha256 = if lib.isNixpkgsStable
      then "1lqdcjwfndak59i89rzb1bfyc4p0644ahyyi6mvbll3p5h6h47gj"
      else "0cvsw06r174xc5zn04glcvlc2ckjj32y7bs8qk1wicm28nkq71qp";

    doCheck = false;

    postInstall = ''
      rm $out/bin/rust-*
    '';
  };
  cargo-binutils = {
    cargo-binutils-unwrapped, makeWrapper
  , stdenvNoCC, stdenv, bintools ? stdenv.cc.bintools.bintools
  }: stdenvNoCC.mkDerivation {
    pname = "cargo-binutils-wrapper";
    inherit (cargo-binutils-unwrapped) version;

    nativeBuildInputs = [ makeWrapper ];
    buildInputs = [ cargo-binutils-unwrapped ];

    # $bintools/bin should contain: ar, nm, objcopy, objdump, profdata, readobj/readelf, size, strip
    cargoBinutils = cargo-binutils-unwrapped;
    inherit bintools;
    buildCommand = ''
      mkdir -p $out
      for binary in $cargoBinutils/bin/cargo-*; do
        makeWrapper $binary $out/bin/$(basename $binary) \
          --run '[[ -z $CARGO_BUILD_TARGET ]] || extraFlagsArray+=(--target $CARGO_BUILD_TARGET)' \
          --prefix PATH : $bintools/bin
      done
      if [[ -e $bintools/bin/readelf && ! -e $bintools/bin/readobj ]]; then
        ln -s $bintools/bin/readelf $out/bin/readobj
      fi
    '';
  };

  cargo-call-stack = {
    lib, fetchFromGitHub, rustPlatform
  }: rustPlatform.buildRustPackage rec {
    pname = "cargo-call-stack";
    version = "0.1.3";

    src = fetchFromGitHub {
      owner = "japaric";
      repo = pname;
      rev = "v${version}";
      sha256 = "0bbkvxb0y8czidvmsrnk46gm7r8da7cckdbkwxwby2bcvv2fg812";
    };

    cargoPatches = [ ./cargo-call-stack-lock.patch ];
    patches = [ ./cargo-call-stack-intrinsics.patch ];
    cargoSha256 = if lib.isNixpkgsStable
      then "1ssb5kwjmiwnzsxpc9581vmv77xrycvxpjb42gm3hj8vnhlqc2ml"
      else "0wwdyzavq2x9iand65nzrabn7hlv36ygvrmr3996dxc90k7jg7v9";

    meta.broken = !lib.rustVersionAtLeast rustPlatform "1.33";
  };

  cargo-stack-sizes = {
    lib, fetchFromGitHub, rustPlatform
  }: rustPlatform.buildRustPackage rec {
    pname = "stack-sizes";
    version = "0.4.0";

    src = fetchFromGitHub {
      owner = "japaric";
      repo = pname;
      rev = "v${version}";
      sha256 = "0k260hkv734zwwwz5r93zriimrg13v4h0cmhmqf5a4svkns8z06h";
    };

    cargoPatches = [ ./cargo-stack-sizes-lock.patch ];
    patches = [ ./cargo-stack-sizes-warn.patch ./cargo-stack-sizes-features.patch ];
    cargoSha256 = if lib.isNixpkgsStable
      then "0ph5lhxk01rn68jk7981r61pi1wfhrzrv6h4a0h2cndg3n93vg1x"
      else "1zmfa7s0zcwkkqfqk2svashl9a0mnpscyn1p9ds9k423r52gifwk";

    doCheck = false; # there are no tests
  };

  cargo-llvm-lines = {
    lib, fetchFromGitHub, rustPlatform
  }: rustPlatform.buildRustPackage rec {
    pname = "cargo-llvm-lines";
    version = "0.1.6";

    src = fetchFromGitHub {
      owner = "dtolnay";
      repo = pname;
      rev = "${version}";
      sha256 = "0g3vb8zicz8ib6ydjl5vn5lijfx6z61ips60x1zfhyx8h44xp7v5";
    };

    cargoPatches = [ ./cargo-llvm-lines-lock.patch ];
    patches = [ ./cargo-llvm-lines-features.patch ./cargo-llvm-lines-fix-filter.patch ];
    cargoSha256 = if lib.isNixpkgsStable
      then "0b4zq7ck2plxbl8phndgajsrc81ym7la0v5ikap4jrfvmiz94h6h"
      else "0arjrs67z9rqbkrs77drj068614kg2n3y4f1wyf103bsad0vy783";
  };
}
