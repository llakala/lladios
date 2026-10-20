{
  sources ? import ../npins,
  pkgs ? import sources.nixpkgs {},
}:
pkgs.callPackage ./package.nix {}
