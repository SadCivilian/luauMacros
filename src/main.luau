local PLUGIN_ENABLED = true
local ScriptEditorService = game:GetService("ScriptEditorService")
local StudioService = game:GetService("StudioService")
local UserInputService = game:GetService("UserInputService")
local button = plugin:CreateToolbar("luauMacros")
local disablePluginButton = button:CreateButton("disablePluginButton", "Disable macros from functioning.",  "rbxassetid://11459267", "Disable macros")
local createMacroButton = button:CreateButton("createMacroButton", "Create a macro.", "rbxassetid://11459267",  "Add a macro")
local deleteMacroButton = button:CreateButton("deleteMacroButton", "Delete a macro.", "rbxassetid://11459267", "Delete macro")
local outputMacrosButton = button:CreateButton("outputMacrosButton", "Output all your current macros.",  "rbxassetid://11459267", "Output macros")
local thing = game:GetService("ChangeHistoryService")
createMacroButton.ClickableWhenViewportHidden = true
deleteMacroButton.ClickableWhenViewportHidden = true
disablePluginButton.ClickableWhenViewportHidden = true
outputMacrosButton.ClickableWhenViewportHidden = true


local addMacroDock = plugin:CreateDockWidgetPluginGuiAsync("AddMacroDock", DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 300, 300, 300, 300))
local deleteMacroDock =  plugin:CreateDockWidgetPluginGuiAsync("DeleteMacroDock", DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 300, 300, 300, 300))
addMacroDock.Name = "AddMacroDock"
deleteMacroDock.Name = "DeleteMacroDock"
addMacroDock.Title = "Add Macro"
deleteMacroDock.Title = "Delete Macro"

createMacroButton.Click:Connect(function()
	addMacroDock.Enabled = true
	for i, v in pairs(addMacroDock:GetChildren()) do
		if v:IsA("TextBox") then
			v.Text = ""
		end
	end
end)

deleteMacroButton.Click:Connect(function()
	if addMacroDock.Enabled == true then
		return
	else
		deleteMacroDock.Enabled = true
		for i, v in pairs(deleteMacroDock:GetChildren()) do
			if v:IsA("TextBox") then
				v.Text = ""
			end
		end
	end
end)

disablePluginButton.Click:Connect(function()
	PLUGIN_ENABLED = not PLUGIN_ENABLED
	warn("luauMacros enabled: " .. tostring(PLUGIN_ENABLED))
end)

local CURRENT_DOCUMENT : ScriptDocument
local CURRENT_MACROS : {[string] : string} = {}
local MACRO_INPUT_BUFFER : {string} = {}

outputMacrosButton.Click:Connect(function()
	print(CURRENT_MACROS)
end)

local function getPreviousSessionMacros() : {[string] : string}
	local old = plugin:GetSetting("previousSession")
	return old
end

local function getMacro(macroString : string)
	plugin:GetSetting(macroString)
end

local function addMacro(macroString : string, expansion : string)
	if getMacro(macroString) ~= nil then return warn("Duplicate macro") end
	plugin:SetSetting(macroString, expansion)
	CURRENT_MACROS[macroString] = expansion
end

local function removeMacro(macroString : string) : ()
	plugin:SetSetting(macroString, nil)
	CURRENT_MACROS[macroString] = nil
end

local function flushBuffer() : string
	local flushed = table.concat(MACRO_INPUT_BUFFER)
	table.clear(MACRO_INPUT_BUFFER)
	return flushed
end

local function pop_backOfBuffer() : string
	local flush = MACRO_INPUT_BUFFER[#MACRO_INPUT_BUFFER]
	table.remove(MACRO_INPUT_BUFFER, #MACRO_INPUT_BUFFER)
	return flush
end

@deprecated
-- unused
local function isInComment(line : number, col : number) : boolean
		return true
end

local function setupUI()
	local Done = Instance.new("TextButton")
	Done.Name = "Done"
	Done.Position = UDim2.fromScale(0.4, 0.9)
	Done.Size = UDim2.fromScale(0.2, 0.1)
	Done.Text = "done"
	Done.Parent = addMacroDock
	local MacroExpansion = Instance.new("TextBox")
	MacroExpansion.Name = "MacroExpansion"
	MacroExpansion.Position = UDim2.fromScale(0, 0.5)
	MacroExpansion.Size = UDim2.fromScale(1, 0.4)
	MacroExpansion.PlaceholderText = "macro expansion"
	MacroExpansion.ClearTextOnFocus = false
	MacroExpansion.Text = ""
	MacroExpansion.Parent = addMacroDock
	MacroExpansion.BackgroundColor3 = Color3.new(0,0,0)
	MacroExpansion.TextColor3 = Color3.new(1,1,1)
	MacroExpansion.MultiLine = true

	local MacroName = Instance.new("TextBox")
	MacroName.Name = "MacroName"
	MacroName.Position = UDim2.fromScale(0, 0.25)
	MacroName.Size = UDim2.fromScale(1, 0.15)
	MacroName.PlaceholderText = "macro name"
	MacroName.Parent = addMacroDock
	MacroName.ClearTextOnFocus = false
	MacroName.Text = ""
	MacroName.BackgroundColor3 = Color3.new(0,0,0)
	MacroName.TextColor3 = Color3.new(1,1,1)

	local Explanation = Instance.new("TextLabel")
	Explanation.Name = "Explanation"
	Explanation.Text = "Edit the first textbox to be the name of your macro, then write your expansion in the TextBox below."
	Explanation.Size = UDim2.fromScale(1, 0.2)
	Explanation.Position = UDim2.fromScale(0, 0)
	Explanation.Parent = addMacroDock
	Explanation.TextScaled = true

	Done.MouseButton1Click:Connect(function()
		if MacroName.Text == "" or MacroExpansion.Text == "" then
			warn("Add Macro operation aborted by user")
			addMacroDock.Enabled = false
		else
			local macroName = MacroName.Text
			local macroExpansion = MacroExpansion.Text
			addMacro(macroName, macroExpansion)
		end
		addMacroDock.Enabled = false
	end)

	local ExplanationTwo = Instance.new("TextLabel")
	ExplanationTwo.Name = "ExplanationTwo"
	ExplanationTwo.Text = "Simply enter the macro name in the textbox below and click the button to delete your macro."
	ExplanationTwo.Size = UDim2.fromScale(1, 0.2)
	ExplanationTwo.Position = UDim2.fromScale(0, 0)
	ExplanationTwo.Parent = deleteMacroDock
	ExplanationTwo.TextScaled = true

	local DoneTwo = Instance.new("TextButton")
	DoneTwo.Name = "DoneTwo"
	DoneTwo.Position = UDim2.fromScale(0.4, 0.9)
	DoneTwo.Size = UDim2.fromScale(0.2, 0.1)
	DoneTwo.Text = "done"
	DoneTwo.Parent = deleteMacroDock

	local MacroNameTwo = Instance.new("TextBox")
	MacroNameTwo.Name = "MacroNameTwo"
	MacroNameTwo.Position = UDim2.fromScale(0, 0.25)
	MacroNameTwo.Size = UDim2.fromScale(1, 0.15)
	MacroNameTwo.PlaceholderText = "macro name"
	MacroNameTwo.Parent = deleteMacroDock
	MacroNameTwo.ClearTextOnFocus = false
	MacroNameTwo.PlaceholderText = "macro name"
	MacroNameTwo.Text = ""
	MacroNameTwo.BackgroundColor3 = Color3.new(0,0,0)
	MacroNameTwo.TextColor3 = Color3.new(1,1,1)

	DoneTwo.MouseButton1Click:Connect(function()
		if MacroNameTwo.Text == "" then
			deleteMacroDock.Enabled = false
			warn("Delete Macro operation aborted by user")
		else
			local macroName = MacroNameTwo.Text
			removeMacro(macroName)
		end
		deleteMacroDock.Enabled = false
	end)
end

-- No this isn't spyware
local function InitKeylogger()
	plugin.Unloading:Connect(function()
		plugin:SetSetting("previousSession", CURRENT_MACROS)
	end)
	local LastUsedExpansionText
	local bufferLen = #MACRO_INPUT_BUFFER
	local LAST_NON_SPACE_OR_UNDO_POS = 0
	ScriptEditorService.TextDocumentDidChange:Connect(function(doc : ScriptDocument, changesArray : {[number] : {[string] : any}})
		local text = changesArray[1]["text"]
		if LastUsedExpansionText == text then
			LastUsedExpansionText = nil
			return
		end
		if text == "" then
			local charactersRemoved = changesArray[1]["range"]["end"]["character"] - changesArray[1]["range"]["start"]["character"]
			if charactersRemoved == 1 then
				pop_backOfBuffer()
			else
				flushBuffer()
			end
			return
		elseif text == " " then
			local flushed = flushBuffer()
			local flushLen = flushed:len()
			for macro, expansion in CURRENT_MACROS do
				if flushed == macro and PLUGIN_ENABLED then
					local appended = expansion .. " "
					local cursorLine, cursorChar, anchorLine, anchorChar = CURRENT_DOCUMENT:GetSelection()
					LastUsedExpansionText = appended
					CURRENT_DOCUMENT:EditTextAsync(appended, cursorLine, cursorChar - (flushLen + 1), anchorLine, anchorChar)
					break
				end
			end
		elseif text == "		"  or text == "\t" then -- space or tab character
			return
		else
			LAST_NON_SPACE_OR_UNDO_POS = changesArray[1]["range"]["start"]["character"]
			table.insert(MACRO_INPUT_BUFFER, text)
		end
	end)
end

local function InitScriptTracker()
	if StudioService.ActiveScript ~= nil then
		CURRENT_DOCUMENT = ScriptEditorService:FindScriptDocument(StudioService.ActiveScript :: LuaSourceContainer)
	end
	StudioService:GetPropertyChangedSignal("ActiveScript"):Connect(function()
		if StudioService.ActiveScript ~= nil then
			CURRENT_DOCUMENT = ScriptEditorService:FindScriptDocument(StudioService.ActiveScript :: LuaSourceContainer)
		end
	end)
end

setupUI()
InitScriptTracker()
InitKeylogger()
local prev = getPreviousSessionMacros()

if prev == nil then
	CURRENT_MACROS = {}
else
	CURRENT_MACROS = prev
end
