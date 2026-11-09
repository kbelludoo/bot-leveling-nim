import std/[asyncdispatch]
import ws

type
  LevelingSocketClient* = ref object
    ws*: WebSocket
    isConnected*: bool
    url*: string

proc newLevelingSocketClient*(url: string): LevelingSocketClient =
  new(result)
  result.url = url
  result.isConnected = false

proc connect*(self: LevelingSocketClient): Future[bool] {.async.} =
  try:
    self.ws = await newWebSocket(self.url)
    self.isConnected = true
    result = true
  except CatchableError as e:
    echo "[Leveling WS] Erro de conexão WebSocket: ", e.msg
    self.isConnected = false
    result = false

proc sendBinary*(self: LevelingSocketClient, data: seq[byte]): Future[bool] {.async.} =
  if self.ws == nil or not self.isConnected: return false
  var s = newStringOfCap(data.len)
  for b in data: s.add(chr(b))
  try:
    await self.ws.send(s, opcode = Opcode.Binary)
    result = true
  except CatchableError as e:
    echo "[Leveling WS] Erro ao enviar pacote binário: ", e.msg
    self.isConnected = false
    result = false

proc readBinaryMessage*(self: LevelingSocketClient): Future[seq[byte]] {.async.} =
  if self.ws == nil or not self.isConnected: return @[]
  try:
    result = await self.ws.receiveBinaryPacket()
  except CatchableError:
    self.isConnected = false
    result = @[]
