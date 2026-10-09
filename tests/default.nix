# run `nix-unit tests` to make sure the tests pass
let
  inherit (builtins) mapAttrs;
  adios = import ../.;

  mkTest =
    testName:
    {
      module ? null,
      modules ? null,
      evalParams ? { },
      apply ? null,
      expected ? null,
      expectedError ? null,
    }:
    let
      tree = adios (
        if modules != null then
          { inherit modules; }
        else if module != null then
          module
        else
          throw "test '${testName}' didn't provide a 'modules' or 'module' argument!"
      ) evalParams;
    in
    assert (module == null) != (modules == null);
    assert (expected == null) != (expectedError == null);
    {
      expr = if apply != null then apply tree else tree { };
      ${if expected != null then "expected" else null} = expected;
      ${if expectedError != null then "expectedError" else null} = expectedError;
    };

  testFiles =
    (adios.lib.importModules { directory = ./.; })
    // (adios.lib.importModules { directory = ./mergeFuncs; });

in
mapAttrs (
  fileName:
  mapAttrs (name: test: if test ? expr then test else mkTest "${fileName}/${name}" test)
) testFiles
