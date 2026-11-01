let
  inherit (builtins)
    concatLists
    concatStringsSep
    mapAttrs
    seq
    ;

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

  canonicalize = module: {
    _module = module;
    ${if module.modules != { } then "modules" else null} = mapAttrs (_: canonicalize) module.modules;
    ${if module ? __functor then "__functor" else null} = module.__functor;
    inherit (module.args) options inputs results;
    ${if module ? __functor then "result" else null} = module.args.result;
  };

  adios = {
    inherit types lib merge;
    promise = import ./adios/promise.nix;
    eval =
      {
        root,
        options ? { },
      }:
      let
        tree = loadTree tree options root;
      in
      canonicalize tree;
    __functor =
      _: root:
      {
        options ? { },
      }:
      let
        tree = loadTree tree options root;
      in
      seq messages.callingAdiosWarning tree;
  };

in
adios
