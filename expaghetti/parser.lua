local splitStringByEachChar = require("./helpers/string").splitStringByEachChar

local Literal = require("./magic/literal")
local Set = require("./magic/set")

local parser = function(expr)
	local expression, expressionLength = splitStringByEachChar(expr)

	local tree = {
		_index = 0
	}

	local index = 1
	while index <= expressionLength do
		local currentCharacter = expression[index]

		local newIndex, errorMessage
		if Set.is(currentCharacter) then
			newIndex, errorMessage = Set.execute(currentCharacter, index, expression, tree)
		else
			newIndex, errorMessage = Literal.execute(currentCharacter, index, expression, tree)
		end

		if not newIndex or errorMessage then
			return false, errorMessage
		end

		index = newIndex
	end

	return tree
end

local print = require("./helpers/pretty-print")
print(parser(''))
print(parser('a[b]c')) -- valid
print(parser('a[^b]c')) -- valid
print(parser('a[b-c]d')) -- valid
print(parser('a[bc-de]f')) -- valid
print(parser('a[bc-d]e')) -- valid
print(parser('a[b-cd]e')) -- valid
print(parser('a[bc-de-fg]h')) -- valid
print(parser('a[^b-c]d')) -- valid
print(parser('a[^bc-de]f')) -- valid
print(parser('a[^bc-d]e')) -- valid
print(parser('a[^b-cd]e')) -- valid
print(parser('a[^bc-de-fg]h')) -- valid
print(parser('a[-]b')) -- valid
print(parser('a[b-]c')) -- valid
print(parser('a[-b]c')) -- valid
print(parser('a[a-b-]c')) -- valid
print(parser('a[-a-b]c')) -- valid
print(parser('a[-bc-d]e')) -- valid
print(parser('a[b-c-d-e-f-g----]h')) -- valid
print(parser('a[----b-c-d-e-f-g]h')) -- valid
print(parser('a[-bc-de')) -- invalid
print(parser('a-bc-d]e')) -- valid
print(parser('a[%z]c')) -- invalid
print(parser('a[^%c1]c')) -- valid
print(parser('a[%cA-%cA]d')) -- valid
print(parser('a[z%cA-%cAf]d')) -- valid
print(parser('a[%cA-%cAf]d')) -- valid
print(parser('a[z%cA-%cA]d')) -- valid
print(parser('a[%cA-cB]d')) -- valid
print(parser('a[cA-%c1]d')) -- valid
print(parser('a[%c\xFF]d')) -- invalid
print(parser('a[%e0070]b')) -- valid
print(parser('a[2%e00701]b')) -- valid
print(parser('a[2%eFFFF1]b')) -- invalid
print(parser('a[%e00AA-%e00FF]b')) -- valid
print(parser('a[%c2-%e00FF]b')) -- valid
print(parser('a[a-%e00FF]b')) -- valid
print(parser('a[%e0070-z]b')) -- valid
print(parser('a[-%e00FF]b')) -- valid
print(parser('a[%e00FF-]b')) -- valid

return parser