-- File: RBXM.lua (Alur Loader + Multi-Format Importer + Glass UI + Smooth Drag)
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local RBXMImporter = {}
local selectedFilePath: string? = nil
local isMinimized = false
local importedScripts: {LuaSourceContainer} = {}

local SOURCE_URL = "https://raw.githubusercontent.com/rasya0907/syaahub/refs/heads/main/syaahubv2"

-- Membersihkan UI lama jika skrip dijalankan ulang
local existingGui = (gethui and gethui():FindFirstChild("GeminiRBXMImporter")) or CoreGui:FindFirstChild("GeminiRBXMImporter")
if existingGui then
	existingGui:Destroy()
end

-- 1. Pemindai File .rbxm, .rbxmx, .rbxl, dan .rbxlx
local function getSupportedFiles(directory: string?): {string}
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
			elseif normalized:lower():match("%.rbxm[x]?$") or normalized:lower():match("%.rbxl[x]?$") then
				table.insert(results, normalized)
			end
		end
	end

	scan(directory or "")
	return results
end

-- 2. Pemindah Anak Objek Aman (Melewati PackageLink)
local function safeMoveChildren(sourceParent: Instance, targetParent: Instance)
	for _, child in ipairs(sourceParent:GetChildren()) do
		if child:IsA("PackageLink") then
			continue
		end

		pcall(function()
			child.Parent = targetParent
		end)
	end
end

-- 3. Ekstraksi Isi Objek (Mendukung Model & Struktur Service pada .rbxl)
local placeContainerClasses = {
	Workspace = true,
	ReplicatedStorage = true,
	ServerScriptService = true,
	ServerStorage = true,
	StarterGui = true,
	StarterPack = true,
	StarterPlayer = true,
	Lighting = true,
	SoundService = true,
	Chat = true,
	Teams = true,
	ReplicatedFirst = true,
}

local function extractIntoContainer(objects: {Instance}, container: Folder)
	for _, obj in ipairs(objects) do
		if typeof(obj) ~= "Instance" or obj:IsA("PackageLink") then
			continue
		end

		if placeContainerClasses[obj.ClassName] then
			local subFolder = Instance.new("Folder")
			subFolder.Name = obj.Name
			safeMoveChildren(obj, subFolder)

			if #subFolder:GetChildren() > 0 then
				subFolder.Parent = container
			else
				subFolder:Destroy()
			end

			pcall(function()
				obj:Destroy()
			end)
		else
			local moved = pcall(function()
				obj.Parent = container
			end)
			if not moved then
				safeMoveChildren(obj, container)
			end
		end
	end
end

-- 4. Membuat Ulang Script agar Mempertahankan Nama Asli & Anak Objek
local function rebuildScriptsEditable(root: Instance): {LuaSourceContainer}
	local createdScripts = {}
	local targets = {}

	for _, desc in ipairs(root:GetDescendants()) do
		if desc:IsA("LocalScript") or desc:IsA("Script") or desc:IsA("ModuleScript") then
			table.insert(targets, desc)
		end
	end

	for _, oldScript in ipairs(targets) do
		if not oldScript.Parent then
			continue
		end

		local scriptName = oldScript.Name
		local scriptParent = oldScript.Parent
		local className = oldScript.ClassName

		local rawSource = ""
		pcall(function()
			rawSource = oldScript.Source
		end)

		local isDisabled = false
		if oldScript:IsA("BaseScript") then
			pcall(function()
				isDisabled = oldScript.Disabled
			end)
		end

		local runCtx = nil
		if oldScript:IsA("Script") then
			pcall(function()
				runCtx = oldScript.RunContext
			end)
		end

		local okNew, freshScript = pcall(function()
			return Instance.new(className)
		end)

		if okNew and freshScript then
			freshScript.Name = scriptName

			for _, child in ipairs(oldScript:GetChildren()) do
				if not child:IsA("PackageLink") then
					pcall(function()
						child.Parent = freshScript
					end)
				end
			end

			local parentOk = pcall(function()
				freshScript.Parent = scriptParent
			end)

			if parentOk then
				pcall(function()
					freshScript.Source = rawSource
				end)

				if freshScript:IsA("BaseScript") then
					pcall(function()
						freshScript.Disabled = isDisabled
					end)
				end

				if freshScript:IsA("Script") and runCtx ~= nil then
					pcall(function()
						freshScript.RunContext = runCtx
					end)
				end

				pcall(function()
					oldScript:Destroy()
				end)

				table.insert(createdScripts, freshScript)
			else
				freshScript:Destroy()
			end
		end
	end

	return createdScripts
end

-- 5. Fungsi Import File (.rbxm, .rbxmx, .rbxl, .rbxlx)
function RBXMImporter.ImportFile(filePath: string)
	if not filePath or filePath == "" then
		return false, "Pilih file terlebih dahulu!", {}
	end

	local isPlaceFile = filePath:lower():match("%.rbxl[x]?$") ~= nil

	local assetUrl = nil
	if getcustomasset then
		local okAsset, res = pcall(getcustomasset, filePath)
		if okAsset then assetUrl = res end
	end
	if not assetUrl and getsynasset then
		local okSyn, res = pcall(getsynasset, filePath)
		if okSyn then assetUrl = res end
	end

	if not assetUrl then
		return false, "Gagal membuat custom asset dari file.", {}
	end

	local success, objects = pcall(function()
		return game:GetObjects(assetUrl)
	end)

	if not success or not objects or #objects == 0 then
		if isPlaceFile then
			return false, "Format .rbxl gagal dibaca GetObjects di runtime ini.", {}
		end
		return false, "Gagal membaca file RBXM/RBXL.", {}
	end

	local cleanName = filePath:match("([^/\\]+)%.rbx[ml][x]?$") or "ImportedModel"
	local container = Instance.new("Folder")
	container.Name = cleanName
	container.Parent = workspace

	extractIntoContainer(objects, container)

	if #container:GetChildren() == 0 then
		pcall(function()
			container:Destroy()
		end)
		if isPlaceFile then
			return false, ".rbxl tidak menghasilkan objek isi. Export/simpan ke .rbxm.", {}
		end
		return false, "Tidak ada objek valid yang bisa di-import.", {}
	end

	local scriptsFound = rebuildScriptsEditable(container)
	local totalItems = #container:GetDescendants()
	return true, "Berhasil: " .. cleanName .. " (" .. tostring(totalItems) .. " item, " .. tostring(#scriptsFound) .. " script)", scriptsFound
end

-- 6. Fungsi Menjalankan Alur Loader dari URL Sumber
function RBXMImporter.RunRemoteLoader()
	local okHttp, body = pcall(function()
		return game:HttpGet(SOURCE_URL)
	end)
	if not okHttp or not body or body == "" then
		return false, "Gagal mengambil skrip dari URL."
	end

	local okFn, fn = pcall(loadstring, body)
	if not okFn or type(fn) ~= "function" then
		return false, "Gagal mengompilasi skrip dari URL."
	end

	local okRun, err = pcall(fn)
	if not okRun then
		return false, "Error saat menjalankan loader: " .. tostring(err)
	end

	return true, "Loader dari URL berhasil dijalankan."
end

-- 7. Membangun Antarmuka UI (Kaca Solid Gradasi Gemini + Drag Bebas)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GeminiRBXMImporter"
screenGui.ResetOnSpawn = false
screenGui.Parent = (gethui and gethui()) or CoreGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 315, 0, 415)
mainFrame.Position = UDim2.new(0.5, -157, 0.5, -207)
mainFrame.BackgroundColor3 = Color3.fromRGB(238, 244, 255)
mainFrame.BackgroundTransparency = 0.2
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = mainFrame

local geminiGradient = Instance.new("UIGradient")
geminiGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(218, 234, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(228, 220, 255)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(205, 224, 255))
})
geminiGradient.Rotation = 35
geminiGradient.Parent = mainFrame

local glassStroke = Instance.new("UIStroke")
glassStroke.Color = Color3.fromRGB(255, 255, 255)
glassStroke.Transparency = 0.25
glassStroke.Thickness = 1.5
glassStroke.Parent = mainFrame

-- Header Bar (Area Geser / Drag)
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 42)
header.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
header.BackgroundTransparency = 0.45
header.BorderSizePixel = 0
header.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -92, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "✦ RBXM / RBXL Importer"
titleLabel.TextColor3 = Color3.fromRGB(22, 32, 62)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ToggleButton"
toggleBtn.Size = UDim2.new(0, 64, 0, 26)
toggleBtn.Position = UDim2.new(1, -76, 0.5, -13)
toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.BackgroundTransparency = 0.25
toggleBtn.Text = "Tutup"
toggleBtn.TextColor3 = Color3.fromRGB(28, 42, 85)
toggleBtn.Font = Enum.Font.GothamSemibold
toggleBtn.TextSize = 11
toggleBtn.Parent = header

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 7)
toggleCorner.Parent = toggleBtn

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = Color3.fromRGB(160, 185, 245)
toggleStroke.Transparency = 0.4
toggleStroke.Thickness = 1
toggleStroke.Parent = toggleBtn

-- Area Konten Utama
local contentFrame = Instance.new("Frame")
contentFrame.Name = "Content"
contentFrame.Size = UDim2.new(1, -24, 1, -52)
contentFrame.Position = UDim2.new(0, 12, 0, 46)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

local subHeader = Instance.new("Frame")
subHeader.Size = UDim2.new(1, 0, 0, 22)
subHeader.BackgroundTransparency = 1
subHeader.Parent = contentFrame

local pickLabel = Instance.new("TextLabel")
pickLabel.Size = UDim2.new(0.72, 0, 1, 0)
pickLabel.BackgroundTransparency = 1
pickLabel.Text = "File (.rbxm / .rbxl):"
pickLabel.TextColor3 = Color3.fromRGB(25, 35, 70)
pickLabel.Font = Enum.Font.GothamSemibold
pickLabel.TextSize = 12
pickLabel.TextXAlignment = Enum.TextXAlignment.Left
pickLabel.Parent = subHeader

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0, 62, 0, 20)
refreshBtn.Position = UDim2.new(1, -62, 0.5, -10)
refreshBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
refreshBtn.BackgroundTransparency = 0.25
refreshBtn.Text = "↻ Scan"
refreshBtn.TextColor3 = Color3.fromRGB(45, 70, 155)
refreshBtn.Font = Enum.Font.GothamSemibold
refreshBtn.TextSize = 11
refreshBtn.Parent = subHeader

local refreshCorner = Instance.new("UICorner")
refreshCorner.CornerRadius = UDim.new(0, 6)
refreshCorner.Parent = refreshBtn

-- Daftar File
local fileListFrame = Instance.new("ScrollingFrame")
fileListFrame.Name = "FileList"
fileListFrame.Size = UDim2.new(1, 0, 0, 115)
fileListFrame.Position = UDim2.new(0, 0, 0, 25)
fileListFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
fileListFrame.BackgroundTransparency = 0.35
fileListFrame.BorderSizePixel = 0
fileListFrame.ScrollBarThickness = 4
fileListFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 130, 225)
fileListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
fileListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
fileListFrame.Parent = contentFrame

local listCorner = Instance.new("UICorner")
listCorner.CornerRadius = UDim.new(0, 9)
listCorner.Parent = fileListFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = fileListFrame

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 5)
listPadding.PaddingBottom = UDim.new(0, 5)
listPadding.PaddingLeft = UDim.new(0, 5)
listPadding.PaddingRight = UDim.new(0, 5)
listPadding.Parent = fileListFrame

-- Label Daftar Script Hasil Import
local scriptHeaderLabel = Instance.new("TextLabel")
scriptHeaderLabel.Size = UDim2.new(1, 0, 0, 18)
scriptHeaderLabel.Position = UDim2.new(0, 0, 0, 144)
scriptHeaderLabel.BackgroundTransparency = 1
scriptHeaderLabel.Text = "Script Terdeteksi (Klik untuk salin path):"
scriptHeaderLabel.TextColor3 = Color3.fromRGB(25, 35, 70)
scriptHeaderLabel.Font = Enum.Font.GothamSemibold
scriptHeaderLabel.TextSize = 11
scriptHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
scriptHeaderLabel.Parent = contentFrame

-- Daftar Script Hasil Import
local scriptListFrame = Instance.new("ScrollingFrame")
scriptListFrame.Name = "ScriptList"
scriptListFrame.Size = UDim2.new(1, 0, 0, 78)
scriptListFrame.Position = UDim2.new(0, 0, 0, 163)
scriptListFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
scriptListFrame.BackgroundTransparency = 0.35
scriptListFrame.BorderSizePixel = 0
scriptListFrame.ScrollBarThickness = 4
scriptListFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 130, 225)
scriptListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scriptListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scriptListFrame.Parent = contentFrame

local scriptListCorner = Instance.new("UICorner")
scriptListCorner.CornerRadius = UDim.new(0, 9)
scriptListCorner.Parent = scriptListFrame

local scriptListLayout = Instance.new("UIListLayout")
scriptListLayout.Padding = UDim.new(0, 4)
scriptListLayout.SortOrder = Enum.SortOrder.LayoutOrder
scriptListLayout.Parent = scriptListFrame

local scriptListPadding = Instance.new("UIPadding")
scriptListPadding.PaddingTop = UDim.new(0, 5)
scriptListPadding.PaddingBottom = UDim.new(0, 5)
scriptListPadding.PaddingLeft = UDim.new(0, 5)
scriptListPadding.PaddingRight = UDim.new(0, 5)
scriptListPadding.Parent = scriptListFrame

-- Status Label
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 18)
statusLabel.Position = UDim2.new(0, 0, 0, 246)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Siap memindai folder..."
statusLabel.TextColor3 = Color3.fromRGB(40, 50, 88)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
statusLabel.Parent = contentFrame

-- Tombol Import Proporsional
local importBtn = Instance.new("TextButton")
importBtn.Name = "ImportButton"
importBtn.Size = UDim2.new(0, 120, 0, 32)
importBtn.Position = UDim2.new(0.5, -126, 1, -34)
importBtn.BackgroundColor3 = Color3.fromRGB(85, 125, 250)
importBtn.BackgroundTransparency = 0.05
importBtn.Text = "Import"
importBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
importBtn.Font = Enum.Font.GothamBold
importBtn.TextSize = 12
importBtn.Parent = contentFrame

local importCorner = Instance.new("UICorner")
importCorner.CornerRadius = UDim.new(0, 8)
importCorner.Parent = importBtn

local importGradient = Instance.new("UIGradient")
importGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(70, 130, 255)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(135, 98, 250))
})
importGradient.Parent = importBtn

-- Tombol Jalankan Loader URL
local loaderBtn = Instance.new("TextButton")
loaderBtn.Name = "LoaderButton"
loaderBtn.Size = UDim2.new(0, 120, 0, 32)
loaderBtn.Position = UDim2.new(0.5, 6, 1, -34)
loaderBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
loaderBtn.BackgroundTransparency = 0.25
loaderBtn.Text = "Run Hub"
loaderBtn.TextColor3 = Color3.fromRGB(28, 42, 85)
loaderBtn.Font = Enum.Font.GothamBold
loaderBtn.TextSize = 12
loaderBtn.Parent = contentFrame

local loaderCorner = Instance.new("UICorner")
loaderCorner.CornerRadius = UDim.new(0, 8)
loaderCorner.Parent = loaderBtn

local loaderStroke = Instance.new("UIStroke")
loaderStroke.Color = Color3.fromRGB(160, 185, 245)
loaderStroke.Transparency = 0.4
loaderStroke.Thickness = 1
loaderStroke.Parent = loaderBtn

-- Sistem Geser / Tarik Bebas (Smooth Drag Touch & Mouse)
local dragging = false
local dragInput: InputObject? = nil
local dragStartPos = Vector3.zero
local frameStartPos = UDim2.new()

header.InputBegan:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStartPos = input.Position
		frameStartPos = mainFrame.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

header.InputChanged:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input: InputObject)
	if dragging and input == dragInput then
		local delta = input.Position - dragStartPos
		mainFrame.Position = UDim2.new(
			frameStartPos.X.Scale,
			frameStartPos.X.Offset + delta.X,
			frameStartPos.Y.Scale,
			frameStartPos.Y.Offset + delta.Y
		)
	end
end)

-- Fungsi Menampilkan Daftar Script Setelah Import
local function refreshScriptList(scriptsList: {LuaSourceContainer})
	for _, child in ipairs(scriptListFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for _, scr in ipairs(scriptsList) do
		if scr and scr.Parent then
			local scrBtn = Instance.new("TextButton")
			scrBtn.Size = UDim2.new(1, 0, 0, 24)
			scrBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			scrBtn.BackgroundTransparency = 0.25
			scrBtn.Text = "  📜 " .. scr.Name .. " (" .. scr.ClassName .. ")"
			scrBtn.TextColor3 = Color3.fromRGB(22, 32, 65)
			scrBtn.Font = Enum.Font.GothamMedium
			scrBtn.TextSize = 11
			scrBtn.TextXAlignment = Enum.TextXAlignment.Left
			scrBtn.TextTruncate = Enum.TextTruncate.AtEnd
			scrBtn.Parent = scriptListFrame

			local scrCorner = Instance.new("UICorner")
			scrCorner.CornerRadius = UDim.new(0, 6)
			scrCorner.Parent = scrBtn

			scrBtn.MouseButton1Click:Connect(function()
				local fullPath = scr:GetFullName()
				if setclipboard then
					pcall(setclipboard, fullPath)
				end
				statusLabel.Text = "Path: " .. fullPath
			end)
		end
	end
end

-- Fungsi Mengisi Ulang Daftar File
local fileButtons = {}
local function populateFileList()
	for _, btn in ipairs(fileButtons) do
		btn:Destroy()
	end
	table.clear(fileButtons)
	selectedFilePath = nil

	local files = getSupportedFiles("")
	if #files == 0 then
		statusLabel.Text = "Tidak ada file .rbxm/.rbxl ditemukan."
		return
	end

	statusLabel.Text = "Ditemukan " .. tostring(#files) .. " file. Pilih salah satu."

	for _, filePath in ipairs(files) do
		local fileName = filePath:match("([^/\\]+)$") or filePath
		local itemBtn = Instance.new("TextButton")
		itemBtn.Size = UDim2.new(1, 0, 0, 26)
		itemBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		itemBtn.BackgroundTransparency = 0.25
		itemBtn.Text = "  📄 " .. fileName
		itemBtn.TextColor3 = Color3.fromRGB(22, 32, 65)
		itemBtn.Font = Enum.Font.GothamMedium
		itemBtn.TextSize = 11
		itemBtn.TextXAlignment = Enum.TextXAlignment.Left
		itemBtn.TextTruncate = Enum.TextTruncate.AtEnd
		itemBtn.Parent = fileListFrame

		local itemCorner = Instance.new("UICorner")
		itemCorner.CornerRadius = UDim.new(0, 6)
		itemCorner.Parent = itemBtn

		itemBtn.MouseButton1Click:Connect(function()
			selectedFilePath = filePath
			statusLabel.Text = "Terpilih: " .. fileName

			for _, other in ipairs(fileButtons) do
				other.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				other.BackgroundTransparency = 0.25
				other.TextColor3 = Color3.fromRGB(22, 32, 65)
			end
			itemBtn.BackgroundColor3 = Color3.fromRGB(90, 130, 250)
			itemBtn.BackgroundTransparency = 0.05
			itemBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end)

		table.insert(fileButtons, itemBtn)
	end
end

-- Event Tombol Buka / Tutup
toggleBtn.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	local targetSize = isMinimized and UDim2.new(0, 315, 0, 42) or UDim2.new(0, 315, 0, 415)
	toggleBtn.Text = isMinimized and "Buka" or "Tutup"

	TweenService:Create(
		mainFrame,
		TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
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

	statusLabel.Text = "Memproses file..."
	local ok, msg, scriptsList = RBXMImporter.ImportFile(selectedFilePath)
	importedScripts = scriptsList or {}
	refreshScriptList(importedScripts)
	statusLabel.Text = (ok and "✔ " or "✖ ") .. msg
end)

-- Event Tombol Run Hub (Alur Loader URL)
loaderBtn.MouseButton1Click:Connect(function()
	statusLabel.Text = "Memuat hub dari URL..."
	local ok, msg = RBXMImporter.RunRemoteLoader()
	statusLabel.Text = (ok and "✔ " or "✖ ") .. msg
end)

-- Jalankan scan otomatis saat pertama dibuka
populateFileList()

return RBXMImporter
