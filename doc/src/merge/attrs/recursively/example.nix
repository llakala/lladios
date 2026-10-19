# module/git.nix
{ types, merge, ... }:
{
  options = {
    settings = {
      type = types.attrs;
      mergeFunc = merge.attrs.recursively;
    };
  };
}
