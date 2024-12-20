from "%scripts/dagui_library.nut" import *

let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getEsUnitType } = require("%scripts/unit/unitInfo.nut")

//************************************************************************//
//*********************functions to work with esUnitType******************//
//*******************but better to work with unitTypes enum***************//
//************************************************************************//

::getUnitTypeText <- function getUnitTypeText(esUnitType) {
  return unitTypes.getByEsUnitType(esUnitType).name
}

::getUnitTypeByText <- function getUnitTypeByText(typeName, caseSensitive = false) {
  return unitTypes.getByName(typeName, caseSensitive).esUnitType
}

function get_unit_icon_by_unit(unit, iconName) {
  let esUnitType = getEsUnitType(unit)
  let t = unitTypes.getByEsUnitType(esUnitType)
  return $"{t.uiSkin}{iconName}.ddsx"
}

::get_unit_icon_by_unit <- get_unit_icon_by_unit

::get_tomoe_unit_icon <- function get_tomoe_unit_icon(iconName, isForGroup = false) {
  return $"!#ui/unitskin#tomoe_{iconName}{isForGroup ? "_group" : ""}.ddsx"
}

return {
  get_unit_icon_by_unit
}