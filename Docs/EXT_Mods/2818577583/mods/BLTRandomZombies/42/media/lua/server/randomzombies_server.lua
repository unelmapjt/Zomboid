local Lib = BLTRandomZombies

-- -----------------------------------------------------------------------------
-- Helpers

local SPEED_SPRINTER = 1
local SPEED_FAST_SHAMBLER = 2
local SPEED_SHAMBLER = 3
-- local SPEED_RANDOM = 4

local COGNITION_SMART = 1
local COGNITION_DEFAULT = 3
local COGNITION_RANDOM = 4

local cognitionField = nil
local speedField = nil
local speedConfigOption = nil
local cognitionConfigOption = nil

local banditsEnabled = false

function Lib.findField(o, fname)
  for i = 0, getNumClassFields(o) - 1 do
    local f = getClassField(o, i)
    if tostring(f) == fname then
      return f
    end
  end
end

local function defaultDistribution()
  local distribution = {}

  distribution.Crawler = 2
  distribution.Shambler = 15
  distribution.FastShambler = 78
  distribution.Sprinter = 5

  distribution.Fragile = 0
  distribution.NormalTough = 100
  distribution.Tough = 0

  distribution.Smart = 0

  return distribution
end

local warnModal = nil
local warnAcked = false

local function dismissUserError(_button)
  if warnModal then
    warnModal:removeFromUIManager()
    warnModal = nil
    warnAcked = true
  end
end

local function userError(msg)
  if warnModal or warnAcked then
    return
  end

  local player = getPlayer():getPlayerNum()
  local w = 380
  local h = 120
  local x = getPlayerScreenLeft(player) + (getPlayerScreenWidth(player) - w) / 2
  local y = getPlayerScreenTop(player) + (getPlayerScreenHeight(player) - h) / 2
  local text = "Random Zombies has encountered an error, falling back to default config.\nPlease check your configuration.\n\nError message:\n" .. msg

  warnModal = ISModalDialog:new(x, y, w, h, text, false, nil, dismissUserError, player)
  warnModal:initialise()
  warnModal:addToUIManager()
  warnModal:bringToTop()

  if JoypadState.players[player+1] then
    warnModal.prevFocus = JoypadState.players[player+1].focus
    setJoypadFocus(player, warnModal)
  end
end

function Lib.makeDistribution()
  local distribution = {}

  local crawler = SandboxVars.BLTRandomZombies.Crawler
  local shambler = SandboxVars.BLTRandomZombies.Shambler
  local fastShambler = SandboxVars.BLTRandomZombies.FastShambler
  local sprinter = SandboxVars.BLTRandomZombies.Sprinter
  local fragile = SandboxVars.BLTRandomZombies.Fragile
  local normalTough = SandboxVars.BLTRandomZombies.NormalTough
  local tough = SandboxVars.BLTRandomZombies.Tough

  if SandboxVars.BLTRandomZombies.CheckConfig then
    if Math.round((crawler + shambler + fastShambler + sprinter) * 100) ~= 10000 then
      userError("Crawler, Shambler, FastShambler and Sprinter do not add up to 100.")
      return defaultDistribution()
    end

    if Math.round((fragile + normalTough + tough) * 100) ~= 10000 then
      userError("Fragile, NormalTough and Tough do not add up to 100.")
      return defaultDistribution()
    end

    distribution.Crawler = 100 * crawler
    distribution.Shambler = distribution.Crawler + 100 * shambler
    distribution.FastShambler = distribution.Shambler + 100 * fastShambler
    distribution.Sprinter = distribution.FastShambler + 100 * sprinter

    distribution.Fragile = 100 * fragile
    distribution.NormalTough = distribution.Fragile + 100 * normalTough
    distribution.Tough = distribution.NormalTough + 100 * tough
  else
    -- user wants to use relative weighing instead of sum-to-100
    local speedTotal = crawler + shambler + fastShambler + sprinter
    distribution.Crawler = 10000 * crawler / speedTotal
    distribution.Shambler = distribution.Crawler + 10000 * shambler / speedTotal
    distribution.FastShambler = distribution.Shambler + 10000 * fastShambler / speedTotal
    distribution.Sprinter = distribution.FastShambler + 10000 * sprinter / speedTotal

    local toughTotal = fragile + normalTough + tough
    distribution.Fragile = 10000 * fragile / toughTotal
    distribution.NormalTough = distribution.Fragile + 10000 * normalTough / toughTotal
    distribution.Tough = distribution.NormalTough + 10000 * tough / toughTotal
  end

  distribution.Smart = math.floor(100 * SandboxVars.BLTRandomZombies.Smart)

  return distribution
end

-- local function shiftRight(a, b)
--   while a > 0 and b > 0 do
--     a = math.floor(a / 2)
--     b = b - 1
--   end
--   return a
-- end

-- NOTE: we implement our own since
-- - % operator doesn't work with big numbers, confirm with 2^37%100 and 2^38%100
--   because the result of the first division HAS TO fit in an int32 as per KahluaThread.primitiveMath, case 16
-- - math.fmod is in fact the remainder
-- local function modulo(a, b)
--   return a - math.floor(a/b)*b
-- end

local p = 16 -- we want 2^p bits
local maxValue = 2^p -- OnlineID defined as a short as of 41.71
local two_32 = 2^32
local function hash(x)
  -- (x*2654435769 % 2^32) >> (32 - p)

  -- NOTE(belette) we use the % operator here because the result of (x%2^32)
  -- will fit in an int32 in our case as x is supposed to fit in a signed short
  -- however, % is actually the remainder and not the modulo, so we have to check for
  -- negative and do the right thing
  x = (x * 2654435769) % two_32
  if x < 0 then
    x = x + two_32
  end

  -- b) shiftRight(x, 32-p)
  y = 32-p
  while x > 0 and y > 0 do
    x = x * 0.5
    x = x - x%1 -- we use the % operator here since x is guaranteed to fit in 2^32
    y = y - 1
  end

  return x
end

local function zombieID(zombie)
  local id = zombie:getOnlineID()
  if id == -1 then
    -- NOTE(belette) we can use % because Object.hashCode() returns an int
    id = zombie:hashCode() % maxValue
  end

  return hash(id)
end

local function hashToSlice(h)
  -- math.floor((h / maxValue) * 10000)
  h = h * 10000
  h = h / maxValue
  return h - h%1
end

-- -----------------------------------------------------------------------------
-- Perf and diagnostics

function Lib.time(tag, fn)
  local timestamp = getTimestampMs()

  fn()

  DebugLog.log(
    string.format("BLTRandomZombies.%s: %dms", tag, getTimestampMs() - timestamp))
end

local callCounts = {};
local startMs = getTimestampMs();
function Lib.called(tag, m)
  m = m or 10
  local cnt = callCounts[tag] or 0
  cnt = cnt + 1
  callCounts[tag] = cnt

  if cnt % m == 0 then
    local diffMs = getTimestampMs() - startMs
    DebugLog.log(string.format("%s: %d/s", tag, cnt*1000 / diffMs))
  end
end

function Lib.hashCheck()
  local filename = "randomzombies-hashcheck-linear.txt"
  local fw = getFileWriter(filename, true, false)
  if not fw then
    error("could not get file writer to " .. (filename or "nil"))
  end
  local zcnt = {
    Crawler = 0,
    CrawlerSmart = 0,
    Shambler = 0,
    ShamblerSmart = 0,
    FastShambler = 0,
    FastShamblerSmart = 0,
    Sprinter = 0,
    SprinterSmart = 0,
    total = 0,
  }
  local distribution = Lib.makeDistribution()

  for i=-2^15, 2^15 do
    local h = hash(i)
    local slice = hashToSlice(h)
    local hh = hash(h)
    local slice2 = hashToSlice(hh)
    local hhh = hash(hh)
    -- local slice3 = hashToSlice(hhh)
    if slice < distribution.Crawler then
      zcnt.Crawler = zcnt.Crawler + 1
      if slice2 < distribution.Smart then
        zcnt.CrawlerSmart = zcnt.CrawlerSmart + 1
      end
    elseif slice < distribution.Shambler then
      zcnt.Shambler = zcnt.Shambler + 1
      if slice2 < distribution.Smart then
        zcnt.ShamblerSmart = zcnt.ShamblerSmart + 1
      end
    elseif slice < distribution.FastShambler then
      zcnt.FastShambler = zcnt.FastShambler + 1
      if slice2 < distribution.Smart then
        zcnt.FastShamblerSmart = zcnt.FastShamblerSmart + 1
      end
    else
      zcnt.Sprinter = zcnt.Sprinter + 1
      if slice2 < distribution.Smart then
        zcnt.SprinterSmart = zcnt.SprinterSmart + 1
      end
    end
    zcnt.total = zcnt.total + 1

    fw:write(string.format("%d -> %s -> %s -> %s -> %s\r\n", i, tostring(h), tostring(hh), tostring(hhh), tostring(slice)))
  end
  fw:write(string.format(
             "[all] crawler:%.2f%% (%d), shambler:%.2f%%, fastshambler:%.2f%%, sprinter:%.2f%% (%d)\r\n",
             zcnt.Crawler*100/zcnt.total,
             zcnt.Crawler,
             zcnt.Shambler*100/zcnt.total,
             zcnt.FastShambler*100/zcnt.total,
             zcnt.Sprinter*100/zcnt.total,
             zcnt.Sprinter))
  fw:write(string.format(
             "[smart] crawler:%.2f%% (%d), shambler:%.2f%% (%d), fastshambler:%.2f%% (%d), sprinter:%.2f%% (%d)\r\n",
             zcnt.CrawlerSmart*100/zcnt.Crawler,
             zcnt.CrawlerSmart,
             zcnt.ShamblerSmart*100/zcnt.Shambler,
             zcnt.ShamblerSmart,
             zcnt.FastShamblerSmart*100/zcnt.FastShambler,
             zcnt.FastShamblerSmart,
             zcnt.SprinterSmart*100/zcnt.Sprinter,
             zcnt.SprinterSmart))
  fw:close()
  print("wrote to " .. filename)

  filename = "randomzombies-hashcheck-zombies.txt"
  fw = getFileWriter(filename, true, false)
  if not fw then
    error("could not get file writer to " .. (filename or "nil"))
  end
  local zs = getCell():getZombieList()
  for i=0, zs:size() - 1 do
    local zid = zombieID(zs:get(i))
    local hh = hash(zid)
    local hhh = hash(hh)
    fw:write(string.format("%d -> %d -> %d -> %d\r\n", zid, hashToSlice(zid), hashToSlice(hh), hashToSlice(hhh)))
  end
  fw:close()
  print("wrote to " .. filename)
end

function Lib.z(id)
  if id == -1 then
    DebugContextMenu.selectedZombie = nil
  elseif id then
    local zs = getCell():getZombieList()
    for i=0, zs:size() - 1 do
      local z = zs:get(i)
      if zombieID(z) == id then
        DebugContextMenu.selectedZombie = z
      end
    end
  end

  local z = DebugContextMenu.selectedZombie
  if not z then
    return
  end

  z:dressInNamedOutfit("TutorialDad")
  z:resetModelNextFrame()

  DebugContextMenu.OnSelectedZombieWalk(getPlayer():getSquare())

  local distribution = Lib.makeDistribution()

  local zid = zombieID(z)
  local slice = hashToSlice(zid)
  local slicename
  if slice < distribution.Crawler then
    slicename = "Crawler"
  elseif slice < distribution.Shambler then
    slicename = "Shambler"
  elseif slice < distribution.FastShambler then
    slicename = "FastShambler"
  else
    slicename = "Sprinter"
  end

  local hh = hash(zid)
  local slice2 = hashToSlice(hh)
  local slice2name
  if slice2 < distribution.Smart then
    slice2name = "Smart"
  else
    slice2name = "Normal"
  end

  local hhh = hash(hh)
  local slice3 = hashToSlice(hhh)
  local slice3name
  if slice3 < distribution.Fragile then
    slice3name = "Fragile"
  elseif slice3 < distribution.NormalTough then
    slice3name = "NormalTough"
  else
    slice3name = "Tough"
  end

  local l = DebugLog.log
  local f = string.format
  l(f('zombieID: %s', tostring(zombieID(z))))
  l(f('hashCode: %s', tostring(z:hashCode())))
  l(f('onlineID: %s', tostring(z:getOnlineID())))
  l(f('isRemoteZombie: %s', tostring(z:isRemoteZombie())))
  l(f('slice: %s (%d)', slicename, slice))
  l(f('slice2: %s (%d)', slice2name, slice2))
  l(f('slice3: %s (%d)', slice3name, slice3))
  l(f('health: %.2f', z:getHealth()))
  l(f('cognition: %d', getClassFieldVal(z, cognitionField)))
  l(f('speedType: %d', getClassFieldVal(z, speedField)))
  -- l(f('isBecomeCrawler: %s', tostring(z:isBecomeCrawler())))
  -- l(f('isCrawling: %s', tostring(z:isCrawling())))
  -- l(f('crawlerType: %s', tostring(z:getCrawlerType())))
  -- l(f('isCanWalk: %s', tostring(z:isCanWalk())))
  l(f('isKnockedDown: %s', tostring(z:isKnockedDown())))
  -- l(f('isFakeDead: %s', tostring(z:isFakeDead())))
  l(f('wasFakeDead: %s', tostring(z:wasFakeDead())))
  -- l(f('isHitLegsWhileOnFloor: %s', tostring(z:isHitLegsWhileOnFloor())))
  l(f('isOnFire: %s', tostring(z:isOnFire())))
end

function Lib.zcheck()
  local filename = "randomzombies-zcheck.txt"
  local fw = getFileWriter(filename, true, false)
  if not fw then
    error("could not get file writer to " .. (filename or "nil"))
  end
  local l = function (s)
    DebugLog.log(s)
    fw:write(s .. "\r\n")
  end
  local f = string.format
  local zs = getCell():getZombieList()
  local distribution = Lib.makeDistribution()
  local cnt = 0
  local zcnt = {
    Crawler = 0,
    CrawlerSmart = 0,
    Shambler = 0,
    ShamblerSmart = 0,
    FastShambler = 0,
    FastShamblerSmart = 0,
    Sprinter = 0,
    SprinterSmart = 0,
    remote = 0,
    duplicateID = 0,
  }
  local zombByID = {}
  local maxOnlineID = -2^32
  local minOnlineID = 2^32

  for i=0, zs:size() - 1 do
    local z = zs:get(i)

    local id = zombieID(z)
    local slice = hashToSlice(id)
    local slice2 = hashToSlice(hash(id))
    if slice < distribution.Crawler then
      zcnt.Crawler = zcnt.Crawler + 1
      if slice2 < distribution.Smart then
        zcnt.CrawlerSmart = zcnt.CrawlerSmart + 1
      end
      if not z:isCrawling() then
        l(f('id=%s expected crawling (crawler)', id))
        cnt = cnt + 1
      end
    elseif slice < distribution.Shambler then
      zcnt.Shambler = zcnt.Shambler + 1
      if slice2 < distribution.Smart then
        zcnt.ShamblerSmart = zcnt.ShamblerSmart + 1
      end
      if z:isCrawling() then
        l(f('id=%s expected not crawling (shambler)', id))
        cnt = cnt + 1
      end
    elseif slice < distribution.FastShambler then
      zcnt.FastShambler = zcnt.FastShambler + 1
      if slice2 < distribution.Smart then
        zcnt.FastShamblerSmart = zcnt.FastShamblerSmart + 1
      end
      if z:isCrawling() then
        l(f('id=%s expected not crawling (fastshambler)', id))
        cnt = cnt + 1
      end
    else
      zcnt.Sprinter = zcnt.Sprinter + 1
      if slice2 < distribution.Smart then
        zcnt.SprinterSmart = zcnt.SprinterSmart + 1
      end
      if z:isCrawling() then
        l(f('id=%s expected not crawling (sprinter)', id))
        cnt = cnt + 1
      end
    end

    if z:isRemoteZombie() then
      zcnt.remote = zcnt.remote + 1
    end

    local onlineID = z:getOnlineID()
    if zombByID[onlineID] then
      zcnt.duplicateID = zcnt.duplicateID + 1
    else
      zombByID[onlineID] = z
    end

    if onlineID > maxOnlineID then
      maxOnlineID = onlineID
    elseif onlineID < minOnlineID then
      minOnlineID = onlineID
    end
  end

  local sz = zs:size()
  l(f("[all] crawler:%.2f%% (%d/%d), shambler:%.2f%% (%d/%d), fastshambler:%.2f%% (%d/%d), sprinter:%.2f%% (%d/%d)",
      zcnt.Crawler*100/sz, zcnt.Crawler, sz,
      zcnt.Shambler*100/sz, zcnt.Shambler, sz,
      zcnt.FastShambler*100/sz, zcnt.FastShambler, sz,
      zcnt.Sprinter*100/sz, zcnt.Sprinter, sz))
  l(f("[smart] crawler:%.2f%% (%d/%d), shambler:%.2f%% (%d/%d), fastshambler:%.2f%% (%d/%d), sprinter:%.2f%% (%d/%d)",
      zcnt.CrawlerSmart*100/zcnt.Crawler, zcnt.CrawlerSmart, zcnt.Crawler,
      zcnt.ShamblerSmart*100/zcnt.Shambler, zcnt.ShamblerSmart, zcnt.Shambler,
      zcnt.FastShamblerSmart*100/zcnt.FastShambler, zcnt.FastShamblerSmart, zcnt.FastShambler,
      zcnt.SprinterSmart*100/zcnt.Sprinter, zcnt.SprinterSmart, zcnt.Sprinter))
  l(f("remote:%.2f%% (%d), duplicate ids: %d, max online id:%d, min online id:%d",
      zcnt.remote*100/sz, zcnt.remote, zcnt.duplicateID, maxOnlineID, minOnlineID))
  l(f("found %d/%d potential inconsistencies (%.2f%%)",
      cnt, sz, cnt*100/sz))

  fw:close()
  print("wrote to " .. filename)
end

function Lib.fullCheck()
  Lib.zcheck()
  Lib.hashCheck()

  local filename = "randomzombies-distribution.txt"
  local fw = getFileWriter(filename, true, false)
  if not fw then
    error("could not get file writer to " .. (filename or "nil"))
  end
  for k, v in pairs(BLTRandomZombies.makeDistribution()) do
    fw:write(string.format("%s -> %.2f\r\n", k, v))
  end
  fw:close()
  print("wrote to " .. filename)

  filename = "randomzombies-server-config.txt"
  fw = getFileWriter(filename, true, false)
  if not fw then
    error("could not get file writer to " .. (filename or "nil"))
  end
  local mods = getServerOptions():getOptionByName("Mods"):getValue()
  local workshopItems = getServerOptions():getOptionByName("WorkshopItems"):getValue()
  fw:write(string.format("Mods=%s\r\nWorkshopItems=%s", mods, workshopItems))
  fw:close()
  print("wrote to " .. filename)
end

function Lib.cycleThroughNZombies()
  local square = getPlayer():getSquare()
  local x = square:getX()
  local y = square:getY()
  local z = square:getZ()
  local count = 10000
  local radius = 30
  local crawler = false
  local isFallOnFront = false
  local isFakeDead = false
  local knockedDown = false
  local health = 1
  local outfit = nil

  SendCommandToServer(
      string.format(
        "/createhorde2 -x %d -y %d -z %d -count %d -radius %d -crawler %s -isFallOnFront %s -isFakeDead %s -knockedDown %s -health %s -outfit %s ",
        x, y, z, count, radius,
        tostring(crawler),
        tostring(isFallOnFront),
        tostring(isFakeDead),
        tostring(knockedDown),
        tostring(health),
        outfit or ""))

end

-- -----------------------------------------------------------------------------
-- Globals and state

local function updateZombies(zs, start, n, currentGen, nextGen, distribution)
  local skipped = 0
  local done = 0
  local nosquare = 0
  local sz = zs:size()
  n = start + n
  n = n > sz and sz or n
  local client = isClient()
  -- NOTE(belette) we try to avoid function calls in hot spots for perf reasons
  for i = start, n - 1 do
    local zombie = zs:get(i)
    if not (client and zombie:isRemoteZombie()) and not (banditsEnabled and zombie:getVariableBoolean("Bandit")) then
      -- IsoZombie::Hit(Vehicle...) suggests that stagger, knockdown and crawling
      -- states are managed by client

      -- IsoZombie::hitConsequences(Vehicle...) suggests that knockdown
      -- states is managed by client && !remote

      -- see also:
      -- IsoZombie::resetForReuse/0
      -- IsoZombie::shouldBecomeCrawler/0
      -- VirtualZombieManager::createRealZombieAlways/3

      local modData = zombie:getModData()

      -- NOTE(belette) We use a generation number to track which zombies have already been processed
      -- We have to include X and Y in the check to catch zombies that have been recycled
      -- see IsoZombie::resetForReuse and VirtualZombieManager::createRealZombieAlways for more info

      local square = zombie:getCurrentSquare()
      if square then
        -- tight loop, we limit number of func calls
        local squareX = square:getX()
        local squareY = square:getY()
        local squareZ = square:getZ()
        local diffX = (modData.BLTx or 0) - squareX
        local diffY = (modData.BLTy or 0) - squareY
        local diffZ = (modData.BLTz or 0) - squareZ
        diffX = diffX < 0 and -diffX or diffX
        diffY = diffY < 0 and -diffY or diffY
        diffZ = diffZ < 0 and -diffZ or diffZ
        if modData.BLTgen == currentGen and diffX < 20 and diffY < 20 and diffZ < 1 then
          skipped = skipped + 1
        else
          local zid = zombieID(zombie)

          -- local function check(result)
          --   if shouldSkip and result then
          --     print(debugstacktrace(),
          --           crawlingVal, modData.BLTcrawl,
          --           speedVal, modData.BLTspeed,
          --           cognitionVal, modData.BLTcog,
          --           squareXVal, modData.BLTx,
          --           squareYVal, modData.BLTy,
          --           hashToSlice(zid), hashToSlice(hash(zid)))
          --   end
          -- end

          local slice = hashToSlice(zid)

          -- update speeds
          if slice < distribution.Crawler then
            if not zombie:isCrawling() then
              -- go to crawl (calls DoZombieStats() internally)
              zombie:toggleCrawling()
              -- from ZombieOnGroundState:execute/1
              zombie:setCanWalk(false);
              -- on your belly, sir
              zombie:setFallOnFront(true)
            end
          else
            -- as of 41.71:
            -- leg break, head bash, vehicle hit: isKnockedDown
            -- randomized vehicle stories: wasFakeDead / crawlerType = 1
            -- fakeDead: wasFakeDead
            -- Kate and Baldspot: crawlerType = 1
            -- createhorde2command: isKnockedDown / crawlerType = 1
            --
            -- Note that isKnockedDown and crawlerType are not transferred on the network
            -- so not reliable when generated by server for client-owned state like knockedDown

            local shouldBeStanding = not zombie:isKnockedDown()
              and zombie:getCrawlerType() == 0
              and not zombie:wasFakeDead()

            if zombie:isCrawling() and shouldBeStanding then
              zombie:toggleCrawling()
              zombie:setCanWalk(true);
            end

            local targetSpeed
            if slice < distribution.Shambler then
              targetSpeed = SPEED_SHAMBLER
            elseif slice < distribution.FastShambler then
              targetSpeed = SPEED_FAST_SHAMBLER
            else
              targetSpeed = SPEED_SPRINTER
            end
            speedConfigOption:setValue(targetSpeed)
            zombie:makeInactive(true)
            zombie:makeInactive(false)
            speedConfigOption:setValue(SPEED_FAST_SHAMBLER)
          end

          -- update cognition
          if distribution.Smart > 0 then
            zid = hash(zid)
            local slice2 = hashToSlice(zid)
            if slice2 < distribution.Smart then
              cognitionConfigOption:setValue(COGNITION_SMART)
              zombie:DoZombieStats()
              cognitionConfigOption:setValue(COGNITION_DEFAULT)
            elseif getClassFieldVal(zombie, cognitionField) == COGNITION_SMART then
              cognitionConfigOption:setValue(COGNITION_RANDOM)
              while getClassFieldVal(zombie, cognitionField) == COGNITION_SMART do
                zombie:DoZombieStats()
              end
              cognitionConfigOption:setValue(COGNITION_DEFAULT)
            end
          end

          -- update toughness
          if distribution.NormalTough ~= 100 then
            if not zombie:getAttackedBy() and not zombie:isOnFire() then
              zid = hash(zid)
              local slice3 = hashToSlice(zid)
              local health = 0.1 * ZombRand(4)
              if slice3 < distribution.Fragile  then
                health = health + 0.5
              elseif slice3 < distribution.NormalTough then
                health = health + 1.5
              else
                health = health + 3.5
              end
              zombie:setHealth(health)
            end
          end

          modData.BLTx = squareX
          modData.BLTy = squareY
          modData.BLTz = squareZ
        end
        modData.BLTgen = nextGen
      else
        nosquare = nosquare + 1
      end
    end
    done = done + 1
  end
  -- print(string.format("done=%d skipped=%d nosquare=%d", done, skipped, nosquare))
  return done
end

local tickFrequency = 10
local lastTicks = {16, 16, 16, 16, 16}
local lastTicksIdx = 1
local last = getTimestampMs()
local tickCount = 0
local workPerTick = 100
local workList = nil
local workDone = 0
local cacheDist = nil
local generation = ZombRand(2^30)
local function updateZombiesTick()
  -- check if we have work left from previous tick
  local nLeft
  local nDone
  local nTodo
  if workList then
    nLeft = workList:size() - workDone
    nTodo = nLeft <= workPerTick and nLeft or workPerTick

    -- Lib.time("update_" .. nTodo, function ()
    nDone = updateZombies(workList, workDone, nTodo, generation, generation + 1, cacheDist)
    -- end)
    -- assert(nDone == nTodo)
    if nDone >= nLeft then
      -- assert(workDone + nDone == workList:size())
      workList = nil
      generation = generation + 1
    else
      workDone = workDone + nDone
    end
    return
  end

  -- check if it's our time to shine
  tickCount = tickCount + 1
  if tickCount % tickFrequency ~= 1 then
    return
  end
  tickCount = 1

  local now = getTimestampMs()
  local diff = now - last
  last = now

  local tickMs = diff / tickFrequency
  lastTicks[lastTicksIdx] = tickMs
  lastTicksIdx = (lastTicksIdx % 5) + 1
  local totalTicks = 0
  local sumTicks = 0
  for _, v in ipairs(lastTicks) do
    sumTicks = sumTicks + v
    totalTicks = totalTicks + 1
  end

  local avgTickMs = sumTicks / totalTicks
  -- NOTE: needs to be at least 2 for modulo check to pass
  tickFrequency = math.max(2, math.ceil(SandboxVars.BLTRandomZombies.Frequency / avgTickMs))

  -- if getDebug() then
  --   local tickString = ""
  --   local first = true
  --   for _, v in pairs(lastTicks)  do
  --     if first then
  --       first = false
  --     else
  --       tickString = tickString .. ", "
  --     end
  --     tickString = string.format("%s%.2f", tickString, v)
  --   end
  --   DebugLog.log(
  --     string.format("BLTRandomZombies.diff: %.2fms", diff))
  --   DebugLog.log(
  --     string.format("BLTRandomZombies.tick_time: %.2fms", tickMs))
  --   DebugLog.log(
  --     string.format("BLTRandomZombies.tick_last_times: %s", tickString))
  --   DebugLog.log(
  --     string.format("BLTRandomZombies.tick_avg_time: %.2fms", avgTickMs))
  --   DebugLog.log(
  --     string.format("BLTRandomZombies.tick_freq: %d", tickFrequency))
  -- end

  local zs = getCell():getZombieList()
  cacheDist = Lib.makeDistribution()
  nLeft = zs:size()
  nTodo = nLeft <= workPerTick and nLeft or workPerTick
  -- Lib.time("update_" .. nTodo, function ()
  nDone = updateZombies(zs, 0, nTodo, generation, generation + 1, cacheDist)
  -- end)
  -- assert(nDone == nTodo)
  if nDone >= nLeft then
    generation = generation + 1
  else
    workList = zs
    workDone = nDone
  end
end

function Lib.enable()
  if not isServer() then
    local prevTickMs = lastTicks[((lastTicksIdx + 3) % 5) + 1]
    last = getTimestampMs() - prevTickMs*tickCount
    Events.OnTick.Add(updateZombiesTick)
  end
end

function Lib.disable()
  if not isServer() then
    Events.OnTick.Remove(updateZombiesTick)
  end
end

local function OnGameStart()
  banditsEnabled = getActivatedMods():contains("Bandits")
  cognitionField =
    Lib.findField(IsoZombie.new(nil), "public int zombie.characters.IsoZombie.cognition")
  speedField =
    Lib.findField(IsoZombie.new(nil), "public int zombie.characters.IsoZombie.speedType")
  speedConfigOption = getSandboxOptions():getOptionByName("ZombieLore.Speed"):asConfigOption()
  cognitionConfigOption = getSandboxOptions():getOptionByName("ZombieLore.Cognition"):asConfigOption()
end

if not isServer() then
  Events.OnGameStart.Add(OnGameStart)
  Lib.enable()
end
