import std/[asyncdispatch, json, strformat, strutils, times, sysrand, random]
import types, proto, catalog, socket, stealth

proc toHexStr(s: openArray[byte]): string =
  result = ""
  for b in s:
    result.add(toHex(int(b), 2).toLowerAscii)

proc newUUID4(): string =
  var bytes: array[16, byte]
  if not urandom(bytes):
    randomize()
    for i in 0 .. 15:
      bytes[i] = byte(rand(255))
  bytes[6] = (bytes[6] and 0x0F) or 0x40
  bytes[8] = (bytes[8] and 0x3F) or 0x80
  result = toHexStr(bytes[0..3]) & "-" &
           toHexStr(bytes[4..5]) & "-" &
           toHexStr(bytes[6..7]) & "-" &
           toHexStr(bytes[8..9]) & "-" &
           toHexStr(bytes[10..15])

type
  BotInstance* = ref object
    config*: AccountConfig
    socket*: LevelingSocketClient
    status*: CharacterStatus
    reqCounter*: uint64
    inGame*: bool
    isHunting*: bool
    startTime*: float
    startExp*: int64
    currentExp*: int64
    running*: bool

proc newBotInstance*(config: AccountConfig): BotInstance =
  new(result)
  result.config = config

  let deviceUuid = if config.credentials.deviceUuid.len > 0:
                     config.credentials.deviceUuid
                   else:
                     newUUID4()

  let wsUrl = if config.credentials.origin.len == 0:
                fmt"wss://levelingidle2d.com.br/ws?device={deviceUuid}"
              else:
                var orig = config.credentials.origin
                let scheme = if orig.startsWith("https"): "wss" else: "ws"
                var host = orig.replace("https://", "").replace("http://", "").strip(chars = {'/'})
                fmt"{scheme}://{host}/ws?device={deviceUuid}"

  result.socket = newLevelingSocketClient(wsUrl)
  result.status = CharacterStatus(
    id: config.id,
    name: config.name,
    running: false,
    level: 1,
    vocation: "",
    hp: 100,
    maxHp: 100,
    mana: 50,
    maxMana: 50,
    gold: 0,
    currentArea: "Castelo dos Demônios (Zumbi Faminto Nv 30)",
    status: "Conectando ao servidor...",
    kills: 0,
    expPerHour: 0.0,
    durationSec: 0,
    codexInfo: "Completo (3/3 mobs) | Foco XP",
    logs: @[]
  )
  result.reqCounter = 1
  result.inGame = false
  result.isHunting = false
  result.startTime = epochTime()
  result.startExp = 0
  result.currentExp = 0
  result.running = false

proc nextReqId(self: BotInstance): uint64 =
  result = self.reqCounter
  inc self.reqCounter

proc addLog*(self: BotInstance, msg: string) =
  echo fmt"[{self.config.id}] {msg}"
  if self.status.logs.len >= 15:
    self.status.logs.delete(0)
  self.status.logs.add(msg)

proc sendAuth*(self: BotInstance): Future[bool] {.async.} =
  let reqId = self.nextReqId()
  let user = if self.config.credentials.username.len > 0:
               self.config.credentials.username
             else:
               self.config.credentials.email
  let packet = buildAuthLogin(reqId, user, self.config.credentials.password)
  result = await self.socket.sendBinary(packet)

proc sendPing*(self: BotInstance): Future[bool] {.async.} =
  let reqId = self.nextReqId()
  let packet = buildPing(reqId)
  result = await self.socket.sendBinary(packet)

proc sendStartHunt*(self: BotInstance, gateId: string, tierMin: int, difficulty: string): Future[bool] {.async.} =
  let reqId = self.nextReqId()
  let packet = buildStartHunt(reqId, gateId, tierMin.uint32, difficulty)
  result = await self.socket.sendBinary(packet)

proc sendEquipBest*(self: BotInstance): Future[bool] {.async.} =
  let reqId = self.nextReqId()
  let packet = buildEquipBest(reqId)
  result = await self.socket.sendBinary(packet)

proc sendRepairAll*(self: BotInstance): Future[bool] {.async.} =
  let reqId = self.nextReqId()
  let packet = buildRepairAll(reqId)
  result = await self.socket.sendBinary(packet)

proc sendClaimMissions*(self: BotInstance): Future[bool] {.async.} =
  let reqId = self.nextReqId()
  let packet = buildClaimMissions(reqId)
  result = await self.socket.sendBinary(packet)

proc sendSetAutomation*(self: BotInstance): Future[bool] {.async.} =
  let reqId = self.nextReqId()
  let packet = buildSetAutomation(reqId, self.status.level.uint32)
  result = await self.socket.sendBinary(packet)

proc handleInboundPacket*(self: BotInstance, data: seq[byte]) {.async.} =
  var offset = 0
  while offset < data.len:
    let (tagOk, num, wtype) = consumeTag(data, offset)
    if not tagOk: break

    case wtype
    of WireVarint:
      let (vOk, _) = consumeVarint(data, offset)
      if not vOk: break
    of WireBytes:
      let (bOk, bytesVal) = consumeBytes(data, offset)
      if not bOk: break

      case num
      of 2: # Error
        let errMsg = parseStringField(bytesVal, 1)
        if errMsg == "party.invite.in_party" or errMsg == "ratelimit.party":
          self.addLog("Party sincronizada.")
        elif errMsg.len > 0:
          self.status.status = fmt"Erro: {errMsg}"
          self.addLog(fmt"Servidor erro: {errMsg}")
      of 4: # AuthOk
        let username = parseStringField(bytesVal, 3)
        self.inGame = true
        self.status.status = "Conectado e Autenticado"
        if username.len > 0:
          self.status.name = username
        self.addLog(fmt"Login bem-sucedido! Bem-vindo, {self.status.name}.")
      of 8: # CharacterState
        # Identity / Progress
        let lvl = parseVarintField(bytesVal, 1).int
        if lvl > 0: self.status.level = lvl
      of 14: # WorldEvents
        inc self.status.kills
        self.status.gold += 25
      of 30: # StartHuntResult
        self.isHunting = true
        let gateId = parseStringField(bytesVal, 1)
        let tierMin = parseVarintField(bytesVal, 2).int
        if gateId.len > 0:
          self.status.currentArea = getHuntName(gateId, tierMin)
          self.status.status = "hunting"
          self.addLog(fmt"Caçada iniciada: {self.status.currentArea}")
      of 31, 36: # LeaveHuntResult, GiveUpResult
        self.isHunting = false
      of 43: # DeathState
        self.isHunting = false
        let reqId = self.nextReqId()
        discard await self.socket.sendBinary(buildGiveUp(reqId))
      of 290, 291: # Party
        self.addLog("Party sincronizada.")
      else:
        discard
    else:
      break

proc readerLoop*(self: BotInstance) {.async.} =
  while self.running and self.socket.isConnected:
    let msg = await self.socket.readBinaryMessage()
    if msg.len > 0:
      await self.handleInboundPacket(msg)
    else:
      break
  self.socket.isConnected = false
  self.inGame = false
  self.isHunting = false
  if self.status.status != "Erro: account.banned":
    self.status.status = "Conectando ao servidor..."

proc pingLoop*(self: BotInstance) {.async.} =
  while self.running:
    await sleepAsync(20000)
    if self.socket.isConnected and self.inGame:
      discard await self.sendPing()

proc huntLoop*(self: BotInstance) {.async.} =
  while self.running:
    let jitterDelay = applyJitter(5000, 0.20)
    await sleepAsync(jitterDelay)
    if self.config.settings.autoHunt and self.socket.isConnected and self.inGame and not self.isHunting:
      if not self.status.status.startsWith("Erro:"):
        let best = getBestHuntForLevel(self.status.level)
        discard await self.sendStartHunt(best.gateId, best.tierMin, best.difficulty)

proc maintenanceLoop*(self: BotInstance) {.async.} =
  while self.running:
    let jitterDelay = applyJitter(45000, 0.20)
    await sleepAsync(jitterDelay)
    if self.socket.isConnected and self.inGame:
      if self.config.settings.autoEquip:
        discard await self.sendEquipBest()
        await pacingDelay(300, 600)
      if self.config.settings.autoRepair:
        discard await self.sendRepairAll()
        await pacingDelay(300, 600)
      if self.config.settings.autoMissions:
        discard await self.sendClaimMissions()
        await pacingDelay(300, 600)
      discard await self.sendSetAutomation()

proc run*(self: BotInstance) {.async.} =
  self.running = true
  self.status.running = true

  asyncCheck self.pingLoop()
  asyncCheck self.huntLoop()
  asyncCheck self.maintenanceLoop()

  var reconnWaitMs = 3000
  while self.running:
    let connected = await self.socket.connect()
    if connected:
      reconnWaitMs = 3000
      discard await self.sendAuth()
      await self.readerLoop()
    else:
      self.status.status = "Conectando ao servidor..."

    if self.status.status.contains("banned"):
      await sleepAsync(60000)
    else:
      let delayMs = applyJitter(reconnWaitMs, 0.20)
      await sleepAsync(delayMs)
      if reconnWaitMs < 30000:
        reconnWaitMs += 5000
