--!strict

local fs = require("@std/fs")

-- README links are the entry points to executable examples and workflow docs.
-- Validate their targets so deleting an example cannot silently stale onboarding.
local function missingTargets(document: string, exists: (string) -> boolean): { string }
	local missing: { string } = {}
	for target in string.gmatch(document, "%[[^%]]*%]%(([^%)]+)%)") do
		if not string.match(target, "^%a[%w+.-]*:") and string.sub(target, 1, 1) ~= "#" then
			local path = string.match(target, "^[^#]+") or target
			if not exists(path) then
				table.insert(missing, path)
			end
		end
	end
	return missing
end

local fixture = missingTargets(
	"[source](src/example.luau) [deleted](src/deleted.luau) [guide](docs/guide.md#setup) [web](https://example.com) [anchor](#setup)",
	function(path)
		return path == "src/example.luau" or path == "docs/guide.md"
	end
)
assert(#fixture == 1 and fixture[1] == "src/deleted.luau", "link check did not isolate the missing local target")

local missing = missingTargets(fs.readFileToString("README.md"), fs.exists)
assert(#missing == 0, "README references missing local files:\n" .. table.concat(missing, "\n"))
print("[documentation] README local file links passed")
