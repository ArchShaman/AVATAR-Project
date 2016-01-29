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
        threatdistance = math.ceil((Game.mapX+Game.mapY)/20)*500
      end
    end
  end
  
  local mybasebuilder = 0
  
  local reachabilitytab = {}
  local maxvalue = 0
  local minvalue = 99999
  local movetypes = {bot = {id = UnitDefNames["armrectr"].moveDef.id, tar = 90},
                     veh = {id = UnitDefNames["corned"].moveDef.id, tar = 180},
                     amph = {id = UnitDefNames["amphcon"].moveDef.id, tar = 120},
                     spider = {id = UnitDefNames["arm_spider"].moveDef.id, tar = 220}}
  local antiscythe = 0 -- higher = engage anti-scyhte protocal
  local seenscythes = {} -- so we don't repeatedly increase anti-scythe
  
  local nodes = {}
  local facplopped = false
  local mystartpos = {x = 0, y = 0}
  local mode = "debug"
  --variables--
  local reverselookuptab = {}
  local build = {mex   = (UnitDefNames["cormex"].id)*-1,
                 solar = (UnitDefNames["armsolar"].id)*-1,
                 wind  = (UnitDefNames["armwin"].id)*-1,
                 llt   = (UnitDefNames["corllt"].id)*-1,
                 def   = (UnitDefNames["corrl"].id)*-1,
                 radar = (UnitDefNames["corrad"].id)*-1,
                 nano  = (UnitDefNames["armnanotc"].id)*-1,
                 urch  = (UnitDefNames["turrettorp"].id)*-1,
                 star  = (UnitDefNames["armdeva"].id)*-1
                 } -- Holds all the ai's build stuff. It won't handle the heavier defenses but it will attempt to build stuff.
  
  builddefs = {mex   = UnitDefNames["cormex"].id,
                 solar = UnitDefNames["armsolar"].id,
                 wind  = UnitDefNames["armwin"].id,
                 llt   = UnitDefNames["corllt"].id,
                 def   = UnitDefNames["corrl"].id,
                 radar = UnitDefNames["corrad"].id,
                 nano  = UnitDefNames["armnanotc"].id,
                 urch  = UnitDefNames["turrettorp"].id,
                 star  = UnitDefNames["armdeva"].id
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
  
  local globalthreat = 0 -- how scary is the world?
  
  local nodes = {} -- bp nodes
  local mydemand = {bp = 0, expander = 0, metal = 0, energy = 0} -- total demand
  local priority = {bp = 0, expander = 0.5, metal = 0.5, energy = 0}
  local myteamid = 0
  local mycons = {}
  local mexestable = {}
  local avgmetal = 0
  local totalmetal = 0
  local threatgrid = {}
  local reversethreat = {}
  local initalized = false
  
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
    local footx,footy = 0
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
    btype = btype*-1 -- turn negative into positive
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
    local distances = {}
    for num,data in pairs(mexestable) do
      if data.claimed == "none" then
        if x > data.x then
          distances[num] = x - data.x
        else
          distances[num] = data.x - x
        end
        if y > data.z then
          distances[num] = distances[num] + (y - data.z)
        else
          distances[num] = distances[num] + (data.z - y)
        end
        distances[num] = distances[num] * data.value
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
    end
  end
  
  function widget:UnitFinished(unitID, unitDefID, unitTeam) -- update "building" -> "self"
    if unitDefID == UnitDefNames["cormex"].id then
      local x,_,y = Spring.GetUnitPosition(unitID)
      local num = reverselookuptab[tostring(x) .. "," .. tostring(y)]
      if Spring.GetUnitAllyTeam(unitID) == Spring.GetMyAllyTeamID() and num ~= nil and mexestable[num].claim == "none" then
        mexestable[num].claim = "ally"
        UpdateFloorMap(num,-1)
      else
        if num ~= nil and mexestable[num].claim == "none" then
          mexestable[num].claim = "enemy"
          UpdateFloorMap(num,15)
        end
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
      else
        mexestable[num].claim = "none"
        UpdateFloorMap(num,-15)
      end
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
            UpdateThreatGrid(num,damage/(150/mexestable[num].value))
            globalthreat = globalthreat + (damage/2000)
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
    if initalized == true then
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
            gl.Color(0.37,0.58,0.7,1)
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
      if #nodes > 0 then
        for nodeid,data in pairs(nodes) do
          if Spring.IsAABBInView(data.x-1,data.y-1,data.z-1,data.x+1,data.y+1,data.z+1) then
            -- Nodes will eventually go here.
          end
        end
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
        mexestable[tonumber(id)].mtype = "land"
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
      for _,id in pairs(teammexes) do
        local x,_,y = Spring.GetUnitPosition(id)
        mexestable[reverselookuptab[tostring(x) .. "," .. tostring(y)]].claim = "ally"
        UpdateFloorMap(reverselookuptab[tostring(x) .. "," .. tostring(y)],-1)
      end
      SetFloorMap()
    end
    if f == 20 and initalized == true then
      Spring.SendCommands("say a: AVATAR v" .. version .. " initalized. Mode: " .. mode)
    end
    if f%15 == 0 then -- Update Eco Demand
      --metal--
      local mlv,stor,mpull,minc,mexp,_,_,_ = Spring.GetTeamResources(myteamid,"metal")
      local elv,_,epull,epull,einc,eexp,_,_,_ = Spring.GetTeamResources(myteamid,"energy")
      if minc-mpull > 0 and facplopped then -- bp demand
          mydemand.bp = minc-mpull
      end
      if einc < math.ceil(minc * 1.05)+2+(epull-minc) + eexp then -- energy demand
        mydemand.energy = epull + eexp + math.ceil(minc * 1.05)+2
      end
    end
    if f%10 == 0 then -- Update Con orders
      
    end
    if f%600 == 0 then -- Update Threats
      if globalthreat > 0 then
        globalthreat = globalthreat * 0.87 -- lose 13% of the threat value every 2 seconds.
      end
      UpdateThreatValues()
    end
  end
