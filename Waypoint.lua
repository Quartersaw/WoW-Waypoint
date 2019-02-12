-- Waypoint.lua
-- by Michael Thomas
-- June 22, 2014
-- Shoutouts: Esamynn for the Astrolabe library
--            Schnoggo for the excellent SimpleCoords mod.
-- Double click a zone map to set a waypoint.  Double click again to manually clear it.
-- An arrow on the minimap will point to your waypoint and automatically clear when you arrive.

-- Bring in AstroLabe
local DongleFrames = DongleStub("DongleFrames-1.0")
local Astrolabe = DongleStub("Astrolabe-1.0")

local minimapX
local worldmapX

function WaypointOnLoad()
	-- create the minimap waypoint marker
	minimapX = CreateFrame( "Button", nil, Minimap )
	minimapX:SetHeight( 16 )
	minimapX:SetWidth( 16 )
	local texture = minimapX:CreateTexture()
	texture:SetTexture( "Interface\\AddOns\\Waypoint\\images\\WaypointX" )
	texture:SetAllPoints()
	minimapX.dot = texture
	minimapX:SetScript( "OnUpdate", WaypointMinimapXUpdate )
		
	-- create the world map waypoint marker
	worldmapX = CreateFrame( "Button", nil, WorldMapDetailFrame )
	worldmapX:SetWidth( 32 )
	worldmapX:SetHeight( 32 )
	-- looks like Widget specified in the astrolabe docs must contain an "icon"
	worldmapX.icon = worldmapX:CreateTexture( "ARTWORK" ) 
	worldmapX.icon:SetTexture( "Interface\\AddOns\\Waypoint\\images\\WaypointX" )
	worldmapX.icon:SetAllPoints()
	worldmapX:RegisterEvent( "WORLD_MAP_UPDATE" )
	worldmapX:SetScript( "OnEvent", WaypointWorldmapXOnEvent )
	worldmapX.x = -1000
	worldmapX.y = -1000
	worldmapX.inUse = false

	local model = CreateFrame( "Model", nil, icon )
	model:SetHeight( 140.8 )
	model:SetWidth( 140.8 )
	model:SetPoint( "CENTER", Minimap, "CENTER", 0, 0 )
	model:SetModel( "Interface\\Minimap\\Rotating-MinimapArrow.mdx" )
    model:SetModelScale( .600000023841879 )
	model.parent = minimapX
	minimapX.arrow = model
	model:SetScript( "OnUpdate", WaypointMinimapArrowUpdate )
	model:Hide()
	minimapX.inUse = false;
end

local haveArrived = false

function WaypointMinimapXUpdate( self, elapsed )
	local edge = Astrolabe:IsIconOnEdge( self )
	local dot = self.dot:IsShown()
	local arrow = self.arrow:IsShown()

	if ( edge and not arrow ) then
		self.arrow:Show()
		self.dot:Hide()
	elseif not edge and not dot then
		self.dot:Show()
		self.arrow:Hide()
	end

	local dist,x,y = Astrolabe:GetDistanceToIcon( self )
	if ( dist and dist < 75 ) then
		if ( not haveArrived ) then	
			-- let them know that they have arrived
			PlaySoundFile("Sound\\interface\\PickUp\\PutDownGems.wav");
			haveArrived = true;
			worldmapX.inUse = false
			self:Hide()
		end
	else
		haveArrived = false;
	end
end

local dest_x = -1000
local dest_y = -1000
local dest_zone = -1000

function WaypointWorldmapXOnEvent( self, event, ... )
	if ( event == "WORLD_MAP_UPDATE" ) then
		if ( self.inUse and dest_zone == GetCurrentMapAreaID() ) then -- If the worldmap X is active
			self:Show()
		else
			self:Hide()
		end
	end
end

local HALF_PI = math.pi / 2

function WaypointMinimapArrowUpdate( self, elapsed )
	local angle = Astrolabe:GetDirectionToIcon( minimapX )
	if ( angle ~= nil ) then
		local x = .03875* math.cos( angle + HALF_PI ) + 0.04875 
		local y = .03875* math.sin( angle + HALF_PI ) + 0.04875 
		self:SetPosition( x, y, 0 )
		self:SetFacing( angle )
	else
		self:Hide()
	end
end

local HEARTBEAT_INTERVAL = 0.5 -- how many seconds per heartbeat of our internal timer
SecondsSinceUpdate = 0         -- globalish tick counter

function WaypointOnUpdate( self, elapsed )
	SecondsSinceUpdate = SecondsSinceUpdate + elapsed
	if ( SecondsSinceUpdate > HEARTBEAT_INTERVAL ) then
		Astrolabe:UpdateMinimapIconPositions()
		SecondsSinceUpdate = 0
	end
end

WorldMapButton:HookScript("OnDoubleClick",
	function( self, button )
		if button == "LeftButton" then
			if worldmapX.inUse then
				PlaySound( "igMiniMapClose", "master" )
				Astrolabe:RemoveIconFromMinimap( minimapX );
				minimapX.inUse = false;
				worldmapX:Hide()
				worldmapX.inUse = false
			else
				-- Check if the destination zone is on the same continent as the player
				dest_zone = GetCurrentMapAreaID()
				local dest_continent = select( 1, Astrolabe:GetMapInfo( dest_zone, 0 ) )
				local playerZone = Astrolabe:GetUnitPosition( "player", false )
				local playerContinent = Astrolabe:GetMapInfo( playerZone, 0 )

				if ( dest_continent == playerContinent ) then
					PlaySound( "igMiniMapOpen", "master" )
					local x, y = GetCursorPosition()
					x = x / self:GetEffectiveScale()
					y = y / self:GetEffectiveScale()
					local mapXoffset, mapYoffset, mapWidth, mapHeight = WorldMapButton:GetRect()
					dest_x = (x - mapXoffset) / mapWidth  		-- Normalize by shifting to (0,0) and dividing to get a range from 0 to 1
					dest_y = 1 - (y - mapYoffset) / mapHeight  	-- Normalize and reset the origin to the upper left
		
					worldmapX.x = dest_x
					worldmapX.y = dest_y
					Astrolabe:PlaceIconOnWorldMap( WorldMapDetailFrame, worldmapX, dest_zone, 0, dest_x, dest_y )
					worldmapX.inUse = true
					Astrolabe:PlaceIconOnMinimap( minimapX, dest_zone, 0, dest_x, dest_y )
					minimapX.inUse = true
					Astrolabe:UpdateMinimapIconPositions()
					haveArrived = false					
				else
					PlaySound( "igQuestFailed", "master" )
					DEFAULT_CHAT_FRAME:AddMessage( "Unable to set waypoint on another continent.", 0.2, 1.0, 1.0, 1 )
				end
			end
		end
	end)