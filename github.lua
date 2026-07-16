--[[
	CleanUI
	A clean-but-fun UI library for Roblox, built Rayfield-style
	(Window -> Tab -> Create*() elements).

	Requiring this module does nothing by itself -- nothing is created
	until you call CleanUI:CreateWindow(). When you do, it asks the
	player what they're playing on (PC / Mobile) and sizes the window +
	scales the UI accordingly, so it's never too big on a phone or too
	small on desktop.

	FEATURES:
		- Collapsible window: the "-" button tucks the whole window away
		  into a small draggable sun icon; tap the icon to bring it back
		- PC: press RightControl to show/hide the whole GUI
		- Mobile: a floating tap button replaces the keybind, since
		  touch devices have no physical keys to press
		- Inputs: Button, Toggle, Slider, Dropdown, MultiDropdown, Radio,
		  Textbox, Search, ColorPicker, Keybind
		- Layout: Label, Section (collapsible accordion group)
		- Feedback: Notify (toasts), Confirm (yes/no modal),
		  ShowLoading/HideLoading (spinner overlay), ProgressBar
		- Tooltips on any element via cfg.Tooltip
		- Save/Load settings via cfg.Flag + CleanUI:SaveConfig()/LoadConfig()
		- CleanUI:SetTheme("Pink" / "Blue" / "Mint") to re-skin live

	USAGE:
		local CleanUI = require(path.to.CleanUI)
		local Window = CleanUI:CreateWindow({ Title = "My App" })
		-- or skip the prompt: CleanUI:CreateWindow({ Platform = "PC" })
		local Tab = Window:CreateTab("Main")

		Tab:CreateButton({ Text = "Click me", Callback = function() end })
		Tab:CreateSlider({ Text = "Speed", Min = 0, Max = 100, Default = 50, Flag = "speed", Callback = function(v) end })
		Tab:CreateToggle({ Text = "Enabled", Default = false, Flag = "enabled", Callback = function(v) end })
		Tab:CreateDropdown({ Text = "Mode", Options = {"A","B","C"}, Flag = "mode", Callback = function(v) end })
		Tab:CreateMultiDropdown({ Text = "Tags", Options = {"A","B","C"}, Flag = "tags", Callback = function(list) end })
		Tab:CreateRadio({ Text = "Difficulty", Options = {"Easy","Normal","Hard"}, Flag = "diff", Callback = function(v) end })
		Tab:CreateSearch({ PlaceholderText = "Search...", Callback = function(query) end })
		Tab:CreateInput({ Text = "Name", PlaceholderText = "Type here...", Flag = "name", Callback = function(text) end })
		Tab:CreateColorPicker({ Text = "Color", Default = Color3.fromRGB(255,92,141), Flag = "color", Callback = function(c) end })
		Tab:CreateKeybind({ Text = "Toggle Menu", Default = Enum.KeyCode.V, Flag = "keybind", Callback = function(key) end })
		Tab:CreateProgressBar({ Text = "Loading", Default = 0.4 })
		Tab:CreateLabel({ Text = "Just some info text" })

		local Section = Tab:CreateSection({ Text = "Advanced" })
		Section:CreateToggle({ Text = "Nested option", Callback = function(v) end })

		CleanUI:Notify({ Title = "Saved", Text = "Your settings were saved.", Type = "Success" })
		CleanUI:Confirm({ Title = "Reset all?", Text = "This can't be undone.", OnConfirm = function() end })
		CleanUI:ShowLoading("Connecting...")
		CleanUI:HideLoading()
		local json = CleanUI:SaveConfig()   -- persist `json` yourself (DataStore, etc.)
		CleanUI:LoadConfig(json)
		CleanUI:SetTheme("Blue")
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--// Theme -------------------------------------------------------------
local Theme = {
	Background   = Color3.fromRGB(26, 22, 36),
	Surface      = Color3.fromRGB(36, 30, 48),
	SurfaceLight = Color3.fromRGB(48, 40, 64),
	Border       = Color3.fromRGB(68, 56, 92),
	Text         = Color3.fromRGB(245, 242, 250),
	SubText      = Color3.fromRGB(178, 166, 200),
	Accent       = Color3.fromRGB(255, 92, 141),
	Accent2      = Color3.fromRGB(148, 97, 255),
	AccentHover  = Color3.fromRGB(255, 130, 170),
	Success      = Color3.fromRGB(92, 220, 150),
	Warning      = Color3.fromRGB(255, 196, 87),
	Danger       = Color3.fromRGB(255, 90, 90),
	Font         = Enum.Font.GothamMedium,
	FontBold     = Enum.Font.GothamBold,
	Corner       = 12,
}

local ThemePresets = {
	Pink = { Accent = Color3.fromRGB(255, 92, 141), Accent2 = Color3.fromRGB(148, 97, 255) },
	Blue = { Accent = Color3.fromRGB(64, 190, 255),  Accent2 = Color3.fromRGB(99, 102, 241) },
	Mint = { Accent = Color3.fromRGB(72, 219, 168),  Accent2 = Color3.fromRGB(64, 160, 255) },
}

--// Helpers ------------------------------------------------------------
local function new(class, props, children)
	local obj = Instance.new(class)
	for k, v in pairs(props or {}) do
		obj[k] = v
	end
	for _, child in ipairs(children or {}) do
		child.Parent = obj
	end
	return obj
end

local function tween(obj, props, time, style, dir)
	local t = TweenService:Create(
		obj,
		TweenInfo.new(time or 0.18, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function corner(obj, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = obj })
end

local function stroke(obj, color, thickness)
	return new("UIStroke", {
		Color = color or Theme.Border,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = obj,
	})
end

local function padding(obj, all)
	return new("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, all),
		Parent = obj,
	})
end

local function gradient(obj, color1, color2, rotation)
	return new("UIGradient", {
		Color = ColorSequence.new(color1 or Theme.Accent, color2 or Theme.Accent2),
		Rotation = rotation or 90,
		Parent = obj,
	})
end

-- Gradients registered here get live-updated when CleanUI:SetTheme() runs.
local accentGradients = {}
local function accentGradient(obj, rotation)
	local g = gradient(obj, Theme.Accent, Theme.Accent2, rotation)
	table.insert(accentGradients, g)
	return g
end

local function makeDraggable(dragHandle, target)
	local dragging, dragStart, startPos = false, nil, nil

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = target.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			target.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
end

-- Flags: any element created with a `Flag = "name"` in its config gets
-- registered here so CleanUI:SaveConfig()/LoadConfig() can read/write it.
local flagRegistry = {}
local function registerFlag(cfg, getFn, setFn)
	if cfg and cfg.Flag then
		flagRegistry[cfg.Flag] = { Get = getFn, Set = setFn }
	end
end

--// Platform presets ----------------------------------------------------
local PLATFORM_PRESETS = {
	PC     = { Size = UDim2.fromOffset(480, 340), Scale = 1.0, ToggleKey = true },
	Mobile = { Size = UDim2.fromOffset(340, 300), Scale = 1.2, ToggleKey = false },
}

-- Shows a small modal asking the player what they're on, yields until
-- they pick, then returns "PC" or "Mobile".
local function askPlatform()
	local resultEvent = Instance.new("BindableEvent")
	local selected = "PC"

	local overlay = new("ScreenGui", {
		Name = "CleanUI_PlatformAsk",
		ResetOnSpawn = false,
		DisplayOrder = 999,
		IgnoreGuiInset = true,
		Parent = playerGui,
	})
	new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Parent = overlay,
	})

	local card = new("Frame", {
		Size = UDim2.fromOffset(300, 180),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		Parent = overlay,
	})
	corner(card, Theme.Corner)
	stroke(card, Theme.Border, 1)
	padding(card, 20)
	new("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = card,
	})

	new("TextLabel", {
		Text = "What are you playing on?",
		Font = Theme.FontBold,
		TextSize = 16,
		TextColor3 = Theme.Text,
		TextWrapped = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 1,
		Parent = card,
	})
	new("TextLabel", {
		Text = "This sizes the menu for your screen and input.",
		Font = Theme.Font,
		TextSize = 12,
		TextColor3 = Theme.SubText,
		TextWrapped = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 2,
		Parent = card,
	})

	local options = { "PC", "Mobile" }
	for i, opt in ipairs(options) do
		local btn = new("TextButton", {
			Text = opt,
			Font = Theme.FontBold,
			TextSize = 14,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundColor3 = Theme.Accent,
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 0, 38),
			LayoutOrder = 2 + i,
			Parent = card,
		})
		corner(btn, Theme.Corner)
		accentGradient(btn, 100)
		btn.MouseEnter:Connect(function() tween(btn, { Size = UDim2.new(1, 0, 0, 40) }, 0.1) end)
		btn.MouseLeave:Connect(function() tween(btn, { Size = UDim2.new(1, 0, 0, 38) }, 0.1) end)
		btn.MouseButton1Click:Connect(function()
			selected = opt
			overlay:Destroy()
			resultEvent:Fire()
		end)
	end

	resultEvent.Event:Wait()
	resultEvent:Destroy()
	return selected
end

--// Library --------------------------------------------------------------
local CleanUI = {}
CleanUI.__index = CleanUI

--// Global feedback: notifications, confirm dialog, loading spinner -----

local notifyGui, notifyHolder
local function ensureNotifyGui()
	if notifyGui and notifyGui.Parent then return notifyHolder end
	notifyGui = new("ScreenGui", {
		Name = "CleanUI_Notifications",
		ResetOnSpawn = false,
		DisplayOrder = 998,
		IgnoreGuiInset = true,
		Parent = playerGui,
	})
	notifyHolder = new("Frame", {
		Size = UDim2.fromOffset(280, 1),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		BackgroundTransparency = 1,
		Parent = notifyGui,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Parent = notifyHolder,
	})
	return notifyHolder
end

-- CleanUI:Notify({ Title, Text, Type = "Info"|"Success"|"Warning"|"Danger", Duration = 4 })
function CleanUI:Notify(cfg)
	cfg = cfg or {}
	local holder = ensureNotifyGui()
	local color = Theme[cfg.Type] or Theme.Accent

	local toast = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = holder,
	})
	corner(toast, Theme.Corner)
	stroke(toast, Theme.Border, 1)
	padding(toast, 12)
	local scale = new("UIScale", { Scale = 0, Parent = toast })

	local bar = new("Frame", { Size = UDim2.new(0, 4, 1, -4), Position = UDim2.new(0,0,0,2), BackgroundColor3 = color, BorderSizePixel = 0, Parent = toast })
	corner(bar, 2)

	new("TextLabel", {
		Text = cfg.Title or "Notice",
		Font = Theme.FontBold, TextSize = 13, TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 0),
		Size = UDim2.new(1, -14, 0, 18),
		Parent = toast,
	})
	if cfg.Text then
		new("TextLabel", {
			Text = cfg.Text, Font = Theme.Font, TextSize = 12, TextColor3 = Theme.SubText,
			TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 14, 0, 18),
			Size = UDim2.new(1, -14, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = toast,
		})
	end

	tween(scale, { Scale = 1 }, 0.2, Enum.EasingStyle.Back)
	task.delay(cfg.Duration or 4, function()
		if not toast.Parent then return end
		tween(scale, { Scale = 0 }, 0.15)
		task.delay(0.15, function()
			if toast.Parent then toast:Destroy() end
		end)
	end)

	return toast
end

-- CleanUI:Confirm({ Title, Text, ConfirmText, CancelText, OnConfirm, OnCancel })
function CleanUI:Confirm(cfg)
	cfg = cfg or {}
	local overlay = new("ScreenGui", {
		Name = "CleanUI_Confirm", ResetOnSpawn = false, DisplayOrder = 999, IgnoreGuiInset = true, Parent = playerGui,
	})
	new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45, BorderSizePixel = 0, Parent = overlay,
	})
	local card = new("Frame", {
		Size = UDim2.fromOffset(300, 170), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.Surface, BorderSizePixel = 0, Parent = overlay,
	})
	corner(card, Theme.Corner)
	stroke(card, Theme.Border, 1)
	padding(card, 20)
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })

	new("TextLabel", {
		Text = cfg.Title or "Are you sure?", Font = Theme.FontBold, TextSize = 16, TextColor3 = Theme.Text,
		TextWrapped = true, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1, Parent = card,
	})
	if cfg.Text then
		new("TextLabel", {
			Text = cfg.Text, Font = Theme.Font, TextSize = 12, TextColor3 = Theme.SubText,
			TextWrapped = true, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 2, Parent = card,
		})
	end

	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 3, Parent = card })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), Parent = row })

	local cancelBtn = new("TextButton", {
		Text = cfg.CancelText or "Cancel", Font = Theme.FontBold, TextSize = 13, TextColor3 = Theme.Text,
		BackgroundColor3 = Theme.SurfaceLight, AutoButtonColor = false, Size = UDim2.new(0.5, -5, 1, 0), Parent = row,
	})
	corner(cancelBtn, Theme.Corner)
	stroke(cancelBtn, Theme.Border, 1)

	local confirmBtn = new("TextButton", {
		Text = cfg.ConfirmText or "Confirm", Font = Theme.FontBold, TextSize = 13, TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Theme.Accent, AutoButtonColor = false, Size = UDim2.new(0.5, -5, 1, 0), Parent = row,
	})
	corner(confirmBtn, Theme.Corner)
	accentGradient(confirmBtn, 100)

	cancelBtn.MouseButton1Click:Connect(function()
		overlay:Destroy()
		if cfg.OnCancel then cfg.OnCancel() end
	end)
	confirmBtn.MouseButton1Click:Connect(function()
		overlay:Destroy()
		if cfg.OnConfirm then cfg.OnConfirm() end
	end)
end

local loadingGui, loadingConn
function CleanUI:ShowLoading(text)
	if loadingGui then return end
	loadingGui = new("ScreenGui", {
		Name = "CleanUI_Loading", ResetOnSpawn = false, DisplayOrder = 999, IgnoreGuiInset = true, Parent = playerGui,
	})
	new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = loadingGui,
	})
	local card = new("Frame", {
		Size = UDim2.fromOffset(120, 120), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = loadingGui,
	})
	local ring = new("Frame", {
		Size = UDim2.fromOffset(48, 48), Position = UDim2.fromScale(0.5, 0.4),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.Accent, Parent = card,
	})
	corner(ring, 24)
	accentGradient(ring, 0)
	stroke(ring, Theme.Border, 1)
	new("Frame", {
		Size = UDim2.fromOffset(24, 48), Position = UDim2.fromOffset(24, 0),
		BackgroundColor3 = Theme.Background, BorderSizePixel = 0, Parent = ring,
	})

	loadingConn = RunService.Heartbeat:Connect(function(dt)
		ring.Rotation = (ring.Rotation + dt * 240) % 360
	end)

	if text then
		new("TextLabel", {
			Text = text, Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text,
			BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -24), Size = UDim2.new(1, 0, 0, 20), Parent = card,
		})
	end
end

function CleanUI:HideLoading()
	if loadingConn then loadingConn:Disconnect(); loadingConn = nil end
	if loadingGui then loadingGui:Destroy(); loadingGui = nil end
end

-- CleanUI:SaveConfig() -> JSON string. Persist it yourself (DataStore, etc).
function CleanUI:SaveConfig()
	local data = {}
	for flag, entry in pairs(flagRegistry) do
		local ok, value = pcall(entry.Get)
		if ok then data[flag] = value end
	end
	return HttpService:JSONEncode(data)
end

-- CleanUI:LoadConfig(jsonString) applies saved values back onto flagged elements.
function CleanUI:LoadConfig(jsonString)
	local ok, data = pcall(function() return HttpService:JSONDecode(jsonString) end)
	if not ok or type(data) ~= "table" then return false end
	for flag, value in pairs(data) do
		local entry = flagRegistry[flag]
		if entry then pcall(entry.Set, value) end
	end
	return true
end

-- CleanUI:SetTheme("Pink" | "Blue" | "Mint") re-skins every accent gradient live.
function CleanUI:SetTheme(name)
	local preset = ThemePresets[name]
	if not preset then return false end
	Theme.Accent = preset.Accent
	Theme.Accent2 = preset.Accent2
	for _, g in ipairs(accentGradients) do
		pcall(function() g.Color = ColorSequence.new(Theme.Accent, Theme.Accent2) end)
	end
	return true
end

function CleanUI:CreateWindow(config)
	config = config or {}
	local title = config.Title or "CleanUI"

	local platform = config.Platform or askPlatform()
	local preset = PLATFORM_PRESETS[platform] or PLATFORM_PRESETS.PC
	local size = config.Size or preset.Size
	CleanUI.Platform = platform
	CleanUI.IsMobile = (platform == "Mobile")

	local screenGui = new("ScreenGui", {
		Name = "CleanUI_" .. title:gsub("%s+", ""),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	local root = new("Frame", {
		Name = "Root",
		Size = size,
		Position = UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = screenGui,
	})
	corner(root, 14)
	stroke(root, Theme.Border, 1)
	new("UIScale", { Scale = preset.Scale, Parent = root })

	new("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Border,
		BorderSizePixel = 0,
		Parent = root,
	})

	-- Tooltip helper (needs screenGui, so it lives inside CreateWindow)
	local function attachTooltip(obj, text)
		if not text then return end
		local tip
		obj.MouseEnter:Connect(function()
			local pos = UserInputService:GetMouseLocation()
			tip = new("TextLabel", {
				Text = text, Font = Theme.Font, TextSize = 12, TextColor3 = Theme.Text,
				BackgroundColor3 = Theme.Surface, TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.XY,
				ZIndex = 50,
				Parent = screenGui,
			})
			corner(tip, 6)
			stroke(tip, Theme.Border, 1)
			padding(tip, 6)
			tip.Position = UDim2.fromOffset(pos.X + 14, pos.Y - 8)
		end)
		obj.MouseMoved:Connect(function(x, y)
			if tip then tip.Position = UDim2.fromOffset(x + 14, y - 8) end
		end)
		obj.MouseLeave:Connect(function()
			if tip then tip:Destroy(); tip = nil end
		end)
	end

	-- Titlebar
	local titleBar = new("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		Parent = root,
	})
	corner(titleBar, 14)
	new("Frame", {
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, -14),
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		Parent = titleBar,
	})

	new("TextLabel", {
		Text = title,
		Font = Theme.FontBold,
		TextSize = 15,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -80, 1, 0),
		Position = UDim2.new(0, 16, 0, 0),
		Parent = titleBar,
	})

	local collapseBtn = new("TextButton", {
		Text = "-",
		Font = Theme.FontBold,
		TextSize = 16,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(1, -72, 0.5, -16),
		Parent = titleBar,
	})
	collapseBtn.MouseEnter:Connect(function() tween(collapseBtn, { TextColor3 = Theme.Text }, 0.12) end)
	collapseBtn.MouseLeave:Connect(function() tween(collapseBtn, { TextColor3 = Theme.SubText }, 0.12) end)

	local closeBtn = new("TextButton", {
		Text = "\xE2\x9C\x95",
		Font = Theme.Font,
		TextSize = 14,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(1, -38, 0.5, -16),
		Parent = titleBar,
	})
	closeBtn.MouseEnter:Connect(function() tween(closeBtn, { TextColor3 = Theme.Text }, 0.12) end)
	closeBtn.MouseLeave:Connect(function() tween(closeBtn, { TextColor3 = Theme.SubText }, 0.12) end)
	closeBtn.MouseButton1Click:Connect(function() screenGui.Enabled = false end)

	makeDraggable(titleBar, root)

	-- Tab bar
	local tabBar = new("Frame", {
		Name = "TabBar",
		Size = UDim2.new(0, 120, 1, -42),
		Position = UDim2.new(0, 0, 0, 42),
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		Parent = root,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabBar,
	})
	padding(tabBar, 8)

	-- Content area
	local contentArea = new("Frame", {
		Name = "ContentArea",
		Size = UDim2.new(1, -120, 1, -42),
		Position = UDim2.new(0, 120, 0, 42),
		BackgroundTransparency = 1,
		Parent = root,
	})

	local Window = setmetatable({
		_screenGui = screenGui,
		_root = root,
		_tabBar = tabBar,
		_contentArea = contentArea,
		_tabs = {},
		Platform = platform,
	}, { __index = {} })

	-- Collapse / expand: hides the window, shows a small draggable sun icon.
	local collapsedIcon = new("TextButton", {
		Name = "CleanUI_CollapsedIcon",
		Text = "\xE2\x98\x80",
		Font = Theme.FontBold,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundColor3 = Theme.Accent,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(0, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Visible = false,
		ZIndex = 10,
		Parent = screenGui,
	})
	corner(collapsedIcon, 24)
	accentGradient(collapsedIcon, 100)
	stroke(collapsedIcon, Theme.Border, 1)
	makeDraggable(collapsedIcon, collapsedIcon)

	collapseBtn.MouseButton1Click:Connect(function()
		collapsedIcon.Position = UDim2.new(
			0, root.AbsolutePosition.X + 21,
			0, root.AbsolutePosition.Y + 21
		)
		collapsedIcon.Visible = true
		collapsedIcon.Size = UDim2.fromOffset(0, 0)
		tween(collapsedIcon, { Size = UDim2.fromOffset(48, 48) }, 0.22, Enum.EasingStyle.Back)
		root.Visible = false
	end)

	collapsedIcon.MouseButton1Click:Connect(function()
		root.Position = UDim2.new(
			0, collapsedIcon.AbsolutePosition.X - 21,
			0, collapsedIcon.AbsolutePosition.Y - 21
		)
		root.Visible = true
		collapsedIcon.Visible = false
	end)

	-- Show/hide the whole window: keybind on PC, floating button on Mobile.
	if preset.ToggleKey then
		local toggleKey = config.ToggleKey or Enum.KeyCode.RightControl
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if input.KeyCode == toggleKey then
				screenGui.Enabled = not screenGui.Enabled
			end
		end)
	else
		local floatToggle = new("TextButton", {
			Name = "CleanUI_FloatToggle",
			Text = "\xE2\x98\xB0",
			Font = Theme.FontBold,
			TextSize = 18,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundColor3 = Theme.Accent,
			AutoButtonColor = false,
			Size = UDim2.fromOffset(46, 46),
			Position = UDim2.new(0, 16, 1, -62),
			Parent = screenGui,
		})
		corner(floatToggle, 23)
		accentGradient(floatToggle, 100)
		floatToggle.MouseButton1Click:Connect(function()
			screenGui.Enabled = not screenGui.Enabled
		end)
	end

	--// Shared element factory ------------------------------------------
	-- Used for both a Tab's page and any nested Section group, so
	-- Section:CreateButton(...) etc. work exactly like Tab:CreateButton(...).
	local buildElementAPI
	buildElementAPI = function(parentFrame)
		local API = {}
		local orderCounter = 0
		local function nextOrder()
			orderCounter = orderCounter + 1
			return orderCounter
		end

		function API:CreateLabel(cfg)
			cfg = cfg or {}
			local lbl = new("TextLabel", {
				Text = cfg.Text or "Label",
				Font = Theme.Font,
				TextSize = 13,
				TextColor3 = Theme.SubText,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 20),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = nextOrder(),
				Parent = parentFrame,
			})
			if cfg.Tooltip then attachTooltip(lbl, cfg.Tooltip) end
			return lbl
		end

		function API:CreateSection(cfg)
			cfg = cfg or {}
			local header = new("TextButton", {
				Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 24), LayoutOrder = nextOrder(), Parent = parentFrame,
			})
			new("TextLabel", {
				Text = (cfg.Text or "Section"):upper(), Font = Theme.FontBold, TextSize = 11,
				TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1, Size = UDim2.new(1, -20, 1, 0), Parent = header,
			})
			local chevron = new("TextLabel", {
				Text = "\xE2\x96\xBE", Font = Theme.Font, TextSize = 12, TextColor3 = Theme.SubText,
				BackgroundTransparency = 1, Size = UDim2.new(0, 16, 1, 0), Position = UDim2.new(1, -16, 0, 0), Parent = header,
			})

			local inner = new("Frame", {
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y, Visible = cfg.Collapsed ~= true,
				LayoutOrder = nextOrder(), Parent = parentFrame,
			})
			new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = inner })

			local open = cfg.Collapsed ~= true
			chevron.Rotation = open and 0 or -90
			header.MouseButton1Click:Connect(function()
				open = not open
				inner.Visible = open
				tween(chevron, { Rotation = open and 0 or -90 }, 0.15)
			end)

			return buildElementAPI(inner)
		end

		function API:CreateButton(cfg)
			cfg = cfg or {}
			local callback = cfg.Callback or function() end

			local btn = new("TextButton", {
				Text = cfg.Text or "Button",
				Font = Theme.FontBold,
				TextSize = 13,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundColor3 = Theme.Accent,
				AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, 38),
				LayoutOrder = nextOrder(),
				Parent = parentFrame,
			})
			corner(btn, Theme.Corner)
			accentGradient(btn, 100)

			btn.MouseEnter:Connect(function() tween(btn, { Size = UDim2.new(1, 0, 0, 40) }, 0.12) end)
			btn.MouseLeave:Connect(function() tween(btn, { Size = UDim2.new(1, 0, 0, 38) }, 0.12) end)
			btn.MouseButton1Click:Connect(function()
				tween(btn, { Size = UDim2.new(1, 0, 0, 35) }, 0.06)
				task.delay(0.06, function()
					if btn.Parent then tween(btn, { Size = UDim2.new(1, 0, 0, 40) }, 0.12) end
				end)
				local ok, err = pcall(callback)
				if not ok then warn("[CleanUI] Button callback error:", err) end
			end)

			if cfg.Tooltip then attachTooltip(btn, cfg.Tooltip) end
			return btn
		end

		function API:CreateToggle(cfg)
			cfg = cfg or {}
			local state = cfg.Default or false
			local callback = cfg.Callback or function() end

			local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = nextOrder(), Parent = parentFrame })
			new("TextLabel", {
				Text = cfg.Text or "Toggle", Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text,
				TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
				Size = UDim2.new(1, -50, 1, 0), Parent = holder,
			})

			local track = new("Frame", {
				Size = UDim2.new(0, 40, 0, 22), Position = UDim2.new(1, -40, 0.5, -11),
				BackgroundColor3 = state and Theme.Accent or Theme.SurfaceLight, Parent = holder,
			})
			corner(track, 11)
			stroke(track, Theme.Border, 1)
			local toggleGradient = accentGradient(track, 90)
			toggleGradient.Enabled = state

			local knob = new("Frame", {
				Size = UDim2.fromOffset(16, 16),
				Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
				BackgroundColor3 = Theme.Text, Parent = track,
			})
			corner(knob, 8)

			local function setState(v, fire)
				state = v
				tween(track, { BackgroundColor3 = state and Theme.Accent or Theme.SurfaceLight }, 0.15)
				toggleGradient.Enabled = state
				tween(knob, { Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8) }, 0.15)
				if fire ~= false then
					local ok, err = pcall(callback, state)
					if not ok then warn("[CleanUI] Toggle callback error:", err) end
				end
			end

			local clickArea = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = holder })
			clickArea.MouseButton1Click:Connect(function() setState(not state) end)

			registerFlag(cfg, function() return state end, function(v) setState(v, false) end)
			if cfg.Tooltip then attachTooltip(holder, cfg.Tooltip) end

			return { Set = function(_, v) setState(v, false) end, Get = function() return state end }
		end

		function API:CreateSlider(cfg)
			cfg = cfg or {}
			local min = cfg.Min or 0
			local max = cfg.Max or 100
			local value = math.clamp(cfg.Default or min, min, max)
			local callback = cfg.Callback or function() end
			local decimals = cfg.Decimals or 1

			local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), LayoutOrder = nextOrder(), Parent = parentFrame })
			new("TextLabel", {
				Text = cfg.Text or "Slider", Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text,
				TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
				Size = UDim2.new(1, -60, 0, 18), Parent = holder,
			})
			local valueLabel = new("TextLabel", {
				Text = tostring(value), Font = Theme.Font, TextSize = 13, TextColor3 = Theme.SubText,
				TextXAlignment = Enum.TextXAlignment.Right, BackgroundTransparency = 1,
				Size = UDim2.new(0, 60, 0, 18), Position = UDim2.new(1, -60, 0, 0), Parent = holder,
			})

			local track = new("Frame", {
				Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0, 30),
				BackgroundColor3 = Theme.SurfaceLight, Parent = holder,
			})
			corner(track, 3)
			local fill = new("Frame", {
				Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
				BackgroundColor3 = Theme.Accent, Parent = track,
			})
			corner(fill, 3)
			accentGradient(fill, 0)
			local knob = new("Frame", {
				Size = UDim2.fromOffset(14, 14),
				Position = UDim2.new((value - min) / (max - min), -7, 0.5, -7),
				BackgroundColor3 = Theme.Text, ZIndex = 2, Parent = track,
			})
			corner(knob, 7)

			local function setFromAlpha(alpha, fire)
				alpha = math.clamp(alpha, 0, 1)
				local raw = min + (max - min) * alpha
				value = math.floor(raw * 10 ^ decimals + 0.5) / 10 ^ decimals
				local a = (value - min) / (max - min)
				fill.Size = UDim2.new(a, 0, 1, 0)
				knob.Position = UDim2.new(a, -7, 0.5, -7)
				valueLabel.Text = tostring(value)
				if fire ~= false then
					local ok, err = pcall(callback, value)
					if not ok then warn("[CleanUI] Slider callback error:", err) end
				end
			end

			local dragging = false
			track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					setFromAlpha((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X)
				end
			end)
			UserInputService.InputChanged:Connect(function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					setFromAlpha((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X)
				end
			end)
			UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = false
				end
			end)

			registerFlag(cfg, function() return value end, function(v) setFromAlpha((v - min) / (max - min), false) end)
			if cfg.Tooltip then attachTooltip(holder, cfg.Tooltip) end

			return {
				Set = function(_, v) setFromAlpha((v - min) / (max - min), false) end,
				Get = function() return value end,
			}
		end

		function API:CreateDropdown(cfg)
			cfg = cfg or {}
			local options = cfg.Options or {}
			local selected = cfg.Default or options[1]
			local callback = cfg.Callback or function() end
			local open = false

			local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = nextOrder(), ClipsDescendants = false, Parent = parentFrame })
			local box = new("TextButton", { Text = "", BackgroundColor3 = Theme.SurfaceLight, Size = UDim2.new(1, 0, 0, 36), AutoButtonColor = false, Parent = holder })
			corner(box, Theme.Corner)
			stroke(box, Theme.Border, 1)

			new("TextLabel", {
				Text = cfg.Text and (cfg.Text .. ":") or "", Font = Theme.Font, TextSize = 12, TextColor3 = Theme.SubText,
				TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
				Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.new(0, 12, 0, 0), Parent = box,
			})
			local selectedLabel = new("TextLabel", {
				Text = tostring(selected or "Select..."), Font = Theme.FontBold, TextSize = 13, TextColor3 = Theme.Text,
				TextXAlignment = Enum.TextXAlignment.Right, BackgroundTransparency = 1,
				Size = UDim2.new(0.5, -30, 1, 0), Position = UDim2.new(0.5, 0, 0, 0), Parent = box,
			})
			new("TextLabel", {
				Text = "\xE2\x96\xBE", Font = Theme.Font, TextSize = 13, TextColor3 = Theme.SubText,
				BackgroundTransparency = 1, Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -24, 0, 0), Parent = box,
			})

			local list = new("Frame", {
				BackgroundColor3 = Theme.SurfaceLight, Size = UDim2.new(1, 0, 0, 0),
				Position = UDim2.new(0, 0, 1, 4), ClipsDescendants = true, Visible = false, ZIndex = 5, Parent = holder,
			})
			corner(list, Theme.Corner)
			stroke(list, Theme.Border, 1)
			new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
			padding(list, 4)

			local function setSelected(v, fire)
				selected = v
				selectedLabel.Text = tostring(v)
				if fire ~= false then
					local ok, err = pcall(callback, selected)
					if not ok then warn("[CleanUI] Dropdown callback error:", err) end
				end
			end

			local function rebuildOptions()
				for _, c in ipairs(list:GetChildren()) do
					if c:IsA("TextButton") then c:Destroy() end
				end
				for i, opt in ipairs(options) do
					local optBtn = new("TextButton", {
						Text = tostring(opt), Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text,
						TextXAlignment = Enum.TextXAlignment.Left, BackgroundColor3 = Theme.Surface,
						BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = i, ZIndex = 6, Parent = list,
					})
					padding(optBtn, 8)
					corner(optBtn, 6)
					optBtn.MouseEnter:Connect(function() tween(optBtn, { BackgroundTransparency = 0 }, 0.1) end)
					optBtn.MouseLeave:Connect(function() tween(optBtn, { BackgroundTransparency = 1 }, 0.1) end)
					optBtn.MouseButton1Click:Connect(function()
						setSelected(opt)
						open = false
						list.Visible = false
						list.Size = UDim2.new(1, 0, 0, 0)
					end)
				end
			end
			rebuildOptions()

			box.MouseButton1Click:Connect(function()
				open = not open
				list.Visible = open
				local target = open and math.min(#options * 28 + 8, 168) or 0
				tween(list, { Size = UDim2.new(1, 0, 0, target) }, 0.15)
			end)

			registerFlag(cfg, function() return selected end, function(v) setSelected(v, false) end)
			if cfg.Tooltip then attachTooltip(box, cfg.Tooltip) end

			return {
				Set = function(_, v) setSelected(v, false) end,
				Get = function() return selected end,
				Refresh = function(_, newOptions) options = newOptions; rebuildOptions() end,
			}
		end

		function API:CreateMultiDropdown(cfg)
			cfg = cfg or {}
			local options = cfg.Options or {}
			local selected = {}
			for _, v in ipairs(cfg.Default or {}) do selected[v] = true end
			local callback = cfg.Callback or function() end
			local open = false

			local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = nextOrder(), ClipsDescendants = false, Parent = parentFrame })
			local box = new("TextButton", { Text = "", BackgroundColor3 = Theme.SurfaceLight, Size = UDim2.new(1, 0, 0, 36), AutoButtonColor = false, Parent = holder })
			corner(box, Theme.Corner)
			stroke(box, Theme.Border, 1)

			new("TextLabel", {
				Text = cfg.Text and (cfg.Text .. ":") or "", Font = Theme.Font, TextSize = 12, TextColor3 = Theme.SubText,
				TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
				Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.new(0, 12, 0, 0), Parent = box,
			})
			local countLabel = new("TextLabel", {
				Text = "0 selected", Font = Theme.FontBold, TextSize = 12, TextColor3 = Theme.Text,
				TextXAlignment = Enum.TextXAlignment.Right, BackgroundTransparency = 1,
				Size = UDim2.new(0.5, -30, 1, 0), Position = UDim2.new(0.5, 0, 0, 0), Parent = box,
			})
			new("TextLabel", {
				Text = "\xE2\x96\xBE", Font = Theme.Font, TextSize = 13, TextColor3 = Theme.SubText,
				BackgroundTransparency = 1, Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -24, 0, 0), Parent = box,
			})

			local list = new("Frame", {
				BackgroundColor3 = Theme.SurfaceLight, Size = UDim2.new(1, 0, 0, 0),
				Position = UDim2.new(0, 0, 1, 4), ClipsDescendants = true, Visible = false, ZIndex = 5, Parent = holder,
			})
			corner(list, Theme.Corner)
			stroke(list, Theme.Border, 1)
			new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
			padding(list, 4)

			local function updateCount()
				local n = 0
				for _ in pairs(selected) do n = n + 1 end
				countLabel.Text = n .. " selected"
			end

			local function fire()
				local arr = {}
				for k in pairs(selected) do table.insert(arr, k) end
				table.sort(arr, function(a, b) return tostring(a) < tostring(b) end)
				local ok, err = pcall(callback, arr)
				if not ok then warn("[CleanUI] MultiDropdown callback error:", err) end
			end

			for i, opt in ipairs(options) do
				local row = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = i, ZIndex = 6, Parent = list })
				corner(row, 6)
				local check = new("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 6, 0.5, -8), BackgroundColor3 = Theme.Background, ZIndex = 7, Parent = row })
				corner(check, 4)
				stroke(check, Theme.Border, 1)
				local checkGrad = accentGradient(check, 100)
				checkGrad.Enabled = selected[opt] == true
				new("TextLabel", {
					Text = tostring(opt), Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
					Position = UDim2.new(0, 30, 0, 0), Size = UDim2.new(1, -34, 1, 0), ZIndex = 7, Parent = row,
				})
				row.MouseEnter:Connect(function() tween(row, { BackgroundTransparency = 0.85 }, 0.1) end)
				row.MouseLeave:Connect(function() tween(row, { BackgroundTransparency = 1 }, 0.1) end)
				row.MouseButton1Click:Connect(function()
					selected[opt] = (not selected[opt]) or nil
					checkGrad.Enabled = selected[opt] == true
					updateCount()
					fire()
				end)
			end
			updateCount()

			box.MouseButton1Click:Connect(function()
				open = not open
				list.Visible = open
				local target = open and math.min(#options * 28 + 8, 168) or 0
				tween(list, { Size = UDim2.new(1, 0, 0, target) }, 0.15)
			end)

			registerFlag(cfg,
				function() local arr = {}; for k in pairs(selected) do table.insert(arr, k) end; return arr end,
				function(v)
					if type(v) == "table" then
						selected = {}
						for _, val in ipairs(v) do selected[val] = true end
						updateCount()
					end
				end)
			if cfg.Tooltip then attachTooltip(box, cfg.Tooltip) end

			return {
				Get = function() local arr = {}; for k in pairs(selected) do table.insert(arr, k) end; return arr end,
				Set = function(_, v) selected = {}; for _, val in ipairs(v) do selected[val] = true end; updateCount() end,
			}
		end

		function API:CreateRadio(cfg)
			cfg = cfg or {}
			local options = cfg.Options or {}
			local selected = cfg.Default or options[1]
			local callback = cfg.Callback or function() end

			local holder = new("Frame", {
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20),
				AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), Parent = parentFrame,
			})
			if cfg.Text then
				new("TextLabel", {
					Text = cfg.Text, Font = Theme.Font, TextSize = 13, TextColor3 = Theme.SubText,
					TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 18), Parent = holder,
				})
			end
			local list = new("Frame", {
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0, 0, 0, cfg.Text and 22 or 0), Parent = holder,
			})
			new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

			local dots = {}
			local function refresh()
				for opt, dot in pairs(dots) do
					dot.BackgroundTransparency = (opt == selected) and 0 or 1
				end
			end

			for i, opt in ipairs(options) do
				local row = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = i, Parent = list })
				local ring = new("Frame", { Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0, 0, 0.5, -9), BackgroundColor3 = Theme.Background, Parent = row })
				corner(ring, 9)
				stroke(ring, Theme.Border, 1)
				local dot = new("Frame", {
					Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
					BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1, Parent = ring,
				})
				corner(dot, 5)
				accentGradient(dot, 100)
				new("TextLabel", {
					Text = tostring(opt), Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
					Position = UDim2.new(0, 26, 0, 0), Size = UDim2.new(1, -26, 1, 0), Parent = row,
				})
				dots[opt] = dot
				row.MouseButton1Click:Connect(function()
					selected = opt
					refresh()
					local ok, err = pcall(callback, opt)
					if not ok then warn("[CleanUI] Radio callback error:", err) end
				end)
			end
			refresh()

			registerFlag(cfg, function() return selected end, function(v) selected = v; refresh() end)
			if cfg.Tooltip then attachTooltip(holder, cfg.Tooltip) end

			return { Get = function() return selected end, Set = function(_, v) selected = v; refresh() end }
		end

		function API:CreateInput(cfg)
			cfg = cfg or {}
			local callback = cfg.Callback or function() end

			local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 54), LayoutOrder = nextOrder(), Parent = parentFrame })
			new("TextLabel", {
				Text = cfg.Text or "Text", Font = Theme.Font, TextSize = 13, TextColor3 = Theme.SubText,
				TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), Parent = holder,
			})

			local box = new("Frame", { BackgroundColor3 = Theme.SurfaceLight, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0, 20), Parent = holder })
			corner(box, Theme.Corner)
			local outline = stroke(box, Theme.Border, 1)

			local input = new("TextBox", {
				Text = cfg.Default or "", PlaceholderText = cfg.PlaceholderText or "Type here...", PlaceholderColor3 = Theme.SubText,
				Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1, ClearTextOnFocus = false, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 12, 0, 0), Parent = box,
			})

			input.Focused:Connect(function() tween(outline, { Color = Theme.Accent }, 0.15) end)
			input.FocusLost:Connect(function(enterPressed)
				tween(outline, { Color = Theme.Border }, 0.15)
				local ok, err = pcall(callback, input.Text, enterPressed)
				if not ok then warn("[CleanUI] Textbox callback error:", err) end
			end)

			registerFlag(cfg, function() return input.Text end, function(v) input.Text = tostring(v) end)
			if cfg.Tooltip then attachTooltip(box, cfg.Tooltip) end

			return {
				Get = function() return input.Text end,
				Set = function(_, v) input.Text = v end,
				Clear = function() input.Text = "" end,
			}
		end

		function API:CreateSearch(cfg)
			cfg = cfg or {}
			local callback = cfg.Callback or function() end

			local box = new("Frame", { BackgroundColor3 = Theme.SurfaceLight, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = nextOrder(), Parent = parentFrame })
			corner(box, Theme.Corner)
			local outline = stroke(box, Theme.Border, 1)

			new("TextLabel", {
				Text = "\xF0\x9F\x94\x8D", Font = Theme.Font, TextSize = 13, TextColor3 = Theme.SubText,
				BackgroundTransparency = 1, Size = UDim2.new(0, 28, 1, 0), Position = UDim2.new(0, 6, 0, 0), Parent = box,
			})
			local input = new("TextBox", {
				Text = "", PlaceholderText = cfg.PlaceholderText or "Search...", PlaceholderColor3 = Theme.SubText,
				Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1, ClearTextOnFocus = false, Size = UDim2.new(1, -40, 1, 0), Position = UDim2.new(0, 32, 0, 0), Parent = box,
			})

			input.Focused:Connect(function() tween(outline, { Color = Theme.Accent }, 0.15) end)
			input.FocusLost:Connect(function() tween(outline, { Color = Theme.Border }, 0.15) end)
			input:GetPropertyChangedSignal("Text"):Connect(function()
				local ok, err = pcall(callback, input.Text)
				if not ok then warn("[CleanUI] Search callback error:", err) end
			end)

			if cfg.Tooltip then attachTooltip(box, cfg.Tooltip) end

			return {
				Get = function() return input.Text end,
				Set = function(_, v) input.Text = v end,
				Clear = function() input.Text = "" end,
			}
		end

		function API:CreateColorPicker(cfg)
			cfg = cfg or {}
			local color = cfg.Default or Color3.fromRGB(255, 92, 141)
			local callback = cfg.Callback or function() end
			local hue, sat, val = Color3.toHSV(color)

			local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = nextOrder(), ClipsDescendants = false, Parent = parentFrame })
			new("TextLabel", {
				Text = cfg.Text or "Color", Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text,
				TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Size = UDim2.new(1, -50, 1, 0), Parent = holder,
			})
			local swatch = new("TextButton", { Text = "", BackgroundColor3 = color, AutoButtonColor = false, Size = UDim2.new(0, 36, 0, 26), Position = UDim2.new(1, -36, 0.5, -13), Parent = holder })
			corner(swatch, 8)
			stroke(swatch, Theme.Border, 1)

			local popup = new("Frame", {
				Size = UDim2.new(1, 0, 0, 150), Position = UDim2.new(0, 0, 1, 6),
				BackgroundColor3 = Theme.SurfaceLight, Visible = false, ZIndex = 5, Parent = holder,
			})
			corner(popup, Theme.Corner)
			stroke(popup, Theme.Border, 1)
			padding(popup, 10)

			local svBox = new("Frame", { Size = UDim2.new(1, 0, 0, 90), BackgroundColor3 = Color3.fromHSV(hue, 1, 1), ZIndex = 6, Parent = popup })
			corner(svBox, 8)
			local whiteGrad = new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hue, 1, 1)), Rotation = 0, Parent = svBox })
			local blackOverlay = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 7, Parent = svBox })
			corner(blackOverlay, 8)
			new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }), Rotation = 90, Parent = blackOverlay })
			local svCursor = new("Frame", {
				Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1),
				Position = UDim2.new(sat, 0, 1 - val, 0), ZIndex = 8, Parent = svBox,
			})
			corner(svCursor, 5)
			stroke(svCursor, Color3.new(0, 0, 0), 1)

			local hueBar = new("Frame", { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 0, 98), ZIndex = 6, Parent = popup })
			corner(hueBar, 8)
			local hueKeypoints = {}
			for i = 0, 6 do
				table.insert(hueKeypoints, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)))
			end
			new("UIGradient", { Color = ColorSequence.new(hueKeypoints), Rotation = 0, Parent = hueBar })
			local hueCursor = new("Frame", {
				Size = UDim2.fromOffset(6, 20), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1),
				Position = UDim2.new(hue, 0, 0.5, 0), ZIndex = 8, Parent = hueBar,
			})
			corner(hueCursor, 3)
			stroke(hueCursor, Color3.new(0, 0, 0), 1)

			local function fire()
				local ok, err = pcall(callback, color)
				if not ok then warn("[CleanUI] ColorPicker callback error:", err) end
			end
			local function refresh()
				color = Color3.fromHSV(hue, sat, val)
				swatch.BackgroundColor3 = color
				svBox.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
				whiteGrad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hue, 1, 1))
				svCursor.Position = UDim2.new(sat, 0, 1 - val, 0)
				hueCursor.Position = UDim2.new(hue, 0, 0.5, 0)
			end

			local svDragging, hueDragging = false, false
			svBox.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					svDragging = true
				end
			end)
			hueBar.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					hueDragging = true
				end
			end)
			UserInputService.InputChanged:Connect(function(input)
				if not (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then return end
				if svDragging then
					sat = math.clamp((input.Position.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X, 0, 1)
					val = 1 - math.clamp((input.Position.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y, 0, 1)
					refresh(); fire()
				elseif hueDragging then
					hue = math.clamp((input.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
					refresh(); fire()
				end
			end)
			UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					svDragging, hueDragging = false, false
				end
			end)

			swatch.MouseButton1Click:Connect(function()
				popup.Visible = not popup.Visible
			end)

			registerFlag(cfg,
				function() return { R = color.R, G = color.G, B = color.B } end,
				function(v)
					if type(v) == "table" then
						hue, sat, val = Color3.toHSV(Color3.new(v.R or 0, v.G or 0, v.B or 0))
						refresh()
					end
				end)
			if cfg.Tooltip then attachTooltip(swatch, cfg.Tooltip) end

			return {
				Get = function() return color end,
				Set = function(_, c) hue, sat, val = Color3.toHSV(c); refresh() end,
			}
		end

		function API:CreateKeybind(cfg)
			cfg = cfg or {}
			local callback = cfg.Callback or function() end
			local key = cfg.Default

			local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = nextOrder(), Parent = parentFrame })
			new("TextLabel", {
				Text = cfg.Text or "Keybind", Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text,
				TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Size = UDim2.new(1, -90, 1, 0), Parent = holder,
			})

			if CleanUI.IsMobile then
				-- No physical keyboard on touch devices: show a disabled
				-- placeholder instead of a capture box that could never fire.
				new("TextLabel", {
					Text = "N/A on mobile", Font = Theme.Font, TextSize = 12, TextColor3 = Theme.SubText,
					BackgroundTransparency = 1, Size = UDim2.new(0, 90, 1, 0), Position = UDim2.new(1, -90, 0, 0),
					TextXAlignment = Enum.TextXAlignment.Right, Parent = holder,
				})
				return { Get = function() return nil end, Set = function() end }
			end

			local box = new("TextButton", {
				Text = key and key.Name or "...", Font = Theme.FontBold, TextSize = 12, TextColor3 = Theme.Text,
				BackgroundColor3 = Theme.SurfaceLight, AutoButtonColor = false, Size = UDim2.new(0, 80, 0, 28),
				Position = UDim2.new(1, -80, 0.5, -14), Parent = holder,
			})
			corner(box, 8)
			stroke(box, Theme.Border, 1)

			local listening = false
			box.MouseButton1Click:Connect(function()
				listening = true
				box.Text = "..."
				tween(box, { BackgroundColor3 = Theme.Accent }, 0.12)
			end)

			UserInputService.InputBegan:Connect(function(input)
				if not listening then return end
				if input.UserInputType == Enum.UserInputType.Keyboard then
					key = input.KeyCode
					box.Text = key.Name
					listening = false
					tween(box, { BackgroundColor3 = Theme.SurfaceLight }, 0.12)
					local ok, err = pcall(callback, key)
					if not ok then warn("[CleanUI] Keybind callback error:", err) end
				end
			end)

			registerFlag(cfg, function() return key and key.Name or nil end, function(v)
				if v and Enum.KeyCode[v] then
					key = Enum.KeyCode[v]
					box.Text = key.Name
				end
			end)
			if cfg.Tooltip then attachTooltip(box, cfg.Tooltip) end

			return {
				Get = function() return key end,
				Set = function(_, k) key = k; box.Text = k and k.Name or "..." end,
			}
		end

		function API:CreateProgressBar(cfg)
			cfg = cfg or {}
			local progress = math.clamp(cfg.Default or 0, 0, 1)

			local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = nextOrder(), Parent = parentFrame })
			new("TextLabel", {
				Text = cfg.Text or "Progress", Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text,
				TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Size = UDim2.new(1, -50, 0, 18), Parent = holder,
			})
			local pctLabel = new("TextLabel", {
				Text = math.floor(progress * 100) .. "%", Font = Theme.Font, TextSize = 12, TextColor3 = Theme.SubText,
				TextXAlignment = Enum.TextXAlignment.Right, BackgroundTransparency = 1, Size = UDim2.new(0, 50, 0, 18), Position = UDim2.new(1, -50, 0, 0), Parent = holder,
			})
			local track = new("Frame", { Size = UDim2.new(1, 0, 0, 8), Position = UDim2.new(0, 0, 0, 24), BackgroundColor3 = Theme.SurfaceLight, Parent = holder })
			corner(track, 4)
			local fill = new("Frame", { Size = UDim2.new(progress, 0, 1, 0), BackgroundColor3 = Theme.Accent, Parent = track })
			corner(fill, 4)
			accentGradient(fill, 0)

			if cfg.Tooltip then attachTooltip(holder, cfg.Tooltip) end

			return {
				Set = function(_, v)
					progress = math.clamp(v, 0, 1)
					tween(fill, { Size = UDim2.new(progress, 0, 1, 0) }, 0.2)
					pctLabel.Text = math.floor(progress * 100) .. "%"
				end,
				Get = function() return progress end,
			}
		end

		return API
	end

	function Window:CreateTab(name)
		local tabButton = new("TextButton", {
			Text = name, Font = Theme.Font, TextSize = 13, TextColor3 = Theme.SubText,
			BackgroundColor3 = Theme.SurfaceLight, BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 32), Parent = tabBar,
		})
		corner(tabButton, 8)

		local page = new("ScrollingFrame", {
			Name = name .. "Page", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Border, CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = contentArea,
		})
		padding(page, 16)
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })

		local function selectTab()
			for _, t in pairs(Window._tabs) do
				t.button.BackgroundTransparency = 1
				t.button.TextColor3 = Theme.SubText
				t.page.Visible = false
			end
			tween(tabButton, { BackgroundTransparency = 0 }, 0.15)
			tabButton.TextColor3 = Theme.Text
			page.Visible = true
		end

		tabButton.MouseButton1Click:Connect(selectTab)
		tabButton.MouseEnter:Connect(function()
			if not page.Visible then tween(tabButton, { BackgroundTransparency = 0.6 }, 0.12) end
		end)
		tabButton.MouseLeave:Connect(function()
			if not page.Visible then tween(tabButton, { BackgroundTransparency = 1 }, 0.12) end
		end)

		table.insert(Window._tabs, { button = tabButton, page = page, select = selectTab })
		if #Window._tabs == 1 then selectTab() end

		return buildElementAPI(page)
	end

	return Window
end

return CleanUI
