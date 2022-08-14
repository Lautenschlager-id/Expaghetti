local strchar = strchar
local tonumber = tonumber

local stringUtils = require("./helpers/string")
local stringCharToCtrlChar = stringUtils.stringCharToCtrlChar

local characterClasses = require("./magic/characterClasses")

local Escaped = { }

local ESCAPE_CHARACTER = '%'

Escaped.c = function(currentCharacter, index, expression)
	local ctrlChar = stringCharToCtrlChar(currentCharacter)
	if not ctrlChar then
		return false, "Invalid regular expression: Character following \"" .. ESCAPE_CHARACTER .. "c\" must be valid"
	end

	return index, {
		type = "literal",
		value = ctrlChar
	}
end

Escaped.e = function(currentCharacter, index, expression)
	local hex = "0x"

	-- Must be exactly 4 characters long
	for paramIndex = 0, 3 do
		hex = hex .. (expression[index + paramIndex] or '')
	end

	hex = #hex == 4 and tonumber(hex)
	if not hex then
		return false, "Invalid regular expression: A valid 4 characters hexadecimal value must be passed to \"" .. ESCAPE_CHARACTER .. "e\""
	end

	return index + 4, {
		type = "literal",
		value = strchar(hex)
	}
end

Escaped.is = function(currentCharacter)
	return currentCharacter == ESCAPE_CHARACTER
end

Escaped.execute = function(currentCharacter, index, expression, tree)
	index = index + 1
	currentCharacter = expression[index]

	if not currentCharacter then
		return false, "Invalid regular expression: Attempt to escape null"
	end

	index = index + 1

	if characterClasses[currentCharacter] then
		return index, characterClasses[currentCharacter]
	elseif currentCharacter == ESCAPE_CHARACTER then
		return index, {
			type = "literal",
			value = currentCharacter
		}
	elseif currentCharacter then
		if Escaped[currentCharacter] then
			return Escaped[currentCharacter](expression[index], index, expression)
		end
	end
end

return Literal