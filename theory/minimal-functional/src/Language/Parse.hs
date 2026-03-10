module Language.Parse
  ( parseProgram
  ) where

import           Text.Megaparsec
import           Text.Megaparsec.Char
import qualified Text.Megaparsec.Char.Lexer as Lexer
import           Data.Void

import           Language.Core

type Parser = Parsec Void String

sc :: Parser ()
sc = Lexer.space space1 Text.Megaparsec.empty Text.Megaparsec.empty

lexeme :: Parser a -> Parser a
lexeme = Lexer.lexeme sc

symbol :: String -> Parser String
symbol = Lexer.symbol sc

integer :: Parser Int
integer = lexeme Lexer.decimal

identifier :: Parser String
identifier = lexeme ((:) <$> letterChar <*> many (alphaNumChar <|> char '_'))

operatorIdentifier :: Parser String
operatorIdentifier = lexeme $ between (char '(') (char ')') op
  where
    op = some (oneOf ("+-*/><=:~$@#!%"))

parseInt :: Parser Expr
parseInt = EInt <$> integer

parseVar :: Parser Expr
parseVar = do
  name <- try operatorIdentifier <|> identifier
  return $ EVar name

parseUnit :: Parser Expr
parseUnit = EUnit
  <$ symbol "("
  <* symbol ")"

parseTuple :: Parser Expr
parseTuple = ETuple
  <$  symbol "("
  <*> parseExpr
  <*  sc
  <*  symbol ","
  <*  sc
  <*> parseExpr
  <*  sc
  <*  symbol ")"

parsePatternVar :: Parser Pattern
parsePatternVar = PVar
  <$> identifier

parsePatternWild :: Parser Pattern
parsePatternWild = PWild
  <$  symbol "_"

parsePatternInt :: Parser Pattern
parsePatternInt = PInt
  <$> integer

parsePatternUnit :: Parser Pattern
parsePatternUnit = PUnitP
  <$  symbol "()"

parsePatternTuple :: Parser Pattern
parsePatternTuple = do
  _ <- char '('
  sc
  p1 <- parsePattern
  sc
  m <- optional $ do
    _ <- char ','
    sc
    parsePattern
  sc
  _ <- char ')'
  case m of
    Just p2 -> return (PTupleP p1 p2)
    Nothing -> return p1

parsePatternCons :: Parser Pattern
parsePatternCons = parsePatternTuple

parsePatternGuard :: Parser Pattern
parsePatternGuard = PGuard <$> parseVar <*> parseExpr

parsePattern :: Parser Pattern
parsePattern = choice
  [ parsePatternVar
  , parsePatternGuard
  , parsePatternWild
  , parsePatternInt
  , parsePatternUnit
  , parsePatternTuple
  , parsePatternCons
  ]

parseCasePattern :: Parser (Pattern, Expr)
parseCasePattern = do
  pat <- parsePattern
  sc
  _ <- string "->"
  sc
  expr <- parseExpr
  return (pat, expr)

parseCaseExpr :: Parser Expr
parseCaseExpr = choice
  [ try parseCall
  , parseVar
  ]

parseCase :: Parser Expr
parseCase = do
  scrut <- parseCaseExpr
  sc
  _ <- string "=>"
  sc
  branches <- some branch
  return $ ECase scrut branches
  where
    branch = do
      _ <- char '|'
      sc
      parseCasePattern

parseParens :: Parser [Expr]
parseParens = between (symbol "(") (symbol ")") (parseExpr `sepBy` sc)

parseCall :: Parser Expr
parseCall = do
  fn <- parseVar
  sc
  args <- parseParens
  return $ ECall fn args

parseInlineLambda :: Parser Expr
parseInlineLambda = do
  _ <- char '('
  sc
  pats <- many parsePattern
  sc
  _ <- char '='
  sc
  body <- parseExpr
  sc
  _ <- char ')'
  return $ ELam pats body

parseExpr :: Parser Expr
parseExpr = choice
  [ try parseCase
  , try parseInlineLambda
  , try parseCall
  , parseVar
  , try parseTuple
  , parseUnit
  , parseInt
  ]

-- We pack function in let binding.
parseTopLevelOne :: Parser Expr
parseTopLevelOne = do
  name <- try operatorIdentifier <|> identifier
  sc
  pats <- many parsePattern
  sc
  _ <- char '='
  sc
  body <- parseExpr
  return $ ELet name (ELam pats body) (EVar name)

parseTopLevel :: Parser [Expr]
parseTopLevel = many (try parseTopLevelOne <|> parseCall)

parseProgram :: String -> Either (ParseErrorBundle String Void) [Expr]
parseProgram input = parse parseTopLevel "" input
