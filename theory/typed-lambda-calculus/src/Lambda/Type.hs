module Lambda.Type
  ( Type(..)
  , TypeEnv
  , TypeScheme(..)
  , Expr(..)
  , runInfer
  , generalize
  ) where

import qualified Data.Map as M
import qualified Data.Set as S
import           Data.Map (Map)
import           Data.Set (Set)
import           Control.Monad.State
import           Control.Monad.Except
import           Data.Maybe (fromMaybe)

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

-- Type schemes
data TypeScheme = Forall [String] Type

-- Expressions are there since depends on type and type
-- inference works on expressions.
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
