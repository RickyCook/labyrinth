module Labyrinth.Action (performMove) where

import Control.Monad.State

import Data.List
import Data.Maybe

import Labyrinth.Map
import Labyrinth.Move

import Peeker

performMove :: PlayerId -> Move -> State Labyrinth MoveResult
performMove pi move = do
    current <- getS currentPlayer
    if current /= pi
        then return WrongTurn
        else performMove' move

performMove' :: Move -> State Labyrinth MoveResult
performMove' (Move actions) = do
    posChosen <- getS positionsChosen
    if not posChosen
        then return InvalidMove
        else do
            pi <- getS currentPlayer
            if length (filter isMovement actions) > 1
                then return InvalidMove
                else do
                    updS (player pi ~> pfell) False
                    actionRes <- performActions actions
                    advancePlayer
                    return $ MoveRes actionRes

performMove' (ChoosePosition pos) = do
    pi <- getS currentPlayer
    out <- gets (isOutside pos)
    if out
        then return InvalidMove
        else do
            updS (player pi ~> position) pos
            next <- advancePlayer
            if (next == 0)
                then do
                    updS positionsChosen True
                    return $ ChoosePositionR AllChosenOK
                else
                    return $ ChoosePositionR ChosenOK

advancePlayer :: State Labyrinth PlayerId
advancePlayer = do
    pi <- getS currentPlayer
    queue <- alivePlayers
    pCount <- gets playerCount
    let next = head $ tail $ dropWhile (pi /=) $ cycle queue
    updS currentPlayer next
    return next

isMovement :: Action -> Bool
isMovement (Go _) = True
isMovement _ = False

returnContinue :: [Action] -> ActionResult -> State Labyrinth [ActionResult]
returnContinue rest res = do
    restRes <- performActions rest
    return $ res:restRes

returnStop :: ActionResult -> State Labyrinth [ActionResult]
returnStop = return . (:[])

alwaysContinue :: [Action] -> State Labyrinth ActionResult -> State Labyrinth [ActionResult]
alwaysContinue rest act = do
    res <- act
    returnContinue rest res

performActions :: [Action] -> State Labyrinth [ActionResult]
performActions [] = return []
performActions (act:rest) = case act of
    Go dir      -> performMovement dir rest
    Grenade dir -> alwaysContinue rest $ performGrenade dir
    Shoot dir   -> alwaysContinue rest $ performShoot dir

transferAmmo :: Maybe Int -> Peek Labyrinth Int -> Peek Labyrinth Int -> State Labyrinth Int
transferAmmo maxAmount from to = do
    found <- getS from
    has <- getS to
    let amount = case maxAmount of
                     (Just max) -> min found $ max - has
                     Nothing    -> found
    let found' = found - amount
    let has' = has + amount
    updS from found'
    updS to has'
    return found

transferAmmo_ :: Maybe Int -> Peek Labyrinth Int -> Peek Labyrinth Int -> State Labyrinth ()
transferAmmo_ maxAmount from to = do
    transferAmmo maxAmount from to
    return ()

pickBullets :: State Labyrinth Int
pickBullets = do
    i <- getS currentPlayer
    pos <- getS $ player i ~> position
    out <- gets $ isOutside pos
    if out
        then return 0
        else transferAmmo
            (Just maxBullets)
            (cell pos ~> cbullets)
            (player i ~> pbullets)

pickGrenades :: State Labyrinth Int
pickGrenades = do
    i <- getS currentPlayer
    pos <- getS $ player i ~> position
    out <- gets $ isOutside pos
    if out
        then return 0
        else transferAmmo
            (Just maxGrenades)
            (cell pos ~> cgrenades)
            (player i ~> pgrenades)

afterMove :: State Labyrinth (Maybe Position)
afterMove = do
    pi <- getS currentPlayer
    pos <- getS (player pi ~> position)
    ct <- getS (cell pos ~> ctype)
    case ct of
        Land -> return Nothing
        Armory -> do
            updS (player pi ~> pbullets) maxBullets
            updS (player pi ~> pgrenades) maxGrenades
            return Nothing
        Hospital -> do
            updS (player pi ~> phealth) Healthy
            return Nothing
        Pit i -> do
            npits <- gets pitCount
            let i' = (i + 1) `mod` npits
            pos' <- gets (pit i')
            return $ Just pos'
        River d -> do
            let pos' = advance pos d
            return $ Just pos'
        RiverDelta -> return Nothing

performMovement :: MoveDirection -> [Action] -> State Labyrinth [ActionResult]
performMovement (Towards dir) rest = let returnCont = returnContinue rest in do
    pi <- getS currentPlayer
    pos <- getS (player pi ~> position)
    w <- getS (wall pos dir)
    if w == NoWall
        then do
            let npos = advance pos dir
            updS (player pi ~> position) npos
            out <- gets $ isOutside npos
            if out
                then do
                    t <- getS (player pi ~> ptreasure)
                    case t of
                        Nothing -> returnCont $ GoR $ WentOutside Nothing
                        (Just FakeTreasure) -> do
                            updS (player pi ~> ptreasure) Nothing
                            returnCont $ GoR $ WentOutside $ Just TurnedToAshesR
                        (Just TrueTreasure) -> do
                            updS (player pi ~> ptreasure) Nothing
                            returnStop $ GoR $ WentOutside $ Just TrueTreasureR
                            -- TODO: mark the game as ended?
                else do
                    ct <- getS (cell npos ~> ctype)
                    -- Perform cell-type-specific actions
                    npos' <- afterMove
                    let npos'' = fromMaybe npos npos'
                    updS (player pi ~> position) npos''
                    -- If transported, determine the new cell type
                    nct <- if isJust npos' then do
                            nct' <- getS (cell npos'' ~> ctype)
                            return $ Just nct'
                        else
                            return Nothing
                    -- Pick ammo
                    cb <- pickBullets
                    cg <- pickGrenades
                    -- Pick treasures
                    ctr <- getS (cell npos'' ~> ctreasures)
                    ptr <- getS (player pi ~> ptreasure)
                    if ptr == Nothing && length ctr > 0
                        then do
                            let ctr' = tail ctr
                            let ptr' = Just $ head ctr
                            updS (cell npos'' ~> ctreasures) ctr'
                            updS (player pi ~> ptreasure) ptr'
                        else
                            return ()
                    let nctr = (fmap ctResult) nct
                    returnCont $ GoR $ Went (ctResult ct) cb cg (length ctr) nctr
        else
            returnCont $ GoR HitWall

performGrenade :: Direction -> State Labyrinth ActionResult
performGrenade dir = do
    pi <- getS currentPlayer
    g <- getS (player pi ~> pgrenades)
    if g > 0
        then do
            updS (player pi ~> pgrenades) (g - 1)
            pickGrenades
            pos <- getS (player pi ~> position)
            out <- gets $ isOutside pos
            if out then return ()
                else do
                    ct <- getS (cell pos ~> ctype)
                    when (ct == Armory) $
                        updS (player pi ~> pgrenades) maxGrenades
                    w <- getS (wall pos dir)
                    if w /= HardWall
                        then do
                            updS (wall pos dir) NoWall
                        else
                            return ()
            return $ GrenadeR GrenadeOK
        else
            return $ GrenadeR NoGrenades

performShoot :: Direction -> State Labyrinth ActionResult
performShoot dir = do
    pi <- getS currentPlayer
    b <- getS (player pi ~> pbullets)
    if b > 0
        then do
            pos <- getS (player pi ~> position)
            ct <- getS (cell pos ~> ctype)
            if ct == Hospital || ct == Armory
                then return $ ShootR Forbidden
                else do
                    updS (player pi ~> pbullets) (b - 1)
                    pickBullets
                    res <- performShootFrom pos dir
                    return $ ShootR res
        else
            return $ ShootR NoBullets

alivePlayers :: State Labyrinth [PlayerId]
alivePlayers = do
    cnt <- gets playerCount
    filterM playerAlive [0..cnt - 1]
    where playerAlive :: PlayerId -> State Labyrinth Bool
          playerAlive i = do
              ph <- getS (player i ~> phealth)
              return $ ph /= Dead

playersAliveAt :: Position -> State Labyrinth [PlayerId]
playersAliveAt pos = do
    alive <- alivePlayers
    atPos <- filterM (playerAt pos) alive
    filterM notFallen atPos

playerAt :: Position -> PlayerId -> State Labyrinth Bool
playerAt pos i = do
    pp <- getS (player i ~> position)
    return $ pos == pp

notFallen :: PlayerId -> State Labyrinth Bool
notFallen i = (liftM not) $ getS (player i ~> pfell)

performShootFrom :: Position -> Direction -> State Labyrinth ShootResult
performShootFrom pos dir = do
    outside <- gets $ isOutside pos
    ct <- getS (cell pos ~> ctype)
    pi <- getS currentPlayer
    cnt <- gets playerCount
    hit <- playersAliveAt pos
    if not outside && ct == Hospital
        then return ShootOK
        else do
            let othersHit = delete pi hit
            if length othersHit == 0
                then if outside
                    then return ShootOK
                    else do
                        if ct == Armory
                            then return ShootOK
                            else do
                                w <- getS (wall pos dir)
                                if w == NoWall
                                    then performShootFrom (advance pos dir) dir
                                    else return ShootOK
                else do
                    forM_ othersHit $ \i -> do
                        ph <- getS (player i ~> phealth)
                        if outside
                            then updS (player i ~> pbullets) 0
                            else transferAmmo_ Nothing (player i ~> pbullets) (cell pos ~> cbullets)
                        when (ph == Healthy) $ do
                            updS (player i ~> phealth) Wounded
                            updS (player i ~> pfell) True
                        when (ph == Wounded) $ do
                            if outside
                                then updS (player i ~> pgrenades) 0
                                else transferAmmo_ Nothing (player i ~> pgrenades) (cell pos ~> cgrenades)
                            updS (player i ~> phealth) Dead
                    return Scream
