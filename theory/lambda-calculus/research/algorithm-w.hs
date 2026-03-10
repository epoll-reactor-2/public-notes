-- AlgorithmW.hs
-- A working, self-contained implementation of Algorithm W
-- Cleaned up from: "Algorithm W Step by Step" (Martin Grabmüller)
-- Tested with recent GHC versions.
--
-- File also represents core Hindley-Milner type system implementation.

module Main where

import qualified Data.Map  as Map
import qualified Data.Set  as Set
import           Data.Map  (Map)
import           Data.Set  (Set)
import           Control.Monad.Except
import           Control.Monad.State
import           Data.Char (chr)

--------------------------------------------------------------------------------
-- Syntax (Expressions, Literals), Types, and Schemes
--------------------------------------------------------------------------------

data Exp
  = EVar String
  | ELit Lit
  | EApp Exp Exp
  | EAbs String Exp
  | ELet String Exp Exp
  deriving (Eq, Ord)

data Lit
  = LInt Integer
  | LBool Bool
  deriving (Eq, Ord)

data Type
  = TVar String
  | TInt
  | TBool
  | TFun Type Type
  deriving (Eq, Ord)

data Scheme = Scheme [String] Type

--------------------------------------------------------------------------------
-- Pretty-printing (simple Show instances)
--------------------------------------------------------------------------------

instance Show Type where
  showsPrec _ (TVar n)     = showString n
  showsPrec _ TInt         = showString "Int"
  showsPrec _ TBool        = showString "Bool"
  showsPrec p (TFun a b)   =
    showParen (p > 0) $
      showsPrec 1 a . showString " -> " . showsPrec 0 b

instance Show Exp where
  showsPrec _ (EVar n)         = showString n
  showsPrec _ (ELit l)         = shows l
  showsPrec _ (EApp e1 e2)     = showString "(" . shows e1 . showString " " . shows e2 . showString ")"
  showsPrec _ (EAbs n e)       = showString "(\\" . showString n . showString " -> " . shows e . showString ")"
  showsPrec _ (ELet x b body)  =
    showString "(let " . showString x . showString " = " . shows b
    . showString " in " . shows body . showString ")"

instance Show Lit where
  showsPrec _ (LInt i)  = shows i
  showsPrec _ (LBool b) = showString (if b then "True" else "False")

instance Show Scheme where
  showsPrec _ (Scheme vars t) =
    showString "All " . showString (unwords vars) . showString ". " . shows t

--------------------------------------------------------------------------------
-- Types class: free type variables (ftv) and substitution (apply)
--------------------------------------------------------------------------------

type Subst = Map String Type

class Types a where
  ftv   :: a -> Set String
  apply :: Subst -> a -> a

instance Types Type where
  ftv (TVar n)     = Set.singleton n
  ftv TInt         = Set.empty
  ftv TBool        = Set.empty
  ftv (TFun a b)   = ftv a `Set.union` ftv b

  apply s (TVar n) = case Map.lookup n s of
                       Nothing -> TVar n
                       Just t  -> t
  apply s (TFun a b) = TFun (apply s a) (apply s b)
  apply _ t           = t

instance Types Scheme where
  ftv (Scheme vars t) = ftv t `Set.difference` Set.fromList vars
  apply s (Scheme vars t) =
    let s' = foldr Map.delete s vars
    in Scheme vars (apply s' t)

instance Types a => Types [a] where
  ftv   = foldr (Set.union . ftv) Set.empty
  apply = map . apply

--------------------------------------------------------------------------------
-- Type environments
--------------------------------------------------------------------------------

newtype TypeEnv = TypeEnv (Map String Scheme)

instance Types TypeEnv where
  ftv (TypeEnv env)    = ftv (Map.elems env)
  apply s (TypeEnv e)  = TypeEnv (Map.map (apply s) e)

remove :: TypeEnv -> String -> TypeEnv
remove (TypeEnv env) var = TypeEnv (Map.delete var env)

generalize :: TypeEnv -> Type -> Scheme
generalize env t =
  let vars = Set.toList (ftv t `Set.difference` ftv env)
  in Scheme vars t

--------------------------------------------------------------------------------
-- Inference monad, fresh type variables, instantiation
--------------------------------------------------------------------------------

type TIState = Int
type TI a    = ExceptT String (State TIState) a

runTI :: TI a -> (Either String a, TIState)
runTI m = runState (runExceptT m) 0

-- Generate fresh type variables: a, b, c, ..., z, aa, ab, ...
newTyVar :: TI Type
newTyVar = do
  s <- get
  put (s + 1)
  pure (TVar (toTyVar s))
  where
    toTyVar :: Int -> String
    toTyVar c
      | c < 26    = [chr (97 + c)]  -- 'a'..'z'
      | otherwise = let (n, r) = c `divMod` 26
                    in  chr (97 + r) : toTyVar (n - 1)

instantiate :: Scheme -> TI Type
instantiate (Scheme vars t) = do
  nvars <- mapM (const newTyVar) vars
  let s = Map.fromList (zip vars nvars)
  pure (apply s t)

--------------------------------------------------------------------------------
-- Substitutions and unification
--------------------------------------------------------------------------------

nullSubst :: Subst
nullSubst = Map.empty

composeSubst :: Subst -> Subst -> Subst
composeSubst s1 s2 = (Map.map (apply s1) s2) `Map.union` s1

mgu :: Type -> Type -> TI Subst
mgu (TFun l r) (TFun l' r') = do
  s1 <- mgu l l'
  s2 <- mgu (apply s1 r) (apply s1 r')
  pure (s2 `composeSubst` s1)
mgu (TVar u) t              = varBind u t
mgu t (TVar u)              = varBind u t
mgu TInt TInt               = pure nullSubst
mgu TBool TBool             = pure nullSubst
mgu t1 t2                   = throwError $ "types do not unify: " ++ show t1 ++ " vs. " ++ show t2

varBind :: String -> Type -> TI Subst
varBind u t
  | t == TVar u               = pure nullSubst
  | u `Set.member` ftv t      = throwError $ "occurs check fails: " ++ u ++ " vs. " ++ show t
  | otherwise                 = pure (Map.singleton u t)

--------------------------------------------------------------------------------
-- Type inference (Algorithm W)
--------------------------------------------------------------------------------

tiLit :: Lit -> TI (Subst, Type)
tiLit (LInt  _) = pure (nullSubst, TInt)
tiLit (LBool _) = pure (nullSubst, TBool)

ti :: TypeEnv -> Exp -> TI (Subst, Type)
ti (TypeEnv env) (EVar n) =
  case Map.lookup n env of
    Nothing     -> throwError $ "unbound variable: " ++ n
    Just sigma  -> do t <- instantiate sigma
                      pure (nullSubst, t)

ti _ (ELit l) =
  tiLit l

ti env (EAbs n e) = do
  tv <- newTyVar
  -- Shadow n with a fresh monomorphic assumption
  let TypeEnv env'  = remove env n
      env''         = TypeEnv (env' `Map.union` Map.singleton n (Scheme [] tv))
  (s1, t1) <- ti env'' e
  pure (s1, TFun (apply s1 tv) t1)

ti env (EApp e1 e2) = do
  tv        <- newTyVar
  (s1, t1)  <- ti env e1
  (s2, t2)  <- ti (apply s1 env) e2
  s3        <- mgu (apply s2 t1) (TFun t2 tv)
  pure (s3 `composeSubst` s2 `composeSubst` s1, apply s3 tv)

ti env@(TypeEnv gamma) (ELet x e1 e2) = do
  (s1, t1) <- ti env e1
  let env'        = apply s1 (TypeEnv gamma)
      sigma       = generalize env' t1
      env''       = case env' of
                      TypeEnv m -> TypeEnv (Map.insert x sigma m)
  (s2, t2) <- ti env'' e2
  pure (s2 `composeSubst` s1, t2)

typeInference :: Map String Scheme -> Exp -> TI Type
typeInference env e = do
  (s, t) <- ti (TypeEnv env) e
  pure (apply s t)

--------------------------------------------------------------------------------
-- Sample expressions (from the paper) and a tiny test harness
--------------------------------------------------------------------------------

-- let id = \x -> x in id
e0 = ELet "id" (EAbs "x" (EVar "x"))
               (EVar "id")

-- let id = \x -> x in id id
e1 = ELet "id" (EAbs "x" (EVar "x"))
               (EApp (EVar "id") (EVar "id"))

-- let id = \x -> let y = x in y in id id
e2 = ELet "id" (EAbs "x" (ELet "y" (EVar "x") (EVar "y")))
               (EApp (EVar "id") (EVar "id"))

-- let id = \x -> let y = x in y in id id 2
e3 = ELet "id" (EAbs "x" (ELet "y" (EVar "x") (EVar "y")))
               (EApp (EApp (EVar "id") (EVar "id")) (ELit (LInt 2)))

-- let id = \x -> x x in id     -- should fail (occurs check / non-typable)
e4 = ELet "id" (EAbs "x" (EApp (EVar "x") (EVar "x")))
               (EVar "id")

-- \m -> let y = m in let x = y True in x
-- (forces m to be Bool -> a)
e5 = EAbs "m" (ELet "y" (EVar "m")
            (ELet "x" (EApp (EVar "y") (ELit (LBool True)))
                 (EVar "x")))

e6 = ELet "id" (EAbs "x" (EVar "x"))
               (ELit (LInt 100))

test :: Exp -> IO ()
test e =
  let (res, _) = runTI (typeInference Map.empty e)
  in case res of
       Left err -> putStrLn (show e ++ "\nerror: " ++ err)
       Right t  -> putStrLn (show e ++ " :: " ++ show t)

main :: IO ()
main = mapM_ test [e0, e1, e2, e3, e4, e5, e6]
