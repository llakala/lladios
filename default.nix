let
  inherit (builtins) concatLists concatStringsSep;

  types = import ./adios/types.nix {
    korora = import ./korora;
  };
  merge = {
    lists.concat = { mutators }: concatLists mutators;
    strings.concatLines = { mutators }: concatStringsSep "\n" mutators;
    attrs.flat = import ./adios/merge/attrs-flat.nix {
      inherit (types) toPretty;
    };
    attrs.recursively = import ./adios/merge/attrs-recursively.nix {
      inherit (types) toPretty;
    };
    general.withPrio = throw ''
      `adios.merge.general.withPrio` has been renamed to `adios.merge.general.withOrder`
      This is because the function really sets ordering info, not priority,
      and we may wish to add a withPrio function in the future
    '';
    general.withOrder = import ./adios/merge/with-order.nix;
  };
  lib = {
    importModules = import ./adios/lib/importModules.nix { inherit adios; };
    inject = import ./adios/lib/inject.nix;
    merge = throw ''
      'adios.lib.merge' has been moved to 'adios.merge'.
      The new location allows `merge` to be conveniently destructured in a file's toplevel parameters.

      See the lladios [changelog](https://github.com/llakala/lladios/blob/main/CHANGELOG.md#merge-moved) for more information.'';
  };

  loadTree = import ./adios/loadTree.nix types;

  adios = {
    inherit types lib merge;
    promise = import ./adios/promise.nix;
    __functor =
      _: rootDef:
      {
        options ? { },
      }:
      let
        # Allow viewing the final result while using the tree for fetching
        # modules relative to root
        tree = loadTree tree options rootDef;
      in
      tree;
  };

in
adios
