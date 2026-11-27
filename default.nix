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
    lists.concat = concatLists;
    strings.concatLines = concatStringsSep "\n";
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

  promise = {
    __functor = _: resolve: {
      __adiosPromise = true;
      inherit resolve;
    };
    map = seq messages.awaitWarning await;
  };

  await = await: {
    __adiosAwaiting = true;
    inherit await;
  };

  loadTree = import ./adios/loadTree.nix types messages;

  canonicalize =
    let
      recurse = mapAttrs (_: canonicalize);
    in
    module: {
      _module = module;
      ${if module.modules != { } then "modules" else null} = recurse module.modules;
      inherit (module) type;
      inherit (module.args) options inputs results;
      ${if module ? __functor then "__functor" else null} = module.__functor;
      ${if module ? __functor then "result" else null} = module.args.result;
    };

  adios = {
    inherit
      types
      lib
      merge
      promise
      await
      ;
    eval =
      root:
      let
        tree = loadTree tree null root;
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
