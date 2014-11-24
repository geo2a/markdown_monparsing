module Parsers where

import Control.Monad
import Data.Char(ord)

import Helpers

newtype Parser a = Parser (String -> [(a,String)])

parse :: Parser p -> String -> [(p,String)]
parse (Parser p) = p

instance Monad Parser where
  return a = Parser (\cs -> [(a,cs)])
  p >>= f  = Parser (\cs -> concat [parse (f a) cs' |
                            (a,cs') <- parse p cs])

instance MonadPlus Parser where
  mzero = Parser (\cs -> [])
  p `mplus` q = Parser (\cs -> parse p cs ++ parse q cs)

-- | Determenistic analog of mplus (return first result)
(<|>) :: Parser a -> Parser a -> Parser a
p1 <|> p2 = Parser $ \cs -> case parse (p1 `mplus` p2) cs of
                          []  -> []
                          x:_ -> [x]

-- |Consumes one symbol of any kind 
item :: Parser Char
item = Parser (\inp -> case inp of
                        [] -> []
                        (x:xs) -> [(x,xs)])

-- |Consumes item only if it satisfies predicate
sat :: (Char -> Bool) -> Parser Char
sat p = do
  x <- item 
  if p x then return x else mzero

----------------Парсеры для одиночных символов----------------

-- |Consumes item only if it is equal to specified char
char :: Char -> Parser Char
char x = sat (\y -> x == y)

-- |Decimal digit
digit :: Parser Char
digit = sat (\x -> '0' <= x && x <= '9')

-- |Lowercase letter
lower :: Parser Char
lower = sat (\x -> 'a' <= x && x <= 'z')

-- |Uppercase letter
upper :: Parser Char
upper = sat (\x -> 'A' <= x && x <= 'Z')

-- |Anycase letter
letter :: Parser Char
letter = lower `mplus` upper

-- |Anycase letter or decimal digit
alphanum :: Parser Char
alphanum = letter `mplus` digit

newline :: Parser Char
newline  = char '\n'  
----------------Парсеры для групп символов----------------

-- |Word (non-empty string of letters)
word :: Parser String
word = do
  l <- letter
  ls <- word'
  return $ l:ls

-- |Same as word, but string may be empty 
word' = nonEmpty `mplus` return ""
  where
    nonEmpty = do
      x <- letter
      xs <- word'
      return (x:xs)

-- |Applyes parser p zero or more times
many :: Parser a -> Parser [a]
many p = many1 p <|> many0
  where
    many0 = return []

many1 :: Parser a -> Parser [a]
many1 p = do 
  a <- p
  as <- many p
  return (a:as)

-- |Parse a specified string
string :: String -> Parser String
string = mapM char -- sequence . map char

-- |Parse a token with specific parser, thow away any trailing spaces
token :: Parser a -> Parser a
token p = do 
  a <- p 
  spaces
  return a

-- |Parse a symbolic token, just a specification of token parser
symbol :: String -> Parser String
symbol cs = token (string cs)

-- |Parse identifier, i.e. word with leading lowercase letters and trailing alphanums 
ident :: Parser String
ident = do
  x <- lower
  xs <- many alphanum
  return (x:xs)

-- |Same as ident but fails if argument is a member of list of keywords
identifier :: [String] -> Parser String
identifier kwords = do
  x <- ident
  if elem x kwords then return "" else return x

-- |Parse a thing enclosed by brackets
bracket :: Parser a -> Parser b -> Parser c -> Parser b
bracket open p close = do 
  open
  x <- p
  close
  return x

----------------"Lexical issues"----------------
spaces :: Parser String
spaces = many (sat isSpace)

----------------Special parsers----------------
sepby :: Parser a -> Parser b -> Parser [a]
p `sepby` sep = (p `sepby1` sep) `mplus` return []

sepby1:: Parser a -> Parser b -> Parser [a]
p `sepby1` sep = do 
  a <- p
  as <- many (do {sep; p})
  return (a:as)
