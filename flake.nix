{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      config.allowUnsupportedSystem = true;
    };
    pkgsPatched = import nixpkgs {
      system = "x86_64-linux";
      config.allowUnsupportedSystem = true;
      overlays = [
        (final: prev: {
          rustc = prev.rustc.overrideAttrs (oA: {
            RUSTFLAGS = "-Ccodegen-units=32";
            patches = [
              ./core-net.patch
#              (pkgs.fetchpatch {
#                url = "https://github.com/faern/rust/commit/ea3775016f3e5c296b48eb4399bb5a1caf45279b.patch";
#                sha256 = "sha256-Nyfu8S/UlCVJkbV9bSi534RcIVV9/TEOKEoWbR7tDUc=";
#              })
            ];
          });
        })
      ];
    };
    thumbv7emPkgs = import nixpkgs {
      system = "x86_64-linux";
      crossSystem =
        nixpkgs.lib.systems.examples.arm-embedded
        // {
          rustc.config = "thumbv7em-none-eabi";
        };
      config.allowUnsupportedSystem = true;
    };
  in rec {
    packages.x86_64-linux.rustcPatched = pkgsPatched.rustc.override {
      stdenv = pkgsPatched.stdenv.override {
        targetPlatform = thumbv7emPkgs.stdenv.targetPlatform;
        hostPlatform = pkgsPatched.stdenv.hostPlatform;
        buildPlatform = pkgsPatched.stdenv.buildPlatform;
      };
      pkgsBuildBuild = pkgsPatched;
      pkgsBuildHost = pkgsPatched;
      pkgsBuildTarget.targetPackages.stdenv.cc = pkgsPatched.pkgsCross.arm-embedded.stdenv.cc;
      enableRustcDev = false;
    };
    packages.x86_64-linux.rustc = pkgs.rustc.override {
      stdenv = pkgs.stdenv.override {
        targetPlatform = thumbv7emPkgs.stdenv.targetPlatform;
        hostPlatform = pkgs.stdenv.hostPlatform;
        buildPlatform = pkgs.stdenv.buildPlatform;
      };
      pkgsBuildBuild = pkgs;
      pkgsBuildHost = pkgs;
      pkgsBuildTarget.targetPackages.stdenv.cc = pkgsPatched.pkgsCross.arm-embedded.stdenv.cc;
      enableRustcDev = false;
    };
    packages.x86_64-linux.rustPlatform = thumbv7emPkgs.makeRustPlatform {
      rustc = packages.x86_64-linux.rustc;
      inherit (pkgs) cargo;
    };
    packages.x86_64-linux.rustPlatformPatched = thumbv7emPkgs.makeRustPlatform {
      rustc = packages.x86_64-linux.rustcPatched;
      inherit (pkgsPatched) cargo;
    };
    packages.x86_64-linux.patched = pkgs.callPackage ./app {
      rustPlatform = packages.x86_64-linux.rustPlatformPatched;
    };
    packages.x86_64-linux.notPatched = pkgs.callPackage ./app {
      rustPlatform = packages.x86_64-linux.rustPlatform;
    };
  };
}
