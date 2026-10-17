{
  __functor = _: resolve: {
    __adiosPromise = true;
    inherit resolve;
  };
  map = await: {
    __adiosAwaiting = true;
    inherit await;
  };
}
