from "%rGui/globals/ui_library.nut" import *

let { interop } = require("%rGui/globals/interop.nut")
let { fabs } = require("%sqstd/math.nut")

let interopGet = require("interopGen.nut")


let shellHitDamageEvents = {
  hitEventsCount = Watched(0)
  critEventCount = Watched(0)
  armorBlockedEventCount = Watched(0)
  pierceThroughCount = Watched(0)
}

let gunStatesFirstRow = []
let gunStatesSecondRow = []


let shipState = {
  speed = Watched(0)
  steering = Watched(0.0)
  buoyancy = Watched(1.0)
  curRelativeHealth = Watched(1.0)
  maxHealth = Watched(1.0)
  fire = Watched(false)
  portSideMachine = Watched(-1)
  sideboardSideMachine = Watched(-1)
  stopping = Watched(false)

  fwdAngle = Watched(0)
  sightAngle = Watched(0)
  fov = Watched(0)

  obstacleIsNear = Watched(false)
  distanceToObstacle = Watched(-1)
  obstacleAngle = Watched(0)
  timeToDeath = Watched(-1)

  
  enginesCount = Watched(0)
  brokenEnginesCount = Watched(0)
  enginesInCooldown = Watched(false)

  steeringGearsCount = Watched(0)
  brokenSteeringGearsCount = Watched(0)

  torpedosCount = Watched(0)
  brokenTorpedosCount = Watched(0)

  artilleryType = Watched(TRIGGER_GROUP_PRIMARY)
  artilleryCount = Watched(0)
  brokenArtilleryCount = Watched(0)

  transmissionCount = Watched(0)
  brokenTransmissionCount = Watched(0)
  transmissionsInCooldown = Watched(false)

  blockMoveControl = Watched(false)

  aiGunnersState = Watched(0)
  hasAiGunners = Watched(false)

  waterDist = Watched(0)
  buoyancyEx = Watched(0)
  depthLevel = Watched(0)
  wishDist = Watched(0)
  periscopeDepthCtrl = Watched(0)

  gunStatesFirstNumber = Watched(0)
  gunStatesSecondNumber = Watched(0)
  gunStatesFirstRow
  gunStatesSecondRow
  shellHitDamageEvents
  heroCoverPartsRelHp = mkWatched(persist, "shipHeroCoverPartsRelHp", [])
  isCoverDestroyed = Watched(false)
}

function isDiff(time1, time2) {
  return fabs(time1 - time2) >= 0.02;
}

interop.updateShipGunStatus <- function (index, row, state, inDeadZone, startTime, endTime, gunProgress) {
  if (row == 1) {
    while (index >= gunStatesFirstRow.len()) {
      gunStatesFirstRow.append(Watched(
        {state = -1, inDeadZone = -1, startTime = 1, endTime = 1, gunProgress = 1}
      ))
    }
    if (gunStatesFirstRow[index].value.state != state ||
          gunStatesFirstRow[index].value.inDeadZone != inDeadZone ||
          isDiff(gunStatesFirstRow[index].value.gunProgress, gunProgress) ||
          isDiff(gunStatesFirstRow[index].value.startTime, startTime) ||
          isDiff(gunStatesFirstRow[index].value.endTime, endTime)) {
        gunStatesFirstRow[index]({state = state, inDeadZone = inDeadZone, startTime = startTime, endTime = endTime, gunProgress = gunProgress})
    }
  }
  else if (row == 2) {
    while (index >= gunStatesSecondRow.len()) {
      gunStatesSecondRow.append(Watched(
        {state = -1, inDeadZone = -1, startTime = 1, endTime = 1, gunProgress = 1}
      ))
    }
    if (gunStatesSecondRow[index].value.state != state ||
          gunStatesSecondRow[index].value.inDeadZone != inDeadZone ||
          isDiff(gunStatesSecondRow[index].value.gunProgress, gunProgress) ||
          isDiff(gunStatesSecondRow[index].value.startTime, startTime) ||
          isDiff(gunStatesSecondRow[index].value.endTime, endTime)) {
        gunStatesSecondRow[index]({state = state, inDeadZone = inDeadZone, startTime = startTime, endTime = endTime,  gunProgress = gunProgress})
    }
  }
}

interop.updateShellHitDamageEventCounts <- function(hit, crit, blocked, pierceThrough) {
  shellHitDamageEvents.hitEventsCount.set(hit)
  shellHitDamageEvents.critEventCount.set(crit)
  shellHitDamageEvents.armorBlockedEventCount.set(blocked)
  shellHitDamageEvents.pierceThroughCount.set(pierceThrough)
}


interopGet({
  stateTable = shipState
  prefix = "ship"
  postfix = "Update"
})


return shipState
