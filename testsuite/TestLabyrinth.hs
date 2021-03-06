{-# OPTIONS_GHC -F -pgmF htfpp #-}

module TestLabyrinth where

import Labyrinth

import Control.Lens
import Control.Monad.State

import Test.Framework
import TestLabyrinth.Common
import TestLabyrinth.Move.Common

test_advance = do
    assertEqual
        (Pos 0 1) $
        advance (Pos 0 0) D

test_wrong_turn = do
    assertMoveUpdates
        empty_labyrinth
        1
        (Move [goTowards D])
        (MoveRes [WrongTurn])
        $ return ()
    let endgame = applyState empty_labyrinth $ do
        gameEnded .= True
    assertMoveUpdates'
        endgame
        (Move [goTowards D])
        (MoveRes [WrongTurn])
        $ return ()

test_combined = do
    assertMoveUpdates'
        walled_labyrinth
        (Move [Grenade R, goTowards R])
        (MoveRes [GrenadeR GrenadeOK, GoR $ Went LandR noEvents])
        $ do
            (player 0 . position) .= Pos 1 0
            (player 0 . pgrenades) .= 2
            wall (Pos 0 0) R .= NoWall
            currentTurn .= 1

test_invalid = do
    assertMoveUpdates'
        walled_labyrinth
        (Move [goTowards R, goTowards R])
        (MoveRes [InvalidMove])
        $ return ()
