{ lib, ... }:
{
  # throwIf :: [AttrSet] -> Any -> Any
  # throwIf :: [{ assertion :: Boolean, message :: String }] -> a -> a
  # like assertions in evalModules
  throwIf = asserts: ctx:
    builtins.foldl' (ctx: a: lib.throwIf a.assertion a.message ctx) ctx asserts
  ;

  # throwIfNot :: [AttrSet] -> Any -> Any
  # throwIfNot :: [{ assertion :: Boolean, message :: String }] -> a -> a
  throwIfNot = asserts: ctx:
    builtins.foldl' (ctx: a: lib.throwIfNot a.assertion a.message ctx) ctx asserts
  ;
}
