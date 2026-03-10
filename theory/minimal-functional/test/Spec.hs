module Main ( main ) where

import Test.Tasty
import TestsParse
import TestsEval

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "tests" [testsEval, testsParse]
