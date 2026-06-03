let
  inherit (builtins) sort;
in
mergeFunc:
{ mutators }:
mergeFunc {
  mutators = map (mutation: mutation.value) (sort (a: b: a.order < b.order) mutators);
}
