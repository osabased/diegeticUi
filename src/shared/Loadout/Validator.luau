--!strict
--# selene: allow(incorrect_standard_library_use)

local Catalog = if script ~= nil then require(script.Parent.Catalog) else require("./Catalog")

local Validator = {}

function Validator.validate(requestId: string, itemId: string): (boolean, string)
	if #requestId < 1 or #requestId > 64 then
		return false, "Invalid request identifier."
	end
	local item = Catalog.get(itemId)
	if item == nil then
		return false, "That equipment does not exist."
	end
	if not item.available then
		return false, item.lockReason or "That equipment is locked."
	end
	return true, `Equipped {item.name} for this session.`
end

return Validator
