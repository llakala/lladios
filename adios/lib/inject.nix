let
  inherit (builtins)
    elemAt
    foldl'
    head
    isAttrs
    length
    zipAttrsWith
    ;

  recurse = zipAttrsWith (
    name: values:
    if length values == 1 then
      # only one side, stop recursing
      head values
    else
      let
        lhs = elemAt values 1;
        rhs = head values;
      in
      if !isAttrs rhs then
        # can't recurse, not awaiting. rhs wins
        rhs
      else if rhs.__adiosAwaiting or false then
        # awaiting a previous value to inject into it
        if (lhs.__adiosPromise or false) then
          # left side is a promise, create a new promise that calls the old one
          lhs
          // {
            awaiters = (lhs.awaiters or [ ]) ++ [ rhs.await ];
          }
        else
          # left side wasn't a promise, pass the prev value directly
          rhs.await lhs
      else if !isAttrs lhs then
        # left isn't an attrset, rhs wins
        rhs
      else
        # lhs and rhs are both non-promise attrsets
        recurse values
  );
in
foldl' (
  a: b:
  if a == {} then
    b
  else
    recurse [ b a ]
) {}
