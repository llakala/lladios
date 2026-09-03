# Installation
To access the `adios` attribute set, use your favorite pinning tool (npins, flakes, tack, etc) and then import the root
of this repo. With flakes/tack it may also be more idiomatic to use this repo's `adios` flake output.

```nix
# Pinning without any tools (requires manual updates).
let
  adios = let
    # Replace this with the commit/tag you want to use.
    commit = "ec8d74d782820c915cff9cc0da48666efc4bad85";

    src = builtins.fetchTarball {
      url = "https://github.com/llakala/lladios/archive/${commit}.tar.gz";
      # Replace with the result from `nix-prefetch-url` or the fetch-time error.
      sha256 = "";
    };
  in
    import src;
in
  # Use adios as needed.
```

```nix
# Pinning with npins, or any similar source-based pinning tool.
let
  sources = import ./npins;

  adios = import sources.adios;
in
  # use adios as needed
```

```nix
# Pinning with flakes.
{
  inputs = {
    adios.url = "github:llakala/lladios";
  };

  outputs = inputs: let
    inherit (inputs.adios) adios;
  in
    # use adios as needed
}
```
