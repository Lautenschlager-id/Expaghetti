----------------------------------------------------------------------------------------------------
local Escaped = require("./magic/escaped")
----------------------------------------------------------------------------------------------------
local magicEnum = require("./enums/magic")
local errorsEnum = require("./enums/errors")
local elementsEnum = require("./enums/elements")
----------------------------------------------------------------------------------------------------
local ENUM_OPEN_SET = magicEnum.OPEN_SET
local ENUM_CLOSE_SET = magicEnum.CLOSE_SET
local ENUM_NEGATE_SET = magicEnum.NEGATE_SET
local ENUM_SET_RANGE_SEPARATOR = magicEnum.SET_RANGE_SEPARATOR
local ENUM_ELEMENT_TYPE_LITERAL = elementsEnum.literal
local ENUM_ELEMENT_TYPE_SET = elementsEnum.set
----------------------------------------------------------------------------------------------------
local Set = { }

local getCharacterConsideringEscapedElements = function(character, index, expression)
	if not character then
		return
	end

	local isEscaped = false
	if Escaped.is(character) then
		local value
		index, value = Escaped.execute(character, index, expression)
		if not index then
			-- value = error message
			return false, value
		end

		if value.type == ENUM_ELEMENT_TYPE_LITERAL then
			character = value.value
		else
			character = value
		end

		index = index - 1
		isEscaped = true
	end

	return index, character, isEscaped
end

local findMagicClosingAndElementsList = function(index, expression)
	local charactersIndex, charactersList, boolEscapedList = 0, { }, { }

	local currentCharacter, isEscaped
	repeat
		index, currentCharacter, isEscaped = getCharacterConsideringEscapedElements(
			expression[index], index, expression, true)
		if not index and currentCharacter then
			-- currentCharacter = error message
			return false, currentCharacter
		end

		-- expression ended but magic was never closed
		if not currentCharacter then
			return false, errorsEnum.unclosedSet
		elseif not isEscaped and currentCharacter == ENUM_CLOSE_SET then
			return index, charactersList, boolEscapedList, charactersIndex
		end

		charactersIndex = charactersIndex + 1
		charactersList[charactersIndex] = currentCharacter
		boolEscapedList[charactersIndex] = isEscaped

		index = index + 1
	until false
end
----------------------------------------------------------------------------------------------------
Set.is = function(currentCharacter)
	return currentCharacter == ENUM_OPEN_SET
end

Set.execute = function(currentCharacter, index, expression, tree)
	-- skip magic opening
	index = index + 1

	local endIndex, charactersList, boolEscapedList, charactersIndex =
		findMagicClosingAndElementsList(index, expression)
	if not endIndex then
		-- charactersList = error message
		return false, charactersList

	-- Empty set
	elseif index == endIndex then
		return false, errorsEnum.emptySet
	end

	--[[
		{
			type = ENUM_ELEMENT_TYPE_SET,

			hasToNegateMatch = false,

			rangeIndex = 0,
			ranges = {
				[min1] = '',
				[max1] = '',
				...
			},

			classIndex = 0,
			classes = { },

			quantifier = nil,

			[literal1] = true,
			...
		}
	]]
	local set = {
		type = ENUM_ELEMENT_TYPE_SET,

		hasToNegateMatch = false,

		rangeIndex = 0,
		ranges = { },

		classIndex = 0,
		classes = { },
	}

	local isNextCharacterEscaped, watchingForRangeSeparator
	local nextCharacter, lastCharacter
	local elementIndex = 0
	repeat
		elementIndex = elementIndex + 1
		currentCharacter = charactersList[elementIndex]

		-- first character of the set
		if elementIndex == 1 and currentCharacter == ENUM_NEGATE_SET then
			set.hasToNegateMatch = true
		elseif currentCharacter.type == ENUM_ELEMENT_TYPE_SET then
			set.classIndex = set.classIndex + 1
			set.classes[set.classIndex] = currentCharacter
		else
			nextCharacter = charactersList[elementIndex + 1]
			isNextCharacterEscaped = boolEscapedList[elementIndex + 1]

			-- assumes that currentCharacter == ENUM_SET_RANGE_SEPARATOR
			if watchingForRangeSeparator then
				watchingForRangeSeparator = false

				-- having the first condition to check if the char is a set,
				-- then it won't fall in this condition ever
				-- and when only the next char is a set, then .type ~= nil
				-- so the reason for this comparison is that
				-- it can only be a range when both .type are nil
				if nextCharacter and not (lastCharacter.type or nextCharacter.type) then
					-- Lua can perform string comparisons natively
					if lastCharacter > nextCharacter then
						return false, errorsEnum.unorderedSetRange
					end

					set.rangeIndex = set.rangeIndex + 1
					set.ranges[set.rangeIndex] = lastCharacter

					set.rangeIndex = set.rangeIndex + 1
					set.ranges[set.rangeIndex] = nextCharacter

					-- Skip next element
					elementIndex = elementIndex + 1
				else
					-- For example, `a-%a`, adds `a` and `-`, and executes `%a` in the next iter
					set[lastCharacter] = true
					set[currentCharacter] = true
				end
			elseif not isNextCharacterEscaped and nextCharacter == ENUM_SET_RANGE_SEPARATOR then
				watchingForRangeSeparator = true
			else
				set[currentCharacter] = true
			end
		end

		lastCharacter = currentCharacter
	until elementIndex == charactersIndex

	-- skip magic closing
	index = endIndex + 1

	tree._index = tree._index + 1
	tree[tree._index] = set

	return index, set
end

return Set