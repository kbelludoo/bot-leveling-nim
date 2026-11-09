import std/[strformat]

type
  HuntTier* = object
    gateId*: string
    gateName*: string
    tierMin*: int
    tierMax*: int
    monsterId*: string
    monsterName*: string
    bossName*: string
    difficulty*: string
    areaLevel*: int
    requiredLevel*: int

const CatalogTiers*: seq[HuntTier] = @[
  HuntTier(gateId: "blue-gate", gateName: "Blue Gate", tierMin: 1, tierMax: 5, monsterId: "rato-ruina", monsterName: "Rato da Ruína", bossName: "Rato Gigante", difficulty: "normal", areaLevel: 5, requiredLevel: 1),
  HuntTier(gateId: "blue-gate", gateName: "Blue Gate", tierMin: 6, tierMax: 10, monsterId: "morcego", monsterName: "Morcego Sombrio", bossName: "Morcego Ancestral", difficulty: "normal", areaLevel: 10, requiredLevel: 6),
  HuntTier(gateId: "blue-gate", gateName: "Blue Gate", tierMin: 11, tierMax: 15, monsterId: "goblin", monsterName: "Goblin", bossName: "Goblin Chefão", difficulty: "normal", areaLevel: 15, requiredLevel: 11),
  HuntTier(gateId: "blue-gate", gateName: "Blue Gate", tierMin: 16, tierMax: 20, monsterId: "esqueleto-guerreiro", monsterName: "Esqueleto Guerreiro", bossName: "Esqueleto Campeão", difficulty: "normal", areaLevel: 20, requiredLevel: 16),
  HuntTier(gateId: "castelo-demonios", gateName: "Castelo dos Demônios", tierMin: 21, tierMax: 25, monsterId: "orc-jovem", monsterName: "Orc Jovem", bossName: "Orc Senhor da Guerra", difficulty: "normal", areaLevel: 25, requiredLevel: 21),
  HuntTier(gateId: "castelo-demonios", gateName: "Castelo dos Demônios", tierMin: 26, tierMax: 30, monsterId: "zumbi-faminto", monsterName: "Zumbi Faminto", bossName: "Zumbi Devorador", difficulty: "normal", areaLevel: 30, requiredLevel: 26),
  HuntTier(gateId: "castelo-demonios", gateName: "Castelo dos Demônios", tierMin: 31, tierMax: 35, monsterId: "slime-corrosivo", monsterName: "Slime Corrosivo", bossName: "Slime Colossal", difficulty: "normal", areaLevel: 35, requiredLevel: 31),
  HuntTier(gateId: "castelo-demonios", gateName: "Castelo dos Demônios", tierMin: 36, tierMax: 40, monsterId: "aranha-pedra", monsterName: "Aranha de Pedra", bossName: "Aranha Matriarca", difficulty: "normal", areaLevel: 40, requiredLevel: 36),
  HuntTier(gateId: "ilha-jeju", gateName: "Ilha Jeju", tierMin: 41, tierMax: 45, monsterId: "golem-barro", monsterName: "Golem de Barro", bossName: "Golem Ancestral", difficulty: "normal", areaLevel: 45, requiredLevel: 41),
  HuntTier(gateId: "ilha-jeju", gateName: "Ilha Jeju", tierMin: 46, tierMax: 50, monsterId: "espirito-errante", monsterName: "Espírito Errante", bossName: "Espírito Carrasco", difficulty: "normal", areaLevel: 50, requiredLevel: 46),
  HuntTier(gateId: "ilha-jeju", gateName: "Ilha Jeju", tierMin: 51, tierMax: 55, monsterId: "cavaleiro-morto", monsterName: "Cavaleiro Morto", bossName: "Comandante Caído", difficulty: "normal", areaLevel: 55, requiredLevel: 51),
  HuntTier(gateId: "ilha-jeju", gateName: "Ilha Jeju", tierMin: 56, tierMax: 60, monsterId: "mago-esqueleto", monsterName: "Mago Esqueleto", bossName: "Necromante Supremo", difficulty: "normal", areaLevel: 60, requiredLevel: 56),
  HuntTier(gateId: "templo-carneton", gateName: "Templo de Carneton", tierMin: 61, tierMax: 65, monsterId: "senhor-vampiro", monsterName: "Senhor Vampiro", bossName: "Lorde Vampiro", difficulty: "normal", areaLevel: 65, requiredLevel: 61),
  HuntTier(gateId: "templo-carneton", gateName: "Templo de Carneton", tierMin: 66, tierMax: 70, monsterId: "troll-cavernas", monsterName: "Troll das Cavernas", bossName: "Troll Ancião", difficulty: "normal", areaLevel: 70, requiredLevel: 66)
]

proc getBestHuntForLevel*(level: int): HuntTier =
  if level <= 0: return CatalogTiers[0]
  var best = CatalogTiers[0]
  var found = false
  for t in CatalogTiers:
    if level >= t.requiredLevel and (not found or t.areaLevel > best.areaLevel):
      best = t
      found = true
  result = best

proc getHuntName*(gateId: string, tierMin: int): string =
  for t in CatalogTiers:
    if t.gateId == gateId and t.tierMin == tierMin:
      return fmt"{t.gateName} ({t.monsterName} Nv {t.areaLevel})"
  result = fmt"{gateId} (Tier {tierMin})"
