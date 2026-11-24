-- File: RBXM.lua (Tema Glassmorphism Bening & Gradasi Gemini)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local RBXMImporter = {}
local selectedFilePath: string? = nil
local isMinimized = false

-- Membersihkan UI lama jika skrip dijalankan ulang
local existingGui = (gethui and gethui():FindFirstChild("GeminiRBXMImporter")) or CoreGui:FindFirstChild("GeminiRBXMImporter")
if existingGui then
	existingGui:Destroy()
end

-- Fungsi Pemindai File .rbxm / .rbxmx di Workspace
local function getRBXMFiles(directory: string?): {string}
	local results = {}
	if not listfiles then
		return results
	end

	local function scan(currentPath: string)
		local ok, items = pcall(function()
			return listfiles(currentPath)
		end)
		if not ok or not items then return end

		for _, item in ipairs(items) do
			local normalized = item:gsub("\\", "/")
			if isfolder and isfolder(normalized) then
				scan(normalized)
			elseif normalized:lower():match("%.rbxm[x]?$") then
				table.insert(results, normalized)
			end
		end
	end

	scan(directory or "")
	return results
end

-- Fungsi Import Model ke Workspace
function RBXMImporter.ImportFile(filePath: string)
	if not filePath or filePath == "" then
		return false, "Pilih file terlebih dahulu!"
	end

	local assetUrl = nil
	if getcustomasset then
		assetUrl = getcustomasset(filePath)
	elseif getsynasset then
		assetUrl = getsynasset(filePath)
	else
		return false, "getcustomasset tidak didukung."
	end

	local success, objects = pcall(function()
		return game:GetObjects(assetUrl)
	end)

	if not success or not objects or #objects == 0 then
		return false, "Gagal membaca file RBXM."
	end

	local cleanName = filePath:match("([^/\\]+)%.rbxm[x]?$") or "ImportedModel"
	local container = Instance.new("Folder")
	container.Name = cleanName
	container.Parent = workspace

	for _, obj in ipairs(objects) do
		if typeof(obj) == "Instance" then
			obj.Parent = container
		end
	end

	return true, "Berhasil import: " .. cleanName
end

-- Membangun Antarmuka UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GeminiRBXMImporter"
screenGui.ResetOnSpawn = false
screenGui.Parent = (gethui and gethui()) or CoreGui

-- Main Frame (Efek Kaca Bening + Gradasi Gemini)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 320, 0, 360)
mainFrame.Position = UDim2.new(0.5, -160, 0.5, -180)
mainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
mainFrame.BackgroundTransparency = 0.78 -- Transparansi kaca bening
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 16)
mainCorner.Parent = mainFrame

-- Gradasi Warna Latar Khas Gemini (Biru Muda -> Ungu -> Indigo Lembut)
local geminiGradient = Instance.new("UIGradient")
geminiGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(168, 210, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(195, 175, 255)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(130, 170, 255))
})
geminiGradient.Rotation = 45
geminiGradient.Parent = mainFrame

-- Border Kaca Bening (Glass Stroke)
local glassStroke = Instance.new("UIStroke")
glassStroke.Color = Color3.fromRGB(255, 255, 255)
glassStroke.Transparency = 0.45
glassStroke.Thickness = 1.5
glassStroke.Parent = mainFrame

-- Header Bar
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
header.BackgroundTransparency = 0.85
header.BorderSizePixel = 0
header.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -95, 1, 0)
titleLabel.Position = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "✦ RBXM Importer"
titleLabel.TextColor3 = Color3.fromRGB(25, 35, 65)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 15
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

-- Tombol Buka / Tutup (Minimize/Expand)
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ToggleButton"
toggleBtn.Size = UDim2.new(0, 68, 0, 28)
toggleBtn.Position = UDim2.new(1, -80, 0.5, -14)
toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.BackgroundTransparency = 0.55
toggleBtn.Text = "Tutup"
toggleBtn.TextColor3 = Color3.fromRGB(30, 45, 90)
toggleBtn.Font = Enum.Font.GothamSemibold
toggleBtn.TextSize = 12
toggleBtn.Parent = header

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 8)
toggleCorner.Parent = toggleBtn

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = Color3.fromRGB(255, 255, 255)
toggleStroke.Transparency = 0.4
toggleStroke.Thickness = 1
toggleStroke.Parent = toggleBtn

-- Area Konten Utama
local contentFrame = Instance.new("Frame")
contentFrame.Name = "Content"
contentFrame.Size = UDim2.new(1, -24, 1, -56)
contentFrame.Position = UDim2.new(0, 12, 0, 48)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

-- Label Subjudul + Tombol Refresh Scan
local subHeader = Instance.new("Frame")
subHeader.Size = UDim2.new(1, 0, 0, 26)
subHeader.BackgroundTransparency = 1
subHeader.Parent = contentFrame

local pickLabel = Instance.new("TextLabel")
pickLabel.Size = UDim2.new(0.7, 0, 1, 0)
pickLabel.BackgroundTransparency = 1
pickLabel.Text = "Pilih File (.rbxm):"
pickLabel.TextColor3 = Color3.fromRGB(30, 40, 75)
pickLabel.Font = Enum.Font.GothamSemibold
pickLabel.TextSize = 13
pickLabel.TextXAlignment = Enum.TextXAlignment.Left
pickLabel.Parent = subHeader

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0, 65, 0, 22)
refreshBtn.Position = UDim2.new(1, -65, 0.5, -11)
refreshBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
refreshBtn.BackgroundTransparency = 0.6
refreshBtn.Text = "↻ Scan"
refreshBtn.TextColor3 = Color3.fromRGB(45, 70, 150)
refreshBtn.Font = Enum.Font.GothamSemibold
refreshBtn.TextSize = 11
refreshBtn.Parent = subHeader

local refreshCorner = Instance.new("UICorner")
refreshCorner.CornerRadius = UDim.new(0, 6)
refreshCorner.Parent = refreshBtn

-- Daftar Scrollable File
local fileListFrame = Instance.new("ScrollingFrame")
fileListFrame.Name = "FileList"
fileListFrame.Size = UDim2.new(1, 0, 0, 195)
fileListFrame.Position = UDim2.new(0, 0, 0, 32)
fileListFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
fileListFrame.BackgroundTransparency = 0.82
fileListFrame.BorderSizePixel = 0
fileListFrame.ScrollBarThickness = 4
fileListFrame.ScrollBarImageColor3 = Color3.fromRGB(110, 140, 230)
fileListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
fileListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
fileListFrame.Parent = contentFrame

local listCorner = Instance.new("UICorner")
listCorner.CornerRadius = UDim.new(0, 10)
listCorner.Parent = fileListFrame

local listStroke = Instance.new("UIStroke")
listStroke.Color = Color3.fromRGB(255, 255, 255)
listStroke.Transparency = 0.55
listStroke.Thickness = 1
listStroke.Parent = fileListFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = fileListFrame

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 6)
listPadding.PaddingBottom = UDim.new(0, 6)
listPadding.PaddingLeft = UDim.new(0, 6)
listPadding.PaddingRight = UDim.new(0, 6)
listPadding.Parent = fileListFrame

-- Status Label
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.Position = UDim2.new(0, 0, 0, 232)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Siap memindai folder Workspace..."
statusLabel.TextColor3 = Color3.fromRGB(45, 55, 95)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
statusLabel.Parent = contentFrame

-- Tombol Import Utama (Gradasi Biru-Ungu Gemini)
local importBtn = Instance.new("TextButton")
importBtn.Name = "ImportButton"
importBtn.Size = UDim2.new(1, 0, 0, 38)
importBtn.Position = UDim2.new(0, 0, 1, -42)
importBtn.BackgroundColor3 = Color3.fromRGB(90, 130, 255)
importBtn.BackgroundTransparency = 0.15
importBtn.Text = "Import Model"
importBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
importBtn.Font = Enum.Font.GothamBold
importBtn.TextSize = 14
importBtn.Parent = contentFrame

local importCorner = Instance.new("UICorner")
importCorner.CornerRadius = UDim.new(0, 10)
importCorner.Parent = importBtn

local importGradient = Instance.new("UIGradient")
importGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(75, 135, 255)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(145, 105, 255))
})
importGradient.Parent = importBtn

-- Fungsi Mengisi Ulang Daftar File
local fileButtons = {}
local function populateFileList()
	for _, btn in ipairs(fileButtons) do
		btn:Destroy()
	end
	table.clear(fileButtons)
	selectedFilePath = nil

	local files = getRBXMFiles("")
	if #files == 0 then
		statusLabel.Text = "Tidak ada file .rbxm ditemukan di Workspace."
		return
	end

	statusLabel.Text = "Ditemukan " .. tostring(#files) .. " file. Pilih salah satu."

	for _, filePath in ipairs(files) do
		local fileName = filePath:match("([^/\\]+)$") or filePath
		local itemBtn = Instance.new("TextButton")
		itemBtn.Size = UDim2.new(1, 0, 0, 30)
		itemBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		itemBtn.BackgroundTransparency = 0.72
		itemBtn.Text = "  📄 " .. fileName
		itemBtn.TextColor3 = Color3.fromRGB(25, 35, 70)
		itemBtn.Font = Enum.Font.GothamMedium
		itemBtn.TextSize = 12
		itemBtn.TextXAlignment = Enum.TextXAlignment.Left
		itemBtn.TextTruncate = Enum.TextTruncate.AtEnd
		itemBtn.Parent = fileListFrame

		local itemCorner = Instance.new("UICorner")
		itemCorner.CornerRadius = UDim.new(0, 7)
		itemCorner.Parent = itemBtn

		itemBtn.MouseButton1Click:Connect(function()
			selectedFilePath = filePath
			statusLabel.Text = "Terpilih: " .. fileName

			-- Reset warna item lain dan sorot item terpilih
			for _, other in ipairs(fileButtons) do
				other.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				other.BackgroundTransparency = 0.72
				other.TextColor3 = Color3.fromRGB(25, 35, 70)
			end
			itemBtn.BackgroundColor3 = Color3.fromRGB(100, 140, 255)
			itemBtn.BackgroundTransparency = 0.35
			itemBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end)

		table.insert(fileButtons, itemBtn)
	end
end

-- Event Tombol Buka / Tutup
toggleBtn.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	local targetSize = isMinimized and UDim2.new(0, 320, 0, 44) or UDim2.new(0, 320, 0, 360)
	toggleBtn.Text = isMinimized and "Buka" or "Tutup"

	TweenService:Create(
		mainFrame,
		TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Size = targetSize }
	):Play()
end)

-- Event Tombol Scan Ulang
refreshBtn.MouseButton1Click:Connect(function()
	populateFileList()
end)

-- Event Tombol Import
importBtn.MouseButton1Click:Connect(function()
	if not selectedFilePath then
		statusLabel.Text = "⚠ Silakan pilih file terlebih dahulu!"
		return
	end

	statusLabel.Text = "Memuat model..."
	local ok, msg = RBXMImporter.ImportFile(selectedFilePath)
	statusLabel.Text = (ok and "✔ " or "✖ ") .. msg
end)

-- Jalankan scan otomatis saat pertama dibuka
populateFileList()

return RBXMImporter
