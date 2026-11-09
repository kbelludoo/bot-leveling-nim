const
  WireVarint* = 0'u32
  WireFixed64* = 1'u32
  WireBytes* = 2'u32
  WireFixed32* = 5'u32

proc appendVarint*(buf: var seq[byte], val: uint64) =
  var v = val
  while v >= 0x80'u64:
    buf.add(byte((v and 0x7F'u64) or 0x80'u64))
    v = v shr 7
  buf.add(byte(v and 0x7F'u64))

proc appendTag*(buf: var seq[byte], fieldNumber: uint32, wireType: uint32) =
  let key = (fieldNumber shl 3) or wireType
  appendVarint(buf, key.uint64)

proc appendFixed32*(buf: var seq[byte], val: uint32) =
  buf.add(byte(val and 0xFF'u32))
  buf.add(byte((val shr 8) and 0xFF'u32))
  buf.add(byte((val shr 16) and 0xFF'u32))
  buf.add(byte((val shr 24) and 0xFF'u32))

proc appendBytes*(buf: var seq[byte], bytes: openArray[byte]) =
  appendVarint(buf, bytes.len.uint64)
  for b in bytes:
    buf.add(b)

proc appendString*(buf: var seq[byte], s: string) =
  appendVarint(buf, s.len.uint64)
  for c in s:
    buf.add(byte(ord(c)))

proc wrapClientMsg*(reqId: uint64, opcodeTag: uint32, payload: openArray[byte]): seq[byte] =
  result = @[]
  appendTag(result, 1, WireVarint)
  appendVarint(result, reqId)
  appendTag(result, opcodeTag, WireBytes)
  appendBytes(result, payload)

proc buildAuthLogin*(reqId: uint64, user, pass: string): seq[byte] =
  var payload: seq[byte] = @[]
  appendTag(payload, 1, WireBytes)
  appendString(payload, user)
  appendTag(payload, 2, WireBytes)
  appendString(payload, pass)
  result = wrapClientMsg(reqId, 4, payload)

proc buildPing*(reqId: uint64): seq[byte] =
  result = wrapClientMsg(reqId, 2, [])

proc buildStartHunt*(reqId: uint64, gateId: string, tierMin: uint32, difficulty: string): seq[byte] =
  var payload: seq[byte] = @[]
  if gateId.len > 0:
    appendTag(payload, 1, WireBytes)
    appendString(payload, gateId)
  if tierMin > 0:
    appendTag(payload, 2, WireVarint)
    appendVarint(payload, tierMin.uint64)
  if difficulty.len > 0:
    appendTag(payload, 3, WireBytes)
    appendString(payload, difficulty)
  result = wrapClientMsg(reqId, 30, payload)

proc buildLeaveHunt*(reqId: uint64): seq[byte] =
  result = wrapClientMsg(reqId, 31, [])

proc buildGiveUp*(reqId: uint64): seq[byte] =
  result = wrapClientMsg(reqId, 36, [])

proc buildRevive*(reqId: uint64): seq[byte] =
  result = wrapClientMsg(reqId, 35, [])

proc buildEquipBest*(reqId: uint64): seq[byte] =
  var payload: seq[byte] = @[]
  appendTag(payload, 1, WireVarint)
  appendVarint(payload, 2)
  result = wrapClientMsg(reqId, 54, payload)

proc buildRepairAll*(reqId: uint64): seq[byte] =
  var payload: seq[byte] = @[]
  appendTag(payload, 2, WireVarint)
  appendVarint(payload, 0)
  result = wrapClientMsg(reqId, 65, payload)

proc buildSetAutomation*(reqId: uint64, level: uint32): seq[byte] =
  var hpPotion: seq[byte] = @[]
  appendTag(hpPotion, 2, WireFixed32)
  appendFixed32(hpPotion, 0x3f000000'u32)
  appendTag(hpPotion, 4, WireVarint)
  appendVarint(hpPotion, 1)

  var manaPotion: seq[byte] = @[]
  appendTag(manaPotion, 2, WireFixed32)
  appendFixed32(manaPotion, 0x3e99999a'u32)
  appendTag(manaPotion, 4, WireVarint)
  appendVarint(manaPotion, 1)

  var autoMsg: seq[byte] = @[]
  appendTag(autoMsg, 2, WireVarint)
  appendVarint(autoMsg, 1)
  if level >= 15:
    appendTag(autoMsg, 5, WireVarint)
    appendVarint(autoMsg, 1)
  appendTag(autoMsg, 6, WireVarint)
  appendVarint(autoMsg, 1)
  appendTag(autoMsg, 7, WireBytes)
  appendBytes(autoMsg, hpPotion)
  appendTag(autoMsg, 8, WireBytes)
  appendBytes(autoMsg, manaPotion)
  if level >= 15:
    appendTag(autoMsg, 9, WireVarint)
    appendVarint(autoMsg, 1)
  appendTag(autoMsg, 10, WireVarint)
  appendVarint(autoMsg, 1)
  if level >= 15:
    appendTag(autoMsg, 16, WireVarint)
    appendVarint(autoMsg, 1)

  var setAuto: seq[byte] = @[]
  appendTag(setAuto, 1, WireBytes)
  appendBytes(setAuto, autoMsg)
  result = wrapClientMsg(reqId, 98, setAuto)

proc buildClaimMissions*(reqId: uint64): seq[byte] =
  var payload: seq[byte] = @[]
  appendTag(payload, 1, WireVarint)
  appendVarint(payload, 1)
  appendTag(payload, 2, WireVarint)
  appendVarint(payload, 1)
  appendTag(payload, 3, WireBytes)
  appendString(payload, "daily")
  result = wrapClientMsg(reqId, 410, payload)

proc buildPartyInvite*(reqId: uint64, targetName: string): seq[byte] =
  var inviteByName: seq[byte] = @[]
  appendTag(inviteByName, 1, WireBytes)
  appendString(inviteByName, targetName)

  var partyReq: seq[byte] = @[]
  appendTag(partyReq, 2, WireBytes)
  appendBytes(partyReq, inviteByName)
  result = wrapClientMsg(reqId, 290, partyReq)

proc buildPartyAnswer*(reqId: uint64, fromAccount: int64, accept: bool): seq[byte] =
  var answer: seq[byte] = @[]
  appendTag(answer, 1, WireVarint)
  appendVarint(answer, fromAccount.uint64)
  appendTag(answer, 2, WireVarint)
  appendVarint(answer, if accept: 1'u64 else: 0'u64)

  var partyReq: seq[byte] = @[]
  appendTag(partyReq, 3, WireBytes)
  appendBytes(partyReq, answer)
  result = wrapClientMsg(reqId, 290, partyReq)

# Decoding helpers
proc consumeVarint*(data: openArray[byte], offset: var int): tuple[ok: bool, val: uint64] =
  var v: uint64 = 0
  var shift: int = 0
  while offset < data.len:
    let b = data[offset]
    inc offset
    v = v or ((b.uint64 and 0x7F'u64) shl shift)
    if (b and 0x80'u8) == 0:
      return (true, v)
    shift += 7
    if shift >= 64: return (false, 0'u64)
  return (false, 0'u64)

proc consumeTag*(data: openArray[byte], offset: var int): tuple[ok: bool, num: uint32, wtype: uint32] =
  let (ok, v) = consumeVarint(data, offset)
  if not ok: return (false, 0'u32, 0'u32)
  return (true, uint32(v shr 3), uint32(v and 0x07'u64))

proc consumeBytes*(data: openArray[byte], offset: var int): tuple[ok: bool, bytes: seq[byte]] =
  let (ok, len) = consumeVarint(data, offset)
  if not ok: return (false, @[])
  let l = len.int
  if offset + l > data.len: return (false, @[])
  var s: seq[byte] = @[]
  for i in offset ..< offset + l:
    s.add(data[i])
  offset += l
  return (true, s)

proc parseStringField*(data: openArray[byte], targetNum: uint32): string =
  var offset = 0
  while offset < data.len:
    let (tagOk, num, wtype) = consumeTag(data, offset)
    if not tagOk: break
    if wtype == WireBytes:
      let (bOk, bData) = consumeBytes(data, offset)
      if not bOk: break
      if num == targetNum:
        var str = ""
        for b in bData: str.add(chr(b))
        return str
    elif wtype == WireVarint:
      let (vOk, _) = consumeVarint(data, offset)
      if not vOk: break
    elif wtype == WireFixed32:
      offset += 4
    elif wtype == WireFixed64:
      offset += 8
    else:
      break
  return ""

proc parseVarintField*(data: openArray[byte], targetNum: uint32): uint64 =
  var offset = 0
  while offset < data.len:
    let (tagOk, num, wtype) = consumeTag(data, offset)
    if not tagOk: break
    if wtype == WireVarint:
      let (vOk, v) = consumeVarint(data, offset)
      if not vOk: break
      if num == targetNum: return v
    elif wtype == WireBytes:
      let (bOk, _) = consumeBytes(data, offset)
      if not bOk: break
    elif wtype == WireFixed32:
      offset += 4
    elif wtype == WireFixed64:
      offset += 8
    else:
      break
  return 0'u64
