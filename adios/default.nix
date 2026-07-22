(builtins.warn or builtins.trace) ''
  Importing Adios through the adios folder has been deprecated.

  Where one would previously do:

  ```nix
    adios = import "''${sources.adios}/adios";
  ```

  You should now do:
  ```nix
    adios = import sources.adios;
  ```

  For rationale, see the changelog:
  https://github.com/llakala/lladios/blob/main/CHANGELOG.md#only-one-adios-entrypoint
'' (import ../.)
