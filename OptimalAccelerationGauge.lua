--By Quaternions
--localize
local abs=math.abs
local ceil=math.ceil
local min,max=math.min,math.max
local sqrt=math.sqrt

local insert,remove=table.insert,table.remove

local IN_FORWARD=8
local IN_BACK=16
local IN_MOVELEFT=512
local IN_MOVERIGHT=1024
local MOUSE_LEFT=107

local tick=SysTime
local Colour=Color--lolol good spell mate
local newGui=vgui.Create
local MousePos=gui.MousePos
local IsBtn=input.IsMouseDown

local P--=LocalPlayer()

--Settings
local Calibrating=true

local Width=192
local Height=108
local MinWidth=112
local MinHeight=63
local ResizeBorder=7
local GaugeThickness=20

local FadeDuration=0.2
local AveragingDuration=0.1
local MinAveragingFrames=8

local BackgroundColour=Colour(0,0,0,96)
local GaugeColour=Colour(45,73,124,192)
local YawspeedTargetColour=Colour(39,232,51,32)

--Functions
local function AbsolutePos(thing)
	local x,y=thing:GetPos()
	local Parent=thing:GetParent()
	while Parent do
		local px,py=Parent:GetPos()
		x,y=x+px,y+py
		Parent=Parent:GetParent()
	end
	return x,y
end

local function InBounds(thing,mx,my)
	local x,y=AbsolutePos(thing)
	local w,h=thing:GetSize()
	return mx>=x and mx<=x+w and my>=y and my<=y+h
end

local GuiOpen=false
local Panel,YawspeedTarget,Gauge,Credit,Close,GaugeDescription,YawspeedTargetLabel

--Fade state data
local FadeBegin=tick()+3
local WasHovering=true

local function Fade(t)
	if GuiOpen then
		local a=255*t
		Credit:SetAlpha(a)
		Close:SetAlpha(a)
		GaugeDescription:SetAlpha(a)
		YawspeedTargetLabel:SetAlpha(a)
	end
end

--Drag state data
local GripX,GripY
local ResizeX,ResizeY
local ResizeGripX,ResizeGripY

--Mouse state data
local LastHovering=false
local LastButton1=false

--Previous frame data
local LastTime=tick()
local LastAngle=0
local LastVelocity=0
local CurrentAveragingFrames=0

--Ongoing collected data
local Data={}
local DataOverwrite=0
local ConsecutiveValidFrames=0
local _00,_01,_10,_11,_0,_1=0,0,0,0,0,0--Used to calculate linear least squares fit of equation constants

local function Resized()
	if GuiOpen then
		Panel:SetSize(Width,Height)
		YawspeedTarget:SetSize(Width,GaugeThickness)
		YawspeedTarget:SetPos(0,(Height-GaugeThickness)/2)
		Gauge:SetSize(Width,GaugeThickness)
		local v=P:GetAbsVelocity():Length2D()
		if v>0 then
			local w=0
			for i=1,CurrentAveragingFrames do
				local d=Data[i]
				w=w+d.w
			end
			w=w/CurrentAveragingFrames
			local p=(_0*_11-_1*_01)/(_1*_00-_0*_10)
			if p==p then
				Gauge:SetPos(0,(Height-GaugeThickness)*max(0,1-abs(w*v/p)))
			end
		else
			Gauge:SetPos(0,Height-GaugeThickness)
		end
		Credit:SetPos(Width/2-Credit:GetWide()/2,0)
		Close:SetPos(Width-Close:GetWide(),0)
		GaugeDescription:Center()
		YawspeedTargetLabel:Center()
	end
end

--Update GUIs
local function UpdateGUIs()
	if GuiOpen then
		local CurrentTime=tick()
		local FramePeriod=CurrentTime-LastTime
		local DesiredAveragingFrames=max(MinAveragingFrames,ceil(AveragingDuration/FramePeriod))
		local Velocity=P:GetAbsVelocity()
		local CurrentAngle=P:EyeAngles().y
		local CurrentVelocity=Velocity:Length2D()
		local CurrentYawspeed=((CurrentAngle-LastAngle+180)%360-180)/FramePeriod
		local CurrentAcceleration=(CurrentVelocity-LastVelocity)/FramePeriod

		if DesiredAveragingFrames>CurrentAveragingFrames then
			CurrentAveragingFrames=CurrentAveragingFrames+1
			DataOverwrite=DataOverwrite+1
			insert(Data,DataOverwrite,{v=LastVelocity,w=abs(CurrentYawspeed),a=CurrentAcceleration})
		elseif DesiredAveragingFrames<CurrentAveragingFrames then
			remove(Data,DataOverwrite%CurrentAveragingFrames+1)
			CurrentAveragingFrames=CurrentAveragingFrames-1
			if DataOverwrite>=CurrentAveragingFrames then
				DataOverwrite=1
			else
				DataOverwrite=DataOverwrite+1
			end
			Data[DataOverwrite]={v=LastVelocity,w=abs(CurrentYawspeed),a=CurrentAcceleration}
		else
			DataOverwrite=DataOverwrite%CurrentAveragingFrames+1
			Data[DataOverwrite]={v=LastVelocity,w=abs(CurrentYawspeed),a=CurrentAcceleration}
		end

		if Calibrating then
			local EyeAngle=Angle(0,CurrentAngle,0)
			local ControlDirection=EyeAngle:Forward()*((P:KeyDown(IN_FORWARD)and 1 or 0)-(P:KeyDown(IN_BACK)and 1 or 0))+EyeAngle:Right()*((P:KeyDown(IN_MOVERIGHT)and 1 or 0)-(P:KeyDown(IN_MOVELEFT)and 1 or 0))
			local ValidFrame=false
			if CurrentYawspeed~=0 and CurrentAcceleration>0 and not P:OnGround() and CurrentVelocity>0 then
				local cx,cy=ControlDirection.x,ControlDirection.y
				local c2=cx*cx+cy*cy
				if c2>0 then
					local vc=Velocity.x*cx+Velocity.y*cy
					if vc*vc/(c2*CurrentVelocity*CurrentVelocity)<0.0025 then --If the control direction is (approximately) perpendicular to the velocity
						ValidFrame=true
					end
				end
			end
			if ValidFrame then
				ConsecutiveValidFrames=ConsecutiveValidFrames+1
				if ConsecutiveValidFrames>=CurrentAveragingFrames then
					local v,w,a=0,0,0
					for i=1,CurrentAveragingFrames do
						local d=Data[i]
						v,w,a=v+d.v,w+d.w,a+d.a
					end
					v,w,a=v/CurrentAveragingFrames,w/CurrentAveragingFrames,a/CurrentAveragingFrames
					local w2=w*w
					_0=_0-a*w
					_00=_00+w2
					_01=_01-v*w*w2
					_1=_1+a*v*w2
					_10=_10-v*w*w2
					_11=_11+v*v*w2*w2
				end
			elseif ConsecutiveValidFrames>0 then
				ConsecutiveValidFrames=0
			end
		end

		if CurrentVelocity>0 then
			local w=0
			for i=1,CurrentAveragingFrames do
				local d=Data[i]
				w=w+d.w
			end
			w=w/CurrentAveragingFrames
			--local c=(_1*_00-_0*_10)/(_01*_10-_00*_11)
			local p=(_0*_11-_1*_01)/(_1*_00-_0*_10)
			if p==p then
				Gauge:SetPos(0,(Height-GaugeThickness)*max(0,1-abs(w*CurrentVelocity/p)))
			end
		else
			Gauge:SetPos(0,Height-GaugeThickness)
		end

		local mx,my=MousePos()
		local Hovering=GripX or GripY or ResizeX and ResizeGripX or ResizeY and ResizeGripY or InBounds(Panel,mx,my)
		local CurrentButton1=IsBtn(MOUSE_LEFT)
		if GripX and GripY then
			local px,py=AbsolutePos(Panel:GetParent())
			local sx,sy=Panel:GetParent():GetSize()
			Panel:SetPos(max(0,min(sx-Width,mx-px-GripX)),max(0,min(sy-Height,my-py-GripY)))
			if not CurrentButton1 then
				GripX,GripY=nil,nil
			end
		elseif GripX then
			local x,y=Panel:GetPos()
			local px,py=AbsolutePos(Panel:GetParent())
			local sx,sy=Panel:GetParent():GetSize()
			Panel:SetPos(max(0,min(sx-Width,mx-px-GripX)),y)
			if not CurrentButton1 then
				GripX=nil
			end
		elseif GripY then
			local x,y=Panel:GetPos()
			local px,py=AbsolutePos(Panel:GetParent())
			local sx,sy=Panel:GetParent():GetSize()
			Panel:SetPos(x,max(0,min(sy-Height,my-py-GripY)))
			if not CurrentButton1 then
				GripY=nil
			end
		end
		if ResizeX and ResizeGripX or ResizeY and ResizeGripY then
			if ResizeX and ResizeGripX then
				if ResizeGripX>0 then
					Width=max(MinWidth,ResizeX-mx+ResizeGripX)
				else
					Width=max(MinWidth,mx-ResizeX-ResizeGripX)
				end
			end
			if ResizeY and ResizeGripY then
				if ResizeGripY>=0 then
					Height=max(MinHeight,ResizeY-my+ResizeGripY)
				else
					Height=max(MinHeight,my-ResizeY-ResizeGripY)
				end
			end
			if not CurrentButton1 then
				ResizeX,ResizeY=nil,nil
				ResizeGripX,ResizeGripY=nil,nil
			end
			Resized()
		end
		if Hovering then
			if InBounds(Close,mx,my) then
				Panel:SetCursor'arrow'
			else
				local px,py=AbsolutePos(Panel)
				local sx,sy=Panel:GetSize()
				local SignX,SignY=mx-px<ResizeBorder and 1 or mx-px>sx-ResizeBorder and -1 or 0,my-py<ResizeBorder and 1 or my-py>sy-ResizeBorder and -1 or 0
				if SignX==0 and SignY==0 then
					Panel:SetCursor'arrow'
				elseif SignX==0 then
					Panel:SetCursor'sizens'
				elseif SignY==0 then
					Panel:SetCursor'sizewe'
				elseif SignX*SignY==1 then
					Panel:SetCursor'sizenwse'
				elseif SignX*SignY==-1 then
					Panel:SetCursor'sizenesw'
				end
			end
			if CurrentButton1 and not LastButton1 then
				if InBounds(Close,mx,my) then
					--gobwey
					GuiOpen=false
					Panel:Remove()
					hook.Remove("PreDrawHUD","UpdateAccelerationGauge")
				else
					local px,py=AbsolutePos(Panel)
					local sx,sy=Panel:GetSize()
					local NoResize=true
					if mx-px<ResizeBorder then
						NoResize=false
						GripX=mx-px
						ResizeX=px+sx
						ResizeGripX=max(1,mx-px)
					elseif mx-px>sx-ResizeBorder then
						NoResize=false
						ResizeX=px
						ResizeGripX=min(-1,mx-(px+sx))
					end
					if my-py<ResizeBorder then
						NoResize=false
						GripY=my-py
						ResizeY=py+sy
						ResizeGripY=max(1,my-py)
					elseif my-py>sy-ResizeBorder then
						NoResize=false
						ResizeY=py
						ResizeGripY=min(-1,my-(py+sy))
					end
					if NoResize then
						GripX,GripY=mx-px,my-py
					end
				end
			end
		elseif not LastHovering then
			Panel:SetCursor'arrow'
		end

		if FadeBegin then
			local t=(CurrentTime-FadeBegin)/FadeDuration
			if t>0 then
				if Hovering then
					if WasHovering then
						WasHovering=false
						if t<1 then
							FadeBegin=2*CurrentTime-FadeBegin-FadeDuration
							Fade((1-t)*(1-t))
						else
							FadeBegin=CurrentTime
							Fade(1)
						end
					else
						if t<1 then
							Fade(t*t)
						else
							FadeBegin=nil
							WasHovering=true
							Fade(1)
						end
					end
				else
					if WasHovering then
						if t<1 then
							Fade((1-t)*(1-t))
						else
							FadeBegin=nil
							WasHovering=false
							Fade(0)
						end
					else
						WasHovering=true
						if t<1 then
							FadeBegin=2*CurrentTime-FadeBegin-FadeDuration
							Fade(t*t)
						else
							FadeBegin=CurrentTime
							Fade(0)
						end
					end
				end
			end
		elseif Hovering~=WasHovering then
			FadeBegin=CurrentTime
		end

		LastTime,LastAngle,LastVelocity=CurrentTime,CurrentAngle,CurrentVelocity
		LastButton1,LastHovering=CurrentButton1,Hovering
	end
end

--Create GUIs
local function CreateGUIs()
	P=LocalPlayer()
	LastAngle=P:EyeAngles().y or 0
	LastVelocity=P:GetAbsVelocity():Length2D() or 0

	Panel=newGui("DPanel")
	Panel:SetSize(Width,Height)
	Panel:SetPos(ScrW()-Width,ScrH()/3-Height/2)
	Panel:SetBackgroundColor(BackgroundColour)

	YawspeedTarget=newGui("DPanel",Panel)
	YawspeedTarget:SetSize(Width,GaugeThickness)
	YawspeedTarget:SetPos(0,(Height-GaugeThickness)/2)
	YawspeedTarget:SetBackgroundColor(YawspeedTargetColour)

	Gauge=newGui("DPanel",Panel)
	Gauge:SetSize(Width,GaugeThickness)
	Gauge:SetPos(0,Height-GaugeThickness)
	Gauge:SetBackgroundColor(GaugeColour)

	Credit=newGui("DLabel",Panel)
	Credit:SetText'Made by Quaternions'
	Credit:SizeToContents()
	Credit:SetPos(Width/2-Credit:GetWide()/2,0)
	Credit:SetAlpha(255)

	Close=newGui("DLabel",Panel)
	Close:SetText'x'
	--Close:SetTextColor(Color(255,0,0,255))
	Close:SizeToContents()
	Close:SetPos(Width-Close:GetWide(),0)
	Close:SetAlpha(255)

	GaugeDescription=newGui("DLabel",Gauge)
	GaugeDescription:SetText'Your Camera Turning Speed'
	GaugeDescription:SizeToContents()
	GaugeDescription:Center()
	GaugeDescription:SetAlpha(255)

	YawspeedTargetLabel=newGui("DLabel",YawspeedTarget)
	YawspeedTargetLabel:SetText'Best Camera Turning Speed'
	YawspeedTargetLabel:SizeToContents()
	YawspeedTargetLabel:Center()
	YawspeedTargetLabel:SetAlpha(255)

	GuiOpen=true
	hook.Add("PreDrawHUD","UpdateAccelerationGauge",UpdateGUIs)
end

concommand.Add("showgauge",function()
	if GuiOpen then
		GuiOpen=false
		Panel:Remove()
		hook.Remove("PreDrawHUD","UpdateAccelerationGauge")
	end
	CreateGUIs()
end)

concommand.Add("resetgauge",function()
	_00,_01,_10,_11,_0,_1=0,0,0,0,0,0
end)
