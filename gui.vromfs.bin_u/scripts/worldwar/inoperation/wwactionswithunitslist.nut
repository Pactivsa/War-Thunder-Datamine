from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let DataBlock  = require("DataBlock")
let wwOperationUnitsGroups = require("%scripts/worldWar/inOperation/wwOperationUnitsGroups.nut")
let { WwUnit } = require("%scripts/worldWar/inOperation/model/wwUnit.nut")
let { wwGetSpeedupFactor, wwGetOperationId } = require("worldwar")
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { getWwSetting, getWWConfigurableValue } = require("%scripts/worldWar/worldWarStates.nut")

let getForceControlledByAIUnitTypes = memoize(function() {
  let mapName = getOperationById(wwGetOperationId())?.getMapId() ?? ""
  return getWwSetting("forceControlledByAIUnitType", null)?[mapName]
})

function loadUnitsFromBlk(blk, aiUnitsBlk = null) {
  if (!blk)
    return []

  let units = []
  for (local i = 0; i < blk.blockCount(); i++) {
    let unitBlk = blk.getBlock(i)
    let unit    = WwUnit(unitBlk)

    if (unit.isValid()) {
      let types = getForceControlledByAIUnitTypes()
      let unitForceControlledByAI = types?[unit.wwUnitType.textCode] ?? false
      unit.setForceControlledByAI(unitForceControlledByAI)
      units.append(unit)
    }

    if (aiUnitsBlk) {
      let aiUnitData = getTblValue(unitBlk.getBlockName(), aiUnitsBlk)
      if (aiUnitData) {
        let aiUnit = WwUnit(unitBlk)
        aiUnit.setCount(getTblValue("count", aiUnitData, -1))
        aiUnit.setForceControlledByAI(true)
        units.append(aiUnit)
      }
    }
  }
  return units
}

function loadUnitsFromNameCountTbl(tbl) {
  if (u.isEmpty(tbl))
    return []

  let units = []
  let loadingBlk = DataBlock()
  foreach (name, count in tbl) {
    loadingBlk["name"] = name
    loadingBlk["count"] = count

    let unit = WwUnit(loadingBlk)
    if (unit.isValid())
      units.append(unit)
  }

  return units
}

function loadWWUnitsFromUnitsArray(unitsArray) {
  if (u.isEmpty(unitsArray))
    return []

  let units = []
  let loadingBlk = DataBlock()
  foreach (unit in unitsArray) {
    loadingBlk["name"] = unit.name
    loadingBlk["count"] = 1

    let wwUnit = WwUnit(loadingBlk)
    if (wwUnit.isValid())
      units.append(wwUnit)
  }

  return units
}

function getFakeUnitsArray(blk) {
  if (!blk?.fakeInfantry)
    return []

  let resArray = []
  let loadingBlk = DataBlock()
  loadingBlk.changeBlockName("fake_infantry")
  loadingBlk.count <- blk.fakeInfantry
  let fakeUnit = WwUnit(loadingBlk)
  if (fakeUnit.isValid())
    resArray.append(fakeUnit)

  return resArray
}

function unitsCount(units = []) {
  local res = 0
  foreach (wwUnit in units)
    res += wwUnit.count
  return res
}

function setMaxCountColumnWidth(wwUnits) {
  if (wwUnits.len() == 0)
    return
  let maxWidth = wwUnits.reduce(function(res, v) {
    return max(res, v.columnCountWidth)
  }, 0)
  wwUnits.each(@(v) v.columnCountWidth = maxWidth)
}

function getUnitsListViewParams(wwUnits, params = {}, needSort = true) {
  if (needSort)
    wwUnits.sort(::g_world_war.sortUnitsBySortCodeAndCount)
  wwUnits = wwUnits.map(@(wwUnit) wwUnit.getShortStringView(params))
  setMaxCountColumnWidth(wwUnits)
  return wwOperationUnitsGroups.overrideUnitsViewParamsByGroups(wwUnits)
}

function getMaxFlyTime(unit) {
  if (!unit?.isAir() && !unit?.isHelicopter())
    return 0

  let maxFlyTime = unit.getUnitWpCostBlk().maxFlightTimeMinutes ??
    getWWConfigurableValue("defaultMaxFlightTimeMinutes", 0)
  return (maxFlyTime * 60 / wwGetSpeedupFactor()).tointeger()
}

return {
  loadUnitsFromBlk
  loadUnitsFromNameCountTbl
  loadWWUnitsFromUnitsArray
  getFakeUnitsArray
  unitsCount
  getUnitsListViewParams = kwarg(getUnitsListViewParams)
  getMaxFlyTime
}