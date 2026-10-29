let
  inherit (builtins) concatLists concatStringsSep seq;

  types = import ./adios/types.nix {
    korora = import ./korora;
  };
  messages = import ./adios/messages.nix;
  merge = {
    lists.concat = { mutators }: concatLists mutators;
    strings.concatLines = { mutators }: concatStringsSep "\n" mutators;
    attrs.flat = import ./adios/merge/attrs-flat.nix {
      inherit (types) toPretty;
    };
    attrs.recursively = import ./adios/merge/attrs-recursively.nix {
      inherit (types) toPretty;
    };
    general.withPrio = messages.withPrioError;
    general.withOrder = import ./adios/merge/with-order.nix;
  };
  lib = {
    importModules = import ./adios/lib/importModules.nix { inherit adios; };
    inject = import ./adios/lib/inject.nix;
    merge = seq messages.mergeMovedWarning merge;
  };

  loadTree = import ./adios/loadTree.nix types messages;

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
