--By Quaternions
local next=next
local setmetatable=setmetatable

local DefaultBackgroundColor=Color(255,255,255,255)

local tick=SysTime

local NoTexture=draw.NoTexture
local DrawColor=surface.SetDrawColor
local DrawRect=surface.DrawRect

local MousePos=gui.MousePos
local IsBtn=input.IsMouseDown

--Updating
local function InternalMoved(Box)
	local BoxParent=Box.Parent
	if BoxParent then
		Box.PosX=BoxParent.PosX+BoxParent.SizeX*Box.PosScaleX+Box.PosOffsetX
		Box.PosY=BoxParent.PosY+BoxParent.SizeY*Box.PosScaleY+Box.PosOffsetY
	end
	local Children=Box.Children
	for i=1,#Children do
		local Child=Children[i].ActualBox
		if Child then
			Child.InternalMoved()
		end
	end
	local MovedFunc=Box.Moved
	if MovedFunc then
		MovedFunc(Box)
	end
end
local function InternalResize(Box)
	local BoxParent=Box.Parent
	if BoxParent then
		Box.SizeX=BoxParent.SizeX*Box.SizeScaleX+Box.SizeOffsetX
		Box.SizeY=BoxParent.SizeY*Box.SizeScaleY+Box.SizeOffsetY
	end
	local Children=Box.Children
	for i=1,#Children do
		local Child=Children[i].ActualBox
		if Child then
			InternalMoved(Child)
			InternalResize(Child)
		end
	end
	local ResizeFunc=Box.Resize
	if ResizeFunc then
		ResizeFunc(Box)
	end
end

local InternalCallbacks={
	[{PosScaleX=true,PosScaleY=true,PosOffsetX=true,PosOffsetY=true}]=InternalMoved,
	[{SizeScaleX=true,SizeScaleY=true,SizeOffsetX=true,SizeOffsetY=true}]=InternalResize,
}
local InternalRequests={--Calculate 'em fresh, 'cause why not
	PosX=function(Box)
		local BoxParent=Box.Parent
		if BoxParent then
			return BoxParent.PosX+BoxParent.SizeX*Box.PosScaleX+Box.PosOffsetX
		end
	end,
	PosY=function(Box)
		local BoxParent=Box.Parent
		if BoxParent then
			return BoxParent.PosY+BoxParent.SizeY*Box.PosScaleY+Box.PosOffsetY
		end
	end,
}

--Drawing
local function InternalDraw(Box)
	if Box.Visible then
		local PreDrawFunc=Box.PreDraw
		if PreDrawFunc then
			PreDrawFunc(Box)
		end
		if Box.DrawBackground then
			NoTexture()
			DrawColor(Box.BackgroundColor)
			DrawRect(Box.PosX,Box.PosY,Box.SizeX,Box.SizeY)
		end
		local DrawFunc=Box.Draw
		if DrawFunc then
			DrawFunc(Box)
		end
		local Children=Box.Children
		for i=1,#Children do
			local Child=Children[i].ActualBox
			if Child then
				InternalDraw(Child)
			end
		end
		local PostDrawFunc=Box.PostDraw
		if PostDrawFunc then
			PostDrawFunc(Box)
		end
	end
end

--Thinking
local function InternalThink(Box)
	local mx,my=MousePos()
	Box.Hovering=Box.MouseFocus or mx>=Box.PosX and mx<=Box.PosX+Box.SizeX and my>=Box.PosY and my<=Box.PosY+Box.SizeY

	--

	--Fading! :D
	local FadeFunc=Box.Fade
	if FadeFunc then
		local CurrentTime=tick()
		if Box.FadeBegin then
			local t=(CurrentTime-Box.FadeBegin)/Box.FadeDuration
			if t>0 then
				if Box.Hovering then
					if Box.WasHovering then
						Box.WasHovering=false
						if t<1 then
							Box.FadeBegin=2*CurrentTime-Box.FadeBegin-Box.FadeDuration
							FadeFunc((1-t)*(1-t))
						else
							Box.FadeBegin=CurrentTime
							FadeFunc(1)
						end
					else
						if t<1 then
							FadeFunc(t*t)
						else
							Box.FadeBegin=nil
							Box.WasHovering=true
							FadeFunc(1)
						end
					end
				else
					if Box.WasHovering then
						if t<1 then
							FadeFunc((1-t)*(1-t))
						else
							Box.FadeBegin=nil
							Box.WasHovering=false
							FadeFunc(0)
						end
					else
						Box.WasHovering=true
						if t<1 then
							Box.FadeBegin=2*CurrentTime-Box.FadeBegin-Box.FadeDuration
							FadeFunc(t*t)
						else
							Box.FadeBegin=CurrentTime
							FadeFun(0)
						end
					end
				end
			end
		elseif Box.Hovering~=Box.WasHovering then
			Box.FadeBegin=CurrentTime
		end
	end
	local ThinkFunc=Box.Think
	if ThinkFunc then
		ThinkFunc(Box)
	end
	local Children=Box.Children
	for i=1,#Children do
		local Child=Children[i].ActualBox
		if Child then
			Child.InternalThink()
		end
	end
end

local ROOT
local function newBox(parent)
	local Box={
		Parent=parent or ROOT,
		Children={},

		PosX=0,PosY=0,
		PosScaleX=0,PosScaleY=0,
		PosOffsetX=0,PosOffsetY=0,

		SizeX=0,SizeY=0,
		SizeScaleX=0,SizeScaleY=0,
		SizeOffsetX=0,SizeOffsetY=0,

		Visible=true
		DrawBackground=true,
		BackgroundColor=DefaultBackgroundColor,

		Hovering=false,
		WasHovering=false,
		FadeDuration=0.2,
		FadeBegin=nil,
	}

	local BoxMetatable={}
	function BoxMetatable:__index(i)
		local RequestListener=InternalRequests[i]
		if RequestListener then
			return RequestListener(Box)
		else
			return Box[i]
		end
	end
	function BoxMetatable:__newindex(i,v)
		Box[i]=v
		for CallbackListeners,Callback in next,InternalCallbacks do
			if CallbackListeners[i] then
				Callback(Box)
			end
		end
	end

	local _Box=setmetatable({ActualBox=Box},BoxMetatable)
	if parent then
		local ParentChildren=parent.Children
		if ParentChildren then
			ParentChildren[#ParentChildren+1]=_Box
		end
	end
	return _Box
end

do
	local ScrW,ScrH=ScrW,ScrH
	ROOT=newBox()
	local Base=ROOT.ActualBox
	Base.DrawBackground=false
	Base.BackgroundColor=Color(0,0,0,0)
	local LastSizeX,LastSizeY=ScrW(),ScrH()
	vgui.Register("BoxBase",{
		Paint=function()
			InternalDraw(Base)
		end,
		Init=function()
			Base.SizeX,Base.SizeY=LastSizeX,LastSizeY
		end,
		Think=function()
			local w,h=ScrW(),ScrH()
			if w~=LastSizeX or h~=LastSizeY then
				Base.SizeX,Base.SizeY=w,h
				InternalResize(Base)
				LastSizeX,LastSizeY=w,h
			end
			InternalThink(Base)
		end
	})
	vgui.Create'BoxBase'
end
_G.newBox=newBox
return newBox
