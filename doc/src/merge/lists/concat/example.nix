# modules/environment.nix
{ types, merge, ... }:
{
  options = {
    systemPackages = {
      type = types.listOf types.derivation;
      mergeFunc = merge.lists.concat;
    };
  };
}
