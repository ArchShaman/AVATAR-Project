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
          gl.Text("Grid Num: " .. Spring.GetUnitRulesParams(data.id,"gridNumber"),-10.0,0,12,"v")
          gl.PopMatrix()
      end
    end
end
