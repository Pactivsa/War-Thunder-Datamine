from "%scripts/dagui_library.nut" import *

let { format } = require("string")
let { fabs } = require("math")
let enums = require("%sqStdLibs/helpers/enums.nut")
let { isAffectedBySpecialization, isAffectedByLeadership } = require("%scripts/crew/crewSkills.nut")
let { getCrewSkillValue } = require("%scripts/crew/crew.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { getCachedCrewId, getCachedCrewUnit } = require("%scripts/crew/crewShortCache.nut")
let { getSpecTypeByCrewAndUnit } = require("%scripts/crew/crewSpecType.nut")
let { skillParametersRequestType } = require("%scripts/crew/skillParametersRequestType.nut")

enum skillColumnOrder {
  TOTAL
  EQUALS_SIGN
  BASE
  SKILLS
  SPECIALIZATION
  LEADERSHIP
  GUNNERS
  EMPTY
  MAX
  GUNNERS_COUNT

  UNKNOWN
}

::g_skill_parameters_column_type <- {
  types = []
}

::g_skill_parameters_column_type._checkSkill <- function _checkSkill(_memberName, _skillName) {
  return true
}

::g_skill_parameters_column_type._checkCrewUnitType <- function _checkCrewUnitType(_crewUnitType) {
  return true
}

::g_skill_parameters_column_type._getHeaderText <- function _getHeaderText() {
  if (this.headerLocId.len() == 0)
    return null
  return loc(this.headerLocId)
}

::g_skill_parameters_column_type._getHeaderImage <- function _getHeaderImage(_params) {
  if (this.imageName.len() == 0 || this.imageSize <= 0)
    return null
  return this.imageName
}

::g_skill_parameters_column_type._getHeaderImageLegendText <- function _getHeaderImageLegendText() {
  return loc($"crewSkillParameter/legend/{this.id.tolower()}")
}

::g_skill_parameters_column_type._createValueItem <- function _createValueItem(
  prevValue, curValue, prevSelectedValue, curSelectedValue, measureType, sign) {
  local itemText = this.getDiffText(prevValue, curValue, sign, measureType, this.textColor)
  let selectedDiffText = this.getDiffText(prevSelectedValue - prevValue,
    curSelectedValue - curValue, sign, measureType, "userlogColoredText", true)
  itemText = "".concat(itemText, selectedDiffText)

  if (this.addMeasureUnits)
    itemText = "".concat(itemText, format(" %s", colorize(this.textColor, measureType.getMeasureUnitsName())))
  let valueItem = {
    itemText = itemText
  }
  return valueItem
}

::g_skill_parameters_column_type._getDiffText <- function _getDiffText(prevValue, curValue, sign, measureType, colorName, isAdditionalText = false) {
  let diffAbsValue = fabs(curValue - prevValue)
  if (isAdditionalText && !diffAbsValue)
    return ""

  local diffText = measureType.getMeasureUnitsText(diffAbsValue, false, true)
  if (isAdditionalText && diffText == "0")
    return ""

  local diffSignChar = ""
  if ((curValue - prevValue < 0) || (this.addSignChar && !diffAbsValue && !sign))
    diffSignChar = "-"
  else if (this.addSignChar || isAdditionalText)
    diffSignChar = "+"

  diffText = $"{diffSignChar}{diffText}"
  if (diffAbsValue > 0)
    diffText = colorize(colorName, diffText)
  return diffText
}

::g_skill_parameters_column_type._isSkillNotOnlyForTotalAndTop <- function _isSkillNotOnlyForTotalAndTop(memberName, skillName) {
  return (memberName != "commander" || skillName != "leadership")
         && (memberName != "ship_commander" || skillName != "leadership")
         && (memberName != "gunner" || skillName != "members")
         && (memberName != "groundService" || skillName != "repairRank")
}

::g_skill_parameters_column_type.template <- {
  id = "" 
  headerLocId = ""
  previousParametersRequestType = null
  currentParametersRequestType = null
  textColor = ""
  imageName = ""
  imageSize = 0
  addDummyBlock = false
  addSignChar = true
  addMeasureUnits = false
  sortOrder = skillColumnOrder.UNKNOWN

  


  checkSkill = ::g_skill_parameters_column_type._checkSkill

  


  checkCrewUnitType = ::g_skill_parameters_column_type._checkCrewUnitType

  getHeaderText = ::g_skill_parameters_column_type._getHeaderText
  getHeaderImage = ::g_skill_parameters_column_type._getHeaderImage
  getHeaderImageLegendText = ::g_skill_parameters_column_type._getHeaderImageLegendText
  createValueItem = ::g_skill_parameters_column_type._createValueItem
  getDiffText = ::g_skill_parameters_column_type._getDiffText
}

enums.addTypesByGlobalName("g_skill_parameters_column_type", {

  


  BASE = {
    sortOrder = skillColumnOrder.BASE
    headerLocId = "crewSkillParameterTable/baseValueText"
    previousParametersRequestType = null
    currentParametersRequestType = skillParametersRequestType.BASE_VALUES
    addSignChar = false

    checkSkill = ::g_skill_parameters_column_type._isSkillNotOnlyForTotalAndTop
  }

  




  SKILLS = {
    sortOrder = skillColumnOrder.SKILLS
    previousParametersRequestType = skillParametersRequestType.BASE_VALUES
    currentParametersRequestType = skillParametersRequestType.CURRENT_VALUES_NO_SPEC_AND_LEADERSHIP
    textColor = "goodTextColor"
    imageName = "#ui/gameuiskin#skill_star_1.svg"
    imageSize = 27

    checkSkill = ::g_skill_parameters_column_type._isSkillNotOnlyForTotalAndTop
  }

  


  SPECIALIZATION = {
    sortOrder = skillColumnOrder.SPECIALIZATION
    previousParametersRequestType = skillParametersRequestType.CURRENT_VALUES_NO_SPEC_AND_LEADERSHIP
    currentParametersRequestType = skillParametersRequestType.CURRENT_VALUES_NO_LEADERSHIP
    textColor = "goodTextColor"
    imageSize = 27

    checkSkill = function (memberName, skillName) {
      return isAffectedBySpecialization(memberName, skillName)
    }

    getHeaderImage = function (params) {
      return getSpecTypeByCrewAndUnit(params.crew, params.unit).trainedIcon
    }
  }

  



  LEADERSHIP = {
    sortOrder = skillColumnOrder.LEADERSHIP
    previousParametersRequestType = skillParametersRequestType.CURRENT_VALUES_NO_LEADERSHIP
    currentParametersRequestType = skillParametersRequestType.CURRENT_VALUES
    textColor = "goodTextColor"
    imageName = "#ui/gameuiskin#leaderBonus.svg"
    imageSize = 27

    checkSkill = function (memberName, skillName) {
      return isAffectedByLeadership(memberName, skillName)
    }
    checkCrewUnitType = @(crewUnitType) crewUnitType == CUT_TANK || crewUnitType == CUT_SHIP
  }

  



  GUNNERS_COUNT = {
    sortOrder = skillColumnOrder.GUNNERS_COUNT
    checkSkill = @(memberName, skillName) memberName == "gunner" && skillName == "members"
    checkCrewUnitType = @(crewUnitType) crewUnitType == CUT_AIRCRAFT

    getHeaderText = function () {
      let unitName = getUnitName(getCachedCrewUnit())
      let pad = "    "
      return "".concat(pad, loc("crew/forUnit", { unitName = unitName }), pad)
    }

    createValueItem = function (_prevValue, _curValue, _prevSelectedValue, _curSelectedValue, _measureType, _sign) {
      let crewId = getCachedCrewId()
      let unit = getCachedCrewUnit()
      let isUnitCompatible = unit && unit.unitType.hasAiGunners &&
        this.checkCrewUnitType(unit.unitType.crewUnitType)
      let unitTotalGunners = isUnitCompatible ? (unit?.gunnersCount ?? 0) : 0
      let crewExpGunners = getCrewSkillValue(crewId, unit, "gunner", "members")
      let curGunners = min(crewExpGunners, unitTotalGunners)
      local text = "".concat(curGunners, loc("ui/slash"), unitTotalGunners)
      if (isUnitCompatible) {
        let color = crewExpGunners < unitTotalGunners ? "badTextColor" : "goodTextColor"
        text = colorize(color, text)
      }
      return {
        itemText = text
      }
    }
  }

  



  GUNNERS = {
    sortOrder = skillColumnOrder.GUNNERS
    previousParametersRequestType = skillParametersRequestType.CURRENT_VALUES_NO_LEADERSHIP
    currentParametersRequestType = skillParametersRequestType.CURRENT_VALUES
    textColor = "badTextColor"
    imageName = "#ui/gameuiskin#gunnerBonus.svg"
    imageSize = 27

    checkSkill = function (memberName, skillName) {
      return memberName == "gunner" && skillName != "members"
    }

    checkCrewUnitType = function (crewUnitType) {
      return crewUnitType == CUT_AIRCRAFT
    }
  }

  


  MAX = {
    sortOrder = skillColumnOrder.MAX
    headerLocId = "crewSkillParameterTable/maxValueText"
    previousParametersRequestType = null
    currentParametersRequestType = skillParametersRequestType.MAX_VALUES
    addSignChar = false
    addMeasureUnits = true
  }

  


  EMPTY = {
    sortOrder = skillColumnOrder.EMPTY
    addDummyBlock = true

    createValueItem = function (_prevValue, _curValue, _prevSelectedValue, _curSelectedValue, _measureType, _sign) {
      return {
        itemDummy = true
      }
    }
  }

  


  EQUALS_SIGN = {
    sortOrder = skillColumnOrder.EQUALS_SIGN
    createValueItem = function (_prevValue, _curValue, _prevSelectedValue, _curSelectedValue, _measureType, _sign) {
      return {
        itemText = "="
      }
    }

    getHeaderText = function () {
      return ""
    }

    checkSkill = ::g_skill_parameters_column_type._isSkillNotOnlyForTotalAndTop
  }

  


  TOTAL = {
    sortOrder = skillColumnOrder.TOTAL
    addMeasureUnits = true
    headerLocId = "crewSkillParameterTable/currentValueText"
    previousParametersRequestType = null
    currentParametersRequestType = skillParametersRequestType.CURRENT_VALUES
    addSignChar = false
  }
}, null, "id")

::g_skill_parameters_column_type.types.sort(function(a, b) {
  if (a.sortOrder != b.sortOrder)
    return a.sortOrder < b.sortOrder ? -1 : 1
  return 0
})