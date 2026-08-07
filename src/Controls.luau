--!strict

local CanvasModule = require("./Canvas")
local ElementModule = require("./Element")
local Signal = require("./Signal")

type Canvas = CanvasModule.Canvas
type Element = ElementModule.Element

local Controls = {}

local function copy(properties: { [string]: any }?): { [string]: any }
	return if properties then table.clone(properties) else {}
end

local function patch(element: Element, properties: { [string]: any }?)
	if properties then
		element:patch(properties)
	end
end

local function connect(connections: { any }, signal: Signal.Signal, callback: (...any) -> ())
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function disconnectAll(connections: { any })
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function displayKey(value: string?): string
	if value == nil then
		return "Unbound"
	end
	local words = string.gsub(value, "(%l)(%u)", "%1 %2")
	words = string.gsub(words, "(%a)(%d)", "%1 %2")
	return words
end

local function normalizeKey(value: string?): string?
	if value == nil then
		return nil
	end
	local normalized = string.gsub(value, "^Enum%.KeyCode%.", "")
	assert(normalized ~= "" and normalized ~= "Unknown", "keybind value must name a key")
	return normalized
end

local function baseSquare(properties: { [string]: any }?, position: any, size: any, zIndex: number)
	local result = copy(properties)
	result.Position = position
	result.Size = size
	result.ZIndex = zIndex
	if result.Visible == nil then
		result.Visible = true
	end
	if result.Filled == nil then
		result.Filled = true
	end
	return result
end

local function baseText(properties: { [string]: any }?, text: string, position: any, zIndex: number)
	local result = copy(properties)
	result.Text = text
	result.Position = position
	result.ZIndex = zIndex
	if result.Visible == nil then
		result.Visible = true
	end
	return result
end

function Controls.createSegmented(canvas: Canvas, options: any, vector2: any): any
	assert(type(options) == "table", "segmented control options are required")
	assert(
		type(options.Options) == "table" and #options.Options > 0,
		"segmented control needs Options"
	)
	assert(options.Position and options.Size, "segmented control needs Position and Size")
	assert(vector2, "segmented controls require Vector2 in Limn.new options")

	local style = options.Style or {}
	local values = options.Options
	local position = options.Position
	local size = options.Size
	local layout = options.Layout
	local selectedIndex = 1
	for index, option in values do
		if option.Value == options.Value then
			selectedIndex = index
			break
		end
	end
	local disabled = options.Disabled == true
	local visible = true
	local hoveredIndex: number? = nil
	local focusedIndex: number? = nil
	local destroyed = false
	local state = "idle"
	local changed = Signal.new()
	local stateChanged = Signal.new()
	local connections = {}
	local owned: { Element } = {}
	local segments: { Element } = {}
	local labels: { Element? } = {}

	local frame =
		canvas:create("Square", baseSquare(style.Frame, position, size, options.ZIndex or 0))
	table.insert(owned, frame)

	local control = {
		Changed = changed,
		StateChanged = stateChanged,
	} :: any

	local function currentState(): string
		if disabled then
			return "disabled"
		end
		if focusedIndex then
			return "focused"
		end
		return "idle"
	end

	local function updateState()
		local nextState = currentState()
		if state ~= nextState then
			state = nextState
			stateChanged:Fire(state)
		end
	end

	local function updateSegment(index: number)
		local segment = segments[index]
		if not segment:isAlive() then
			return
		end
		patch(segment, style.Option)
		if index == selectedIndex then
			patch(segment, style.Selected)
		end
		if index == hoveredIndex then
			patch(segment, style.Hovered)
		end
		if index == focusedIndex then
			patch(segment, style.Focused)
		end
		if disabled then
			patch(segment, style.Disabled)
		end
		segment:setInteractive(not disabled and visible)
		segment:setFocusable(not disabled and visible)
		segment:set("Visible", visible)
	end

	local function segmentLayout(index: number): (any, any, any)
		local defaultPosition =
			vector2.new(position.X + size.X * ((index - 1) / #values), position.Y)
		local defaultSize = vector2.new(size.X / #values, size.Y)
		local custom = if layout then layout(index, #values, position, size) else nil
		local segmentPosition = if custom and custom.Position
			then custom.Position
			else defaultPosition
		local segmentSize = if custom and custom.Size then custom.Size else defaultSize
		local labelPosition = if custom and custom.LabelPosition
			then custom.LabelPosition
			else segmentPosition
		return segmentPosition, segmentSize, labelPosition
	end

	local function updateGeometry()
		if frame:isAlive() then
			frame:patch({ Position = position, Size = size, ZIndex = options.ZIndex or 0 })
		end
		for index, segment in segments do
			local segmentPosition, segmentSize, labelPosition = segmentLayout(index)
			if segment:isAlive() then
				segment:patch({
					Position = segmentPosition,
					Size = segmentSize,
					ZIndex = (options.ZIndex or 0) + 1,
				})
			end
			local label = labels[index]
			if label and label:isAlive() then
				label:patch({ Position = labelPosition, ZIndex = (options.ZIndex or 0) + 2 })
			end
		end
	end

	local function updateAll()
		for index = 1, #segments do
			updateSegment(index)
		end
		if frame:isAlive() then
			patch(frame, style.Frame)
			if disabled then
				patch(frame, style.Disabled)
			end
			frame:set("Visible", visible)
		end
		for index, label in labels do
			if label and label:isAlive() then
				patch(label, style.Label)
				if index == selectedIndex then
					patch(label, style.SelectedLabel)
				end
				label:set("Visible", visible)
			end
		end
		updateGeometry()
		updateState()
	end

	local function setValue(value: any, source: string): boolean
		if destroyed or disabled then
			return false
		end
		local nextIndex: number? = nil
		for index, option in values do
			if option.Value == value then
				nextIndex = index
				break
			end
		end
		assert(nextIndex, "segmented control value must match an option")
		if nextIndex == selectedIndex then
			return false
		end
		local previous = values[selectedIndex].Value
		selectedIndex = nextIndex
		updateAll()
		changed:Fire(values[selectedIndex].Value, previous, source)
		return true
	end

	for index, option in values do
		local segmentPosition, segmentSize, labelPosition = segmentLayout(index)
		local segment = canvas:create(
			"Square",
			baseSquare(style.Option, segmentPosition, segmentSize, (options.ZIndex or 0) + 1),
			{
				interactive = not disabled,
			}
		)
		segment:setFocusable(not disabled and visible)
		table.insert(owned, segment)
		table.insert(segments, segment)

		if option.Label ~= nil then
			local label = canvas:create(
				"Text",
				baseText(
					style.Label,
					tostring(option.Label),
					labelPosition,
					(options.ZIndex or 0) + 2
				)
			)
			table.insert(owned, label)
			labels[index] = label
		end

		connect(connections, segment.PointerEntered, function()
			if not disabled then
				hoveredIndex = index
				updateSegment(index)
			end
		end)
		connect(connections, segment.PointerLeft, function()
			if hoveredIndex == index then
				hoveredIndex = nil
				updateSegment(index)
			end
		end)
		connect(connections, segment.Focused, function()
			focusedIndex = index
			updateAll()
		end)
		connect(connections, segment.FocusLost, function()
			if focusedIndex == index then
				focusedIndex = nil
				updateAll()
			end
		end)
		connect(connections, segment.Clicked, function()
			setValue(option.Value, "pointer")
		end)
		connect(connections, segment.KeyDown, function(_: any, key: string)
			if disabled then
				return
			end
			if key == "Left" or key == "Up" then
				canvas:focus(segments[math.max(1, index - 1)])
			elseif key == "Right" or key == "Down" then
				canvas:focus(segments[math.min(#segments, index + 1)])
			elseif key == "Enter" or key == "Space" then
				setValue(option.Value, "keyboard")
			end
		end)
	end

	function control:getValue(): any
		return values[selectedIndex].Value
	end

	function control:getState(): string
		return currentState()
	end

	function control:setValue(value: any): boolean
		return setValue(value, "programmatic")
	end

	function control:setDisabled(value: boolean)
		if destroyed or disabled == value then
			return
		end
		disabled = value
		if disabled and focusedIndex then
			canvas:focus(nil)
		end
		updateAll()
	end

	function control:setLayout(nextLayout: any)
		assert(type(nextLayout) == "table", "segmented control layout is required")
		assert(
			nextLayout.Position and nextLayout.Size,
			"segmented control layout needs Position and Size"
		)
		if destroyed then
			return
		end
		position = nextLayout.Position
		size = nextLayout.Size
		layout = nextLayout.Layout
		updateAll()
	end

	function control:setVisible(nextVisible: boolean)
		if destroyed or visible == nextVisible then
			return
		end
		visible = nextVisible
		if not visible then
			hoveredIndex = nil
			if focusedIndex then
				canvas:focus(nil)
			end
		end
		updateAll()
	end

	function control:destroy()
		if destroyed then
			return
		end
		destroyed = true
		if focusedIndex then
			canvas:focus(nil)
		end
		disconnectAll(connections)
		for _, element in owned do
			element:destroy()
		end
		changed:Destroy()
		stateChanged:Destroy()
	end

	updateAll()
	return control
end

function Controls.createKeybind(canvas: Canvas, options: any, vector2: any): any
	assert(type(options) == "table", "keybind control options are required")
	assert(options.Position and options.Size, "keybind control needs Position and Size")
	assert(vector2, "keybind controls require Vector2 in Limn.new options")
	assert(
		options.Value == nil or type(options.Value) == "string",
		"keybind control Value must be a key name or nil"
	)

	local style = options.Style or {}
	local position = options.Position
	local size = options.Size
	local layout = options.Layout or {}
	local disabled = options.Disabled == true
	local visible = true
	local listening = false
	local focused = false
	local destroyed = false
	local value: string? = normalizeKey(options.Value)
	local state = "idle"
	local changed = Signal.new()
	local listeningChanged = Signal.new()
	local stateChanged = Signal.new()
	local connections = {}
	local owned: { Element } = {}
	local zIndex = options.ZIndex or 0
	local frame = canvas:create("Square", baseSquare(style.Frame, position, size, zIndex), {
		interactive = not disabled,
	})
	frame:setFocusable(not disabled and visible)
	table.insert(owned, frame)
	local label: Element? = nil
	if options.Label ~= nil then
		label = canvas:create(
			"Text",
			baseText(
				style.Label,
				tostring(options.Label),
				layout.LabelPosition or position,
				zIndex + 1
			)
		)
		table.insert(owned, label)
	end
	local displayPosition = layout.ValuePosition
		or vector2.new(position.X + size.X * 0.5, position.Y)
	local display =
		canvas:create("Text", baseText(style.Value, displayKey(value), displayPosition, zIndex + 1))
	table.insert(owned, display)

	local control = {
		Changed = changed,
		ListeningChanged = listeningChanged,
		StateChanged = stateChanged,
	} :: any

	local function updateGeometry()
		if frame:isAlive() then
			frame:patch({ Position = position, Size = size, ZIndex = zIndex })
		end
		if label and label:isAlive() then
			label:patch({ Position = layout.LabelPosition or position, ZIndex = zIndex + 1 })
		end
		if display:isAlive() then
			local nextDisplayPosition = layout.ValuePosition
				or vector2.new(position.X + size.X * 0.5, position.Y)
			display:patch({ Position = nextDisplayPosition, ZIndex = zIndex + 1 })
		end
	end

	local function currentState(): string
		if disabled then
			return "disabled"
		end
		if listening then
			return "listening"
		end
		if focused then
			return "focused"
		end
		return "idle"
	end

	local function update()
		if frame:isAlive() then
			patch(frame, style.Frame)
			patch(display, style.Value)
			if focused then
				patch(frame, style.Focused)
				patch(display, style.Focused)
			end
			if listening then
				patch(frame, style.Listening)
				patch(display, style.Listening)
				display:set("Text", (options.ListeningLabel or "Listening"))
			else
				display:set("Text", (options.FormatKey or displayKey)(value))
			end
			if disabled then
				patch(frame, style.Disabled)
				patch(display, style.Disabled)
			end
			frame:setInteractive(not disabled and visible)
			frame:setFocusable(not disabled and visible)
			frame:set("Visible", visible)
		end
		if label and label:isAlive() then
			label:set("Visible", visible)
		end
		if display:isAlive() then
			display:set("Visible", visible)
		end
		updateGeometry()
		local nextState = currentState()
		if nextState ~= state then
			state = nextState
			stateChanged:Fire(state)
		end
	end

	local function cancel()
		if not listening then
			return false
		end
		listening = false
		listeningChanged:Fire(false)
		update()
		return true
	end

	local function assign(nextValue: string?, source: string): boolean
		if destroyed or disabled then
			return false
		end
		local previous = value
		cancel()
		if previous == nextValue then
			return false
		end
		value = nextValue
		update()
		changed:Fire(value, previous, source)
		return true
	end

	function control:getValue(): string?
		return value
	end

	function control:getDisplayValue(): string
		return (options.FormatKey or displayKey)(value)
	end

	function control:getState(): string
		return currentState()
	end

	function control:begin(): boolean
		if destroyed or disabled or not visible or listening then
			return false
		end
		canvas:focus(frame)
		listening = true
		listeningChanged:Fire(true)
		update()
		return true
	end

	function control:cancel(): boolean
		return cancel()
	end

	function control:clear(): boolean
		return assign(nil, "clear")
	end

	function control:setValue(nextValue: string?): boolean
		assert(
			nextValue == nil or type(nextValue) == "string",
			"keybind value must be a key name or nil"
		)
		return assign(normalizeKey(nextValue), "programmatic")
	end

	function control:setDisabled(nextDisabled: boolean)
		if destroyed or disabled == nextDisabled then
			return
		end
		disabled = nextDisabled
		if disabled then
			cancel()
			if canvas:getFocusedElement() == frame then
				canvas:focus(nil)
			end
		end
		update()
	end

	function control:setLayout(nextLayout: any)
		assert(type(nextLayout) == "table", "keybind control layout is required")
		assert(
			nextLayout.Position and nextLayout.Size,
			"keybind control layout needs Position and Size"
		)
		if destroyed then
			return
		end
		position = nextLayout.Position
		size = nextLayout.Size
		layout = nextLayout.Layout or {}
		update()
	end

	function control:setVisible(nextVisible: boolean)
		if destroyed or visible == nextVisible then
			return
		end
		visible = nextVisible
		if not visible then
			cancel()
			if canvas:getFocusedElement() == frame then
				canvas:focus(nil)
			end
		end
		update()
	end

	function control:destroy()
		if destroyed then
			return
		end
		destroyed = true
		if canvas:getFocusedElement() == frame then
			canvas:focus(nil)
		end
		disconnectAll(connections)
		for _, element in owned do
			element:destroy()
		end
		changed:Destroy()
		listeningChanged:Destroy()
		stateChanged:Destroy()
	end

	connect(connections, frame.Focused, function()
		focused = true
		update()
	end)
	connect(connections, frame.FocusLost, function()
		focused = false
		if not frame:isAlive() then
			listening = false
			return
		end
		cancel()
		update()
	end)
	connect(connections, frame.Clicked, function()
		control:begin()
	end)
	connect(connections, frame.KeyDown, function(_: any, key: string)
		if disabled or not visible then
			return
		end
		if not listening then
			if key == "Enter" or key == "Space" then
				control:begin()
			end
			return
		end
		if key == "Escape" then
			cancel()
		elseif key == "Backspace" or key == "Delete" then
			control:clear()
		else
			assign(key, "keyboard")
		end
	end)

	update()
	return control
end

return Controls
