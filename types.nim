import std/[json, options]

type
  GameCredentials* = object
    username*: string
    email*: string
    password*: string
    token*: string
    deviceUuid*: string
    origin*: string

  GameSettings* = object
    huntTarget*: string
    autoHunt*: bool
    autoSell*: bool
    autoHeal*: bool
    autoDaily*: bool
    autoEquip*: bool
    autoRepair*: bool
    autoShadows*: bool
    autoTower*: bool
    autoDailyBoss*: bool
    autoGems*: bool
    autoEnchant*: bool
    autoStats*: bool
    autoMissions*: bool
    autoPromotion*: bool
    partyLeader*: bool
    partyMembers*: seq[string]
    autoParty*: bool
    codexMode*: bool
    codexTarget*: int64
    goldReserve*: int64
    preferredClass*: string

  AccountConfig* = object
    id*: string
    name*: string
    enabled*: bool
    localIp*: string
    proxy*: string
    credentials*: GameCredentials
    settings*: GameSettings

  CharacterStatus* = object
    id*: string
    name*: string
    running*: bool
    level*: int
    vocation*: string
    hp*: int
    maxHp*: int
    mana*: int
    maxMana*: int
    gold*: int64
    currentArea*: string
    status*: string
    kills*: int64
    expPerHour*: float
    durationSec*: int64
    codexInfo*: string
    logs*: seq[string]

proc parseCredentials(node: JsonNode): GameCredentials =
  if node != nil:
    result.username = node{"username"}.getStr("")
    result.email = node{"email"}.getStr("")
    result.password = node{"password"}.getStr("")
    result.token = node{"token"}.getStr("")
    result.deviceUuid = node{"deviceUuid"}.getStr("")
    result.origin = node{"origin"}.getStr("")

proc parseSettings(node: JsonNode): GameSettings =
  result.huntTarget = "floresta-sombria"
  result.autoHunt = true
  result.autoSell = true
  result.autoHeal = true
  result.autoDaily = true
  result.autoEquip = true
  result.autoRepair = true
  result.autoShadows = true
  result.autoTower = true
  result.autoDailyBoss = true
  result.autoGems = true
  result.autoEnchant = true
  result.autoStats = true
  result.autoMissions = true
  result.autoPromotion = true
  result.partyLeader = false
  result.partyMembers = @[]
  result.autoParty = true
  result.codexMode = true
  result.codexTarget = 2000
  result.goldReserve = 100000
  result.preferredClass = ""

  if node != nil:
    if node.hasKey("huntTarget"): result.huntTarget = node["huntTarget"].getStr("floresta-sombria")
    if node.hasKey("autoHunt"): result.autoHunt = node["autoHunt"].getBool(true)
    if node.hasKey("autoSell"): result.autoSell = node["autoSell"].getBool(true)
    if node.hasKey("autoHeal"): result.autoHeal = node["autoHeal"].getBool(true)
    if node.hasKey("autoDaily"): result.autoDaily = node["autoDaily"].getBool(true)
    if node.hasKey("autoEquip"): result.autoEquip = node["autoEquip"].getBool(true)
    if node.hasKey("autoRepair"): result.autoRepair = node["autoRepair"].getBool(true)
    if node.hasKey("autoShadows"): result.autoShadows = node["autoShadows"].getBool(true)
    if node.hasKey("autoTower"): result.autoTower = node["autoTower"].getBool(true)
    if node.hasKey("autoDailyBoss"): result.autoDailyBoss = node["autoDailyBoss"].getBool(true)
    if node.hasKey("autoGems"): result.autoGems = node["autoGems"].getBool(true)
    if node.hasKey("autoEnchant"): result.autoEnchant = node["autoEnchant"].getBool(true)
    if node.hasKey("autoStats"): result.autoStats = node["autoStats"].getBool(true)
    if node.hasKey("autoMissions"): result.autoMissions = node["autoMissions"].getBool(true)
    if node.hasKey("autoPromotion"): result.autoPromotion = node["autoPromotion"].getBool(true)
    if node.hasKey("partyLeader"): result.partyLeader = node["partyLeader"].getBool(false)
    if node.hasKey("autoParty"): result.autoParty = node["autoParty"].getBool(true)
    if node.hasKey("codexMode"): result.codexMode = node["codexMode"].getBool(true)
    if node.hasKey("codexTarget"): result.codexTarget = node["codexTarget"].getBiggestInt(2000)
    if node.hasKey("goldReserve"): result.goldReserve = node["goldReserve"].getBiggestInt(100000)
    if node.hasKey("preferredClass"): result.preferredClass = node["preferredClass"].getStr("")

proc parseAccountConfig*(node: JsonNode): AccountConfig =
  result.id = node{"id"}.getStr("")
  result.name = node{"name"}.getStr(result.id)
  result.enabled = node{"enabled"}.getBool(true)
  result.localIp = node{"localIp"}.getStr("")
  result.proxy = node{"proxy"}.getStr("")
  result.credentials = parseCredentials(node{"credentials"})
  result.settings = parseSettings(node{"settings"})
