module Lambda.Env
  ( initialTypeEnv
  , initialValueEnv
  ) where

import qualified Data.Map as M
import           Lambda.Type
import           Lambda.Runtime

-- Initial envs with primitives (including concat)
initialTypeEnv :: TypeEnv
initialTypeEnv = M.fromList
  [ ("add",    Forall [] (TyFun TyInt (TyFun TyInt TyInt)))
  , ("and",    Forall [] (TyFun TyBool (TyFun TyBool TyBool)))
  , ("not",    Forall [] (TyFun TyBool TyBool))
  , ("map",    Forall ["a","b"] (TyFun (TyFun (TyVar "a") (TyVar "b")) (TyFun (TyList (TyVar "a")) (TyList (TyVar "b")))))
  , ("foldr",  Forall ["a","b"] (TyFun (TyFun (TyVar "a") (TyFun (TyVar "b") (TyVar "b"))) (TyFun (TyVar "b") (TyFun (TyList (TyVar "a")) (TyVar "b")))))
  , ("cons",   Forall ["a"] (TyFun (TyVar "a") (TyFun (TyList (TyVar "a")) (TyList (TyVar "a")))))
  , ("concat", Forall ["a"] (TyFun (TyList (TyList (TyVar "a"))) (TyList (TyVar "a"))))
  ]

-- ===========================================
-- Built-in evaluation routines
-- ===========================================

expectInt :: String -> Value -> Either String Int
expectInt _ (VInt x)  = Right x
expectInt name v         = Left $ name ++ ": expected Int, got " ++ show v

expectBool :: String -> Value -> Either String Bool
expectBool _ (VBool x) = Right x
expectBool name v         = Left $ name ++ ": expected Bool, got " ++ show v

expectList :: String -> Value -> Either String [Value]
expectList _ (VList xs) = Right xs
expectList name v          = Left $ name ++ ": expected List, got " ++ show v

foldrM :: (t1 -> t2 -> Either a t2) -> t2 -> [t1] -> Either a t2
foldrM _ z [] = Right z
foldrM f z (x:xs) = do
  r <- foldrM f z xs
  f x r

concatLists [] = Right $ VList []
concatLists (VList xs : rest) =
  case concatLists rest of
    Right (VList ys) -> Right $ VList (xs ++ ys)
    Right bad        -> Left $ "concat: expected list, got " ++ show bad
    Left err         -> Left err
concatLists (bad : _) = Left $ "concat inner element not a list: " ++ show bad

initialValueEnv :: Env
initialValueEnv = M.fromList $
  [ ("add", VPrim2 $ \a b -> do
      x <- expectInt "add" a
      y <- expectInt "add" b
      pure (VInt (x + y)))

  , ("and", VPrim2 $ \a b -> do
      x <- expectBool "and" a
      y <- expectBool "and" b
      pure (VBool (x && y)))

  , ("not", VPrim1 $ \x -> do
      b <- expectBool "not" x
      pure (VBool (not b)))

  , ("cons", VPrim2 $ \h t -> do
      xs <- expectList "cons" t
      pure (VList (h:xs)))

  , ("map", VPrim2 $ \f xs -> do
      vs <- expectList "map" xs
      VList <$> traverse (applyValue f) vs)

  , ("foldr", VPrim2 $ \f z ->
      Right $ VPrim1 $ \xs -> do
        vs <- expectList "foldr" xs
        foldrM (\x acc -> do fx <- applyValue f x; applyValue fx acc) z vs)

  , ("concat", VPrim1 $ \xs -> do
      vss <- expectList "concat" xs
      concatLists vss)
  ]
