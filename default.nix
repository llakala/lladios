let
  inherit (builtins) concatLists concatStringsSep;

  types = import ./adios/types.nix {
    korora = import ./korora;
  };

  # Helper functions for users, accessed through `adios.lib`
  lib = {
    importModules = import ./adios/lib/importModules.nix { inherit adios; };
    inject = import ./adios/lib/inject.nix;
    merge = {
      lists.concat = { mutators }: concatLists mutators;
      strings.concatLines = { mutators }: concatStringsSep "\n" mutators;
      attrs.flat = import ./adios/lib/merge-attrs-flat.nix;
      attrs.recursively = import ./adios/lib/merge-attrs-recursively.nix {
        inherit (types) toPretty;
      };
      general.withPrio = throw ''
        `adios.merge.general.withPrio` has been renamed to `adios.merge.general.withOrder`
        This is because the function really sets ordering info, not priority,
        and we may wish to add a withPrio function in the future
      '';
      general.withOrder = import ./adios/lib/withOrder.nix;
    };
  };

  loadTree = import ./adios/loadTree.nix types;

  adios = {
    inherit types lib;
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
