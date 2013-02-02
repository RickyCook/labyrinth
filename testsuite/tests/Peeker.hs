{-# Language TemplateHaskell #-}

import Peeker

import Control.Monad.State

import Test.HUnit

data Wrap2 a = Wrap2 (Wrap a)
             deriving (Eq, Show)

data Wrap a = Wrap a
            deriving (Eq, Show)

data Flip = Foo | Bar
            deriving (Eq, Show)

data Fruit = Apple | Orange
             deriving (Eq, Show)

data Animal = Cat | Fox
              deriving (Eq, Show)

data Rec = RecC { fruit_  :: Fruit
                , animal_ :: Animal
                }
         | RecC2 { number_ :: Int
                 }
         | RecC3 Bool Bool
         deriving (Eq, Show)

derivePeek ''Rec

main = runTestTT tests

tests = TestList [ test_getter
                 , test_updater
                 , test_state
                 , test_composition
                 , test_lift
                 , test_list
                 , test_template
                 ]

p1 :: Peek (Wrap2 a) (Wrap a)
p1 (Wrap2 x) = (x, Wrap2)

p2 :: Peek (Wrap a) a
p2 (Wrap x) = (x, Wrap)

test_composition = TestCase $ do
    assertEqual "getP via composition"
        Foo $
        getP (p1 ~> p2) $ Wrap2 $ Wrap Foo
    assertEqual "set via composition"
        (Wrap2 (Wrap Bar)) $
        updP (p1 ~> p2) (Wrap2 $ Wrap Foo) Bar

test_getter = TestCase $ do
    assertEqual "getP value"
        Foo $
        getP p2 $ Wrap Foo

test_updater = TestCase $ do
    assertEqual "update value"
        (Wrap Bar) $
        updP p2 (Wrap Foo) Bar

test_state = TestCase $ do
    assertEqual "value gotten from state monad"
        Foo $
        evalState (getS p2) (Wrap Foo)
    assertEqual "value updated in state monad"
        (Wrap Bar) $
        execState (updS p2 Bar) (Wrap Foo)

test_lift = TestCase $ do
    assertEqual "getting lifted value"
        Foo $
        getP liftP Foo
    assertEqual "updating lifted value"
        Bar $
        updP liftP Foo Bar

test_list = TestCase $ do
    let lst = [10,20,30,40]
    assertEqual "getting value from a list"
        30 $
        getP (listP 2) lst
    assertEqual "putting value into a list"
        [10,20,99,40] $
        updP (listP 2) lst 99

test_template = TestCase $ do
    let rec = RecC Apple Cat
    let rec2 = RecC2 10
    assertEqual "getP first derived value"
        Apple $
        getP fruit rec
    assertEqual "getP second derived value"
        Cat $
        getP animal rec
    assertEqual "getP second alternative"
        10 $
        getP number rec2
    assertEqual "put derived value"
        (RecC Orange Cat) $
        updP fruit rec Orange
    assertEqual "put second derived value"
        (RecC Apple Fox) $
        updP animal rec Fox
    assertEqual "put second alternative"
        (RecC2 5) $
        updP number rec2 5
