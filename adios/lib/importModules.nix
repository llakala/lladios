{ adios }:

let
  inherit (builtins)
    attrNames
    concatMap
    head
    isAttrs
    listToAttrs
    match
    pathExists
    readDir
    warn
    ;

  matchNixFile = match "(.+)\\.nix$";
in
params:
let
  deprecatedParams = !isAttrs params;
  dir = if deprecatedParams then params else params.directory;
  args = if deprecatedParams then adios else params.args or adios;
  files = readDir dir;
  result = listToAttrs (
    concatMap (
      name:
      if files.${name} == "directory" then
        if pathExists (dir + "/${name}/default.nix") then
          [
            {
              inherit name;
              value = import (dir + "/${name}") args;
            }
          ]
        else
          [ ]
      else
        let
          m = matchNixFile name;
          moduleName = head m;
        in
        if m != null && name != "default.nix" then
          [
            {
              name =
                if files ? ${moduleName} then
                  throw ''
                    Module ${moduleName} was provided by both:
                    - ${dir}/${moduleName}/default.nix
                    - ${name}

                    This is ambigious. Restructure your code to not have ambigious module names.
                  ''
                else
                  moduleName;
              value = import (dir + "/${name}") args;
            }
          ]
        else
          [ ]
    ) (attrNames files)
  );
in
if deprecatedParams then
  warn ''
    `adios.lib.importModules` was passed path '${toString dir}' directly. This is
    deprecated in favor of structured attributes:

    ```nix
    adios.lib.importModules { directory = <your-dir-here>; }
    ```

    See the changelog for more info:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#structured-importmodules'' result
else
  result
