from "%scripts/dagui_natives.nut" import entitlement_expires_in, gchat_is_enabled, shop_get_premium_account_ent_name
from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let { Balance, Cost } = require("%scripts/money.nut")
let { format } = require("string")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let time = require("%scripts/time.nut")
let { isChatEnabled, hasMenuChat } = require("%scripts/chat/chatStates.nut")
let showTitleLogo = require("%scripts/viewUtils/showTitleLogo.nut")
let { setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { hasBattlePass } = require("%scripts/battlePass/unlocksRewardsState.nut")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { boosterEffectType, haveActiveBonusesByEffectType } = require("%scripts/items/boosterEffect.nut")
let globalCallbacks = require("%sqDagui/globalCallbacks/globalCallbacks.nut")
let { decimalFormat } = require("%scripts/langUtils/textFormat.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getProfileInfo, getCurExpTable } = require("%scripts/user/userInfoStats.nut")
let { getCustomNick } = require("%scripts/contacts/customNicknames.nut")
let { getFriendsOnlineNum } = require("%scripts/contacts/contactsInfo.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { chatRooms } = require("%scripts/chat/chatStorage.nut")
let { checkClanTagForDirtyWords } = require("%scripts/clans/clanTextInfo.nut")
let { getUnseenCandidatesCount } = require("%scripts/clans/clanCandidates.nut")
let { check_new_user_logs } = require("%scripts/userLog/userlogUtils.nut")
let { updateShortQueueInfo } = require("%scripts/queue/queueInfo/qiViewUtils.nut")
let { isItemsManagerEnabled } = require("%scripts/items/itemsManager.nut")
let { invitesAmount } = require("%scripts/invites/invitesState.nut")

let lastGamercardScenes = persist("lastGamercardScenes", @() [])

function doWithAllGamercards(func) {
  foreach (scene in lastGamercardScenes)
    if (checkObj(scene))
      func(scene)
}

function addGamercardScene(scene) {
  for (local idx = lastGamercardScenes.len() - 1; idx >= 0; idx--) {
    let s = lastGamercardScenes[idx]
    if (!checkObj(s))
      lastGamercardScenes.remove(idx)
    else if (s.isEqual(scene))
      return
  }
  lastGamercardScenes.append(scene)
}

::set_last_gc_scene_if_exist <- function set_last_gc_scene_if_exist(scene) {
  foreach (idx, gcs in lastGamercardScenes)
    if (checkObj(gcs) && scene.isEqual(gcs)
        && idx < lastGamercardScenes.len() - 1) {
      lastGamercardScenes.remove(idx)
      lastGamercardScenes.append(scene)
      break
    }
}

function getLastGamercardScene() {
  if (lastGamercardScenes.len() > 0)
    for (local i = lastGamercardScenes.len() - 1; i >= 0; i--)
      if (checkObj(lastGamercardScenes[i]))
        return lastGamercardScenes[i]
      else
        lastGamercardScenes.remove(i)
  return null
}

function updateGcButton(obj, isNew, tooltip = null) {
  if (!checkObj(obj))
    return

  if (tooltip)
    obj.tooltip = tooltip

  showObjectsByTable(obj, {
    icon    = !isNew
    iconNew = isNew
  })

  let objGlow = obj.findObject("iconGlow")
  if (checkObj(objGlow))
    objGlow.wink = isNew ? "yes" : "no"
}

function updateGcInvites(scene) {
  let haveNew = invitesAmount.get() > 0
  updateGcButton(scene.findObject("gc_invites_btn"), haveNew)
}

function countNewMessages(callback) {
  local newMessagesCount = 0
  local countInternal = null
  countInternal = function(rooms_, idx) {
    if (idx >= rooms_.len()) {
      callback?(newMessagesCount)
    }
    else {
      local room = rooms_[idx]
      room.concealed(function(isConcealed) {
        if (!room.hidden && !isConcealed)
          newMessagesCount += room.newImportantMessagesCount
        countInternal(rooms_, idx + 1)
      })
    }
  }
  countInternal(chatRooms, 0)
}

function update_gamercards_chat_info(prefix = "gc_") {
  if (!gchat_is_enabled() || !hasMenuChat.value)
    return

  countNewMessages(function(newMessagesCount) {
    let haveNew = newMessagesCount > 0
    let tooltip = loc(haveNew ? "mainmenu/chat_new_messages" : "mainmenu/chat")

    let newMessagesText = newMessagesCount ? newMessagesCount.tostring() : ""

    doWithAllGamercards(function(scene) {
      let objBtn = scene.findObject($"{prefix}chat_btn")
      if (!checkObj(objBtn))
        return

      updateGcButton(objBtn, haveNew, tooltip)
      let newCountChatObj = objBtn.findObject($"{prefix}new_chat_messages")
      newCountChatObj.setValue(newMessagesText)
    })
  })
}

function fill_gamer_card(cfg = null, prefix = "gc_", scene = null, save_scene = true) {
  if (!checkObj(scene)) {
    scene = getLastGamercardScene()
    if (!scene)
      return
  }
  let isGamercard = prefix == "gc_"
  let isShowGamercard = isLoggedIn.get()
  let div = showObjById("gamercard_div", isShowGamercard, scene)
  let isValidGamercard = checkObj(div)
  if (isGamercard && !isValidGamercard)
    return

  if (isValidGamercard)
    showTitleLogo(div)

  if (scene && save_scene && isGamercard && isValidGamercard)
    addGamercardScene(scene)

  if (!isShowGamercard)
    return

  if (!cfg)
    cfg = getProfileInfo()

  let getObj = @(id) scene.findObject(id)
  local showClanTag = false
  foreach (name, val in cfg) {
    let obj = getObj($"{prefix}{name}")
    if (checkObj(obj)) {
      if (name == "frame") {
        obj.show(val != "")
        if (val != "")
          obj["background-image"] = $"!ui/images/avatar_frames/{val}.avif"
      }
      if (name == "country")
        obj["background-image"] = getCountryIcon(val)
      else if (name == "rankProgress") {
        let value = val.tointeger()
        let isProgressVisible = !isGamercard || value >= 0
        if (isProgressVisible)
          obj.setValue(value != -1 ? value : 1000)
        obj.show(isProgressVisible)

        let expTable = getCurExpTable(cfg)
        obj.tooltip = expTable
          ? nbsp.concat(decimalFormat(expTable.exp), "/", decimalFormat(expTable.rankExp))
          : "".concat(loc("ugm/total"), loc("ui/colon"), decimalFormat(cfg.exp))
      }
      else if (name ==  "prestige") {
        if (val != null)
          obj["background-image"] = $"#ui/gameuiskin#prestige{val}"
        let titleObj = getObj($"{prefix}prestige_title")
        if (titleObj) {
          let prestigeTitle = (val ?? 0) > 0 ? loc($"rank/prestige{val}") : ""
          titleObj.setValue(prestigeTitle)
        }
      }
      else if (name == "exp") {
        let expTable = getCurExpTable(cfg)
        obj.setValue(expTable
          ? nbsp.concat(decimalFormat(expTable.exp), "/", decimalFormat(expTable.rankExp))
          : "")
        obj.tooltip = "".concat(loc("ugm/total"), loc("ui/colon"), decimalFormat(cfg.exp))
      }
      else if (name == "clanTag") {
        showClanTag = hasFeature("Clans") && val != ""
        let clanTagName = checkClanTagForDirtyWords(val.tostring())
        let btnText = obj.findObject($"{prefix}{name}_name")
        if (checkObj(btnText))
          btnText.setValue(clanTagName)
        else
          obj.setValue(clanTagName)
      }
      else if (name == "gold") {
        let moneyInst = Cost(0, val)
        let valStr = moneyInst.toStringWithParams({ isGoldAlwaysShown = true })

        let tooltipText = "\n".concat(colorize("activeTextColor", valStr), loc("mainmenu/gold"))
        obj.getParent().tooltip = tooltipText

        obj.setValue(moneyInst.toStringWithParams({ isGoldAlwaysShown = true, needIcon = false }))
      }
      else if (name == "balance") {
        let moneyInst = Cost(val)
        let valStr = moneyInst.toStringWithParams({ isWpAlwaysShown = true })
        let tooltipText = "\n".concat(colorize("activeTextColor", valStr),
          loc("mainmenu/warpoints"),
          ::get_current_bonuses_text(boosterEffectType.WP))

        let buttonObj = obj.getParent()
        buttonObj.tooltip = tooltipText
        buttonObj.showBonusCommon = haveActiveBonusesByEffectType(boosterEffectType.WP, false) ? "yes" : "no"
        buttonObj.showBonusPersonal = haveActiveBonusesByEffectType(boosterEffectType.WP, true) ? "yes" : "no"

        obj.setValue(moneyInst.toStringWithParams({ isWpAlwaysShown = true, needIcon = false }))
      }
      else if (name == "free_exp") {
        let valStr = Balance(0, 0, val).toStringWithParams({ isFrpAlwaysShown = true })
        let tooltipText = "\n".concat(colorize("activeTextColor", valStr),
          loc("currency/freeResearchPoints/desc"),
          ::get_current_bonuses_text(boosterEffectType.RP))

        obj.tooltip = tooltipText
        obj.showBonusCommon = haveActiveBonusesByEffectType(boosterEffectType.RP, false) ? "yes" : "no"
        obj.showBonusPersonal = haveActiveBonusesByEffectType(boosterEffectType.RP, true) ? "yes" : "no"
      }
      else if (name == "name") {
        local valStr
        if (u.isEmpty(val))
          valStr = loc("mainmenu/pleaseSignIn")
        else {
          let customNick = getCustomNick(cfg)
          valStr = customNick == null ? getPlayerName(val)
            : $"{getPlayerName(val)}{loc("ui/parentheses/space", { text = customNick })}"
        }
        obj.setValue(valStr)
      }
      else
        obj.setValue((val ?? "").tostring())
    }
  }

  if (!isGamercard)
    return

  
  if (hasFeature("UserLog")) {
    let objBtn = getObj($"{prefix}userlog_btn")
    if (checkObj(objBtn)) {
      let newLogsCount = check_new_user_logs().len()
      let haveNew = newLogsCount > 0
      let tooltip = haveNew ?
        format(loc("userlog/new_messages"), newLogsCount) : loc("userlog/no_new_messages")
      updateGcButton(objBtn, haveNew, tooltip)
    }
  }

  update_gamercards_chat_info(prefix)

  if (hasFeature("Friends")) {
    let friendsOnline = getFriendsOnlineNum()
    let cObj = getObj($"{prefix}contacts")
    if (checkObj(cObj))
      cObj.tooltip = format(loc("contacts/friends_online"), friendsOnline)

    let fObj = getObj($"{prefix}friends_online")
    if (checkObj(fObj))
      fObj.setValue(friendsOnline > 0 ? friendsOnline.tostring() : "")
  }

  let totalText = []
  let premAccName = shop_get_premium_account_ent_name()
  foreach (name in ["PremiumAccount", "RateWeek"]) {
    local entName = name
    if (entName == "PremiumAccount")
      entName = premAccName
    let expire = entitlement_expires_in(entName)
    local text = loc("mainmenu/noPremium")
    local premPic = "#ui/gameuiskin#sub_premium_noactive.svg"
    if (expire > 0) {
      text = loc("ui/colon").concat(loc($"charServer/entitlement/{name}"), time.getExpireText(expire))
      totalText.append(text)
      premPic = "#ui/gameuiskin#sub_premiumaccount.svg"
    }
    let obj = getObj($"{prefix}{name}")
    if (obj && obj.isValid()) {
      let icoObj = obj.findObject("gc_prempic")
      if (checkObj(icoObj))
        icoObj["background-image"] = premPic
      obj.tooltip = text
    }
  }
  if (totalText.len() > 0) {
    let name = $"{prefix}subscriptions"
    let obj = getObj(name)
    if (obj && obj.isValid()) {
      obj.show(true)
      obj.tooltip = "\n".join(totalText)
    }
  }

  let queueTextObj = getObj("gc_queue_wait_text")
  updateShortQueueInfo(queueTextObj, queueTextObj, getObj("gc_queue_wait_icon"))

  let battlePassImgObj = getObj("gc_BattlePassProgressImg")
  if (battlePassImgObj?.isValid() ?? false)
    battlePassImgObj.setValue(stashBhvValueConfig([{
      watch = hasBattlePass
      updateFunc = @(obj, value) obj["background-saturate"] = value ? 1 : 0
  }]))

  let canSpendGold = hasFeature("SpendGold")
  let featureEnablePremiumPurchase = hasFeature("EnablePremiumPurchase")
  let canHaveFriends = hasFeature("Friends")
  let is_in_menu = isInMenu()
  let skipNavigation = getObj("gamercard_div")?["gamercardSkipNavigation"] ?? "no"

  let hasPremiumAccount = entitlement_expires_in(premAccName) > 0

  let buttonsShowTable = {
    gc_clanTag = showClanTag
    gc_profile = true
    gc_contacts = canHaveFriends
    gc_chat_btn = hasMenuChat.value
    gc_shop = is_in_menu && canSpendGold
    gc_eagles = canSpendGold
    gc_warpoints = hasFeature("WarpointsInMenu")
    gc_PremiumAccount = hasFeature("showPremiumAccount")
      && ((canSpendGold && featureEnablePremiumPurchase) || hasPremiumAccount)
    gc_BattlePassProgress = true
    gc_dropdown_premium_button = featureEnablePremiumPurchase
    gc_dropdown_shop_eagles_button = canSpendGold
    gc_free_exp = hasFeature("SpendGold")
    gc_items_shop_button = isItemsManagerEnabled() && isInMenu()
      && hasFeature("ItemsShop")
    gc_online_shop_button = hasFeature("OnlineShopPacks")
    gc_clanAlert = hasFeature("Clans") && getUnseenCandidatesCount() > 0
    gc_invites_btn = !is_platform_xbox || hasFeature("XboxCrossConsoleInteraction")
    gc_userlog_btn = hasFeature("UserLog")
    gc_manual_unlocks_unseen = is_in_menu
  }

  foreach (id, status in buttonsShowTable) {
    let bObj = getObj(id)
    if (checkObj(bObj)) {
      bObj.show(status)
      bObj.enable(status)
      bObj.inactive = status ? "no" : "yes"
      if (status)
        bObj["skip-navigation"] = skipNavigation
    }
  }

  let buttonsEnableTable = {
    gc_clanTag = showClanTag && is_in_menu
    gc_contacts = canHaveFriends
    gc_chat_btn = hasMenuChat.value && isChatEnabled()
    gc_free_exp = canSpendGold && is_in_menu
    gc_warpoints = canSpendGold && is_in_menu
    gc_eagles = canSpendGold && is_in_menu
    gc_PremiumAccount = canSpendGold && featureEnablePremiumPurchase && is_in_menu
    gc_BattlePassProgress = canSpendGold && is_in_menu
  }

  foreach (id, status in buttonsEnableTable) {
    let pObj = getObj(id)
    if (checkObj(pObj)) {
      pObj.enable(status)
      pObj.inactive = status ? "no" : "yes"
    }
  }
  let squadWidgetObj = getObj("gamercard_squad_widget")
  if (squadWidgetObj?.isValid())
    squadWidgetObj["gamercardSkipNavigation"] = skipNavigation

  ::g_discount.updateDiscountNotifications(scene)
  setVersionText(scene)
  ::server_message_update_scene(scene)
  updateGcInvites(scene)
}

::update_gamercards <- function update_gamercards() {
  let info = getProfileInfo()
  local needUpdateGamerCard = false
  for (local idx = lastGamercardScenes.len() - 1; idx >= 0; idx--) {
    let s = lastGamercardScenes[idx]
    if (!s || !s.isValid())
      lastGamercardScenes.remove(idx)
    else if (s.isVisible()) {
      needUpdateGamerCard = true
      fill_gamer_card(info, "gc_", s, false)
    }
  }
  if (!needUpdateGamerCard)
    return

  ::checkNewNotificationUserlogs()
  broadcastEvent("UpdateGamercard")
}

::get_active_gc_popup_nest_obj <- function get_active_gc_popup_nest_obj() {
  let gcScene = getLastGamercardScene()
  let nestObj = gcScene ? gcScene.findObject("chatPopupNest") : null
  return checkObj(nestObj) ? nestObj : null
}

::update_clan_alert_icon <- function update_clan_alert_icon() {
  let needAlert = hasFeature("Clans") && getUnseenCandidatesCount() > 0
  doWithAllGamercards(function(scene) {
      showObjById("gc_clanAlert", needAlert, scene)
    })
}

function updateGamercardChatButton() {
  let canChat = gchat_is_enabled() && hasMenuChat.value
  doWithAllGamercards(@(scene) showObjById("gc_chat_btn", canChat, scene))
}

hasMenuChat.subscribe(@(_) updateGamercardChatButton())

globalCallbacks.addTypes({
  onOpenGameModeSelect = {
    onCb = @(_obj, _params) broadcastEvent("OpenGameModeSelect")
  }
})


return {
  fill_gamer_card
  update_gamercards_chat_info
  doWithAllGamercards
  getLastGamercardScene
  updateGcInvites
  addGamercardScene
}
