function widget:GetInfo()
    return {
      name      = "Testing_ExposeGridNumbers",
      desc      = "expose the grid numbers",
      author    = "",
      date      = "",
      license   = "",
      layer     = 5,
      enabled   = true,
    }
  end
  
  local gridunits = {}

  function widget:UnitFinished(unitID, unitDefID, unitTeam)
      if UnitDefs[unitDefID].customParams.pylonrange then
          x,y,z = Spring.GetUnitPosition(unitID)
          gridunits[unitID] = {id = unitID, defid = unitDefID,x=x,y=y,z=z}
      end
  end
  
function widget:DrawWorld()
    for id,data in pairs(gridunits) do
        if Spring.IsAABBInView(data.x-1,data.y-1,data.z-1,data.x+1,data.y+1,data.z+1) then
          gl.PushMatrix()
          gl.Translate(data.x, data.y, data.z)
          gl.Billboard()
          gl.Color(0.7, 0.9, 0.7, 1.0)
          local ya = 0
          for name2,data2 in pairs(Spring.GetUnitRulesParams(data.id,"gridNumber")) do
                if tostring(data2) == "<table>" then
                    for name3,data3 in pairs(data2) do
                        data2string = tostring("\t" .. name3 .. ": " .. data3)
                    end
                else
                    data2string = tostring(data2)
                end
                gl.Text(name2 .. ": " .. data2string,-10.0,ya,12,"v")
                ya = ya - 12
            end
          gl.PopMatrix()
      end
    end
end
