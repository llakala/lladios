let
  inherit (builtins)
    elemAt
    foldl'
    head
    isAttrs
    isFunction
    length
    zipAttrsWith
    ;

  injectModule =
    canCall:
    zipAttrsWith (
      name: values:
      if length values == 1 then
        head values
      else
        let
          lhs = head values;
          rhsOld = elemAt values 1;
          # If current attribute is a module, allow rhs to read the old version
          # when determining its injection
          rhs = if canCall == true && isFunction rhsOld then rhsOld lhs else rhsOld;
        in
        if !isAttrs lhs || !isAttrs rhs then
          # TODO: consider throwing in the future if one side is a different
          # type than the other. alternatively, prevent recursing into values
          # like modules.options.foo.default
          rhs
        else
          injectModule (
            if canCall == null || canCall == false && name != "modules" then
              # We're either:
              # - about to enter another module field like `options` or `inputs`
              # - have already done that, and should continue to be null
              null
            else
              # we should toggle the state of inModule. We're either:
              # - Currently in some module foo (foo may be root), and are about to
              # enter `foo.modules`. allow calling modules with their old versions.
              # - Currently in `foo.modules`, and about to enter `foo.modules.bar`.
              # Don't allow calling modules this time (but possibly in two
              # iterations)
              !canCall
          ) [ lhs rhs ]
    );
in
foldl' (
  a: b:
  if a == { } then
    b
  else
    injectModule true [ a b ]
) { }
