{-# LANGUAGE LambdaCase #-}

module Main where

import qualified Data.Map.Strict as M
import           Control.Monad (foldM)

-- Simple error monad
type Eval a = Either String a

-- AST (minimal)
data Expr
  = EInt Int
  | EVar String
  | EUnit                  -- ()
  | ETuple Expr Expr       -- (a, b)
  | ECall Expr [Expr]      -- id(args...) or constructor call
  | ELam [Pattern] Expr    -- \p1 p2 -> body    (multiple pattern parameters)
  | ECase Expr [(Pattern, Expr)] -- Case expression: case e of p1 -> e1 | p2 -> e2 ...
  | ELet String Expr Expr  -- let <name> = expr in body  (recursive)
  deriving (Show, Eq)

-- Patterns
data Pattern
  = PVar String
  | PWild                 -- _
  | PInt Int
  | PUnitP                -- ()
  | PTupleP Pattern Pattern
  | PConsP Pattern Pattern -- Cons(h,t) or (head, tail) treated as pair
  deriving (Show, Eq)

-- Runtime values
data Value
  = VInt Int
  | VUnit
  | VPair Value Value           -- tuple / cons cell
  | VFun [Pattern] Expr Env     -- user function closure
  | VPrim String ([Value] -> Eval Value) -- builtin function (name, impl)
  | VRec String Expr Env        -- recursive thunk: name -> expr (evaluated when forced)
  deriving ()

instance Show Value where
  show = \case
    VInt n     -> show n
    VUnit      -> "()"
    VPair a b  -> "(" ++ show a ++ ", " ++ show b ++ ")"
    VFun{}     -> "<fun>"
    VPrim n _  -> "<prim " ++ n ++ ">"
    VRec n _ _ -> "<rec " ++ n ++ ">"

-- Environment: simple map from names to Values
type Env = M.Map String Value

-- Force: resolve VRec to its evaluated value (no memoization here)
force :: Value -> Eval Value
force v@(VRec name expr env) = eval env' expr
  where
    -- env' contains the recursive binding so expr can reference itself
    env' = M.insert name v env
force v = return v

-- Pattern matching: if pattern matches value, return bindings map
matchPattern :: Pattern -> Value -> Eval (M.Map String Value)
matchPattern pat val = case pat of
  PWild       -> return M.empty
  PInt n      -> case val of
                   VInt m | m == n -> return M.empty
                   _ -> Left $ "pattern int " ++ show n ++ " doesn't match " ++ show val
  PUnitP      -> case val of
                   VUnit -> return M.empty
                   _     -> Left $ "pattern () doesn't match " ++ show val
  PVar x      -> return $ M.singleton x val
  PTupleP p1 p2 -> case val of
                     VPair a b -> do
                       m1 <- matchPattern p1 a
                       m2 <- matchPattern p2 b
                       mergeMaps m1 m2
                     _ -> Left $ "tuple pattern doesn't match " ++ show val
  PConsP ph pt -> case val of
                    VPair a b -> do
                      m1 <- matchPattern ph a
                      m2 <- matchPattern pt b
                      mergeMaps m1 m2
                    _ -> Left $ "cons/pair pattern doesn't match " ++ show val
  where
    mergeMaps a b =
      if null (M.keys (M.intersection a b))
         then return (a `M.union` b)
         else Left "duplicate variable in patterns"

-- Helper: evaluate a list of expressions to values
evalArgs :: Env -> [Expr] -> Eval [Value]
evalArgs env = mapM (eval env)

-- Apply a value as function to arguments
apply :: Value -> [Value] -> Eval Value
apply v args = do
  v' <- force v
  case v' of
    VPrim _ impl -> impl args
    VFun pats body closEnv -> do
      if length pats /= length args
         then Left $ "arity mismatch: expected " ++ show (length pats) ++ ", got " ++ show (length args)
         else do
           maps <- zipWithM matchPatVal pats args
           let merged = foldl M.union M.empty maps
           eval (merged `M.union` closEnv) body
    _ -> Left $ "attempt to call non-function " ++ show v'

  where
    zipWithM f xs ys = sequence (zipWith f xs ys)
    matchPatVal pat val = matchPattern pat val   -- ✅ fixed: no `return`

-- Builtins (use host arithmetic for integers)
primBinInt :: String -> (Int -> Int -> Int) -> Value
primBinInt name f = VPrim name $ \case
  [VInt a, VInt b] -> return $ VInt (f a b)
  args -> Left $ "builtin " ++ name ++ " expects two ints, got " ++ show args

primDiv :: Value
primDiv = VPrim "/" $ \case
  [VInt _, VInt 0] -> Left "division by zero"
  [VInt a, VInt b] -> return $ VInt (a `div` b)
  xs -> Left $ "/ expects two ints, got " ++ show xs

primEq :: Value
primEq = VPrim "==" $ \case
  [VInt a, VInt b] -> return $ if a == b then VInt 1 else VInt 0
  _ -> Left "== expects two ints"

-- initial environment with builtins
initialEnv :: Env
initialEnv = M.fromList
  [ ("+",     primBinInt "+" (+))
  , ("-",     primBinInt "-" (-))
  , ("*",     primBinInt "*" (*))
  , ("/",     primDiv)
  , ("%",     primBinInt "%" mod)
  , ("==",    primEq)
  , ("nil",   VUnit)                       -- represent nil as unit
  , ("cons",  VPrim "cons" $ \case         -- cons(h,t) -> pair
        [h,t] -> return $ VPair h t
        xs -> Left $ "cons expects two args, got " ++ show xs)
  , ("tuple", VPrim "tuple" $ \case       -- explicit tuple constructor
        [a,b] -> return $ VPair a b
        xs -> Left $ "tuple expects two args, got " ++ show xs)
  ]

-- Evaluation function
eval :: Env -> Expr -> Eval Value
eval env = \case
  EInt n -> return $ VInt n
  EVar x -> case M.lookup x env of
              Just v  -> return v
              Nothing -> Left $ "unbound variable: " ++ x
  EUnit -> return VUnit
  ETuple a b -> do
    va <- eval env a
    vb <- eval env b
    return $ VPair va vb
  ECall fnExpr args -> do
    fnv <- eval env fnExpr
    argvs <- evalArgs env args
    apply fnv argvs
  ELam pats body -> return $ VFun pats body env
  ECase scrut branches -> do
    sv <- eval env scrut
    tryBranches sv branches
    where
      tryBranches _ [] = Left "non-exhaustive patterns in case"
      tryBranches v ((pat, br):bs) = case matchPattern pat v of
        Right binds -> eval (binds `M.union` env) br
        Left _ -> tryBranches v bs
  ELet name rhs body -> do
    -- recursive binding: name maps to VRec and is visible in rhs and body
    let rec = VRec name rhs env'
        env' = M.insert name rec env
    eval env' body

-- Utils: desugar a surface list [e1,e2,...] into nested cons calls:
--   [a,b,c] -> cons(a, cons(b, cons(c, nil)))
desugarList :: [Expr] -> Expr
desugarList [] = EVar "nil"
desugarList (x:xs) = ECall (EVar "cons") [x, desugarList xs]

-- Example programs (constructed directly in AST)

-- sumList: sum a list of ints (pattern matching on cons/unit)
-- sumList = \lst ->
--   case lst of
--     () -> 0
--     (h,t) -> h + sumList(t)
sumListExpr :: Expr
sumListExpr =
  ELet "sum"
    (ELam [PVar "lst"] $
      ECase (EVar "lst")
        [ (PUnitP, EInt 0)
        , (PConsP (PVar "h") (PVar "t"), ECall (EVar "+") [EVar "h", ECall (EVar "sum") [EVar "t"]])
        ])
    (EVar "sum")

-- Example: compute sum [1,2,3]
example1 :: Expr
example1 =
  ECall sumListExpr [desugarList [EInt 1, EInt 2, EInt 3]]

-- factorial using recursion and builtin *
-- fact = \n ->
--   case n of
--     0 -> 1
--     k -> k * fact(k-1)
factExpr :: Expr
factExpr =
  ELet "fact"
    (ELam [PVar "n"] $
      ECase (EVar "n")
        [ (PInt 0, EInt 1)
        , (PVar "k", ECall (EVar "*")
            [ EVar "k"
            , ECall (EVar "fact") [ ECall (EVar "-") [EVar "k", EInt 1] ]
            ])
        ])
    (EVar "fact")

-- map f xs =
--   case xs of
--     () -> []
--     (h, t) -> (f h, map (f, t))
mapExpr :: Expr
mapExpr =
  ELet "map"
    (ELam [PVar "f", PVar "xs"] $
      ECase (EVar "xs")
        [ (PUnitP, EUnit)  -- []
        , (PConsP (PVar "h") (PVar "t"),
            ETuple
              (ECall (EVar "f") [EVar "h"])
              (ECall (EVar "map") [EVar "f", EVar "t"]))
        ])
    (EVar "map")

-- foldl f acc xs =
--   case xs of
--     [] -> acc
--     (h, t) -> foldl f (f acc h) t
foldlExpr :: Expr
foldlExpr =
  ELet "foldl"
    (ELam [PVar "f", PVar "acc", PVar "xs"] $
      ECase (EVar "xs")
        [ (PUnitP, EVar "acc")  -- []
        , (PConsP (PVar "h") (PVar "t"),
            ECall (EVar "foldl")
              [ EVar "f"
              , ECall (EVar "f") [EVar "acc", EVar "h"]
              , EVar "t"
              ])
        ])
    (EVar "foldl")

-- sum xs = foldl (+) 0 xs
sumExpr :: Expr
sumExpr =
  ELet "sum"
    (ELam [PVar "xs"] $
      ECall foldlExpr
        [ EVar "+"
        , EInt 0
        , EVar "xs"
        ])
    (EVar "sum")

example2 :: Expr
example2 = ECall factExpr [EInt 6]

example3 :: Expr
example3 = ECall mapExpr [ELam [PVar "x"] (ECall (EVar "*") [EVar "x", EVar "x"]), desugarList [EInt 1, EInt 2, EInt 3]]

-- small helper to run and pretty-print evaluation
runEval :: Expr -> IO ()
runEval e = case eval initialEnv e of
  Left err -> putStrLn $ "Error: " ++ err
  Right v  -> putStrLn $ show v

main :: IO ()
main = do
  putStrLn "List [1,2,3] =>"
  runEval $ desugarList [EInt 1, EInt 2, EInt 3]
  putStrLn "sum [1,2,3] =>"
  runEval example1
  putStrLn "fact 6 =>"
  runEval example2
  putStrLn "map =>"
  runEval example3
