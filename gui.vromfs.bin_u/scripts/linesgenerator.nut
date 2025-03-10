from "%scripts/dagui_library.nut" import *
from "%sqDagui/daguiNativeApi.nut" import DaGuiObject

let { Point2 } = require("dagor.math")
let { abs } = require("math")
let { GuiBox, getBlockFromObjData } = require("%scripts/guiBox.nut")
let { format } = require("string")

















































enum lines_priorities { 
  OBSTACLE = 0
  TARGET   = 1,
  LINE     = 2,
  TEXT     = 3,

  MAXIMUM  = 3
}

function getHelpDotMarkup(point  , tag = "helpLineDot") {
  return format("%s { pos:t='%d-0.5w, %d-0.5h'; position:t='absolute' } ", tag, point.x.tointeger(), point.y.tointeger())
}

function monoLineCountDiapason(link, checkBox, axis, obstacles) {
  
  local diapason = [[checkBox.c1[axis], checkBox.c2[axis]]]
  for (local j = obstacles.len() - 1; j >= 0; j--) {
    let box = obstacles[j]
    if (!box.isIntersect(checkBox))
      continue
    if (link && (link[0].isInside(box) || link[1].isInside(box)))
      continue

    if (box.c1[axis] < checkBox.c1[axis] && box.c2[axis] > checkBox.c2[axis]) {
      diapason = null
      break
    }

    local found = false
    let start = box.c1[axis]
    let end = box.c2[axis]
    for (local d = diapason.len() - 1; d >= 0; d--) {
      let segment = diapason[d]
      if (segment[1] < start)
        break
      if (!found && segment[0] > end)
        continue

      diapason.remove(d)
      if (!found && segment[1] > end)
        diapason.insert(d, [end + 1, segment[1]])
      found = true

      if (segment[0] < start) {
        diapason.insert(d, [segment[0], start - 1])
        break
      }
    }
  }
  return diapason
}

function monoLineGetBestPos(diapason, checkBox, axis, lineWidth, bestPos = null) { 
  if (bestPos == null)
    bestPos = ((checkBox.c1[axis] + checkBox.c2[axis] - lineWidth) / 2).tointeger()

  local found = false
  local pos = 0
  for (local d = diapason.len() - 1; d >= 0; d--) {
    let segment = diapason[d]
    if (segment[1] - segment[0] < lineWidth)
      continue

    if (segment[0] > bestPos) {
      pos = segment[0]
      found = true
      continue
    }

    let _pos = min(bestPos, segment[1] - lineWidth)
    if (!found || (bestPos - _pos) < (pos - bestPos))
      pos = _pos
    found = true
    break
  }
  return found ? pos : null
}

function findGoodPos(obj, axis, obstacles, posMin, posMax, bestPos = null) {
  let box = GuiBox().setFromDaguiObj(obj)
  let objWidth = box.c2[axis] - box.c1[axis]
  box.c1[axis] = posMin
  box.c2[axis] = posMax

  let diapason = monoLineCountDiapason(null, box, axis, obstacles)
  if (diapason && diapason.len())
    return monoLineGetBestPos(diapason, box, axis, objWidth, bestPos)
  return null
}

function addLinesBoxes(obstacles, linesBoxes, priority, interval) {
  if (priority > lines_priorities.LINE)
    return

  foreach (box in linesBoxes) {
    let newBox = interval ? box.cloneBox(interval) : box
    newBox.priority = lines_priorities.LINE
    obstacles.append(newBox)
  }
}

function getP2byAxisCoords(axis, axisValue, altAxisValue) {
  return Point2(axis ? altAxisValue : axisValue, axis ? axisValue : altAxisValue)
}

function getBoxByAxis(axisIdx, axis0, axis1, altAxis0, altAxis1) {
  if (axisIdx)
    return GuiBox(altAxis0, axis0, altAxis1, axis1)
  return GuiBox(axis0, altAxis0, axis1, altAxis1)
}

function getLineBoxByP2(start_dot, end_dot, lineWidth) {
  return GuiBox(min(start_dot.x, end_dot.x), min(start_dot.y, end_dot.y),
                  max(start_dot.x, end_dot.x) + ((start_dot.x == end_dot.x) ? lineWidth : 0),
                  max(start_dot.y, end_dot.y) + ((start_dot.y == end_dot.y) ? lineWidth : 0))
}


function checkLinkIntersect(res, links) {
  for (local i = links.len() - 1; i >= 0; i--) {
    let link = links[i]
    let dot = link[1].getIntersectCorner(link[0])
    if (!dot)
      continue

    res.dots0.append(dot)
    res.dots1.append(dot)
    links.remove(i)
  }
  return res
}

function genMonoLines(res, links, obstacles, interval, lineWidth, priority) {
  for (local i = links.len() - 1; i >= 0; i--) {
    let link = links[i]
    
    local checkBox = null
    local axis = 0 
    for (local a = 0; a < 2; a++)
      if (link[0].c2[a] > link[1].c1[a]
        && link[1].c2[a] > link[0].c1[a]) {
        axis = a
        checkBox = GuiBox()
        checkBox.c1[1 - a] = min(link[0].c2[1 - a], link[1].c2[1 - a])
        checkBox.c2[1 - a] = max(link[0].c1[1 - a], link[1].c1[1 - a])
        checkBox.c1[a] = max(link[0].c1[a], link[1].c1[a])
        checkBox.c2[a] = min(link[0].c2[a], link[1].c2[a])
        break
      }
    if (!checkBox)
      continue

    
    let diapason = monoLineCountDiapason(link, checkBox, axis, obstacles)
    if (!diapason || !diapason.len())
      continue

    
    let pos = monoLineGetBestPos(diapason, checkBox, axis, lineWidth)
    if (pos == null)
      continue

    
    checkBox.c1[axis] = pos
    checkBox.c2[axis] = pos + lineWidth
    res.lines.append(checkBox)
    addLinesBoxes(obstacles, [checkBox], priority, interval)

    let dotPos = pos + (0.5 * lineWidth).tointeger()
    let dot0 = getP2byAxisCoords(axis, dotPos, checkBox.c1[1 - axis])
    let dot1 = getP2byAxisCoords(axis, dotPos, checkBox.c2[1 - axis])
    let invertDots = link[0].c1[1 - axis] > link[1].c1[1 - axis]
    res.dots0.append(invertDots ? dot1 : dot0)
    res.dots1.append(invertDots ? dot0 : dot1)
    links.remove(i)
  }
  return res
}

function cloneDoubleLineZone(zone) {
  let diapason = []
  foreach (d in zone.diapason)
    diapason.append([d[0], d[1]])
  return {
    start = zone.start
    end = zone.end
    diapason = diapason
  }
}

function doubleLineCutZoneList(zoneData, box) {
  let axis = zoneData.axis
  let zoneList = zoneData.zone
  let wayAxis = zoneData.wayAxis
  let wayAltAxis = zoneData.wayAltAxis

  let zStart = box.c1[axis]
  let zEnd   = box.c2[axis]
  let dStart = box.c1[1 - axis]
  let dEnd   = box.c2[1 - axis]
  for (local z = zoneList.len() - 1; z >= 0; z--) {
    local zone = zoneList[z]
    if (zone.end > zEnd && zone.start < zEnd) {
      let newZone = cloneDoubleLineZone(zone)
      zone.end = zEnd
      newZone.start = zEnd + 1
      zoneList.insert(++z, newZone)
      zone = newZone
    }
    else if (zone.end > zStart && zone.start < zStart) {
      let newZone = cloneDoubleLineZone(zone)
      zone.end = zStart - 1
      newZone.start = zStart
      zoneList.insert(++z, newZone)
      zone = newZone
    }

    if ((!wayAxis && zone.start > zEnd)
        || (wayAxis && zone.end < zStart))
      continue 

    local found = false
    let diapason = zone.diapason
    let zoneFree = zone.start >= zEnd || zone.end <= zStart
    for (local d = diapason.len() - 1; d >= 0; d--) {
      let segment = diapason[d]
      if (segment[1] < dStart)
        if (!zoneFree && wayAltAxis) {
          diapason.remove(d)
          continue
        }
        else
          break

      if (!found && segment[0] > dEnd) {
        if (!zoneFree && !wayAltAxis)
          diapason.remove(d)
        continue
      }

      diapason.remove(d)
      if ((zoneFree || wayAltAxis) && !found && segment[1] > dEnd)
        diapason.insert(d, [dEnd + 1, segment[1]])
      found = true

      if ((zoneFree || !wayAltAxis) && segment[0] < dStart) {
        diapason.insert(d, [segment[0], dStart - 1])
        break
      }
    }
    if (!diapason.len())
      zoneList.remove(z)
  }
  return zoneList.len()
}

function doubleLineZoneCheckObstacles(zones, link, obstacles) {
  for (local o = obstacles.len() - 1; o >= 0; o--) {
    let box = obstacles[o]
    for (local z = zones.len() - 1; z >= 0; z--) {
      let zoneData = zones[z]
      if (!box.isIntersect(zoneData.box))
        continue

      if (link[0].isInside(box) || link[1].isInside(box))
        continue 

      let count = doubleLineCutZoneList(zoneData, box)
      if (!count)
        zones.remove(z)
    }
    if (!zones.len())
      break
  }
  return zones
}

function doubleLineChooseBestInZone(zoneData, link, lineWidth) {
  let axis = zoneData.axis
  let bestPos =    ((link[1].c1[axis] + link[1].c2[axis] - lineWidth) / 2).tointeger()
  let altBestPos = ((link[0].c1[1 - axis] + link[0].c2[1 - axis] - lineWidth) / 2).tointeger()
  local found = false
  local posAxis = 0
  local posAltAxis = 0
  local bestDiff = 0
  for (local z = zoneData.zone.len() - 1; z >= 0; z--) {
    let zone = zoneData.zone[z]
    if (zone.end - zone.start < lineWidth)
      continue

    let _posAxis = (zone.start > bestPos) ? zone.start : min(bestPos, zone.end - lineWidth)
    local _posAltAxis = 0
    local dFound = false
    let diapason = zone.diapason
    for (local d = diapason.len() - 1; d >= 0; d--) {
      let segment = diapason[d]
      if (segment[1] - segment[0] < lineWidth)
        continue

      if (segment[0] > altBestPos) {
        _posAltAxis = segment[0]
        dFound = true
        continue
      }

      let _dpos = min(altBestPos, segment[1] - lineWidth)
      if (!dFound || (altBestPos - _dpos) < (_posAltAxis - altBestPos))
        _posAltAxis = _dpos
      dFound = true
      break
    }

    if (!dFound)
      continue

    let _bestDiff = abs(_posAxis - bestPos) + abs(_posAltAxis - altBestPos)
    if (!found || _bestDiff < bestDiff) {
      found = true
      bestDiff = _bestDiff
      posAxis = _posAxis
      posAltAxis = _posAltAxis
      if (bestDiff == 0)
        break
    }
  }
  if (found)
    return [posAxis, posAltAxis]
  return null
}

function doubleLineGetZones(link) {
  let zones = []  
                    
  for (local j = 0; j < 2; j++) { 
    if (link[0].c1[j] > link[1].c1[j]) {  
      if (link[0].c1[1 - j] < link[1].c1[1 - j]) 
        zones.append({
          box = getBoxByAxis(j, link[1].c1[j], link[0].c1[j], link[0].c1[1 - j], link[1].c1[1 - j])
          zone = [{ start = link[1].c1[j]
                    end   = min(link[0].c1[j],   link[1].c2[j])
                    diapason = [[link[0].c1[1 - j], min(link[1].c1[1 - j], link[0].c2[1 - j])]]
                 }]
          axis = j
          wayAxis = false
          wayAltAxis = true
        })
      if (link[0].c2[1 - j] > link[1].c2[1 - j])  
        zones.append({
          box = getBoxByAxis(j, link[1].c1[j], link[0].c1[j], link[1].c2[1 - j], link[0].c2[1 - j])
          zone = [{ start = link[1].c1[j]
                    end   = min(link[0].c1[j],   link[1].c2[j])
                    diapason = [[max(link[1].c2[1 - j], link[0].c1[1 - j]), link[0].c2[1 - j]]]
                 }]
          axis = j
          wayAxis = false
          wayAltAxis = false
        })
    }
    if (link[0].c2[j] < link[1].c2[j]) {  
      if (link[0].c1[1 - j] < link[1].c1[1 - j])  
        zones.append({
          box = getBoxByAxis(j, link[0].c2[j], link[1].c2[j], link[0].c1[1 - j], link[1].c1[1 - j])
          zone = [{ start = max(link[0].c2[j], link[1].c1[j])
                    end   = link[1].c2[j]
                    diapason = [[link[0].c1[1 - j], min(link[1].c1[1 - j], link[0].c2[1 - j])]]
                 }]
          axis = j
          wayAxis = true
          wayAltAxis = true
        })
      if (link[0].c2[1 - j] > link[1].c2[1 - j]) 
        zones.append({
          box = getBoxByAxis(j, link[0].c2[j], link[1].c2[j], link[1].c2[1 - j], link[0].c2[1 - j])
          zone = [{ start = max(link[0].c2[j], link[1].c1[j])
                    end   = link[1].c2[j]
                    diapason = [[max(link[1].c2[1 - j], link[0].c1[1 - j]), link[0].c2[1 - j]]]
                 }]
          axis = j
          wayAxis = true
          wayAltAxis = false
        })
    }
  }
  return zones
}

function genDoubleLines(res, links, obstacles, interval, lineWidth, priority) {
  for (local i = links.len() - 1; i >= 0; i--) {
    let link = links[i]
    local zones = doubleLineGetZones(link)

    
    zones = doubleLineZoneCheckObstacles(zones, link, obstacles)
    if (!zones.len())
      continue

    
    zones.sort(function(a, b) {
        if (a.axis != b.axis)
          return a.axis ? 1 : -1
        if (a.wayAxis != b.wayAxis)
          return a.wayAxis ? -1 : 1
        if (a.wayAltAxis != b.wayAltAxis)
          return a.wayAltAxis ? -1 : 1
        return 0;
      })

    
    for (local z = 0; z < zones.len(); z++) {
      let zoneData = zones[z]
      let lineData = doubleLineChooseBestInZone(zoneData, link, lineWidth)
      if (!lineData)
        continue

      let axis = zoneData.axis
      let box = zoneData.box
      let halfWidth = (0.5 * lineWidth).tointeger()
      let dot0 = getP2byAxisCoords(axis, zoneData.wayAxis ? box.c1[axis] : box.c2[axis], lineData[1])
      let dot1 = getP2byAxisCoords(axis, lineData[0], lineData[1])
      let dot2 = getP2byAxisCoords(axis, lineData[0], zoneData.wayAltAxis ? box.c2[1 - axis] : box.c1[1 - axis])

      let linesList = [ getLineBoxByP2(dot0, dot1, lineWidth)
                          getLineBoxByP2(dot1, dot2, lineWidth)
                        ]
      res.lines.extend(linesList)
      addLinesBoxes(obstacles, linesList, priority, interval)

      dot0.x += halfWidth
      dot0.y += halfWidth
      dot2.x += halfWidth
      dot2.y += halfWidth
      res.dots0.append(dot0)
      res.dots1.append(dot2)
      links.remove(i)
      break
    }
  }
  return res
}

function createLinkLines(links, obstacles, interval = 0, lineWidth = 1, priority = 0, initial = true) {
  let res = {
    lines = []
    dots0 = []
    dots1 = []
  }
  if (initial) {
    let _links = links
    links = []
    for (local i = _links.len() - 1; i >= 0; i--) 
      links.append(_links[i])
    let _obstacles = obstacles
    obstacles = []
    for (local i = 0; i < _obstacles.len(); i++)
      if (_obstacles[i].priority >= priority)
        obstacles.append(interval ? _obstacles[i].cloneBox(interval) : _obstacles[i])
    checkLinkIntersect(res, links)
  }
  else
    for (local i = obstacles.len() - 1; i >= 0; i--)
      if (obstacles[i].priority < priority)
        obstacles.remove(i)

  genMonoLines(res, links, obstacles, interval, lineWidth, priority)
  genDoubleLines(res, links, obstacles, interval, lineWidth, priority)

  
  
  if (links.len() && priority < lines_priorities.MAXIMUM) {
    let addRes = createLinkLines(links, obstacles, interval, lineWidth, priority + 1, false)
    foreach (key in ["lines", "dots0", "dots1"])
      res[key].extend(addRes[key])
  }
  return res
}

function generateLinkLinesMarkup(links, obstacleBoxList, interval = "@helpLineInterval", width = "@helpLineWidth") {
  let guiScene = get_cur_gui_scene()
  let lines = createLinkLines(links, obstacleBoxList, guiScene.calcString(interval, null),
                                                 guiScene.calcString(width, null))

  let shadowOffset = to_pixels("1@helpLineShadowOffset")
  let shadowOffsetArr = [ shadowOffset, shadowOffset ]
  let shadowOffsetP2 = Point2(shadowOffset, shadowOffset)

  local data = []
  foreach (box in lines.lines)
    data.append(box.cloneBox().incPos(shadowOffsetArr).getBlkText("helpLineShadow"))
  foreach (dot in lines.dots0)
    data.append(getHelpDotMarkup(dot + shadowOffsetP2, "helpLineDotShadow"))
  foreach (box in lines.lines)
    data.append(box.getBlkText("helpLine"))
  foreach (dot in lines.dots0)
    data.append(getHelpDotMarkup(dot, "helpLineDot"))

  return "".join(data, true)
}

function getLinkLinesMarkup(config) {
  if (!config)
    return ""

  let startObjContainer = getTblValue("startObjContainer", config, null)
  if (!checkObj(startObjContainer))
    return ""

  let endObjContainer = getTblValue("endObjContainer", config, null)
  if (!checkObj(endObjContainer))
    return ""

  let linksDescription = getTblValue("links", config)
  if (!linksDescription)
    return ""

  let boxList = []
  let links = []
  foreach (_idx, linkDescriprion in linksDescription) {
    let startBlock = getBlockFromObjData(linkDescriprion.start, startObjContainer)
    if (!startBlock)
      continue

    startBlock.box.priority = getTblValue("priority", linkDescriprion.start, lines_priorities.TEXT)
    boxList.append(startBlock.box)

    let endBlock = getBlockFromObjData(linkDescriprion.end, endObjContainer)
    if (!endBlock)
      continue

    endBlock.box.priority = getTblValue("priority", linkDescriprion.end, lines_priorities.TARGET)
    boxList.append(endBlock.box)

    links.append([endBlock.box, startBlock.box])
  }

  let lineInterval = config?.lineInterval ?? "@helpLineInterval"
  let lineWidth = getTblValue("lineWidth", config, "@helpLineWidth")

  let obstacles = getTblValue("obstacles", config, null)
  if (obstacles != null)
    foreach (_idx, obstacle in obstacles) {
      let obstacleBlock = getBlockFromObjData(obstacle, startObjContainer) ||
                                                getBlockFromObjData(obstacle, endObjContainer)
      if (!obstacleBlock)
        continue

      obstacleBlock.box.priority = getTblValue("priority", obstacle, lines_priorities.OBSTACLE)
      boxList.append(obstacleBlock.box)
    }

  return generateLinkLinesMarkup(links, boxList, lineInterval, lineWidth)
}

return {
  getLinkLinesMarkup
  generateLinkLinesMarkup
  findGoodPos
  createLinkLines
}