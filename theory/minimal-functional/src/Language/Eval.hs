{-# LANGUAGE LambdaCase #-}

module Language.Eval
  ( eval
  ) where

import qualified Data.Map.Strict as M
import           Language.Core

-- Force: resolve VRec to its evaluated value (no memoization here)
force :: Value -> EvalResult Value
force v@(VRec name expr env) = do
  (val, _) <- eval env' expr
  Right val
  where
    env' = M.insert name v env
force v = Right v

-- Pattern matching: if pattern matches value, return bindings map
matchPattern :: Pattern -> Value -> Env -> EvalResult (M.Map String Value)
matchPattern pat val env = case pat of
  PWild ->
    Right M.empty

  PInt n ->
    case val of
      VInt m | m == n -> Right M.empty
      _               -> Left $ "pattern int " ++ show n ++ " doesn't match " ++ show val

  PUnitP ->
    case val of
      VUnit -> Right M.empty
      _     -> Left $ "pattern () doesn't match " ++ show val

  PVar x ->
    Right $ M.singleton x val

  PTupleP l r ->
    case val of
      VPair a b -> do
        m1 <- matchPattern l a env
        m2 <- matchPattern r b env
        mergeMaps m1 m2
      _ -> Left $ "tuple pattern doesn't match " ++ show val

  PGuard guardFn expr -> do
    (fnObj, _) <- eval env guardFn
    (branchVal, _) <- eval env expr

    case fnObj of
      VPrim _ f -> do
        result <- f [val, branchVal]
        case result of
          VInt 0 -> Left "guard failed"
          VInt _ -> Right M.empty
          _      -> Left "guard must return int (0=false, nonzero=true)"
      _ -> Left $ "guard function did not evaluate to a function: " ++ show fnObj

  where
    mergeMaps a b =
      if null (M.keys (M.intersection a b))
        then Right (a `M.union` b)
        else Left "duplicate variable in patterns"

apply :: Value -> [Value] -> Env -> EvalResult Value
apply v args env = do
  v' <- force v
  case v' of
    -- Built-in function. Call from host.
    VPrim _ f -> f args
    -- External function. Evaluate.
    VFun patterns body closureEnv -> do
      if length patterns /= length args
        then Left $ "arity mismatch: expected " ++ show (length patterns) ++ ", got " ++ show (length args)
        else do
          maps <- sequence $ zipWith (\p a -> matchPattern p a env) patterns args
          let merged = foldl M.union M.empty maps
          (result, _) <- eval (merged `M.union` closureEnv) body
          Right result
    _ -> Left $ "attempt to call non-function " ++ show v'

evalArgs :: Env -> [Expr] -> EvalResult [Value]
evalArgs env exprs = do
  pairs <- mapM (eval env) exprs
  Right $ map fst pairs

eval :: Env -> Expr -> EvalResult (Value, Env)
eval env = \case
  EInt n ->
    Right (VInt n, env)

  EVar x ->
    case M.lookup x env of
      Just v  -> Right (v, env)
      Nothing -> Left $ "unbound variable: " ++ x

  EUnit ->
    Right (VUnit, env)

  ETuple a b -> do
    (a', _) <- eval env a
    (b', _) <- eval env b
    Right ((VPair a' b'), env)

  ECall fnRef args -> do
    (fnObj, _) <- eval env fnRef
    argvs <- evalArgs env args
    case apply fnObj argvs env of
      Left err -> Left $ err
      Right result -> Right (result, env)

  ELam patterns body ->
    Right (VFun patterns body env, env)

  ECase scrut branches -> do
    (caseValue, _) <- eval env scrut
    tryBranches caseValue branches
    where
      tryBranches :: Value -> [(Pattern, Expr)] -> EvalResult (Value, Env)
      tryBranches _ [] = Left "non-exhaustive patterns in case"
      tryBranches v ((pattern, expr):xs) =
        case matchPattern pattern v env of
          Right binds -> eval (binds `M.union` env) expr
          Left _ -> tryBranches v xs

  -- Function inserted to the environment, then evaluated.
  ELet name rhs body -> do
    -- Recursive binding: name maps to VRec and is visible in rhs and body
    let rec = VRec name rhs env'
        env' = M.insert name rec env
    eval env' body
