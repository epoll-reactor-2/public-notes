{-# LANGUAGE LambdaCase #-}

module Language.Env
  ( initialEnv
  ) where

import qualified Data.Map.Strict as M
import           Language.Core

primBinInt :: String -> (Int -> Int -> Int) -> Value
primBinInt name f = VPrim name $ \case
  [VInt a, VInt b] -> return $ VInt $ f a b
  args -> Left $ "builtin " ++ name ++ " expects two ints, got " ++ show args

primDiv :: Value
primDiv = VPrim "/" $ \case
  [VInt _, VInt 0] -> Left "division by zero"
  [VInt a, VInt b] -> return $ VInt (a `div` b)
  xs -> Left $ "/ expects two ints, got " ++ show xs

primCmp :: String -> (Int -> Int -> Bool) -> Value
primCmp name cmp = VPrim name $ \case
  [VInt a, VInt b] -> return $ if cmp a b then VInt 1 else VInt 0
  _ -> Left $ name ++ " expects two ints"

primLogic :: String -> (Int -> Int -> Int) -> Value
primLogic name f = VPrim name $ \case
  [VInt a, VInt b] -> return $ VInt (f a b)
  _ -> Left $ name ++ " expects two ints"

primAnd = primLogic "&&" (\a b -> if a /= 0 && b /= 0 then 1 else 0)
primOr  = primLogic "||" (\a b -> if a /= 0 || b /= 0 then 1 else 0)

primNot :: Value
primNot = VPrim "not" $ \case
  [VInt a] -> return $ VInt (if a == 0 then 1 else 0)
  _ -> Left "not expects one int"

initialEnv :: Env
initialEnv = M.fromList
  [ ("+",     primBinInt "+" (+))
  , ("-",     primBinInt "-" (-))
  , ("*",     primBinInt "*" (*))
  , ("%",     primBinInt "%" mod)
  , ("/",     primDiv)
  -- Comparisons
  , ("==", primCmp "==" (==))
  , ("!=", primCmp "!=" (/=))
  , ("<",  primCmp "<"  (<))
  , ("<=", primCmp "<=" (<=))
  , (">",  primCmp ">"  (>))
  , (">=", primCmp ">=" (>=))
  -- Logic
  , ("&&",  primAnd)
  , ("||",  primOr)
  , ("not", primNot)
  , ("nil",   VUnit)
  ]

