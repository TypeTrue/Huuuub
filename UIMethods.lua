local Methods = {}

-- Other
local SIN_SCROLL_THREAD = nil

-- Services
local TextService = game:GetService("TextService")
local Camera = workspace.CurrentCamera

local function GetHierarchyPath(Object: GuiObject, Path: table)
	Path = Path or {Object}
	
	local Parent = Object.Parent
	
	if Parent then
		if Parent:IsA("GuiObject") then
			table.insert(Path, Parent)
			return GetHierarchyPath(Parent, Path)
		end
		
		if Parent:IsA("ScreenGui") then
			table.insert(Path, Parent)
		end
	end
	
	return Path
end

function Methods:CollidesWith(gui1, gui2)
	local gui1_topLeft = gui1.AbsolutePosition
	local gui1_bottomRight = gui1_topLeft + gui1.AbsoluteSize

	local gui2_topLeft = gui2.AbsolutePosition
	local gui2_bottomRight = gui2_topLeft + gui2.AbsoluteSize

	return ((gui1_topLeft.x < gui2_bottomRight.x and gui1_bottomRight.x > gui2_topLeft.x) and (gui1_topLeft.y < gui2_bottomRight.y and gui1_bottomRight.y > gui2_topLeft.y))
end

function Methods:GetLowestPoint(GuiObject: GuiObject)
	return Methods:GetEdgePoint(GuiObject, "Down")
end

function Methods:GetEdgePoint(GuiObject: GuiObject, Side: string)
	local TargetPoint = 0
	local AbsPos = GuiObject.AbsolutePosition
	local AbsSize = GuiObject.AbsoluteSize

	local OffsetX = AbsPos.X
	local OffsetY = AbsPos.Y

	if Side == "Top" or Side == "Left" then
		TargetPoint = math.huge
	else
		TargetPoint = 0
	end

	local Children = GuiObject:GetChildren()
	local Found = false

	for _, Object in Children do
		if Object:IsA("GuiObject") and Object.Visible then
			Found = true
			
			local ObjPos = Object.AbsolutePosition
			local ObjSize = Object.AbsoluteSize

			if Side == "Down" then
				local Point = (ObjPos.Y - OffsetY) + ObjSize.Y
				if Point > TargetPoint then TargetPoint = Point end

			elseif Side == "Top" then
				local Point = (ObjPos.Y - OffsetY)
				if Point < TargetPoint then TargetPoint = Point end

			elseif Side == "Right" then
				local Point = (ObjPos.X - OffsetX) + ObjSize.X
				if Point > TargetPoint then TargetPoint = Point end

			elseif Side == "Left" then
				local Point = (ObjPos.X - OffsetX)
				if Point < TargetPoint then TargetPoint = Point end
			end
		end
	end

	if not Found or TargetPoint == math.huge then return 0 end

	return TargetPoint
end

function Methods:GetLength(GuiObject: GuiObject)
	local Closest = math.huge
	local Farest = 0
	
	local Offset = GuiObject.AbsolutePosition.X
	local Children = GuiObject:GetChildren()

	for i=1, #Children do
		local Object = Children[i]

		if Object:IsA("GuiObject") then
			local LeftCorner = (Object.AbsolutePosition.X - Offset)
			local RightCorner = (Object.AbsolutePosition.X - Offset) + Object.AbsoluteSize.X

			if LeftCorner < Closest then
				Closest = LeftCorner
			end

			if RightCorner > Farest then
				Farest = RightCorner
			end
		end
	end

	return math.abs(Farest - Closest)
end

function Methods:GetArrangeData(Width: number, Children: table | GuiObject, Offset: UDim2)
	local StartPoint = UDim2.fromScale(0, 0)
	local Result = {}
	
	-- If that was GuiObject.
	if typeof(Children) == "Instance" then
		Children = Children:GetChildren()
	end
	
	-- Rearranging Stuff.
	for i=1, #Children do
		local Object = Children[i]
		
		if Object:IsA("GuiObject") then
			local ScaleX = Object.Size.X.Scale
			local ScaleY = Object.Size.Y.Scale
			
			-- Inserting.
			table.insert(Result, {Object, StartPoint})
			
			-- Offseting.
			StartPoint += UDim2.fromScale(ScaleX + Offset.X.Scale, 0)
			
			if StartPoint.X.Scale >= Width then
				StartPoint = UDim2.fromScale(0, StartPoint.Y.Scale + ScaleY + Offset.Y.Scale)
			end
		end
	end
	
	-- Callback.
	return Result
end

function Methods:GetHierarchyAbsSize(Object: GuiObject)
	local CurrentAbsSize = Vector2.zero
	local Path = GetHierarchyPath(Object)
	local Iterations = #Path
	
	for i=Iterations, 1, -1 do
		local Object = Path[i]
		
		if i == Iterations then
			CurrentAbsSize = Object.AbsoluteSize
		else
			CurrentAbsSize *= Vector2.new(Object.Size.X.Scale, Object.Size.Y.Scale)
		end
	end
	
	return CurrentAbsSize
end

function Methods:PredictTextBounds(Width: number, FontData: Font | Enum.Font, TextSize: number, Text: string, RichText: boolean)
	FontData = Font.fromEnum(FontData)

	local Params = Instance.new("GetTextBoundsParams")
	Params.Text = Text
	Params.RichText = RichText
	Params.Font = FontData
	Params.Size = TextSize
	Params.Width = Width

	local Success, Bounds = pcall(function() 
		return TextService:GetTextBoundsAsync(Params)
	end)

	-- Rich Text Failure.
	if not Success then
		Params.RichText = false
		Bounds = TextService:GetTextBoundsAsync(Params)
	end

	-- Clearing from RAM.
	Params:Destroy() 
	Params = nil

	-- Callback.
	return Bounds
end

function Methods:SetPixelsScale(Object: GuiObject, NewAbsSize: Vector2, TargetAbsoluteSize: Vector2?)
	local Ratio = (TargetAbsoluteSize or Object.AbsoluteSize) / NewAbsSize
	local Children = Object:GetChildren()

	for i=1, #Children do
		local Object = Children[i]
		if not Object:IsA("GuiObject") then continue end

		-- Scroll Check.
		if Object:IsA("ScrollingFrame") then
			Object.CanvasSize = UDim2.fromScale(Object.CanvasSize.X.Scale * Ratio.X, Object.CanvasSize.Y.Scale * Ratio.Y)
		end

		local Size = Object.Size
		local Position = Object.Position

		Object.Size = UDim2.fromScale(Size.X.Scale * Ratio.X, Size.Y.Scale * Ratio.Y)
		Object.Position = UDim2.fromScale(Position.X.Scale * Ratio.X, Position.Y.Scale * Ratio.Y)	
	end

	Object.Size = UDim2.fromScale(Object.Size.X.Scale / Ratio.X, Object.Size.Y.Scale / Ratio.Y)
end

function Methods:IsObjectOnScreen(Object: GuiObject)
	local Parent:GuiObject | ScreenGui = Object.Parent

	local ParentLeftCorner = Parent.AbsolutePosition
	local ParentRightCorner = ParentLeftCorner + Parent.AbsoluteSize

	local ObjectLeftCorner = Object.AbsolutePosition
	local ObjectRightCorner = ObjectLeftCorner + Object.AbsoluteSize

	return ObjectRightCorner.X > ParentLeftCorner.X and ObjectLeftCorner.X < ParentRightCorner.X and 
		ObjectRightCorner.Y > ParentLeftCorner.Y and ObjectLeftCorner.Y < ParentRightCorner.Y
end

function Methods:IsAtBottom(Scroll:ScrollingFrame, ExtraRemove)
	local CanvasPosition = Scroll.CanvasPosition.Y
	local AbsoluteCanvasSize = Scroll.AbsoluteCanvasSize.Y
	local AbsoluteWindowSize = Scroll.AbsoluteWindowSize.Y

	local MaxScroll = math.max(0, AbsoluteCanvasSize - (ExtraRemove or 0) - AbsoluteWindowSize)

	return CanvasPosition >= MaxScroll - 5
end

function Methods:SetCanvasScale(Scroll: ScrollingFrame, Pixels: Vector2)
	local OldCanvasSize = Scroll.AbsoluteCanvasSize
	local NewScale = (Pixels + Scroll.CanvasPosition) / Scroll.Parent.AbsoluteSize

	Scroll.CanvasSize = UDim2.fromScale(NewScale.X, NewScale.Y)

	local Ratio = OldCanvasSize / Scroll.AbsoluteCanvasSize
	local Children = Scroll:GetChildren()

	for i=1, #Children do
		local Object = Children[i]

		if Object:IsA("GuiObject") then
			Object.Size = UDim2.fromScale(Object.Size.X.Scale * Ratio.X, Object.Size.Y.Scale * Ratio.Y)
			Object.Position = UDim2.fromScale(Object.Position.X.Scale * Ratio.X, Object.Position.Y.Scale * Ratio.Y)
		end
	end
end

function Methods:CanvasScaleIntoPixels(Scroll: ScrollingFrame, Scale: Vector2)
	local Offset = (Scroll.AbsolutePosition - Scroll.Parent.AbsolutePosition) * Vector2.new(math.sign(Scale.X), math.sign(Scale.Y))
	return (Scroll.Parent.AbsoluteSize * Scale) - Offset
end

function Methods:DefaultCenterScale(TObject: GuiObject)
	Methods:SetPixelsScale(TObject, Vector2.new(TObject.AbsoluteSize.X, Methods:GetLowestPoint(TObject) + 5))
	TObject.Position = UDim2.fromScale(0.5 - TObject.Size.X.Scale/2, 0.5 - TObject.Size.Y.Scale/2)
end

function Methods:SinScroll(Scroll, PixelsY)
	if SIN_SCROLL_THREAD and SIN_SCROLL_THREAD.Connected then
		SIN_SCROLL_THREAD:Disconnect()
	end

	local Current = Scroll.CanvasPosition.Y
	local Difference = PixelsY - Current

	local RemainTime = .25
	local Elapsed = 0

	SIN_SCROLL_THREAD = game:GetService("RunService").Heartbeat:Connect(function(DeltaTime)
		Elapsed += DeltaTime

		local x = math.min(Elapsed / RemainTime, 1)
		local sin = math.sin(math.pi/2 * x)

		Scroll.CanvasPosition = Vector2.new(0, Current + (Difference * sin))

		if x == 1 then
			SIN_SCROLL_THREAD:Disconnect()
			SIN_SCROLL_THREAD = nil
		end
	end)
end

function Methods:StackVertically(TObject: GuiObject, Offset: Vector2)
	Offset = Offset or Vector2.new(5, 5)
	Offset /= TObject.AbsoluteSize
	
	local StartPosition = Offset
	
	for _, Obj in pairs(TObject:GetChildren()) do
		if Obj:IsA("GuiObject") and Obj.Visible then
			Obj.Position = UDim2.fromScale(StartPosition.X, StartPosition.Y)
			StartPosition += Vector2.new(0, Obj.Size.Y.Scale + Offset.Y)
		end
	end
end

-- Sticking Methods.
function Methods:GetMinMaxPoints(Objects: GuiObject)
	local Points = {}
	
	for i=1, #Objects do
		local TObject = Objects[i]
		
		if TObject:IsA("GuiObject") then
			local AbsPos = TObject.AbsolutePosition
			AbsPos -= TObject.AnchorPoint * TObject.AbsoluteSize
			
			table.insert(Points, AbsPos)
			table.insert(Points, AbsPos + TObject.AbsoluteSize)
		end
	end
	
	local Min = Vector2.new(math.huge, math.huge)
	local Max = Vector2.new(-math.huge, -math.huge)
	
	-- Comparing.
	for i=1, #Points do
		local Point = Points[i]
		local ThisX, ThisY = Point.X, Point.Y
		
		if ThisX < Min.X then
			Min = Vector2.new(ThisX, Min.Y)
		end
		
		if ThisY < Min.Y then
			Min = Vector2.new(Min.X, ThisY)
		end
		
		if ThisX > Max.X then
			Max = Vector2.new(ThisX, Max.Y)
		end

		if ThisY > Max.Y then
			Max = Vector2.new(Max.X, ThisY)
		end
	end
	
	return Min, Max
end

function Methods:StickInBox(TParent: GuiObject, Objects: GuiObject, Offset: number)
	Offset = Offset or 0
	
	local AbsSize = (TParent:IsA("ScrollingFrame") and TParent.AbsoluteCanvasSize) or TParent.AbsoluteSize
	local Min, Max = Methods:GetMinMaxPoints(Objects)
	local Bounds = (Max - Min) / AbsSize
	local StartPos = (Min - TParent.AbsolutePosition) / AbsSize

	local Frame = Instance.new("Frame")
	Frame.BackgroundTransparency = 1
	Frame.Size = UDim2.fromScale(Bounds.X, Bounds.Y)
	Frame.Position = UDim2.fromScale(StartPos.X, StartPos.Y)
	Frame.Parent = TParent
		
	for i=1, #Objects do
		local TObj = Objects[i]
		local ThisParent = TObj.Parent
		
		local RelativeOffset = Vector2.new(Offset, Offset) / Frame.AbsoluteSize
		local Ratio = ThisParent.AbsoluteSize / Frame.AbsoluteSize
		
		TObj.Size = UDim2.fromScale((TObj.Size.X.Scale * Ratio.X) - (RelativeOffset.X*2), (TObj.Size.Y.Scale * Ratio.Y) - (RelativeOffset.Y*2))
		TObj.Position = UDim2.fromScale((TObj.Position.X.Scale * Ratio.X) + RelativeOffset.X, (TObj.Position.Y.Scale * Ratio.Y) + RelativeOffset.Y)
		TObj.Parent = Frame
	end
	
	return Frame
end

-- Visual Methods.
function Methods:SetCorner(Object: GuiObject, Radius: (UDim | GuiObject)?)
	local UICorner = Object:FindFirstChildOfClass("UICorner")

	-- Copy from another.
	if typeof(Radius) == "Instance" then
		if UICorner then UICorner:Destroy() end
		UICorner = Radius:FindFirstChildOfClass("UICorner")
		if UICorner then UICorner:Clone().Parent = Object end
		return
	end

	-- Usual Way.
	if not UICorner then
		UICorner = Instance.new("UICorner")
		UICorner.Parent = Object
	end

	UICorner.CornerRadius = Radius or UDim.new(0, shared.techno == "pc" and 6 or 4)
end

function Methods:SetStroke(Object: GuiObject, Color: Color3?, Transparency: number?, Thickness: number?)
	local UIStroke = Object:FindFirstChildOfClass("UIStroke")

	if not UIStroke then
		UIStroke = Instance.new("UIStroke")
		UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		UIStroke.Parent = Object
	end

	UIStroke.Transparency = Transparency or Object.BackgroundTransparency
	UIStroke.Thickness = Thickness or UIStroke.Thickness
	UIStroke.Color = Color or Color3.new(1, 1, 1)
end

-- World Space Methods.
function Methods:WorldToScreen(WorldPosition: Vector3, HUD: ScreenGui)
	local p = Camera:WorldToScreenPoint(WorldPosition)
	local x = math.clamp(1/HUD.AbsoluteSize.X*p.X, 0, 1)
	local y = math.clamp(1/HUD.AbsoluteSize.Y*p.Y, 0, 1)

	return x, y
end

-- Scale Childrens
function Methods:ScaleChildrens(Frame)
	for _, Object:Instance in Frame:GetChildren() do
		if not Object:IsA("GuiObject") then continue end
		
		Object.Size = UDim2.fromScale(Object.AbsoluteSize.X/Frame.AbsoluteSize.X, Object.AbsoluteSize.Y/Frame.AbsoluteSize.Y)
		Object.Position = UDim2.fromScale(
			(Object.AbsolutePosition.X - Frame.AbsolutePosition.X) / Frame.AbsoluteSize.X,
			(Object.AbsolutePosition.Y - Frame.AbsolutePosition.Y) / Frame.AbsoluteSize.Y
		)
	end
end

-- Other Methods.
Methods["SetControls"] = function(Enable: boolean)
	local Controls = require(game:GetService("Players").LocalPlayer.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
	
	if Enable then
		return Controls:Enable()
	end
	
	Controls:Disable()
end

Methods["HideGuis"] = function(wh: {GuiObject? | GuiBase?})
	local HidedList = {UI = {}, GO = {}}
	for i, v in pairs(game.Players.LocalPlayer.PlayerGui:GetChildren()) do
		if not v:IsA("ScreenGui") then continue end
		if not v.Enabled then continue end
		
		
		local Hide = table.find(wh, v) ~= nil
		v.Enabled = Hide
		
		if not Hide then 
			table.insert(HidedList.UI, v)
		end
		
		for _, frame in pairs(v:GetChildren()) do
			if not frame:IsA("Frame") then continue end
			if not frame.Visible then continue end
			if table.find(wh, frame) then continue end
			
			frame.Visible = false
			table.insert(HidedList.GO, frame)
		end
	end
	
	return HidedList
end
Methods["ShowGuis"] = function(GO)
	for i, v in pairs(GO.UI) do
		v.Enabled = true
	end
	for i, v in pairs(GO.GO) do
		v.Visible = true
	end
end
return Methods
