function gadget:GetInfo()
  return {
    name      = "AI testing functions",
    desc      = "Test small parts of AI.",
    author    = "Google Frog",
    date      = "April 20 2014",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false  --  loaded by default?
  }
end

local ceil = math.ceil
local floor = math.floor
local max = math.max
local min = math.min
local sqrt = math.sqrt

local MAP_WIDTH = Game.mapSizeX
local MAP_HEIGHT = Game.mapSizeZ

local PATH_SQUARE = 256
local PATH_MID = PATH_SQUARE/2
local PATH_X = ceil(MAP_WIDTH/PATH_SQUARE)
local PATH_Z = ceil(MAP_HEIGHT/PATH_SQUARE)

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
if (gadgetHandler:IsSyncedCode()) then
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local function DisSQ(x1,z1,x2,z2)
	return (x1 - x2)^2 + (z1 - z2)^2
end

---------------------------------------------------------------
-- Heatmapping
---------------------------------------------------------------

local HeatmapHandler = VFS.Include("LuaRules/Gadgets/CAI/HeatmapHandler.lua")

local aaHeatmap = HeatmapHandler.CreateHeatmap(256, 0)

_G.heatmap = aaHeatmap.heatmap

local ScoutHandler = VFS.Include("LuaRules/Gadgets/CAI/ScoutHandler.lua")

local scoutHandler = ScoutHandler.CreateScoutHandler(0)

function gadget:UnitCreated(unitID)
	--scoutHandler.AddUnit(unitID)
end

---------------------------------------------------------------
-- Pathfinding
---------------------------------------------------------------

local PathfinderGenerator = VFS.Include("LuaRules/Gadgets/CAI/PathfinderGenerator.lua")
local AssetTracker = VFS.Include("LuaRules/Gadgets/CAI/AssetTracker.lua")

local enemyForceHandler = AssetTracker.CreateAssetTracker(0)

-- veh, bot, spider, ship, hover, amph, air

local paths = {
	PathfinderGenerator.CreatePathfinder(UnitDefNames["correap"].id, "tank4", true),
	PathfinderGenerator.CreatePathfinder(UnitDefNames["dante"].id, "kbot4", true),
	PathfinderGenerator.CreatePathfinder(UnitDefNames["armcrabe"].id, "tkbot4", true),
	PathfinderGenerator.CreatePathfinder(UnitDefNames["armmanni"].id, "hover3"),
	PathfinderGenerator.CreatePathfinder(UnitDefNames["subarty"].id, "uboat3", true),
	PathfinderGenerator.CreatePathfinder(UnitDefNames["amphassault"].id, "akbot4", true),
	PathfinderGenerator.CreatePathfinder(UnitDefNames["armmanni"].id, "hover3"),
	PathfinderGenerator.CreatePathfinder(),
}

_G.pathMap = paths[1].pathMap
--_G.botPathMap = botPath.pathMap
--_G.amphPathMap = amphPath.pathMap
--_G.hoverPathMap = hoverPath.pathMap
--_G.shipPathMap = shipPath.pathMap

function gadget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	if allyTeam == 0 then
		local x, _,z = Spring.GetUnitPosition(unitID)
		aaHeatmap.AddUnitHeat(unitID, x, z, 780, 260 )
		enemyForceHandler.AddUnit(unitID, unitDefID)
	end
end

function gadget:GameFrame(f)
	if f%60 == 14 then
		scoutHandler.UpdateHeatmap(f)
		scoutHandler.RunJobHandler()
		--Spring.Echo(scoutHandler.GetScoutedProportion())
	end
	if f%150 == 3 then
		aaHeatmap.UpdateUnitPositions(true)
	end
end

function gadget:AllowCommand_GetWantedCommand()	
	return {[CMD.MOVE] = true, [CMD.FIGHT] = true, [CMD.WAIT] = true}
end

function gadget:AllowCommand_GetWantedUnitDefID()	
	return true
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	
	if cmdID == CMD.MOVE then
		--turretHeat.AddHeatCircle(cmdParams[1], cmdParams[3], 500, 50)
		return true
	end
	
	if cmdID == CMD.WAIT then
		local economyList = enemyForceHandler.GetUnitList("economy")
		local coord = economyList.GetClusterCoordinates()
		Spring.Echo(#coord)
		for i = 1, #coord do
			local c = coord[i]
			Spring.MarkerAddPoint(c[1],0,c[3], "Coord, " .. c[4] .. ", Count " .. c[5])
		end
		local centriod = economyList.GetClusterCostCentroid()
		Spring.Echo(#centriod)
		for i = 1, #centriod do
			local c = centriod[i]
			Spring.MarkerAddPoint(c[1],0,c[3], "Centriod, Cost " .. c[4] .. ", Count " .. c[5])
		end
		--turretHeat.AddHeatCircle(cmdParams[1], cmdParams[3], 500, 50)
		return false
	end
	
	if cmdID == CMD.FIGHT then
		--vehPath.SetDefenseHeatmaps({aaHeatmap})
		--local waypoints, waypointCount = vehPath.GetPath(1150, 650, cmdParams[1], cmdParams[3], false, 0.02)
		--if waypoints then
		--	for i = 1, waypointCount do
		--		Spring.MarkerAddPoint(waypoints[i].x, 0, waypoints[i].z,i)
		--	end
		--end
		return true
	end
	
	return true
end


-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
else -- UNSYNCED
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local function DrawLine(x0, y0, z0, c0, x1, y1, z1, c1)
	gl.Color(c0)
	gl.Vertex(x0, y0, z0)
	gl.Color(c1)
	gl.Vertex(x1, y1, z1)
end


local function DrawPathLink(start, finish, relation, color)
	if start.linkRelationMap[relation[1]] and start.linkRelationMap[relation[1]][relation[2]] then
		local sx, sz = start.x, start.z
		local fx, fz = finish.x, finish.z
		local sColor = ((SYNCED.heatmap[sx] and SYNCED.heatmap[sx][sz] and SYNCED.heatmap[sx][sz].value) or 0)*0.01
		local fColor = ((SYNCED.heatmap[fx] and SYNCED.heatmap[fx][fz] and SYNCED.heatmap[fx][fz].value) or 0)*0.01
		DrawLine(
			start.px, start.py, start.pz, {sColor, sColor, sColor, 1}, 
			finish.px, finish.py, finish.pz, {fColor, fColor, fColor, 1}
		)
	end
end	

local function DrawGraph(array, color)
	for i = 1, PATH_X do
		for j = 1, PATH_Z do
			if i < PATH_X then
				DrawPathLink(array[i][j], array[i+1][j], {1,0})
			end
			if j < PATH_Z then
				DrawPathLink(array[i][j], array[i][j+1], {0,1})
			end
		end
	end
end

local function DrawPathMaps()
	--gl.LineWidth(10)
	--if SYNCED and SYNCED.shipPathMap then	
	--	gl.BeginEnd(GL.LINES, DrawGraph, SYNCED.shipPathMap, {0,1,1,0.5})
	--end
	--gl.LineWidth(7)
	--if SYNCED and SYNCED.hoverPathMap then	
	--	gl.BeginEnd(GL.LINES, DrawGraph, SYNCED.hoverPathMap, {1,0,1,0.5})
	--end
	--gl.LineWidth(5)
	--if SYNCED and SYNCED.amphPathMap then	
	--	gl.BeginEnd(GL.LINES, DrawGraph, SYNCED.amphPathMap, {0.8,0.8,0,0.5})
	--end
	--gl.LineWidth(3)
	--if SYNCED and SYNCED.botPathMap then	
	--	gl.BeginEnd(GL.LINES, DrawGraph, SYNCED.botPathMap, {0,1,0.1,1})
	--end
	gl.LineWidth(2)
	if SYNCED and SYNCED.pathMap and SYNCED.heatmap then	
		gl.BeginEnd(GL.LINES, DrawGraph, SYNCED.pathMap)
	end
end

function gadget:DrawWorldPreUnit()
	--DrawPathMaps()
end

function gadget:Initialize()
	gadgetHandler:AddSyncAction('SetHeatmapDrawData',SetHeatmapDrawData)
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
end -- END UNSYNCED
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------