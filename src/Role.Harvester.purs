module Role.Harvester (runHarvester, HarvesterMemory, Harvester) where

import Prelude

import CreepRoles (Role)
import Data.Array (head, filter)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Screeps (err_not_in_range, find_my_structures, find_sources, resource_energy)
import Screeps.Creep (amtCarrying, carryCapacity, harvestSource, moveTo, transferToStructure)
import Screeps.Extension as Extension
import Screeps.Game (getGameGlobal)
import Screeps.Room (find)
import Screeps.RoomObject (room)
import Screeps.Spawn as Spawn
import Screeps.Tower as Tower 
-- (energy, energyCapacity, toTower)
import Screeps.Types (RawRoomObject, RawStructure, TargetPosition(..), Creep)

ignore :: forall a. a -> Unit
ignore _ = unit

ignoreM :: forall m a. Monad m => m a -> m Unit
ignoreM m = m <#> ignore 

type HarvesterMemory = { role :: Role }
type Harvester = { creep :: Creep, mem :: HarvesterMemory }

desiredTarget :: forall a. RawRoomObject (RawStructure a) -> Boolean
desiredTarget struct = 
  case (Tower.toTower struct) of
    Just tower -> 
       Tower.energy tower < Tower.energyCapacity tower
    Nothing ->
      case (Spawn.toSpawn struct) of
        Just spawn -> 
          Spawn.energy spawn < Spawn.energyCapacity spawn
        Nothing ->
          case (Extension.toExtension struct) of
            Just ext ->
              Extension.energy ext < Extension.energyCapacity ext
            Nothing -> false

runHarvester :: Harvester -> Effect Unit
runHarvester { creep } =

  if amtCarrying creep resource_energy < carryCapacity creep
  then
    case head (find (room creep) find_sources) of
      Nothing -> pure unit
      Just targetSource -> do
        harvestResult <- harvestSource creep targetSource
        if harvestResult == err_not_in_range
        then moveTo creep (TargetObj targetSource) # ignoreM
        else pure unit
        
  else do
    game <- getGameGlobal
    case (head (filter desiredTarget (find (room creep) find_my_structures))) of
      Nothing -> pure unit
      Just spawn1 -> do
        transferResult <- transferToStructure creep spawn1 resource_energy
        if transferResult == err_not_in_range
        then moveTo creep (TargetObj spawn1) # ignoreM
        else pure unit
