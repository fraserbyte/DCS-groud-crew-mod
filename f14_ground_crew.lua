--[[
  F-14 Ground Crew - Version 1 (placeholder objects)

  What it does:
    - Adds an F10 radio menu "Ground Crew" for players in any F-14 (A, B, B(U)).
    - "Call ground crew" places crew, a fuel truck, a power cart and ammo
      around your parked jet.
    - Everything is removed when you start moving, take off, leave the jet,
      or pick "Dismiss ground crew".

  How to load it:
    Mission Editor -> Triggers -> MISSION START -> action DO SCRIPT FILE -> pick this file.

  Land airfields only for now (not carriers).
  Positions in GroundCrew.layout are first guesses: tweak them in-game.
  Errors go to Saved Games\DCS\Logs\dcs.log (search for "GroundCrew").
]]

GroundCrew = {}

GroundCrew.typePrefix    = "F-14"   -- matches F-14A-135-GR, F-14B, etc.
GroundCrew.maxSpeed      = 0.5      -- m/s; faster than this counts as "moving"
GroundCrew.checkInterval = 2        -- seconds between movement checks

--[[
  LAYOUT - one line per object.
    fwd   = metres in front of the jet's centre (negative = behind)
    right = metres to the jet's right           (negative = left)
    hdg   = which way the object faces, in degrees, relative to the jet's nose
            (0 = same way as the jet, 180 = facing the jet's nose)
  These are built-in DCS objects used as placeholders until your own models are ready.
]]
GroundCrew.layout = {
  -- Plane captain, in front of the nose, facing the jet
  { type = "Soldier M4", category = "Infantry", fwd = 10,  right = -2,  hdg = 180 },

  -- Fuel truck parked behind the left wing, plus its operator
  { type = "M978 HEMTT Tanker", category = "Unarmed", fwd = -4, right = -10, hdg = 0 },
  { type = "Soldier M4", category = "Infantry", fwd = -1,  right = -5,  hdg = 90 },

  -- Ground power cart on the right side
  { type = "Ural-4320 APA-5D", category = "Unarmed", fwd = 5, right = 9, hdg = 0 },

  -- Ordnance crew and ammo trays under the right side
  { type = "Soldier M4", category = "Infantry", fwd = 1,   right = 4,   hdg = -90 },
  { type = "ammo_cargo", category = "Cargos", shape = "ammo_box_cargo", mass = 500, fwd = 2,  right = 3, hdg = 0 },
  { type = "ammo_cargo", category = "Cargos", shape = "ammo_box_cargo", mass = 500, fwd = -2, right = 3, hdg = 0 },
}

GroundCrew.active  = {}  -- [unitName] = { list of spawned static names }
GroundCrew.menus   = {}  -- [groupId]  = menu path
GroundCrew.counter = 0

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function msg(unit, text)
  local group = unit:getGroup()
  if group then
    trigger.action.outTextForGroup(group:getID(), text, 8)
  end
end

local function isF14(unit)
  local ok, typeName = pcall(unit.getTypeName, unit)
  return ok and typeName
     and string.sub(typeName, 1, #GroundCrew.typePrefix) == GroundCrew.typePrefix
end

local function speed(unit)
  local v = unit:getVelocity()
  return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

-- Returns the jet's heading (radians, 0 = north) and its position
local function headingAndPos(unit)
  local pos = unit:getPosition()
  local h = math.atan2(pos.x.z, pos.x.x)
  if h < 0 then h = h + 2 * math.pi end
  return h, pos.p
end

----------------------------------------------------------------------
-- Spawn / remove
----------------------------------------------------------------------

function GroundCrew.spawn(unitName)
  local unit = Unit.getByName(unitName)
  if not unit or not unit:isExist() then return end

  if GroundCrew.active[unitName] then
    msg(unit, "Ground crew is already out.")
    return
  end
  if unit:inAir() or speed(unit) > GroundCrew.maxSpeed then
    msg(unit, "Bring the jet to a full stop first.")
    return
  end

  local h, p = headingAndPos(unit)
  local country = unit:getCountry()
  local names = {}

  for _, item in ipairs(GroundCrew.layout) do
    GroundCrew.counter = GroundCrew.counter + 1
    local name = "GC_" .. unitName .. "_" .. GroundCrew.counter

    -- Turn the jet-relative offset into map coordinates
    local x = p.x + item.fwd * math.cos(h) - item.right * math.sin(h)
    local z = p.z + item.fwd * math.sin(h) + item.right * math.cos(h)

    local objHeading = (h + math.rad(item.hdg or 0)) % (2 * math.pi)

    local obj = {
      type       = item.type,
      category   = item.category,
      shape_name = item.shape,
      mass       = item.mass,
      canCargo   = false,
      name       = name,
      x          = x,
      y          = z,  -- DCS static tables call the east-west axis "y"
      heading    = objHeading,
      dead       = false,
    }

    local ok, err = pcall(coalition.addStaticObject, country, obj)
    if ok then
      names[#names + 1] = name
    else
      env.error("GroundCrew: failed to spawn " .. item.type .. ": " .. tostring(err))
    end
  end

  GroundCrew.active[unitName] = names
  msg(unit, "Ground crew is out. They will clear when you start moving.")
end

function GroundCrew.remove(unitName, reason)
  local names = GroundCrew.active[unitName]
  if not names then return end

  for _, n in ipairs(names) do
    local s = StaticObject.getByName(n)
    if s and s:isExist() then s:destroy() end
  end
  GroundCrew.active[unitName] = nil

  local unit = Unit.getByName(unitName)
  if reason and unit and unit:isExist() then msg(unit, reason) end
end

----------------------------------------------------------------------
-- Watch for jets that start moving
----------------------------------------------------------------------

function GroundCrew.monitor(_, time)
  for unitName, _ in pairs(GroundCrew.active) do
    local unit = Unit.getByName(unitName)
    if not unit or not unit:isExist() then
      GroundCrew.remove(unitName)
    elseif unit:inAir() or speed(unit) > GroundCrew.maxSpeed then
      GroundCrew.remove(unitName, "Jet is moving - ground crew cleared.")
    end
  end
  return time + GroundCrew.checkInterval
end

----------------------------------------------------------------------
-- F10 menu
----------------------------------------------------------------------

function GroundCrew.addMenu(unit)
  local group = unit:getGroup()
  if not group then return end
  local gid = group:getID()
  local unitName = unit:getName()

  if GroundCrew.menus[gid] then
    missionCommands.removeItemForGroup(gid, GroundCrew.menus[gid])
  end

  local root = missionCommands.addSubMenuForGroup(gid, "Ground Crew")
  missionCommands.addCommandForGroup(gid, "Call ground crew", root, GroundCrew.spawn, unitName)
  missionCommands.addCommandForGroup(gid, "Dismiss ground crew", root, function(n)
    GroundCrew.remove(n, "Ground crew dismissed.")
  end, unitName)

  GroundCrew.menus[gid] = root
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------

GroundCrew.handler = {}

function GroundCrew.handler:onEvent(e)
  local unit = e.initiator
  if not unit or not unit.getPlayerName then return end  -- ignore statics etc.

  if e.id == world.event.S_EVENT_BIRTH then
    if isF14(unit) and unit:getPlayerName() then
      GroundCrew.addMenu(unit)
    end

  elseif e.id == world.event.S_EVENT_PLAYER_LEAVE_UNIT
      or e.id == world.event.S_EVENT_UNIT_LOST
      or e.id == world.event.S_EVENT_DEAD then
    local ok, name = pcall(unit.getName, unit)
    if ok and name then GroundCrew.remove(name) end
  end
end

world.addEventHandler(GroundCrew.handler)
timer.scheduleFunction(GroundCrew.monitor, nil, timer.getTime() + GroundCrew.checkInterval)
env.info("GroundCrew: loaded")
