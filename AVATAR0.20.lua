local version = "0.20"

function widget:GetInfo()
    return {
      name      = "AVATAR EcoMan v " .. version,
      desc      = "Idlecons automatically start expanding/doing e.",
      author    = "Clan XCOM",
      date      = "",
      license   = "",
      layer     = 50000,
      enabled   = true,
    }
  end
  local facplopped = false
  local chckunits
  local initframe = 0
  local checkunits = false
  local hasfac = false
  local preload = false
  local floormap = false
  local threatdistance = 0
  if Game.mapX + Game.mapY < 10 then -- tiny map!
    threatdistance = 600
  else
    if Game.mapX + Game.mapY < 20 then -- small map
      threatdistance = math.ceil((Game.mapX+Game.mapY)/10)*650
    else
      if Game.mapX + Game.mapY < 30 then -- medium map iceland is about 1800 for reference. produces a nice grid.
        threatdistance = math.ceil((Game.mapX+Game.mapY)/10)*550
      else -- large map
        threatdistance = math.ceil((Game.mapX+Game.mapY)/15)*450
      end
    end
  end
  local claimedmexes = {}
  local mybasebuilder = 0
  local originalfloormap = {}
  local reachabilitytab = {}
  local maxvalue = 0
  local minvalue = 99999
  local movetypes = {bot = {id = UnitDefNames["armrectr"].moveDef.id, tar = 90},
                     veh = {id = UnitDefNames["corned"].moveDef.id, tar = 180},
                     amph = {id = UnitDefNames["amphcon"].moveDef.id, tar = 120},
                     spider = {id = UnitDefNames["arm_spider"].moveDef.id, tar = 220}}
  local antiscythe = 0 -- higher = engage anti-scyhte protocal
  local seenscythes = {} -- so we don't repeatedly increase anti-scythe
  local energyexpenses = {overdrive = 0,
                          other = 0,
                          buffer = 2}
  local nodes = {}
  local mycoms = {}
  local mystartpos = {x = 0, y = 0}
  local mode = "debug"
  --variables--
  local reverselookuptab = {}
  
  local builddefs = {mex   = UnitDefNames["cormex"].id,
                 solar = UnitDefNames["armsolar"].id,
                 wind  = UnitDefNames["armwin"].id,
                 llt   = UnitDefNames["corllt"].id,
                 def   = UnitDefNames["corrl"].id,
                 radar = UnitDefNames["corrad"].id,
                 nano  = UnitDefNames["armnanotc"].id,
                 urch  = UnitDefNames["turrettorp"].id,
                 star  = UnitDefNames["armdeva"].id,
                 stor  = UnitDefNames["armmstor"].id
                 }

  local factorydefs = {
    cloak  = UnitDefNames["factorycloak"].id,
    shield = UnitDefNames["factoryshield"].id,
    spider = UnitDefNames["factoryspider"].id,
    hveh   = UnitDefNames["factorytank"].id,
    lveh   = UnitDefNames["factoryveh"].id,
    bigbot = UnitDefNames["striderhub"].id,
    jumper = UnitDefNames["factoryjump"].id,
    hover  = UnitDefNames["factoryhover"].id,
    air    = UnitDefNames["factoryplane"].id,
    gship  = UnitDefNames["factorygunship"].id,
    ships  = UnitDefNames["factoryship"].id,
    amphs  = UnitDefNames["factoryamph"].id
  }
  local cons = {clky   = UnitDefNames["armrectr"].id,
                tank   = UnitDefNames["coracv"].id,
                lveh   = UnitDefNames["corned"].id,
                amph   = UnitDefNames["amphcon"].id,
                ship   = UnitDefNames["shipcon"].id,
                guns   = UnitDefNames["armca"].id,
                air    = UnitDefNames["armca"].id,
                jump   = UnitDefNames["corfast"].id,
                spid   = UnitDefNames["arm_spider"].id,
                shld   = UnitDefNames["cornecro"].id,
                hovr   = UnitDefNames["corch"].id}
  
  local globalthreat = 100 -- how scary is the world? 100 = neutral, - 100 = i own the world 200+ = o.o
  local mydemand = {bp = 0, expander = 0, energy = 0} -- total demand
  local myteamid = 0
  local mycons = {}
  local mexestable = {}
  local avgmetal = 0
  local totalmetal = 0
  local threatgrid = {}
  local reversethreat = {}
  local initalized = false
  local myassignedcons = {total = {defense = 0,expansion = 0,eco = 0,grid = 0, unassigned = 0}, wanted = {defense = 0, expansion = 2, eco = 0, grid = 0}, priority = {defense = 0, expansion = 1, eco = 0, grid = 0}}
  local function toboolean(ob)
    if ob == nil then
      return false
    end
    if ob == "true" then
      return true
    end
    if ob == 1 then
      return true
    end
    if ob == 0 then
      return false
    end
    return false
  end
  
  local function IsCom(id)
    unitdefid = Spring.GetUnitDefID(id)
    if UnitDefs[unitdefid].customParams.commtype or UnitDefs[unitdefid].customParams.iscommander then
      return true
    else
      return false
    end
  end
  
  local function IsCon(id)
    unitDefID = Spring.GetUnitDefID(id)
    for _,conid in pairs(cons) do
      if conid == unitDefID then -- it's a valid constructor.
        return true
      end
    end
    return false
  end
  
  function IsFac(id)
    unitDefID = Spring.GetUnitDefID(id)
    for mtype,facid in pairs(factorydefs) do
      if facid == unitDefID then
        return true,mtype
      end
    end
    return false
  end
  
  local function SolarOrWind(x,y) -- determine if solar or wind is better at this position.
    local z = Spring.GetGroundHeight(x,y)
    if z <= -10 then
      return "wind" -- wind is 1.2, multiply that by 2 = 2.4 vs 2.0. no extra work needed. Wind: 29.16m/e vs 37.5
    end
    if z > -10 and z < 0 then
      return "none" -- Don't build e here.
    end
    
  end
  
  local function IsInRadius(x,y,tx,ty,rad)
    distance = ((tx - x)^2 + (ty - y)^2)^0.5
    if distance - rad <= rad then
      return true
    else
      return false
    end
  end
  
  local function SetFloorMap()
    for id,data in pairs(mexestable) do
      data.threat = data.tfloor
    end
  end
  
  local function CheckNodes(id)
    
  end
  
  local function CheckUnits()
    local myunits = Spring.GetAllUnits(Spring.GetMyTeamID)
    local unitdefid
    for _,id in pairs(myunits) do
      unitdefid = Spring.GetUnitDefID(id)
      if IsCom(id) then
        mycoms[id] = {id = id,task = "none", facplop = toboolean(Spring.GetUnitRulesParam(id, "facplop"))}
      end
      if IsCon(id) then
        mycons[id] = {id = id,task = "none",params = {},mtype = "unassigned"}
      end
      local isfact,mtype = IsFac(id)
      if isfact then
        local x,y,z = Spring.GetUnitPosition(id)
        nodes[id] = {bp = {bp = 10,wanted = 10},defense = 0,rad = 600,energy = 0.3,metal = 0.3,coords = {x = x, y = y, z = z},type = mtype,units = {id = unitID},value = 600}
      end
    end
  end
  
  local function RecalcFloorMap()
    for id,data in pairs(mexestable) do
      if globalthreat > 100 then
        data.tfloor = originalfloormap[id] + ((globalthreat/100)+1)
      elseif globalthreat < 100 then
        data.tfloor = originalfloormap[id] - math.abs((globalthreat/100))
      end
    end
  end
  
  local function CreateThreatGrid()
    local distance = 0
    for id,data in pairs(mexestable) do
      reversethreat[id] = {}
      for id2,data2 in pairs(mexestable) do
        if id2 ~= id then
          if data2.x > data.x then
            distance = data2.x - data.x
          else
            distance = data.x - data2.x
          end
          if data2.z > data.z then
            distance = distance + (data2.z-data.z)
          else
            distance = distance + (data.z - data2.z)
          end
          Spring.Echo("[ThreatGrid] Distance between " .. id .. " and " .. id2 .. " : " .. distance)
          if distance < threatdistance then
            threatgrid[tostring(id,id2)] = {threat = ((threatdistance/distance)-1),dist = distance}
            Spring.Echo("Mult between " .. id .. "," .. id2 .. "=" .. threatgrid[tostring(id,id2)].threat)
            table.insert(reversethreat[id],id2)
          end
        end
      end
    end
    Spring.Echo("Threatgrid created.")
  end
  
  local function GetNearestMex(x,y)
    local distance = 0
    local closest = 999999999999999
    local close = 0
    for num,data in pairs(mexestable) do
      distance = ((data.x - x)^2 + (data.z - y)^2)^0.5
      --Spring.Echo(num .. " is " .. distance .. "from " .. x,y)
      if distance < closest then
        closest = distance
        close = num
      end
    end
    return close
  end
  
  local function GetFurthestMex(x,y)
    local distance = 0
    local furthest = 0
    local far = 0
    for num,data in pairs(mexestable) do
      distance = ((data.x - x)^2 + (data.z - y)^2)^0.5
      --Spring.Echo(num .. " is " .. distance .. "from " .. x,y)
      if distance > furthest then
        furthest = distance
        far = num
      end
    end
    return far
  end
  
  local function DoSmartPlacement(x,y,btype)
    local footx,footy = 0 -- foot is 16 elmos big.
    footx = UnitDefs[btype].footprintX * 16
    footy = UnitDefs[btype].footprintZ * 16
    Spring.Echo("Building is " .. footx,footy)
    local xtry,ytry = -1
    local z = 0
    local result = 0
    for i=1,10 do
      x = ox+(footx*16*xtry)
      y = oy+(footz*16*ytry)
      xtry = xtry + 1
      if xtry == 2 then
        xtry = -1
        ytry = ytry + 1
      end
      Spring.Echo("[SMARTBUILD] Trying " .. x,y)
      z = Spring.GetGroundHeight(x,y)
      result = Spring.TestBuildOrder(btype,x,z,y,0)
      if result ~= 0 then
        return result,x,z,y
      end
    end
    return 0,ox,oy
  end
  
  local function UpdateFloorMap(uid,threat)
    mexestable[uid].tfloor = mexestable[uid].tfloor + threat
    for _,uid2 in pairs(reversethreat[uid]) do
      mexestable[uid2].tfloor = mexestable[uid2].tfloor + (threat * threatgrid[tostring(uid,uid2)].threat)
    end
  end
  
  local function UpdateThreatGrid(uid,threat)
    mexestable[uid].threat = mexestable[uid].threat + threat
    if mexestable[uid].threat < mexestable[uid].tfloor then
      mexestable[uid].threat = mexestable[uid].tfloor
    end
    for _,uid2 in pairs(reversethreat[uid]) do
      mexestable[uid2].threat = mexestable[uid2].threat + (threat * threatgrid[tostring(uid,uid2)].threat)
      if mexestable[uid2].threat < mexestable[uid2].tfloor then
        mexestable[uid2].threat = mexestable[uid2].tfloor
      end
    end
  end
  
  local function FindNearestBuildArea(x,y,btype,rad) -- Brute force it until it coughs up a good build position
    local ox = x
    local oy = y
    local z = Spring.GetGroundHeight(x,y)
    local result = Spring.TestBuildOrder(btype,x,y,z,0) -- doesnt really matter i think.
    if result == 0 then -- start smart placement
      result,x,y,z = DoSmartPlacement(x,y,btype)
      if result ~= 0 then
        return x,y,z
      end
    end
    if result == 0 then
      local try = 0 -- we're going to give 50 or so random points in the radius.
      local tries = {}
      repeat
        repeat
          x = x + math.random(-(rad),rad)
          y = y + math.random(-(rad),rad)
        until tries[tostring(x) .. "," .. tostring(y)] == nil -- don't try the same point!
        z = Spring.GetGroundHeight(x,y)
        result = Spring.TestBuildOrder(btype,x,y,z,0)
        if result == 0 then
          tries[tostring(x) .. "," .. tostring(y)] = true
          x = ox
          y = oy
        end
      until try == 50 or result > 0
      if result == 0 then
        return "failed"
      else
        return x,y,z
      end
    end
  end
  
  local function GetNearestReachableMex(unitID)
    local defid = Spring.GetUnitDefID(unitID)
    local x,z,y = Spring.GetUnitPosition(unitID)
    local distance,closest = 0
    local closestdistance = 99999999
    local moveid = UnitDefs[defid].moveDef.id
    local reachable
    for num,data in pairs(mexestable) do
      if data.claimed == "none" then
        reachable = IsTargetReachable(moveid,x,z,y,data.x,data.y,data.z,90)
        distance = ((ox - tx)^2 + (oz - tz)^2)^0.5
        if distance < closestdistance then
          closest = num
        end
      end
    end
  end
  
  local function UseUrchin(x,y)
    local z = Spring.GetGroundHeight(x,y)
    if z < -20 then
      return true
    else
      return false
    end
  end
  
local function IsTargetReachable(moveID, ox,oy,oz,tx,ty,tz,radius)
  local result,lastcoordinate, waypoints
  local distance = ((ox - tx)^2 + (oz - tz)^2)^0.5
  if radius == nil then
    radius = 20
  end
  if distance < 48 then
    return "reach"
  end
  Spring.Echo("[AVATARPF] Attempting to path (" .. ox,oz .. ") to (" .. tx,tz .. ")")
  local path = Spring.RequestPath(moveID,ox,oy,oz,tx,ty,tz, radius)
  local waypoint = {}
  if path then
    local cnt = 0
    local x,y,z = 0,0,0
    local nx,ny,nz = path:Next(ox,oy,oz)
    local abort = false
    while (nx) and cnt < 1000 and abort == false do
      waypoint[#waypoint+1] = {nx,ny,nz}
      cnt = cnt + 1
      x,y,z = nx,ny,nz
      nx,ny,nz = path:Next(x,y,z)
      if math.abs(nx - tx) + math.abs(nz - tz) < radius then
        Spring.Echo("[AVATARPF] Reached (" .. tx,tz .. ") from (" .. ox,oz .. ") in " .. #waypoint .. " steps")
        return "reach"
      end
      if nx == -1 and ny == -0 and nz == -1 then
        abort = true
      end
    end
    if math.abs(nx - tx) + math.abs(nz - tz) < radius then
      return "reach"
    else
      if cnt == 1 and ty >= 0 then
        Spring.Echo("[AVATARPF] Abnormality detected during pathing: 1 step used. Returning true.")
        return "reach"
      end
      if cnt == 1 and moveID == UnitDefNames["amphcon"].moveDef.id and ty < 0 then
        return "reach"
      end
      Spring.Echo("[AVATARPF] Failed to reach (" .. tx,tz .. ") [used:" .. cnt .. "] Final coordinates: (" .. nx,nz .. ")")
      Spring.Echo("[AVATARPF] Path:")
      for id,data in pairs(waypoint) do
        Spring.Echo(id .. ": " .. data[1] .. "," .. data[2] .. "," .. data[3])
      end
      return "outofreach"
    end
  end
end
  
  local function CreateFloorMap()
    local distance = 0
    local homemex = GetNearestMex(mystartpos.x,mystartpos.y)
    local farmex = GetFurthestMex(mystartpos.x,mystartpos.y)
    distance = 150/(math.abs(mexestable[homemex].x - mexestable[farmex].x) + math.abs(mexestable[homemex].z-mexestable[farmex].z))
    Spring.Echo("[FloorMap] Mult: " .. distance)
    mexestable[homemex].tfloor = 0
    for num,data in pairs(mexestable) do
      data.tfloor = (math.abs(mexestable[homemex].x-data.x) + math.abs(mexestable[homemex].z-data.z))*distance
      originalfloormap[num] = data.tfloor
    end
    floormap = true
  end
  
  local function UpdateThreatValues()
    for mexid,data in pairs(mexestable) do
      if data.threat > data.tfloor then
        if data.threat*0.87 < 0.005 and data.threat*0.87 > 0 then
          data.threat = data.tfloor
        else
          data.threat = data.threat*0.87 -- lose 13% threat
        end
      else
        if data.threat < data.tfloor then
          data.threat = data.tfloor
        end
      end
      if data.threat >= 100 and data.claim == "none" then
        data.claim = "unviable"
      end
      if data.threat <= 99 and data.claim == "unviable" then
        data.claim = "none"
      end
    end
  end
  
  function widget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
    unitDefID = Spring.GetUnitDefID(unitID)
    if unitDefID == UnitDefNames["cormex"].id and allyTeam ~= Spring.GetMyAllyTeamID() and mexestable[num].claim == "none" then
      local num = reverselookuptab[tostring(x) .. "," .. tostring(y)]
      if num == nil then
        return
      end
      mexestable[num].claim = "enemy"
      UpdateFloorMap(num,15)
      originalfloormap[num] = originalfloormap[num] + 15
    end
  end
  
  function widget:UnitFinished(unitID, unitDefID, unitTeam) -- update "building" -> "self"
    if unitDefID == UnitDefNames["cormex"].id then
      local x,_,y = Spring.GetUnitPosition(unitID)
      local num = reverselookuptab[tostring(x) .. "," .. tostring(y)]
      if Spring.GetUnitAllyTeam(unitID) == Spring.GetMyAllyTeamID() and num ~= nil and mexestable[num].claim == "none" then
        mexestable[num].claim = "ally"
        UpdateFloorMap(num,-1)
        originalfloormap[num] = originalfloormap[num] - 1
      else
        if num ~= nil and mexestable[num].claim == "none" then
          mexestable[num].claim = "enemy"
          UpdateFloorMap(num,15)
          originalfloormap[num] = originalfloormap[num] + 15
        end
      end
    end
    if unitTeam == Spring.GetMyTeamID() then
      if IsCon(unitID) and mycons[unitID] == nil then
        mycons[unitID] = {id = unitID,task = "none",params = {},mtype = "unassigned"}
        myassignedcons.total.unassigned = myassignedcons.total.unassigned + 1
      end
    end
    isfac,mtype = IsFac(unitID)
    if isfac then
      local x,y,z = Spring.GetUnitPosition(unitID)
      nodes[unitID] = {bp = {bp = 10,wanted = 10},defense = 0,rad = 600,energy = 0.3,metal = 0.3,coords = {x = x, y = y, z = z},type = mtype,units = {id = unitID},value = 600}
    end
  end
  
  function widget:UnitIdle(unitID, unitDefID, unitTeam)
    if unitTeam == Spring.GetMyTeamID() and mycons[unitID] then
--      AssignTask(unitID)
    end
  end
  
  function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if unitTeam == Spring.GetMyTeamID() then
      if IsCom(unitID) then
        mycoms[unitID] = {id = unitID,task = "none", facplop = toboolean(Spring.GetUnitRulesParam(unitID, "facplop"))}
      end
      _,_,_,_,bprog = Spring.GetUnitHealth(unitID)
      isfact,mtype = IsFac(unitID)
      if isfact and bprog == 1 then
        local x,y,z = Spring.GetUnitPosition(unitID)
        nodes[unitID] = {bp = {bp = 10,wanted = 10},defense = 0,rad = 600,energy = 0.3,metal = 0.3,coords = {x = x, y = y, z = z},type = mtype,units = {id = unitID},value = 600}
      end
    end
  end
  
  function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam) -- update "building" / "self" / "enemy" -> "none"
    if unitDefID == UnitDefNames["cormex"].id then
      local x,_,y = Spring.GetUnitPosition(unitID)
      local num = reverselookuptab[tostring(x) .. "," .. tostring(y)]
      Spring.Echo("ID " .. num .. " destroyed.")
      if Spring.GetUnitAllyTeam(unitID) == Spring.GetMyAllyTeamID() then
        UpdateThreatGrid(num,mexestable[num].value * 3)
        mexestable[num].claim = "none"
        UpdateFloorMap(num,1)
        originalfloormap[num] = originalfloormap[num] + 1
      else
        mexestable[num].claim = "none"
        UpdateFloorMap(num,-15)
        originalfloormap[num] = originalfloormap[num]-15
      end
    end
    if Spring.GetUnitAllyTeam(unitTeam) == Spring.GetMyAllyTeamID() then
      globalthreat = globalthreat + ((UnitDefs[unitDefID].health/UnitDefs[unitDefID].metalCost))
    else
      globalthreat = globalthreat - ((UnitDefs[unitDefID].health/UnitDefs[unitDefID].metalCost))
    end
    if mycoms[unitID] then
      mycoms[unitID] = nil
    end
    if nodes[unitID] then
      nodes[unitID] = nil
    end
    if mycons[unitID] then
      mycons[unitID] = nil
    end
  end
  
  function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
    if unitDefID == UnitDefNames["cormex"].id and Spring.GetUnitAllyTeam(unitID) == Spring.GetMyAllyTeamID() then -- Increase threat.
      local x,_,y = Spring.GetUnitPosition(unitID)
      local num = reverselookuptab[tostring(x) .. "," .. tostring(y)]
      if num == nil and mode == "debug" then
        Spring.SendCommands("say s: [Critical Error] Mex ID " .. unitID .. " got (" .. x .. "," .. y .. ") but reverse look up failed! Check code!")
      else
        --if mode == "debug" then
          --Spring.SendCommands("say s: [Debug] Mex ID " .. unitID .. " got (" .. x .. "," .. y .. "). Reverse look up shows: " .. num .. ".")
          if mexestable[num].x == x and mexestable[num].z == y then
            --Spring.SendCommands("say s: [Debug] Mex ID " .. unitID .. " Verified successfully. Code is working.")
            UpdateThreatGrid(num,damage/(150*mexestable[num].value))
            globalthreat = globalthreat + (damage/(500*mexestable[num].value)+0.25)
          else
            Spring.SendCommands("say s: [Debug:Abnormality] Mex ID " .. unitID .. " Failed verification. Check code.")
          end
        --end
      end
    end
  end
  
  local function glDrawLines()
    local x1, y1, z1, x2, y2, z2
    local alreadydrawn = {}
    for id,data in pairs(reversethreat) do
      for _,id2 in pairs(data) do
        if alreadydrawn[tostring(id) .. "," .. tostring(id2)] == nil then
          alreadydrawn[tostring(id) .. "," .. tostring(id2)] = 1
          x1 = mexestable[id].x
          y1 = mexestable[id].y
          z1 = mexestable[id].z
          x2 = mexestable[id2].x
          y2 = mexestable[id2].y
          z2 = mexestable[id2].z
          if mexestable[id].claim == "ally" then
            gl.Color(0,1,0,1)
          else
            if mexestable[id].claim == "none" or mexestable[id].claim == "unviable" then
              gl.Color(1,1,1,1)
            else
              gl.Color(1,0,0,1)
            end
          end
          gl.Vertex(x1, y1, z1)
          if mexestable[id2].claim == "ally" then
            gl.Color(0,1,0,1)
          else
            if mexestable[id2].claim == "none" or mexestable[id2].claim == "unviable" then
              gl.Color(1,1,1,1)
            else
              gl.Color(1,0,0,1)
            end
          end
          gl.Vertex(x2, y2, z2)
        end
      end
    end
  end
  
  function widget:DrawWorld() -- handle debug stuff.
    if initalized == true and mode == "debug" then
      for mex,data in pairs(mexestable) do
        if Spring.IsAABBInView(data.x-1,data.y-1,data.z-1,data.x+1,data.y+1,data.z+1) then
          gl.PushMatrix()
          gl.Translate(data.x, data.y, data.z)
          gl.Billboard()
          gl.Color(0.7, 0.9, 0.7, 1.0)
          gl.Text("ID: " .. mex,-10.0,0,12,"v")
          if data.threat <= 50 then
            gl.Color(data.threat/50,1.0,0)
          else
            if data.threat < 100 then
              gl.Color(1.0,(100/data.threat)-1,0,1)
            else
              gl.Color(0,0,0,1)
            end
          end
          gl.Text("Threat: " .. data.threat .. "[Floor: " .. data.tfloor .. "]",-10,-10,12,"v") -- data.value,data.claim,data.type
          if data.value < 1 then
            gl.Color(1,data.value,0)
          else
            if data.value-1 < 0.1 then
              gl.Color(1,1,0,1)
            else
              gl.Color(maxvalue-data.value,1,0,1)
            end
          end
          gl.Text("Value: " .. data.value,-10,-21,12,"v")
          if data.claim == "ally" then
            gl.Color(0,1,0,1)
          else
            if data.claim == "enemy" then
              gl.Color(1,0,0,1)
            else
              if data.claim == "unviable" then
                gl.Color(1,0,0,1)
              else
                gl.Color(1,1,1,1)
              end
            end
          end
          gl.Text("Claim: " .. data.claim,-10,-32,12,"v")
          if data.mtype == "land" then
            gl.Color(0,1,0,1)
          end
          if data.mtype == "hill" then
            gl.Color(1,1,0,1)
          end
          if data.mtype == "mountain" then
            gl.Color(1,0,0,1)
          end
          if data.mtype == "sea" then
            gl.Color(0,1,1,1)
          end
          if data.mtype == "island" then
            gl.Color(0.19,0.72,1,1)
          end
          if data.mtype == "coastal" then
            gl.Color(0.19,0.72,0.65,1)
          end
          if data.mtype == "shallows" then
            gl.Color(0.19,0.72,0.45,1)
          end
          if data.mtype == "isolated" then
            gl.Color(1,1,1,1)
          end
          gl.Text("Type: " .. data.mtype,-10,-45,12,"v")
          gl.PopMatrix()
          gl.Color(1,1,1,1)
        end
      end
      gl.BeginEnd(GL.LINES, glDrawLines)
      if mycoms then
        local num,x,y,z = 0
        for _,data in pairs(mycoms) do
          num = num + 1
          x,y,z = Spring.GetUnitPosition(data.id)
          if Spring.IsAABBInView(x-1,y-1,z-1,x+1,y+1,z+1) then
            gl.PushMatrix()
            gl.Translate(x, y, z)
            gl.Billboard()
            gl.Color(0.19, 0.49, 0.68, 1.0)
            gl.Text("COMMANDER #" .. num .. "\nTask: " .. data.task .. "\nFacplop Avaliable: " .. tostring(data.facplop),-10,-12,14,"v")
            gl.PopMatrix()
            gl.Color(1,1,1,1)
          end
        end
      end
      if mycons then
        local num,x,y,z = 0
        for _,data in pairs(mycons) do
          num = num + 1
          x,y,z = Spring.GetUnitPosition(data.id)
          if Spring.IsAABBInView(x-1,y-1,z-1,x+1,y+1,z+1) then
            gl.PushMatrix()
            gl.Translate(x, y, z)
            gl.Billboard()
            gl.Color(0.78, 0.0, 0.78, 1.0)
            gl.Text(UnitDefs[Spring.GetUnitDefID(data.id)].humanName .. "-" .. num .. "\nTask: " .. data.task .. "\nType: " .. data.mtype,-10,-12,10,"v")
            gl.PopMatrix()
            gl.Color(1,1,1,1)
          end
        end
      end
      if nodes then
        local x,y,z = 0
        local num = 0
        for id,data in pairs(nodes) do
            x = data.coords.x
            y = data.coords.y
            z = data.coords.z
            num = num +1
            if x and Spring.IsAABBInView(x-1,y-1,z-1,x+1,y+1,z+1) then
              gl.PushMatrix()
              gl.Translate(x,y,z)
              gl.Billboard()
              gl.Color(0.75,0.75,0.75,1)
              gl.Text(data.type .. "-" .. num .. ":\nbp: " .. data.bp.bp .. "\nwanted bp: " .. data.bp.wanted .. "\nDefense: " .. data.defense .. " [val: " .. data.value .. "]",-10,-12,10)
              gl.PopMatrix()
              gl.Color(1,1,1,1)
          end
        end
      end
    end
  end
  
  local function AssignTask(unitID)
    if mycons[unitID] then
      if mycons[unitID].mtype == "unassigned" then -- assign con job archetype -- myycons[unitID] = {id = unitID,task = "none",params = {},mtype = "unassigned"}
        --{total = {defense = 0,expansion = 0,eco = 0,grid = 0}, wanted = {defense = 0, expansion = 2, eco = 0, grid = 0}, priority = {defense = 0, expansion = 1, eco = 0, grid = 0}}
      end
    else
      if mycoms[unitID] then
        
      end
    end
  end
  
  local function CheckMexes()
    local reachable = {}
    local revreach = {}
    local myname = ""
    local result
    for name,data in pairs(movetypes) do
      reachable[name] = {}
      myname = name
      for id,data2 in pairs(mexestable) do
        Spring.Echo("Testing mex id " .. id)
        if id ~= nil then
          if revreach[id] == nil then
           revreach[id] = {bot = "?",veh = "?",amph = "?", spider = "?"}
          end
          result = IsTargetReachable(data.id,mystartpos.x,Spring.GetGroundHeight(mystartpos.x,mystartpos.y),mystartpos.y,data2.x,data2.y,data2.z,20)
          table.insert(reachable[name],id,result) -- moveDef, ox,oy,oz,tx,ty,tz,radius,dist
          if myname == "bot" then
            if Spring.GetGroundHeight(mystartpos.x,mystartpos.y) > 0 then
              revreach[id].bot = result
            else
              revreach[id].bot = "outofreach"
            end
          end
          if myname == "veh" then
            if Spring.GetGroundHeight(mystartpos.x,mystartpos.y) > 0 then
              revreach[id].veh = result
            else
              revreach[id].veh = "outofreach"
            end
          end
          if myname == "amph" then
            revreach[id].amph = result
          end
          if myname == "spider" then
            if Spring.GetGroundHeight(mystartpos.x,mystartpos.y) > 0 then
              revreach[id].spider = result
            else
              revreach[id].spider = "outofreach"
            end
          end
        end
      end
    end
    for name,data in pairs(reachable) do
      reachabilitytab[name] = 0
      for id,reach in pairs(data) do
        if reach == "reach" then
          reachabilitytab[name] = reachabilitytab[name] + 1 -- count number of reachable mexes
        end
      end
    end
    for id,data in pairs(revreach) do --bot,veh,amph,spider
      --Spring.Echo("testing " .. id .." : \nbot: " .. data.bot .. "\nveh: " .. data.veh .. "\namph: " .. data.amph .. "\nspider: " .. data.spider)
      if data.bot == "reach" and data.veh == "reach" then
        if Spring.GetGroundHeight(mexestable[tonumber(id)].x,mexestable[tonumber(id)].z) < 0 then
          mexestable[tonumber(id)].mtype = "shallows"
        else
          mexestable[tonumber(id)].mtype = "land"
        end
      else
        if data.bot == "reach" and data.veh ~= "reach" and Spring.GetGroundHeight(mexestable[tonumber(id)].x,mexestable[tonumber(id)].z) > 0 then
          mexestable[tonumber(id)].mtype = "hill"
        else
          if data.bot ~= "reach" and data.veh ~= "reach" and data.amph ~= "reach" and data.spider == "reach" then
            mexestable[tonumber(id)].mtype = "mountain"
          else
            if data.bot ~= "reach" and data.veh ~= "reach" and data.amph == "reach" then
              if Spring.GetGroundHeight(mexestable[tonumber(id)].x,mexestable[tonumber(id)].z) > 0 then
                mexestable[tonumber(id)].mtype = "island"
                if data.spider == "reach" then
                  mexestable[tonumber(id)].mtype = "coastal"
                end
              else
                mexestable[tonumber(id)].mtype = "sea"
              end
            else
              if data.bot == nil or data.veh == nil or data.amph == nil or data.spider == nil then
                mexestable[tonumber(id)].mtype = "?"
              else
                if data.amph == "reach" and Spring.GetGroundHeight(mexestable[tonumber(id)].x,mexestable[tonumber(id)].z) < 0 then
                  mexestable[tonumber(id)].mtype = "sea"
                else
                  mexestable[tonumber(id)].mtype = "isolated"
                  Spring.Echo("Isolation check:\nbot: " .. data.bot .. "\nveh: " .. data.veh .. "\namph: " .. data.amph .. "\nspider: " .. data.spider)
                end
              end
            end
          end
        end
      end
    end
  end
  
  local function initalize()
    local mexes = WG.metalSpots
      myteamid = Spring.GetMyTeamID()
      mystartpos.x,_,mystartpos.y = Spring.GetTeamStartPosition(myteamid)
      if mystartpos.x == nil then -- game hasn't started yet.
        local tries,x,y,xd,yd = 0
        local result = ""
        while tries < 500 and result ~= "reachable" do
          tries = tries + 1
          x = math.random(0,Game.mapSizeX)
          y = math.random(0,Game.mapSizeZ)
          if Spring.GetGroundHeight(x,y) > 0 then
            xd = math.random(x-250,x+250)
            yd = math.random(y-250,y+250)
            result = IsTargetReachable(movetypes.bot,x,Spring.GetGroundHeight(x,y),y,xd,Spring.GetGroundHeight(xd,yd),yd,20)
          end
        end
        mystartpos.x = x
        mystartpos.y = y
      end
      if mexes == false or #mexes == 0 then
        widgetHandler:RemoveWidget()
        Spring.Echo("Removed. Metal map not supported.")
        return
      end
      for i=1, #mexes do
        Spring.Echo("Init: Metal spot " .. i .. ":\nx = " .. mexes[i].x .. "\ny = " .. mexes[i].z .. "\nincome: " .. mexes[i].metal)
        totalmetal = totalmetal + mexes[i].metal
        mexestable[#mexestable+1] = {claim = "none",x = mexes[i].x,y = mexes[i].y, z = mexes[i].z, inc = mexes[i].metal, threat = 0, value = 0,tfloor = 0, mtype = "?"} -- just adding a claimer and threat.
        reverselookuptab[tostring(mexes[i].x) .. "," .. tostring(mexes[i].z)] = i -- we'll use this to quickly look up which mex is what index based on coordinate.
      end
      avgmetal = totalmetal/#mexes
      for _,data in pairs(mexestable) do
        data.value = data.inc/avgmetal
      end
      for i=1,#mexestable do
        if mexestable[i].value > maxvalue then
          maxvalue = mexestable[i].value
        end
        if mexestable[i].value < minvalue then
          minvalue = mexestable[i].value
        end
      end
      if minvalue == maxvalue then
        for i=1,#mexestable do
          mexestable[i].value = 1
        end
      end
      minvalue = 1
      maxvalue = 1
      Spring.Echo("[MetalMap] Total spots: " .. #mexestable .. "\nTotal metal: " .. totalmetal .. "\nAverage spot value: " .. avgmetal .. "\nMinimum value: " .. minvalue .. "\nMaximum value: " .. maxvalue)
      if avgmetal == 0 then
        widgetHandler:RemoveWidget()
        Spring.Echo("Removed. Metal map not supported.")
        return
      end
      CreateThreatGrid()
      Spring.Echo("My ID: " .. myteamid)
      Spring.Echo("Threatdistance: " .. threatdistance)
      UpdateThreatValues()
      Spring.Echo("Done initalizing !")
      initalized = true
    end
  
  function widget:Preload()
    preload = true
  end
  
  function widget:Initialize()
    local init = coroutine.create(initalize)
    local cyclecount = 0
    while (WG.metalSpots == nil or WG.startBoxConfig == nil) and cyclecount < 100000 do
      cyclecount = cyclecount + 1
    end
    if cyclecount < 100000 then
      Spring.Echo("[AVATAR] Init started.")
      coroutine.resume(init)
    else
      Spring.Echo("[AVATAR INIT] Execution took too long. Timeout = 100000 cycles.")
      widgetHandler:RemoveWidget()
    end
    cyclecount = 0
    while cyclecount < 100000 and initalized == false do
      cyclecount = cyclecount + 1
    end
    if cyclecount > 100000 then
      Spring.Echo("[AVATAR INIT] Execution took too long. Timeout = 100000 cycles.")
      widgetHandler:RemoveWidget()
    end
    cyclecount = 0
    while cyclecount < 10000 and preload == false do
      cyclecount = cyclecount + 1
    end
    if cyclecount > 100000 then
      Spring.Echo("[AVATAR INIT] Execution took too long. Timeout = 100000 cycles.")
      widgetHandler:RemoveWidget()
    end
    Spring.Echo("[AVATAR] Post-init started.")
    CheckMexes()
    initialized = true
  end
  
  function widget:GameFrame(f)
    if f > 1 and floormap == false and initialized == true then
      Spring.Echo("[AVATAR] Post-Initialization started")
      mystartpos.x,_,mystartpos.y = Spring.GetTeamStartPosition(myteamid)
      CreateFloorMap()
      CheckMexes()
      local teammexes = {}
      local myallies = Spring.GetTeamList(Spring.GetMyAllyTeamID())
      for id,_ in pairs(myallies) do
        Spring.Echo("team " .. id)
        for num,id2 in pairs(Spring.GetTeamUnitsByDefs(id-1,UnitDefNames["cormex"].id)) do
          Spring.Echo(num .. ": found mex id " .. id2)
          table.insert(teammexes,id2)
        end
      end
      for _,id2 in pairs(teammexes) do
        local x,_,y = Spring.GetUnitPosition(id2)
        mexestable[reverselookuptab[tostring(x) .. "," .. tostring(y)]].claim = "ally"
        UpdateFloorMap(reverselookuptab[tostring(x) .. "," .. tostring(y)],-1)
        originalfloormap[reverselookuptab[tostring(x) .. "," .. tostring(y)]] = originalfloormap[reverselookuptab[tostring(x) .. "," .. tostring(y)]] - 1
      end
      SetFloorMap()
      initframe = f
      chckunits = coroutine.create(CheckUnits)
    end
    if f == initframe + 200 and checkunits == false then
      coroutine.resume(chckunits)
      checkunits = true
    end
    if f == 20 and initalized == true then
      Spring.SendCommands("say a: AVATAR v" .. version .. " initalized. Mode: " .. mode)
    end
    if f%15 == 0 then -- Update Eco Demand
      --metal--
      local mlv,stor,mpull,minc,mexp,_,_,_ = Spring.GetTeamResources(myteamid,"metal")
      local elv,_,epull,einc,eexp,_,_,_ = Spring.GetTeamResources(myteamid,"energy")
      energyexpenses.overdrive = Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "OD_energyOverdrive") or 0
      local bpcost = 0
      if mpull > 0 then -- I'm building something somewhere.
        if mpull > minc then
          bpcost = minc
        else
          bpcost = mpull
        end
      end
      Spring.Echo("bp used: " .. bpcost)
      local effectiveeinc = einc -energyexpenses.overdrive - bpcost
      if minc > effectiveeinc and minc-mexp > 0 then
        local timetostall = elv / (minc-effectiveeinc)
        Spring.Echo("[ECOMONITOR] WARNING: metal income outpaces energy income!\nNeeded: " .. minc-effectiveeinc .. "\nTime until stall: " .. timetostall)
      end
      energyexpenses.buffer = math.ceil(minc * 0.2)
      if minc-mpull > 0 and facplopped then -- bp demand
        mydemand.bp = minc-mpull
        Spring.Echo("[ECOMONITOR] BP needed: " .. mydemand.bp)
      end
      Spring.Echo("[ECOMONITOR] effective E inc: " .. effectiveeinc)
      if effectiveeinc - energyexpenses.buffer < 0 then -- energy demand
        mydemand.energy = math.abs(effectiveeinc-energyexpenses.buffer)
        Spring.Echo("my energy demand: " .. mydemand.energy)
      end
    end
    if f%90 == 0 then -- Update Threats
      UpdateThreatValues()
      RecalcFloorMap()
      for id,data in pairs(mycoms) do
        mycoms[id].facplop = toboolean(Spring.GetUnitRulesParam(id, "facplop"))
      end
    end
    if f%900 == 0 then
      if globalthreat > 100 then
        if globalthreat*0.9 < 0.3 and globalthreat > 100 then
          globalthreat = 100
        elseif globalthreat > 100 then
          if globalthreat - (globalthreat*0.9) < 100 then
            globalthreat = 100
          end
          globalthreat = globalthreat - (globalthreat*0.9)
        end
      else
        if globalthreat < 0 and globalthreat <= 99 then
          if globalthreat + math.abs(globalthreat*0.9) + globalthreat +2 > 100 then
            globalthreat = 100
          end
          globalthreat = math.abs(globalthreat*0.9) + globalthreat +2
        elseif globalthreat > 0 and globalthreat < 100 then
          globalthreat = globalthreat + (globalthreat*0.9) +0.5
        end
      end
      if globalthreat < - 100 then
        globalthreat = -100
      end
    end
  end
