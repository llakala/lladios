let
  inherit (builtins)
    attrNames
    attrValues
    concatStringsSep
    foldl'
    head
    intersectAttrs
    length
    zipAttrsWith
    ;

  printList = list: "[${concatStringsSep ", " list}]";

  # If we detect a name collision, we run more expensive logic to get
  # metadata on which mutators collided, and on which keys. If there's no
  # collisions, this is never evaluated.
  makeErrorMessage =
    mutators:
    let
      checkPreviousMutators =
        prevNames: name:
        foldl' (
          data: prevName:
          let
            intersection = intersectAttrs mutators.${name} mutators.${prevName};
          in
          if intersection != { } && data == null then
            {
              name = prevName;
              sharedKeys = attrNames intersection;
            }
          else
            data
        ) null prevNames;

    in
    foldl' (
      prevNames: name:
      let
        # Each mutator checks whether it has collisions with the previous
        # mutators.
        collisionData = checkPreviousMutators prevNames name;
      in
      if collisionData == null then
        prevNames ++ [ name ]
      else if length collisionData.sharedKeys == 1 then
        throw ''
          Collision between mutators '${collisionData.name}' and '${name}' on key '${head collisionData.sharedKeys}'.
        ''
      else
        throw ''
          Collision between mutators '${collisionData.name}' and '${name}' on keys ${printList collisionData.sharedKeys}.
        ''
    ) [ ] (attrNames mutators);
in
{ mutators }:
zipAttrsWith (
  _: values:
  if length values == 1 then
    # Only one mutator
    head values
  else
    makeErrorMessage mutators
) (attrValues mutators)
