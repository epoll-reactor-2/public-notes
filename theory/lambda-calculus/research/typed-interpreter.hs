-- Call-by-value interpreter with Hindley-Milner type system.

{-# LANGUAGE DeriveFunctor #-}

module Main where

import qualified Data.Map as M
import Data.Map (Map)
import qualified Data.Set as S
import Data.Set (Set)
import Control.Monad.State
import Control.Monad.Except
import Data.Maybe (fromMaybe)

-- Types
data Type
  = TyInt
  | TyBool
  | TyList Type
  | TyFun Type Type
  | TyVar String
  deriving (Eq, Ord)

instance Show Type where
  show TyInt       = "Int"
  show TyBool      = "Bool"
  show (TyList t)  = "List [" ++ show t ++ "]"
  show (TyFun a b) = "(" ++ show a ++ " -> " ++ show b ++ ")"
  show (TyVar v)   = v

-- Expressions (no cons, map, fold, concat)
data Expr
  = Var String
  | Lam String Type Expr
  | App Expr Expr
  | Let String Expr Expr
  | LitInt Int
  | LitBool Bool
  | Nil Type
  deriving (Eq)

instance Show Expr where
  show (Var x)     = show x
  show (Lam n t e) = "λ:" ++ show t ++ " " ++ show e
  show (App l r)   = "(" ++ show l ++ ", " ++ show r ++ ")"
  show (Let s l r) = "let " ++ show l ++ " " ++ show r
  show (LitInt i)  = show i
  show (LitBool b) = show b
  show (Nil _)     = "nil"

-- Runtime values
data Value
  = VInt Int
  | VBool Bool
  | VList [Value]
  | VClosure String Expr Env
  | VPrim1 (Value -> Either String Value)
  | VPrim2 (Value -> Value -> Either String Value)

instance Show Value where
  show (VInt n) = show n
  show (VBool b) = show b
  show (VList vs) = "[" ++ comma vs ++ "]"
    where
      comma [] = ""
      comma [x] = show x
      comma (x:xs) = show x ++ ", " ++ comma xs
  show (VClosure {}) = "<closure>"
  show (VPrim1 {}) = "<prim1>"
  show (VPrim2 {}) = "<prim2>"

-- Type schemes
data TypeScheme = Forall [String] Type

-- ===========================================
-- Types and Substitutions
-- ===========================================

-- A substitution is a mapping from type variables (String)
-- to concrete Types. This is used in type inference to
-- "remember" what each type variable should actually be.
type Subst = Map String Type

-- The empty substitution: no type variables are replaced.
nullSubst :: Subst
nullSubst = M.empty

-- Compose two substitutions:
-- First apply the left substitution to all types in the right substitution,
-- then union them. This ensures that if the right substitution maps
-- "a -> b", and the left says "b -> Int", the final result maps
-- "a -> Int". Left substitution takes priority if both define the same key.
composeSubst :: Subst -> Subst -> Subst
composeSubst l r = M.map (applySubst l) r `M.union` l

-- ===========================================
-- Substitutable Type Class
-- ===========================================

-- This class abstracts "things we can substitute type variables in".
-- Examples: Type, TypeScheme, list of types.
class Substitutable a where
  -- Apply a given substitution to the object
  applySubst :: Subst -> a -> a
  -- Compute the set of free type variables (FTVs) in the object
  ftv        :: a -> Set String

-- Implementation for Type:
-- Apply substitution recursively to all type constructors.
instance Substitutable Type where
  applySubst s t = case t of
    TyInt        -> TyInt
    TyBool       -> TyBool
    TyList x     -> TyList (applySubst s x)
    TyFun a b    -> TyFun (applySubst s a) (applySubst s b)
    TyVar v      -> fromMaybe (TyVar v) (M.lookup v s)

  -- FTV - Free Type Variables
  -- This returns all unbound type variables inside this type.
  ftv t = case t of
    TyInt        -> S.empty                 -- Int has no variables
    TyBool       -> S.empty                 -- Bool has no variables
    TyList x     -> ftv x                   -- Free variables are those in x
    TyFun a b    -> ftv a `S.union` ftv b   -- ... or in a, b
    TyVar v      -> S.singleton v           -- Free variable is just v

-- TypeScheme: a polymorphic type like ∀a. a -> a
-- We must remove quantified variables from substitution (cannot substitute them).
instance Substitutable TypeScheme where
  applySubst s (Forall vars t) =
    let s' = foldr M.delete s vars -- Remove bound variables.
    in Forall vars (applySubst s' t)

  -- Free variables = free vars of t minus those quantified by Forall
  ftv (Forall vars t) = ftv t `S.difference` S.fromList vars

-- Lists of Substitutables: apply substitution element-wise
instance Substitutable a => Substitutable [a] where
  applySubst s = map (applySubst s)
  ftv xs = foldr (S.union . ftv) S.empty xs

-- ===========================================
-- Type Environment
-- ===========================================

-- TypeEnv maps variable names (String) to TypeSchemes.
-- Example: { "id" ↦ ∀a. a -> a }
type TypeEnv = Map String TypeScheme

-- Remove a variable from the type environment.
-- This is used to ensure we don't accidentally use a shadowed variable.
removeEnv :: TypeEnv -> String -> TypeEnv
removeEnv env var = M.delete var env

-- Generalization:
-- Turn a monomorphic type into a polymorphic type scheme (∀-quantified),
-- by finding all free type variables in 't' that are not already fixed
-- by the environment.
--
-- Example:
--   env: { "x" : Int }
--   t:   a -> a
--   Result: ∀a. a -> a   (because "a" is free and not bound by env)
generalize :: TypeEnv -> Type -> TypeScheme
generalize env t =
  let vars = S.toList (ftv t `S.difference` ftv (M.elems env))
  in Forall vars t

-- ===========================================
-- Type Inference Monad
-- ===========================================

-- TI is a StateT that carries an integer counter for fresh type variables,
-- and can fail with an error message (Either String).
--
-- We can put and pop integer from this state, perserving it between
-- calls. This works more like static variable in imperative languages.
type TI a = StateT Int (Either String) a

-- m parameter represent some computation with initial parameter. In
-- this case, we start from zero.
runTI :: TI a -> Either String a
runTI m = evalStateT m 0

-- Generate a fresh type variable: a#0, a#1, ...
-- This is essential for type inference, e.g. for function arguments
-- where the type is initially unknown.
fresh :: TI Type
fresh = do
  n <- get
  put (n + 1)
  return $ TyVar ("a#" ++ show n)

-- Instantiate a polymorphic type scheme into a fresh monotype.
-- Replace all quantified variables with fresh type variables.
-- Example:
--   Forall [a] (a -> a)  becomes  a#0 -> a#0
instantiate :: TypeScheme -> TI Type
instantiate (Forall vars t) = do
  newVars <- mapM (const fresh) vars
  let s = M.fromList (zip vars newVars)
  return $ applySubst s t

-- Return True if variable v appears inside type t.
-- Used in bindVar to avoid creating infinite types like
-- a = a -> Int.
occursCheck :: String -> Type -> Bool
occursCheck v t = S.member v (ftv t)

-- ===========================================
-- Binding a Type Variable to a Type
-- ===========================================

-- bindVar creates a substitution { v ↦ t }, but first checks:
--  1. If v and t are identical (TyVar v == t), return empty substitution.
--  2. If v occurs inside t (occurs check), fail to avoid infinite types.
--  3. Otherwise, return a singleton substitution mapping v to t.
bindVar :: String -> Type -> TI Subst
bindVar v t
  | t == TyVar v = return nullSubst
  | occursCheck v t = lift $ Left $ "Occurs check failed: " ++ v ++ " in " ++ show t
  | otherwise = return $ M.singleton v t

-- unify tries to make two types equal by returning a substitution
-- that, when applied to both, makes them identical.
-- For example:
--   unify (a -> Int) (Bool -> b)
-- returns { a ↦ Bool, b ↦ Int }
unify :: Type -> Type -> TI Subst
unify l r = case (l, r) of
  (TyFun l1 r1, TyFun l2 r2) -> do
    s1 <- unify l1 l2
    s2 <- unify (applySubst s1 r1) (applySubst s1 r2)
    return (composeSubst s1 s2)
  (TyList x, TyList y) -> unify x y
  (TyVar v, t)         -> bindVar v t
  (t, TyVar v)         -> bindVar v t
  (TyInt, TyInt)       -> return nullSubst
  (TyBool, TyBool)     -> return nullSubst
  _                    -> lift $ Left $ "Types do not unify: " ++ show l ++ " vs " ++ show r

-- ===========================================
-- Type Inference
-- ===========================================

-- infer takes a TypeEnv and an expression, and returns:
--  * a substitution (mapping type vars to concrete types)
--  * the inferred type of the expression
--
-- It implements Hindley-Milner style inference:
-- * instantiate types for variables
-- * infer argument/result types for lambdas
-- * unify function types for applications
-- * generalize types for let-bindings
infer :: TypeEnv -> Expr -> TI (Subst, Type)
infer env expr = case expr of

  -- Variable lookup: instantiate its polymorphic type scheme
  Var x -> case M.lookup x env of
    Nothing -> lift $ Left $ "Unbound variable: " ++ x
    Just scheme -> do
      t <- instantiate scheme
      return (nullSubst, t)

  -- Literals have known types
  LitInt  _ -> return (nullSubst, TyInt)
  LitBool _ -> return (nullSubst, TyBool)
  Nil t     -> return (nullSubst, TyList t)

  -- Lambda abstraction: extend environment with parameter type
  Lam x ty body -> do
    let env' = M.insert x (Forall [] ty) env
    (s1, tbody) <- infer env' body
    return (s1, TyFun (applySubst s1 ty) tbody)

  -- Function application: infer function type and argument type,
  -- unify them with a fresh return type.
  App f a -> do
    (s1, tf) <- infer env f
    (s2, ta) <- infer (applyEnv s1 env) a
    tv <- fresh
    s3 <- unify (applySubst s2 tf) (TyFun ta tv)
    let s = composeSubst s3 (composeSubst s2 s1)
    return (s, applySubst s3 tv)

  -- Let binding: infer type of e1, generalize it, and use it in e2.
  Let x e1 e2 -> do
    (s1, t1) <- infer env e1
    let env' = applyEnv s1 env
    let scheme = generalize env' t1
    (s2, t2) <- infer (M.insert x scheme env') e2
    return (composeSubst s2 s1, t2)

-- Apply a substitution to every type in a type environment,
-- but make sure we don't substitute variables that are quantified
-- by the scheme (they are locally bound).
applyEnv :: Subst -> TypeEnv -> TypeEnv
applyEnv s env = M.map (\(Forall vars t) -> Forall vars (applySubst (foldr M.delete s vars) t)) env

runInfer :: TypeEnv -> Expr -> Either String Type
runInfer env e = runTI $ do
  (s, t) <- infer env e
  return (applySubst s t)

-- ===========================================
-- Runtime Environment and Evaluation
-- ===========================================

-- Env maps variable names to runtime values.
type Env = Map String Value

-- Function application at runtime:
-- 1. If we have a closure, extend its environment with the argument and evaluate.
-- 2. If we have a curried primitive (VPrim2), turn it into a unary primitive (VPrim1).
-- 3. If we have a unary primitive, apply it directly.
-- Otherwise: runtime error (cannot apply a non-function).
applyValue :: Value -> Value -> Either String Value
applyValue (VClosure x body env) v = evalExpr (M.insert x v env) body
applyValue (VPrim2 f) v1 = Right $ VPrim1 (f v1)
applyValue (VPrim1 f) v1 = f v1
applyValue other _ = Left $ "Attempt to apply non-function value: " ++ show other

-- Expression evaluator:
-- Walk the AST and produce a Value, using call-by-value semantics.
evalExpr :: Env -> Expr -> Either String Value
evalExpr env expr = case expr of
  -- Look up variable in runtime environment
  Var x -> maybe (Left $ "Unbound variable: " ++ x) Right (M.lookup x env)

  -- Build a closure: capture current environment
  Lam x _ body -> Right $ VClosure x body env

  -- Application: evaluate function and argument, then apply
  App a b -> do
    fa <- evalExpr env a
    fb <- evalExpr env b
    applyValue fa fb

  -- Let binding: evaluate e1, insert into env, then eval e2
  Let x e1 e2 -> do
    v1 <- evalExpr env e1
    evalExpr (M.insert x v1 env) e2

  LitInt n -> Right $ VInt n
  LitBool b -> Right $ VBool b
  Nil _ -> Right $ VList []

evalExprSteps :: TypeEnv -> Env -> Expr -> Int -> Either String [(Expr, Type, Value, Int)]
evalExprSteps typeEnv valEnv expr depth = go typeEnv valEnv expr depth
  where
    go tenv venv e depth = case e of
      Var x ->
        case (M.lookup x venv, M.lookup x tenv) of
          (Just v, Just scheme) -> do
            ty <- runInfer tenv (Var x)
            Right [(e, ty, v, depth)]
          (Nothing, _) -> Left $ "Unbound variable: " ++ x
          (_, Nothing) -> Left $ "No type for variable: " ++ x

      Lam x ty body -> do
        let tenv' = M.insert x (Forall [] ty) tenv
        let v = VClosure x body venv
        tyBody <- runInfer tenv' body
        Right [(e, TyFun ty tyBody, v, depth)]

      App a b -> do
        -- reduce function
        stepsA <- go tenv venv a (depth + 1)
        let (_, _, fa, _) = last stepsA
        -- reduce argument
        stepsB <- go tenv venv b (depth + 1)
        let (_, _, fb, _) = last stepsB
        -- apply
        fv <- applyValue fa fb
        ty <- runInfer tenv (App a b)
        Right (stepsA ++ stepsB ++ [(e, ty, fv, depth)])

      Let x e1 e2 -> do
        steps1 <- go tenv venv e1 depth
        let (_, t1, v1, _) = last steps1
        let tenv' = M.insert x (generalize tenv t1) tenv
        steps2 <- go tenv' (M.insert x v1 venv) e2 depth
        Right (steps1 ++ steps2)

      LitInt n  -> Right [( e, TyInt,    VInt n,   depth )]
      LitBool b -> Right [( e, TyBool,   VBool b,  depth )]
      Nil t     -> Right [( e, TyList t, VList [], depth )]

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
expectInt name (VInt x)  = Right x
expectInt name v         = Left $ name ++ ": expected Int, got " ++ show v

expectBool :: String -> Value -> Either String Bool
expectBool name (VBool x) = Right x
expectBool name v         = Left $ name ++ ": expected Bool, got " ++ show v

expectList :: String -> Value -> Either String [Value]
expectList name (VList xs) = Right xs
expectList name v          = Left $ name ++ ": expected List, got " ++ show v

foldrM f z [] = Right z
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
  [ ("add",    VPrim2 $ \a b -> do
      x <- expectInt "add" a
      y <- expectInt "add" b
      pure (VInt (x + y)))

  , ("and",    VPrim2 $ \a b -> do
      x <- expectBool "and" a
      y <- expectBool "and" b
      pure (VBool (x && y)))

  , ("not",    VPrim1 $ \x -> do
      b <- expectBool "not" x
      pure (VBool (not b)))

  , ("cons",   VPrim2 $ \h t -> do
      xs <- expectList "cons" t
      pure (VList (h:xs)))

  , ("map",    VPrim2 $ \f xs -> do
      vs <- expectList "map" xs
      VList <$> traverse (applyValue f) vs)

  , ("foldr",  VPrim2 $ \f z ->
      Right $ VPrim1 $ \xs -> do
        vs <- expectList "foldr" xs
        foldrM (\x acc -> do fx <- applyValue f x; applyValue fx acc) z vs)

  , ("concat", VPrim1 $ \xs -> do
      vss <- expectList "concat" xs
      concatLists vss)
  ]

-- ===========================================
-- Playground
-- ===========================================

listInts :: Expr
listInts =
  App (App (Var "cons") (LitInt 1))
    (App (App (Var "cons") (LitInt 2))
      (App (App (Var "cons") (LitInt 3))
        (Nil TyInt)))

listBools :: Expr
listBools =
  App (App (Var "cons") (LitBool True))
    (App (App (Var "cons") (LitBool True))
      (App (App (Var "cons") (LitBool False))
        (Nil TyBool)))

listOfLists :: Expr
listOfLists =
  App (App (Var "cons") listInts)
    (App (App (Var "cons") listInts)
      (Nil (TyList TyInt)))

testExprInts :: Expr
testExprInts =
  App
    (App (Var "map") (Lam "x" (TyVar "a") (Var "x"))) -- map id
    listInts

testExprBools :: Expr
testExprBools =
  App
    (App (Var "map") (Lam "x" (TyVar "a") (Var "x"))) -- map id
    listBools

main :: IO ()
main = do
  putStrLn "=== Running map id on listInts ==="
  runTest testExprInts
  putStrLn ""
  putStrLn "=== Running map id on listBools ==="
  runTest testExprBools

  where
    runTest expr =
      case evalExprSteps initialTypeEnv initialValueEnv expr 0 of
        Left err -> putStrLn $ "Error: " ++ err
        Right steps ->
          mapM_ (\(ex, ty, v, d) ->
            putStrLn ((concat (replicate d " |"))
              ++ " "
              ++  show ex
              -- ++ " :: " ++ show ty
              ++ "  ==>  "
              ++ show v
            )) $
            filter (not . isLiteralOrNil . (\(ex,_,_,_) -> ex)) steps

    isLiteralOrNil :: Expr -> Bool
    isLiteralOrNil e = case e of
      LitBool _   -> True
      LitInt _    -> True
      Nil _       -> True
      _           -> False
