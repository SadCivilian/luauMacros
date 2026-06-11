export type Macro = {
	macroString : string,
	expansion : string,
	variable : boolean,
	paramaterNames : {string?},
	macroStringNoParams : string?, -- This is optional because it is not required to be set upon creating the object, and will be appended to the object when the macro name with no params IS identified
}

--[[
NOTES:
make macro string validation already maybe 
then we're somewhat done as that covers any edge cases of a non variable macro with a < or > in the name
]]

-- === READ & WRITE ===
local CURRENT_DOCUMENT : ScriptDocument
local CURRENT_MACROS : {[string] : Macro} = {}
local MACRO_INPUT_BUFFER : {string} = {}
local PLUGIN_ENABLED = true

-- === ERROR/WARNING MESSAGES/HANDLING ===
local UNTERMINATED_MACRO_VARIABLE = "Unterminated macro variable. Please terminate your variables with < or >."
local SPLIT_MACRO_NAME = "Macro name is split between a macro parameter. This behavior is not supported."
local NESTED_MACRO_PARAMETER = "You cannot nest macro parameters."
local UNSUPPORTED_PARAMETER_NAME = "Parameter names cannot be number/binary/hex literals or spaces."
local NO_MACRO_NAME = "Provide a macro name along with your parameters."
local MISMATCHED_PARAMETER_COUNT = "Your amount of parameters provided in the macro and the amount of parameters you have given are mismatched."
local DUPLICATE_MACRO = "Duplicate macro. Macro has not been added."
local BANNED_CHARS = {" ", "\t", "\n"}

-- Connect saving, do this early so that your macros won't null and void somehow (I'm not dealing with it, okay??)
plugin.Unloading:Connect(function()
	plugin:SetSetting("previousSession", CURRENT_MACROS)
end)

local ScriptEditorService = game:GetService("ScriptEditorService")
local StudioService = game:GetService("StudioService")
local UserInputService = game:GetService("UserInputService")
local button = plugin:CreateToolbar("luauMacros")
local disablePluginButton = button:CreateButton("disablePluginButton", "Disable macros from functioning.",  "rbxassetid://11459267", "Disable macros")
local createMacroButton = button:CreateButton("createMacroButton", "Create a macro.", "rbxassetid://11459267",  "Add a macro")
local deleteMacroButton = button:CreateButton("deleteMacroButton", "Delete a macro.", "rbxassetid://11459267", "Delete macro")
local outputMacrosButton = button:CreateButton("outputMacrosButton", "Output all your current macros.",  "rbxassetid://11459267", "Output macros")
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

-- === DEBUGGING ===

-- Errors with the given message.
local function LOG_ERROR(errorMessage : string)
	return error("[LuauMacros]: " .. errorMessage)
end

-- Warns with the given message
local function LOG_WARNING(warnMessage : string)
	return warn("[LuauMacros]: " .. warnMessage)
end

-- Wipes the macro table. Used only for testing purposes.
local function D_FORCE_DELETE_MACROS()
	table.clear(CURRENT_MACROS)
end

-- Create a new macro object.
local function CreateMacroObject(macroString : string, expansion : string, variable : boolean, parameterNames : {string?})
	return {macroString = macroString, expansion = expansion, variable = variable, paramaterNames = parameterNames, macroStringNoParams = nil} :: Macro
end

-- Load previous session macros.
local function getPreviousSessionMacros() : {[string] : Macro}
	local old = plugin:GetSetting("previousSession")
	return old
end

-- Tokenizes a string by splitting it by spaces.
local function tokenizeString(str : string) : {string?}
	local strLen = str:len()
	local strs : {string?} = {}
	local temp : {string} = {}

	for i = 1, strLen do
		local char = str:sub(i,i)
		if char ~= " " then
			table.insert(temp, char)
		else
			table.insert(strs, table.concat(temp))
			table.clear(temp)
		end
	end
	return strs
end

-- Appends a space character to a string.
local function appendSpace(str : string)
	return str .. " "
end

-- Appends a tab character to a string.
local function appendTab(str : string)
	return str .. "\t"
end

-- Returns a boolean on if a macroString is valid.
local function isValidMacroName(macroString : string) : boolean
	local tokenized = tokenizeString(macroString)
	return true
end


local function isValidParameterChar(char : string) : boolean
	if tonumber(char) ~= nil or table.find(BANNED_CHARS, char) then
		return false
	end
	return true
end

-- Strips the parameter names from a macro string.
-- NOTE: This will just wipe everything it sees after a <, because anything after that has to be parameters and can't be part of the macro name.
local function stripParameterNames(macroString : string) : string
	local macroStringLen = macroString:len()
	local temp : {string} = {}
	local lastChar -- this is because parameters DON'T have to be spaced out from the source name string, but they CAN, and if they ARE, we need to remove a space. so if this IS a space, we will remove a character.
	for i = 1, macroStringLen do
		local char = macroString:sub(i,i)
		if char == "<" then
			if lastChar == " " then -- space
				local concatted = table.concat(temp)
				local subbedForSpace = string.sub(concatted, 1, concatted:len() - 1)
				return subbedForSpace
			end
			return table.concat(temp)
		end
		lastChar = char
		table.insert(temp, char)
	end
	return ""
end

-- Feed a macro object to this which is fetched from getMacro() (Remember that when we input a variable macro name, it's just macroStringNoParams of the macro which can be used to retrieve it.)
local function replaceParameterNames(macroObject : Macro, ...: string)
	local macroStrings = table.pack(...)
	local paramAmount = macroStrings.n
	local parameterNames = macroObject.paramaterNames :: {string}
	local parameterNameAmount = #parameterNames
	local target : string
	if paramAmount ~= parameterNameAmount then LOG_ERROR(MISMATCHED_PARAMETER_COUNT) end
	for i, parameterName in ipairs(parameterNames) do
		if target == nil then target = macroObject.expansion end
		local expansion = macroStrings[i]
		local edited = string.gsub(target, parameterName, expansion)
		target = edited
	end
	return target
end

-- Checks if a macro input string is a variable macro. Returns the name of the parameters if it is.
local function isMacroStringVariable(macroName : string) : (boolean, {string?})
	local inserting = false
	local temp : {string} = {}
	local parameterNames : {string?} = {}
	local macroNameLen = macroName:len()
	for i = 1, macroNameLen do
		local char = macroName:sub(i, i)
		if inserting == true then
			if isValidParameterChar(char) then
				table.insert(temp, char)
			else
				LOG_ERROR(UNSUPPORTED_PARAMETER_NAME)
			end
		end

		if char == "<" then
			table.insert(temp, char)
			inserting = true
		elseif char == ">" then
			table.insert(parameterNames, table.concat(temp))
			table.clear(temp)
			inserting = false
		end
	end
	return #parameterNames ~= 0, parameterNames
end

-- Get a macro.
local function getMacro(macroString : string) : Macro
	local found = CURRENT_MACROS[macroString]
	if not found then
		for _, macroObject : Macro in CURRENT_MACROS do
			if macroObject.macroStringNoParams == macroString then
				return macroObject
			end
		end
	end
	return found
end

local function addMacro(macroString : string, expansion : string, variable : boolean, parameterNames : {string?}) : Macro?
	local wiped = stripParameterNames(macroString)
	if getMacro(wiped) ~= nil then LOG_WARNING(DUPLICATE_MACRO) return nil end
	local object = CreateMacroObject(macroString, expansion, variable, parameterNames)
	CURRENT_MACROS[macroString] = object
	return object
end

-- Removes a macro.
local function removeMacro(macroString : string) : ()
	local found = CURRENT_MACROS[macroString]
	if not found then
		for _, macroObject : Macro in CURRENT_MACROS do
			if macroObject.macroStringNoParams == macroString then
				CURRENT_MACROS[macroObject.macroString] = nil
			end
		end
	else
		CURRENT_MACROS[macroString] = nil
	end
end

-- Flushes and returns the input buffer.
local function flushBuffer() : string
	local flushed = table.concat(MACRO_INPUT_BUFFER)
	table.clear(MACRO_INPUT_BUFFER)
	return flushed
end

-- Returns the buffer string, but does not wipe the buffer.
local function getBuffer() : string
	return table.concat(MACRO_INPUT_BUFFER)
end

-- Flushes the current buffer and checks against a variable macro. If succesful, returns the macro name and a table containing the variables used. Lastly, the length of the buffer that was flushed.
local function checkAgainstVarMacro() : (string, {string}, number)
	local flushed = flushBuffer()
	local strlen = flushed:len()
	local macroNameBuf : {string} = {}
	local currentParamBuf : {string} = {}
	local params : {string} = {}
	local insertingIntoMacroName = true
	local insertingIntoParams = false
	for i = 1, strlen do
		local char = flushed:sub(i,i)
		if char == "<" then
			insertingIntoMacroName = false
			insertingIntoParams = true
			continue
		end
		if insertingIntoMacroName then
			table.insert(macroNameBuf, char)
		end

		if (char == ">" or char == ",") and insertingIntoParams then
			table.insert(params, table.concat(currentParamBuf))
			table.clear(currentParamBuf)
		elseif insertingIntoParams then
			table.insert(currentParamBuf, char)
		end
 	end
	return table.concat(macroNameBuf), params, strlen
end

-- Pop the back of the input buffer. (For one character deletions.)
local function pop_backOfBuffer() : string
	local flush = MACRO_INPUT_BUFFER[#MACRO_INPUT_BUFFER]
	table.remove(MACRO_INPUT_BUFFER, #MACRO_INPUT_BUFFER)
	return flush
end

-- Currently only checks for line comments as parsing the source for a block comment will come later. This also does not account for most edge cases like string escape characters and such, but that will come soon, I hope...
local function isInComment(line : number, col : number) : boolean
	local textInLine = CURRENT_DOCUMENT:GetLine(line)
	local prevChar : string? = nil
	local textLen = textInLine:len()
	local isinString = false
	for i = 1, textLen do
		local char = textInLine:sub(i,i)
		if char == '"' then
			if not isinString then isinString = true else isinString = not isinString end
		end
		if char == "-" and prevChar == "-" then
			if col > i and not isinString then return true end
			return false
		end
		prevChar = char
	end
	return false
end

-- Create the UI.
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
	MacroExpansion.TextScaled = true

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
	MacroName.TextScaled = true

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
			local isVariable, parameterNames = isMacroStringVariable(macroName)
			local object = addMacro(macroName, macroExpansion, isVariable, parameterNames)
			if isVariable and object then
				local stripped = stripParameterNames(macroName)
				object.macroStringNoParams = stripped
			end
		end
		addMacroDock.Enabled = false
	end)

	local ExplanationTwo = Instance.new("TextLabel")
	ExplanationTwo.Name = "ExplanationTwo"
	ExplanationTwo.Text = "Simply enter the macro name (without the parameters included, if it is variable) in the textbox below and click the button to delete your macro."
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
	MacroNameTwo.TextScaled = true

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

-- Connect the plugin UI events.
local function connectEvents()
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

	outputMacrosButton.Click:Connect(function()
		print(CURRENT_MACROS)
	end)
end

-- No this isn't spyware
local function InitKeylogger()
	local LastUsedExpansionText : string?
	local bufferLen : number = #MACRO_INPUT_BUFFER
	local LAST_NON_SPACE_OR_UNDO_POS : number = 0
	local LAST_CHAR_TYPED : string
	local FEEDING_VARIABLE_PARAMETERS : boolean = false
	ScriptEditorService.TextDocumentDidChange:Connect(function(doc : ScriptDocument, changesArray : {[number] : {[string] : any}})
		if doc:IsCommandBar() then return end
		local text = changesArray[1]["text"] :: string
		local cursorLine, cursorChar = CURRENT_DOCUMENT:GetSelection()
		if isInComment(cursorLine, cursorChar) then
			return
		end
		if LastUsedExpansionText == text then
			LastUsedExpansionText = nil
			return
		end
		if text == "" then
			local charactersRemoved = changesArray[1]["range"]["end"]["character"] - changesArray[1]["range"]["start"]["character"]
			if charactersRemoved == 1 then
				pop_backOfBuffer()
				if LAST_CHAR_TYPED == "<" then
					FEEDING_VARIABLE_PARAMETERS = false
				end
			else
				FEEDING_VARIABLE_PARAMETERS = false
				flushBuffer()
			end
			return
		elseif text == " " then
			if FEEDING_VARIABLE_PARAMETERS and not (LAST_CHAR_TYPED == ">") then return end -- gotta test this later for sure
			if LAST_CHAR_TYPED == ">" then -- we're flushing a var macro, hopefully. or not. I don't know yet. The program will, though
				local macroName, paramList, flushLen = checkAgainstVarMacro()
				for macro, object : Macro in CURRENT_MACROS do
					if macroName == object.macroStringNoParams then
						local finalized_expansion = replaceParameterNames(object, table.unpack(paramList)) --a,b,c plain text strings
						local appended = appendSpace(finalized_expansion)
						local cursorLine, cursorChar, anchorLine, anchorChar = CURRENT_DOCUMENT:GetSelection()
						LastUsedExpansionText = appended
						CURRENT_DOCUMENT:EditTextAsync(appended, cursorLine, cursorChar - (flushLen + 1), anchorLine, anchorChar)
						break
					end
				end
			else
				local flushed = flushBuffer()
				local flushLen = flushed:len()
				for macro, object : Macro in CURRENT_MACROS do
					if flushed == macro and PLUGIN_ENABLED then
						local appended = appendSpace(object.expansion)
						local cursorLine, cursorChar, anchorLine, anchorChar = CURRENT_DOCUMENT:GetSelection()
						LastUsedExpansionText = appended
						CURRENT_DOCUMENT:EditTextAsync(appended, cursorLine, cursorChar - (flushLen + 1), anchorLine, anchorChar)
						break
					end
				end
			end
		elseif text == "\t" or text == "\n" then
			return
		elseif text == "<" then
			table.insert(MACRO_INPUT_BUFFER, text)
			FEEDING_VARIABLE_PARAMETERS = true
		else
			LAST_NON_SPACE_OR_UNDO_POS = changesArray[1]["range"]["start"]["character"]
			table.insert(MACRO_INPUT_BUFFER, text)
			LAST_CHAR_TYPED = text
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
connectEvents()
InitScriptTracker()
InitKeylogger()
local prev = getPreviousSessionMacros()

if prev == nil then
	CURRENT_MACROS = {}
else
	CURRENT_MACROS = prev
end
