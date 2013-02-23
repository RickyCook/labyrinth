{-# Language TemplateHaskell #-}

module Labyrinth.Move where

import Labyrinth.Map

import Peeker

data MoveDirection = Towards Direction | Next
                   deriving (Eq)

data Action = Go MoveDirection
            | Shoot Direction
            | Grenade Direction
            deriving (Eq)

goTowards :: Direction -> Action
goTowards = Go . Towards

data Move = Move [Action]
          | ChoosePosition Position
          | ReorderCell Position
          deriving (Eq)

data CellTypeResult = LandR
                    | ArmoryR
                    | HospitalR
                    | PitR
                    | RiverR
                    | RiverDeltaR
                    deriving (Eq)

ctResult :: CellType -> CellTypeResult
ctResult Land       = LandR
ctResult Armory     = ArmoryR
ctResult Hospital   = HospitalR
ctResult (Pit _)    = PitR
ctResult (River _)  = RiverR
ctResult RiverDelta = RiverDeltaR

data TreasureResult = TurnedToAshesR
                    | TrueTreasureR
                    deriving (Eq)

data CellResult = CellResult { crtype_         :: CellTypeResult
                             , foundBullets_   :: Int
                             , foundGrenades_  :: Int
                             , foundTreasures_ :: Int
                             , transportedTo_  :: Maybe CellTypeResult
                             } deriving (Eq)

derivePeek ''CellResult

cellResult :: CellTypeResult -> CellResult
cellResult ct = CellResult { crtype_         = ct
                           , foundBullets_   = 0
                           , foundGrenades_  = 0
                           , foundTreasures_ = 0
                           , transportedTo_  = Nothing
                           }

data GoResult = Went { cellr_ :: CellResult
                     }
              | WentOutside { treasureResult_ :: Maybe TreasureResult
                            }
              | HitWall {}
              deriving (Eq)

derivePeek ''GoResult

data ShootResult = ShootOK
                 | Scream
                 | NoBullets
                 | Forbidden
                 deriving (Eq, Show)

data GrenadeResult = GrenadeOK
                   | NoGrenades
                   deriving (Eq, Show)

data ActionResult = GoR GoResult
                  | ShootR ShootResult
                  | GrenadeR GrenadeResult
                  deriving (Eq)

data ChoosePositionResult = ChosenOK
                          | AllChosenOK
                          | ChooseAgain
                          deriving (Eq)

data ReorderCellResult = ReorderOK CellResult
                       | ReorderForbidden
                       deriving (Eq)

data MoveResult = MoveRes [ActionResult]
                | ChoosePositionR ChoosePositionResult
                | ReorderCellR ReorderCellResult
                | WrongTurn
                | InvalidMove
                deriving (Eq)
