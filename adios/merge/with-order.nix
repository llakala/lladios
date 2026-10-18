let
  sortByOrder = builtins.sort (a: b: a.order < b.order);
  mapValues = map (mutation: mutation.value);
in
mergeFunc: definitions: mergeFunc (mapValues (sortByOrder definitions))
