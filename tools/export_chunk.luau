-- Studio side of the script export: returns one ~97,000-character JSON slice of
-- every script's source, starting at script START_I, byte START_OFF. The first
-- slice also carries the manifest. Padded so the MCP saves it as a file.
local START_I, START_OFF = __START_I__, __START_OFF__
local HttpService = game:GetService("HttpService")

local list, scripts = {}, {}
for _, svc in ipairs({ game.ServerScriptService, game.StarterPlayer, game.ReplicatedStorage, game.ServerStorage }) do
	for _, d in ipairs(svc:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			local names, classes = {}, {}
			local node = d
			while node ~= game do
				table.insert(names, 1, node.Name)
				table.insert(classes, 1, node.ClassName)
				node = node.Parent
			end
			local entry = { names = names, classes = classes, class = d.ClassName, len = #d.Source }
			if d:IsA("Script") then
				entry.runContext = d.RunContext.Name
				entry.enabled = d.Enabled
			end
			table.insert(list, entry)
			table.insert(scripts, d)
		end
	end
end

local LIMIT = 95000
local result = { pieces = {} }
local used = 300
if START_I == 1 and START_OFF == 0 then
	result.manifest = list
	used += #HttpService:JSONEncode(list)
end
local i, off = START_I, START_OFF
while i <= #scripts do
	local src = scripts[i].Source
	local remaining = #src - off
	local budget = LIMIT - used
	if budget < 3000 then
		break
	end
	if remaining <= 0 then
		table.insert(result.pieces, { i = i, off = off, text = "" })
		used += 40
		i += 1
		off = 0
	else
		local n = math.min(remaining, math.floor(budget * 0.85))
		local text, enc
		while true do
			local cut = off + n
			-- never split a UTF-8 character
			while cut < #src and cut > off and string.byte(src, cut + 1) >= 0x80 and string.byte(src, cut + 1) < 0xC0 do
				cut -= 1
			end
			text = string.sub(src, off + 1, cut)
			enc = #HttpService:JSONEncode(text)
			if enc + 60 <= budget or cut - off <= 1 then
				n = cut - off
				break
			end
			n = math.floor(n * 0.8)
		end
		table.insert(result.pieces, { i = i, off = off, text = text })
		used += enc + 60
		off += n
		if off >= #src then
			i += 1
			off = 0
		end
	end
end
result.nextI = i
result.nextOff = off
result.done = i > #scripts
result.count = #scripts
local encoded = HttpService:JSONEncode(result)
-- pad past the inline limit so the output is always saved to a file
local target = 97000
if #encoded < target then
	result.pad = string.rep(" ", target - #encoded - 10)
	encoded = HttpService:JSONEncode(result)
end
return encoded
