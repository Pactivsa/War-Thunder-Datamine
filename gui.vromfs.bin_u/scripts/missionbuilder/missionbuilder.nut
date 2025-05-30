from "%scripts/dagui_natives.nut" import fetch_first_builder
from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsCtors.nut" import create_option_combobox, create_option_list

let { currentCampaignMission, set_mission_for_takeoff, get_mission_settings, get_mutable_mission_settings, set_mission_settings
} = require("%scripts/missions/missionsStates.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let DataBlock = require("DataBlock")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { rnd } = require("dagor.random")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_obj } = require("%sqDagui/daguiUtil.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { get_gui_option, getCdBaseDifficulty } = require("guiOptions")
let { dynamicInit, dynamicGetList, dynamicTune, dynamicSetTakeoffMode,
} = require("dynamicMission")
let { select_mission_full } = require("guiMission")
let { setSummaryPreview } = require("%scripts/missions/mapPreview.nut")
let { OPTIONS_MODE_DYNAMIC, USEROPT_DYN_MAP, USEROPT_DYN_ZONE, USEROPT_DYN_SURROUND,
  USEROPT_DMP_MAP, USEROPT_FRIENDLY_SKILL, USEROPT_ENEMY_SKILL, USEROPT_DIFFICULTY,
  USEROPT_TIME, USEROPT_CLIME, USEROPT_TAKEOFF_MODE, USEROPT_LIMITED_FUEL,
  USEROPT_LIMITED_AMMO, USEROPT_WEAPONS, USEROPT_SKIN, USEROPT_DYN_ALLIES,
  USEROPT_DYN_ENEMIES
} = require("%scripts/options/optionsExtNames.nut")
let { create_options_container, get_option } = require("%scripts/options/optionsExt.nut")
let { getCurSlotbarUnit } = require("%scripts/slotbar/slotbarState.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getBattleTypeByUnit } = require("%scripts/airInfo.nut")
let { unitNameForWeapons } = require("%scripts/weaponry/unitForWeapons.nut")
let { isUnitAvailableForGM } = require("%scripts/unit/unitInSlotbarStatus.nut")
let { addMissionListFull, getMaxPlayersForGamemode } = require("%scripts/missions/missionsUtils.nut")
let { checkDiffPkg } = require("%scripts/clientState/contentPacks.nut")
let { canJoinFlightMsgBox } = require("%scripts/squads/squadUtils.nut")

function mergeToBlk(sourceTable, blk) {
  foreach (idx, val in sourceTable)
    blk[idx] = val
}

gui_handlers.MissionBuilder <- class (gui_handlers.GenericOptionsModal) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/options/genericOptionsMap.blk"
  sceneNavBlkName = "%gui/navBuilderOptions.blk"
  wndGameMode = GM_BUILDER
  wndOptionsMode = OPTIONS_MODE_DYNAMIC

  applyAtClose = false
  can_generate_missions = true 
  
  needSlotbar = true

  function initScreen() {
    gui_handlers.GenericOptions.initScreen.bindenv(this)()

    this.guiScene.setUpdatesEnabled(false, false)
    this.init_builder_map()
    this.generate_builder_list(true)

    let options =
    [
      [USEROPT_DYN_MAP, "combobox"],
      [USEROPT_DYN_ZONE, "combobox"],
      [USEROPT_DYN_SURROUND, "spinner"],
      [USEROPT_DMP_MAP, "spinner"],
      [USEROPT_FRIENDLY_SKILL, "spinner"],
      [USEROPT_ENEMY_SKILL, "spinner"],
      [USEROPT_DIFFICULTY, "spinner"],
      [USEROPT_TIME, "spinner"],
      [USEROPT_CLIME, "spinner"],
      [USEROPT_TAKEOFF_MODE, "combobox"],
      [USEROPT_LIMITED_FUEL, "spinner"],
      [USEROPT_LIMITED_AMMO, "spinner"],
    ]

    let container = create_options_container("builder_options", options, true, 0.5, true)
    let optListObj = this.scene.findObject("optionslist")
    this.guiScene.replaceContentFromText(optListObj, container.tbl, container.tbl.len(), this)
    this.optionsContainers.append(container.descr)
    this.setSceneTitle(loc("mainmenu/btnDynamicTraining"), this.scene, "menu-title")

    let desc = get_option(USEROPT_DYN_ZONE)
    let dynZoneObj = this.guiScene["dyn_zone"]
    local value = desc.value
    if (checkObj(dynZoneObj))
      value = this.guiScene["dyn_zone"].getValue()

    setSummaryPreview(this.scene.findObject("tactical-map"), DataBlock(), desc.values[value])

    if (get_mission_settings().dynlist.len() == 0)
      return this.msgBox("no_missions_error", loc("msgbox/appearError"),
                     [["ok", this.goBack ]], "ok", { cancel_fn = this.goBack })

    this.update_takeoff()

    this.reinitOptionsList()
    this.guiScene.setUpdatesEnabled(true, true)

    if (fetch_first_builder())
      this.randomize_builder_options()

    if (this.needSlotbar)
      this.createSlotbar()

    move_mouse_on_obj(this.scene.findObject("btn_select"))
  }

  function reinitOptionsList() {
    if (!checkObj(this.scene))
      return this.goBack()

    this.updateButtons()

    let showOptions = this.isBuilderAvailable()

    let optListObj = this.scene.findObject("options_data")
    let textObj = this.scene.findObject("no_options_textarea")
    optListObj.show(showOptions)
    textObj.setValue(showOptions ? ""
      : loc(showedUnit.value != null ? "msg/builderOnlyForAircrafts" : "events/empty_crew"))

    if (!showOptions)
      return

    this.update_dynamic_map()
  }

  function isBuilderAvailable() {
    return isUnitAvailableForGM(showedUnit.value, GM_BUILDER)
  }

  function updateButtons() {
    if (!checkObj(this.scene))
      return

    let available = this.isBuilderAvailable()
    this.scene.findObject("btn_select").inactiveColor = available ? "no" : "yes"
    showObjById("btn_random", available, this.scene)
  }

  function onApply() {
    if (!canJoinFlightMsgBox({
        maxSquadSize = getMaxPlayersForGamemode(GM_BUILDER)
      }))
      return

    if (!this.isBuilderAvailable())
      return this.msgBox("not_available", loc(showedUnit.value != null ? "msg/builderOnlyForAircrafts" : "events/empty_crew"),
        [["ok"]], "ok")

    if (isInArray(this.getSceneOptValue(USEROPT_DIFFICULTY), ["hardcore", "custom"]))
      if (!checkDiffPkg(g_difficulty.SIMULATOR.diffCode))
        return

    this.applyOptions()
  }

  function getSceneOptRes(optName) {
    let option = get_option(optName)
    let obj = this.scene.findObject(option.id)
    local value = obj ? obj.getValue() : -1
    if (!(value in option.items))
      value = option.value
    return { name = option.items[value], value = option.values[value] }
  }

  function init_builder_map() {
    let mapData = this.getSceneOptRes(USEROPT_DYN_MAP)
    set_mission_settings("layout", mapData.value)
    set_mission_settings("layoutName", mapData.name)

    let settings = DataBlock();
    local playerSide = 1
    foreach (tag in (showedUnit.value?.tags ?? []))
      if (tag == "axis") {
        playerSide = 2
        break
      }
    settings.setInt("playerSide", playerSide)
    dynamicInit(settings, mapData.value)
  }

  function generate_builder_list(wait) {
    if (!this.can_generate_missions)
      return
    if (showedUnit.value == null)
      return

    unitNameForWeapons.set(showedUnit.value.name)

    let settings = DataBlock();
    settings.setStr("player_class", showedUnit.value.name)
    settings.setStr("player_weapons", get_gui_option(USEROPT_WEAPONS) ?? "")
    settings.setStr("player_skin", this.getSceneOptValue(USEROPT_SKIN) || "")
    settings.setStr("wishSector", this.getSceneOptValue(USEROPT_DYN_ZONE))
    settings.setInt("sectorSurround", this.getSceneOptValue(USEROPT_DYN_SURROUND))
    settings.setStr("year", "year_any")
    settings.setBool("isQuickMissionBuilder", true)

    set_mission_settings("dynlist", dynamicGetList(settings, wait))

    let add = []
    foreach (mis in get_mutable_mission_settings().dynlist) {
      let misblk = mis.mission_settings.mission

      mergeToBlk(::missionBuilderVehicleConfigForBlk, misblk)

      misblk.setStr("mis_file", get_mission_settings().layout)
      misblk.setStr("type", "builder")
      misblk.setStr("chapter", "builder")
      if (get_mission_settings().coop)
        misblk.setBool("gt_cooperative", true);
      add.append(misblk)
    }
    addMissionListFull(GM_BUILDER, add, get_mutable_mission_settings().dynlist)
  }

  function update_dynamic_map() {
    let descr = get_option(USEROPT_DYN_MAP)
    let dObj = this.scene.findObject(descr.id)
    if (!dObj?.isValid())
      return
    let txt = create_option_list(descr.id, descr.items, descr.value, descr.cb, false)
    this.guiScene.replaceContentFromText(dObj, txt, txt.len(), this)

    this.init_builder_map()
    if (descr.cb in this)
      this[descr.cb](dObj)
  }

  function update_dynamic_layout(guiScene, _obj, _descr) {
    this.init_builder_map()

    let descrWeap = get_option(USEROPT_DYN_ZONE)
    let txt = create_option_list(descrWeap.id, descrWeap.items, descrWeap.value, "onSectorChange", false)
    let dObj = this.scene.findObject(descrWeap.id)
    guiScene.replaceContentFromText(dObj, txt, txt.len(), this)
    return descrWeap
  }

  function update_dynamic_sector(guiScene, _obj, _descr) {
    this.generate_builder_list(true)
    let descrWeap = get_option(USEROPT_DMP_MAP)
    let txt = create_option_list(descrWeap.id, descrWeap.items, descrWeap.value, null, false)
    let dObj = this.scene.findObject(descrWeap.id)
    guiScene.replaceContentFromText(dObj, txt, txt.len(), this)

    this.update_takeoff()

    setSummaryPreview(this.scene.findObject("tactical-map"), DataBlock(), this.getSceneOptValue(USEROPT_DYN_ZONE))

    return descrWeap
  }

  function update_takeoff() {
    local haveTakeOff = false
    let mapObj = this.scene.findObject("dyn_mp_map")
    if (checkObj(mapObj))
      set_mission_settings("currentMissionIdx", mapObj.getValue())

    let dynMission = getTblValue(get_mission_settings().currentMissionIdx, get_mutable_mission_settings().dynlist)
    if (!dynMission)
      return

    if (dynMission.mission_settings.mission.paramExists("takeoff_mode"))
      haveTakeOff = true

    set_mission_for_takeoff(dynMission.mission_settings.mission.name)
    let descrWeap = get_option(USEROPT_TAKEOFF_MODE)
    if (!haveTakeOff) {
      for (local i = 0; i < descrWeap.items.len(); i++)
        descrWeap.items[i] = { text = descrWeap.items[i], enabled = (i == 0) }
      descrWeap.value = 0
    }
    let txt = create_option_combobox(descrWeap.id, descrWeap.items, descrWeap.value, "onMissionChange", false)
    let dObj = this.scene.findObject(descrWeap.id)
    if (checkObj(dObj))
      this.guiScene.replaceContentFromText(dObj, txt, txt.len(), this)
  }

  function setRandomOpt(optName) {
    let desc = get_option(optName)
    let obj = this.scene.findObject(desc.id)

    if (desc.values.len() == 0) {
      let settings = toString({                      
        DYN_MAP = this.getSceneOptValue(USEROPT_DYN_MAP),
        DYN_ZONE = this.getSceneOptValue(USEROPT_DYN_ZONE),
        DYN_SURROUND = this.getSceneOptValue(USEROPT_DYN_SURROUND),
        DMP_MAP = this.getSceneOptValue(USEROPT_DMP_MAP),
        FRIENDLY_SKILL = this.getSceneOptValue(USEROPT_FRIENDLY_SKILL),
        ENEMY_SKILL = this.getSceneOptValue(USEROPT_ENEMY_SKILL),
        DIFFICULTY = this.getSceneOptValue(USEROPT_DIFFICULTY),
        TIME = this.getSceneOptValue(USEROPT_TIME),
        WEATHER = this.getSceneOptValue(USEROPT_CLIME),
        TAKEOFF_MODE = this.getSceneOptValue(USEROPT_TAKEOFF_MODE),
        LIMITED_FUEL = this.scene.findObject(get_option(USEROPT_LIMITED_FUEL)?.id ?? "").getValue(),
        LIMITED_AMMO = this.scene.findObject(get_option(USEROPT_LIMITED_AMMO)?.id ?? "").getValue()
      })
      let currentUnit = showedUnit.value?.name         
      let slotbarUnit = getCurSlotbarUnit()?.name 
      let optId = desc.id                              
      let values = toString(desc.values)             
      script_net_assert_once("MissionBuilder", "ERROR: Empty value in options.")
      return
    }

    if (obj)
      obj.setValue(rnd() % desc.values.len())
  }

  function randomize_builder_options() {
    if (!checkObj(this.scene))
      return

    this.can_generate_missions = false
    this.guiScene.setUpdatesEnabled(false, false)

    this.setRandomOpt(USEROPT_DYN_MAP)
    this.onLayoutChange(this.scene.findObject("dyn_map"))

    this.guiScene.performDelayed(this, function() {
        if (!this.isValid())
          return

        this.setRandomOpt(USEROPT_DYN_ZONE)
        this.onSectorChange(this.scene.findObject("dyn_zone"))

        this.guiScene.performDelayed(this, function() {
            if (!this.isValid())
              return

            foreach (o in [USEROPT_TIME, USEROPT_CLIME, USEROPT_DYN_SURROUND])
              this.setRandomOpt(o)

            this.guiScene.performDelayed(this, function() {
                if (!this.isValid())
                  return

                this.setRandomOpt(USEROPT_DMP_MAP)

                this.can_generate_missions = true
                this.guiScene.setUpdatesEnabled(true, true)

                this.update_takeoff()
              }
            )
          }
        )
      }
    )
  }

  function applyFunc() {
    if (!canJoinFlightMsgBox({
        maxSquadSize = getMaxPlayersForGamemode(GM_BUILDER)
      }))
      return

    set_mission_settings("currentMissionIdx", this.scene.findObject("dyn_mp_map").getValue())
    let fullMissionBlk = getTblValue(get_mission_settings().currentMissionIdx, get_mutable_mission_settings().dynlist)
    if (!fullMissionBlk)
      return

    if (fullMissionBlk.mission_settings.mission.paramExists("takeoff_mode")) {
      let takeoff_mode = this.scene.findObject("takeoff_mode").getValue()
      let land_mode = takeoff_mode
      dynamicSetTakeoffMode(fullMissionBlk, takeoff_mode, land_mode)
    }

    let settings = DataBlock()
    settings.setInt("allyCount",  this.getSceneOptValue(USEROPT_DYN_ALLIES))
    settings.setInt("enemyCount", this.getSceneOptValue(USEROPT_DYN_ENEMIES))
    settings.setInt("allySkill",  this.getSceneOptValue(USEROPT_FRIENDLY_SKILL))
    settings.setInt("enemySkill", this.getSceneOptValue(USEROPT_ENEMY_SKILL))
    settings.setStr("dayTime",    this.getSceneOptValue(USEROPT_TIME))
    settings.setStr("weather",    this.getSceneOptValue(USEROPT_CLIME))

    set_mission_settings("coop", false)
    set_mission_settings("friendOnly", false)
    set_mission_settings("allowJIP",  true)

    dynamicTune(settings, fullMissionBlk)

    let missionBlk = fullMissionBlk.mission_settings.mission

    missionBlk.setInt("_gameMode", GM_BUILDER)
    missionBlk.setBool("gt_cooperative", get_mission_settings().coop)
    if (get_mission_settings().coop) {
      set_mission_settings("players", 4)
      missionBlk.setInt("_players", 4)
      missionBlk.setInt("maxPlayers", 4)
      missionBlk.setBool("gt_use_lb", false)
      missionBlk.setBool("gt_use_replay", true)
      missionBlk.setBool("gt_use_stats", true)
      missionBlk.setBool("gt_sp_restart", false)
      missionBlk.setBool("isBotsAllowed", true)
      missionBlk.setBool("autoBalance", false)
      missionBlk.setBool("isPrivate", get_mission_settings().friendOnly)
      missionBlk.setBool("allowJIP", ! get_mission_settings().friendOnly)
    }

    missionBlk.setStr("difficulty", this.getSceneOptValue(USEROPT_DIFFICULTY))
    missionBlk.setStr("restoreType", "attempts")

    missionBlk.setBool("isLimitedFuel", get_option(USEROPT_LIMITED_FUEL).value)
    missionBlk.setBool("isLimitedAmmo", get_option(USEROPT_LIMITED_AMMO).value)

    currentCampaignMission.set(missionBlk.getStr("name", ""))
    set_mission_settings("mission", missionBlk)
    set_mission_settings("missionFull", fullMissionBlk)
    select_mission_full(missionBlk, fullMissionBlk);

    

    loadHandler(gui_handlers.MissionBuilderTuner)
  }

  function onLayoutChange(obj) {
    this.guiScene.performDelayed(this, function() {
      if (!this.isValid())
        return
      this.updateOptionDescr(obj, this.update_dynamic_layout)
      this.updateOptionDescr(obj, this.update_dynamic_sector)
    })
  }

  function onMissionChange(_obj) {
    this.update_takeoff()
  }

  function onSectorChange(obj) {
    this.guiScene.performDelayed(this, function() {
      if (!this.isValid())
        return
      this.updateOptionDescr(obj, this.update_dynamic_sector)
    })
  }

  function onYearChange(obj) {
    this.guiScene.performDelayed(this, function() {
      if (!this.isValid())
        return
      this.updateOptionDescr(obj, this.update_dynamic_sector)
    })
  }

  function onRandom(_obj) {
    this.randomize_builder_options()
  }

  function getCurrentEdiff() {
    let diffValue = this.getSceneOptValue(USEROPT_DIFFICULTY)
    let difficulty = (diffValue == "custom") ?
      g_difficulty.getDifficultyByDiffCode(getCdBaseDifficulty()) :
      g_difficulty.getDifficultyByName(diffValue)
    if (difficulty.diffCode != -1) {
      let battleType = getBattleTypeByUnit(showedUnit.value)
      return difficulty.getEdiff(battleType)
    }
    return getCurrentGameModeEdiff()
  }

  function getHandlerRestoreData() {
    return {
      openData = { needSlotbar = this.needSlotbar }
    }
  }

  function onEventBeforeStartMissionBuilder(_p) {
    handlersManager.requestHandlerRestore(this, gui_handlers.MainMenu)
  }

  onEventShowedUnitChanged = @(_p) this.reinitOptionsList()
}