--[[
	ComputerCraft Package Manager (ccpm)
]]
local version = "0.0.1"

local cmds = {}
local method = nil

local logLevel = 0
local assumeYes = false
local skipMissing = false

local sourceCache = {}
local sources = {}
local installedPackages = {}

-- Credit to https://github.com/Team-CC-Corp/Grin/blob/master/lib/json for this API
local JSON_API = [[local ba={["\n"]="\\n",["\r"]="\\r",["\t"]="\\t",["\b"]="\\b",["\f"]="\\f",["\""]="\\\"",["\\"]="\\\\"}
local function ca(cb)local db=0;for _c,ac in pairs(cb)do
if type(_c)~="number"then return false elseif _c>db then db=_c end end;return db==#cb end
local da={['\n']=true,['\r']=true,['\t']=true,[' ']=true,[',']=true,[':']=true}
function removeWhite(cb)while da[cb:sub(1,1)]do cb=cb:sub(2)end;return cb end
local function _b(cb,db,_c,ac)local bc=""
local function cc(_d)bc=bc.. ("\t"):rep(_c).._d end
local function dc(_d,ad,bd,cd,dd)bc=bc..ad;if db then bc=bc.."\n"_c=_c+1 end
for __a,a_a in cd(_d)do cc("")
dd(__a,a_a)bc=bc..","if db then bc=bc.."\n"end end;if db then _c=_c-1 end
if bc:sub(-2)==",\n"then
bc=bc:sub(1,-3).."\n"elseif bc:sub(-1)==","then bc=bc:sub(1,-2)end;cc(bd)end
if type(cb)=="table"then
assert(not ac[cb],"Cannot encode a table holding itself recursively")ac[cb]=true
if ca(cb)then
dc(cb,"[","]",ipairs,function(_d,ad)bc=bc.._b(ad,db,_c,ac)end)else
dc(cb,"{","}",pairs,function(_d,ad)
assert(type(_d)=="string","JSON object keys must be strings",2)bc=bc.._b(_d,db,_c,ac)bc=bc..
(db and": "or":").._b(ad,db,_c,ac)end)end elseif type(cb)=="string"then
bc='"'..cb:gsub("[%c\"\\]",ba)..'"'elseif type(cb)=="number"or type(cb)=="boolean"then
bc=tostring(cb)else
error("JSON only supports arrays, objects, numbers, booleans, and strings",2)end;return bc end;function encode(cb)return _b(cb,false,0,{})end;function encodePretty(cb)
return _b(cb,true,0,{})end;local ab={["\\/"]="/"}
for cb,db in pairs(ba)do ab[db]=cb end;function parseBoolean(cb)
if cb:sub(1,4)=="true"then return true,removeWhite(cb:sub(5))else return
false,removeWhite(cb:sub(6))end end;function parseNull(cb)return nil,
removeWhite(cb:sub(5))end
local bb={['e']=true,['E']=true,['+']=true,['-']=true,['.']=true}
function parseNumber(cb)local db=1;while
bb[cb:sub(db,db)]or tonumber(cb:sub(db,db))do db=db+1 end
local _c=tonumber(cb:sub(1,db-1))cb=removeWhite(cb:sub(db))return _c,cb end
function parseString(cb)cb=cb:sub(2)local db=""local _c=os.clock()
while cb:sub(1,1)~="\""do if
os.clock()-_c>4 then _c=os.clock()os.queueEvent""
os.pullEvent()end;local ac=cb:sub(1,1)cb=cb:sub(2)assert(
ac~="\n","Unclosed string")if ac=="\\"then
local bc=cb:sub(1,1)cb=cb:sub(2)
ac=assert(ab[ac..bc],"Invalid escape character")end;db=db..ac end;return db,removeWhite(cb:sub(2))end
function parseArray(cb)cb=removeWhite(cb:sub(2))local db={}local _c=1
while
cb:sub(1,1)~="]"do local ac=nil;ac,cb=parseValue(cb)db[_c]=ac;_c=_c+1;cb=removeWhite(cb)end;cb=removeWhite(cb:sub(2))return db,cb end
function parseObject(cb)cb=removeWhite(cb:sub(2))local db={}
while cb:sub(1,1)~="}"do
local _c,ac=nil,nil;_c,ac,cb=parseMember(cb)db[_c]=ac;cb=removeWhite(cb)end;cb=removeWhite(cb:sub(2))return db,cb end;function parseMember(cb)local db=nil;db,cb=parseValue(cb)local _c=nil;_c,cb=parseValue(cb)
return db,_c,cb end
function parseValue(cb)
local db=cb:sub(1,1)
if db=="{"then return parseObject(cb)elseif db=="["then return parseArray(cb)elseif
tonumber(db)~=nil or bb[db]then return parseNumber(cb)elseif cb:sub(1,4)=="true"or
cb:sub(1,5)=="false"then return parseBoolean(cb)elseif db=="\""then return
parseString(cb)elseif cb:sub(1,4)=="null"then return parseNull(cb)end;return nil end
function decode(cb)cb=removeWhite(cb)t=parseValue(cb)return t end
function decodeFromFile(cb)local db=assert(fs.open(cb,"r"))
local _c=decode(db.readAll())db.close()return _c end
]]

local JSON = setmetatable( {}, { __index = _G } )
select( 1, load( JSON_API, "JSON_API", "t", JSON ) )()


local function out(text, color, level)
	if (logLevel >= (level or 0)) then
		term.setTextColor(color or 1)
		print(text)
	end
end

local function readFile(path)
	local h = fs.open(path, "r")
	local data = h.readAll()
	h.close()
	return data
end

local function writeFile(path, data)
	local h = fs.open(path, "w")
	local d = type(data) == "table" and textutils.serialize(data) or data
	h.write(d)
	h.close()
end

local function ensureFileStructure()
	if not fs.exists("/.ccpm") then
		fs.makeDir("/.ccpm")
	end
	if not fs.exists("/.ccpm/packages") then
		fs.makeDir("/.ccpm/packages")
	end
	if not fs.exists("/.ccpm/sources.list") then
		out("Source list not found, creating...", colors.orange)
		writeFile("/.ccpm/sources.list", sources)
	end
	if not fs.exists("/.ccpm/cache.list") then
		out("Package cache not found, creating...", colors.orange)
		writeFile("/.ccpm/cache.list", sourceCache)
	end
	if not fs.exists("/.ccpm/packages.list") then
		out("Package list not found, creating...", colors.orange)
		writeFile("/.ccpm/packages.list", installedPackages)
	end
end

local function ensureVariable(var, typedef)
	if var == nil then
		out(typedef.." not specified", colors.red)
		return false
	end
	return true
end

local function readConfigs(bSources, bSourcesCache, bPackages)
	if bSources then
		out("Reading sources...", colors.gray, 1)
		sources = textutils.unserialize(readFile("/.ccpm/sources.list"))
	end
	if bSourcesCache then
		out("Reading source cache...", colors.gray, 1)
		sourceCache = textutils.unserialize(readFile("/.ccpm/cache.list"))
	end
	if bPackages then
		out("Reading package list...", colors.gray, 1)
		installedPackages = textutils.unserialize(readFile("/.ccpm/packages.list"))
	end
end


local function httpRequest(url, jsonDecode)
	out("Fetching "..url, colors.cyan)

	local h

	parallel.waitForAny(function()
		h = http.get(url) or out("Fetch failed", colors.red)
	end, function()
		sleep(10)
		out("Request timed out", colors.red)
	end)

	if h then
		local data = h.readAll()
		h.close()

		if jsonDecode then
			local d = JSON.decode(data) or out("Decode failed", colors.red)

			if type(d) ~= "table" then
				out("Failed to determine format", colors.red)
			end

			out("Request succeeded", colors.lime)
			return d
		else
			out("Request succeeded", colors.lime)
			return data
		end
	end
end

local function populateSource(url, srcList)
	for i = 1, #sources do
		if sources[i].url == url then
			sources[i].name = srcList.name
			sources[i].codeName = srcList.codeName
			sources[i].description = srcList.description
			break
		end
	end
end

local function fetchPackage(package)
	fs.makeDir("/.ccpm/packages/"..package.name)

	local data = httpRequest(package.fetchUrl)

	if data then
		writeFile("/.ccpm/packages/"..package.name.."/install.lua", data)
		return true
	else
		return false
	end
end

local function determineDifferences()
	local diff = {}
	for _, package in pairs(installedPackages) do
		--Test if sources contain installed package
		if sourceCache[package.name] then
			if tonumber(package.version) < tonumber(sourceCache[package.name].version) then
				out(package.name.." outdated", colors.gray, 2)
				table.insert(diff, package)
			end
		end
		--If above check fails, then package has no configured source
		--TODO: Mark package as orphaned
	end
	return diff
end

local function tabulatePackages(table)
	local w, _ = term.getSize()
	local lineWidth = 2

	write("  ")

	for _, package in pairs(table) do
		if lineWidth + #package.name + 1 < w then
			write(package.name.." ")
			lineWidth = lineWidth + #package.name + 1
		else
			print(package.name)
			write("  ")
			lineWidth = 2
		end
	end

	if lineWidth > 2 then print() end
end

local function outHelp()
	out("CCPM "..version)
	print()
	out("Usage: ccpm command [arguments]", colors.lightBlue)
	print()
	out("Available commands:")
	out("  update: Fetch package lists from sources")
	out("  install: Install packages")
	out("  remove: Remove an installed package")
	out("  upgrade: Upgrades installed packages")
	out("  list: Lists installed packages")
	out("  clean: Remove cached content")
	out("  show: See package details")
	out("  search: Search in package cache")
	out("  source: Manipulate sources")
	out("  help: Show this text")
end


--Begin
for _, arg in ipairs({...}) do

	--Test if arg is argument
	if string.sub(arg, 1, 1) == "-" then
		if arg == "-d" then
			logLevel = 1
		elseif arg =="-dd" then
			logLevel = 2
		elseif arg == "-y" then
			assumeYes = true
		elseif arg == "-m" then
			skipMissing = true
		else
			--TODO: Consider breaking to avoid operational errors
			out("Unknown argument: "..arg, colors.lightGray)
		end
	else
		--arg is command
		if not method then
			method = arg
		else
			table.insert(cmds, arg)
		end
	end
end

ensureFileStructure()

if method == "update" then
	local sourcesFailed = 0
	readConfigs(true, true, true)
	out("Updating package lists...", colors.lightBlue)

	if next(sources) == nil then
		out("No sources configured", colors.red)
		return
	end

	for i = 1, #sources do
		local source = sources[i]
		local srcList = nil
		if source.active then
			srcList = httpRequest(source.url, true)
		end

		if srcList then
			--out("Parsing packages from "..source.codeName, colors.gray, 2)
			populateSource(source.url, srcList)
			for j = 1, #srcList.packages do
				local package = srcList.packages[j]
				package.source = source.codeName

				if not package.fetchUrl then
					local fetchUrl = srcList.packageFetchUrl:gsub("$name", package.name)
					fetchUrl = fetchUrl:gsub("$versionName", package.versionName)
					fetchUrl = fetchUrl:gsub("$version", package.version)
					package.fetchUrl = fetchUrl
				end

				--Test if package already in cache
				if sourceCache[package.name] then
					--Don't insert if source version is lower than cached version
					if tonumber(sourceCache[package.name].version) < tonumber(package.version) then
						out(package.name.." newest from "..source.codeName..", inserting", colors.gray, 2)
						sourceCache[package.name] = package
					else
						out("Cache has newer version of "..package.name..", skipping", colors.gray, 2)
					end
				else
					out("New package: "..package.name..", inserting", colors.gray, 2)
					sourceCache[package.name] = package
				end
			end
		elseif source.active then
			sourcesFailed = sourcesFailed + 1
		end
	end
	out("Writing sources...", colors.gray, 1)
	writeFile("/.ccpm/sources.list", textutils.serialize(sources))

	out("Writing source cache...", colors.gray, 1)
	writeFile("/.ccpm/cache.list", textutils.serialize(sourceCache))

	out("Calculating differences...", colors.lightGray, 1)

	local diff = determineDifferences()

	if #diff > 0 then
		if sourcesFailed > 0 then
			out(#diff.." package(s) upgradable, but "..sourcesFailed.." source(s) failed to update", colors.yellow)
		else
			out(#diff.." package(s) upgradable", colors.lime)
		end
	else
		if sourcesFailed > 0 then
			out("Up-to-date, but "..sourcesFailed.." source(s) failed to update", colors.yellow)
		else
			out("Packages up-to-date", colors.lime)
		end
	end
elseif method == "install" then
	readConfigs(false, true, true)

	if next(sourceCache) == nil then
		out("Package cache empty, do 'ccpm update' first", colors.red)
		return
	end

	local packagesToInstall = cmds

	if #packagesToInstall == 0 then
		out("No package specified", colors.red)
		return
	end

	for i = 1, #packagesToInstall do
		if not sourceCache[packagesToInstall[i]] then
			out("Unable to locate "..packagesToInstall[i], colors.red)
			return
		end

		local package = sourceCache[packagesToInstall[i]]

		if fetchPackage(package) then
			out("Preparing to unpack "..package.name.." ["..package.versionName.."]", colors.white)

			local state = shell.run("/.ccpm/packages/"..package.name.."/install.lua", "install")

			if state then
				installedPackages[package.name] = sourceCache[package.name]
				out("Installed "..package.name.." successfully", colors.lime)
				fs.delete("/.ccpm/packages/"..package.name)
			else
				out("Installing "..package.name.." failed", colors.red)
			end
		else
			out("Fetching package failed, aborting", colors.red)
			return
		end
	end


	out("Writing package list...", colors.gray, 1)
	writeFile("/.ccpm/packages.list", textutils.serialize(installedPackages))
elseif method == "remove" then
	readConfigs(false, false, true)
	if not ensureVariable(cmds[1], "Package name") then return end

	for _, package in pairs(installedPackages) do
		if package.name == cmds[1] then
			out("Removing package "..package.name, colors.lightGray)
			installedPackages[package.name] = nil
			out("Package removed: "..package.name, colors.lime)

			out("Writing package list...", colors.gray, 1)
			writeFile("/.ccpm/packages.list", textutils.serialize(installedPackages))
			return
		end
	end

	out("Package not found: "..cmds[1], colors.red)

elseif method == "upgrade" then
	readConfigs(false, true, true)

	if next(sourceCache) == nil then
		out("Package cache empty, do 'ccpm update' first", colors.red)
		return
	end

	out("Calculating differences...", colors.lightGray, 1)

	local diff = determineDifferences()

	if #diff == 0 then
		out("All packages are up-to-date", colors.lime)
		return
	end

	out("The following packages are due for upgrade", colors.lightBlue)
	term.setTextColor(colors.white)

	tabulatePackages(diff)

	out("Do you want to continue? [Y/n]", colors.lightBlue)

	while true do
		if assumeYes then break end

		local e = {os.pullEvent()}

		if e[1] == "key" then
			if e[2] == 28 or e[2] == 21 then --Y or enter
				break
			elseif e[2] == 1 or e[2] == 49 then --N or escape
				out("Aborting...", colors.red)
				return
			end
		end
	end

	local skippedPackages = {}

	local packagesToInstall = {}
	for _, package in pairs(diff) do
		table.insert(packagesToInstall, sourceCache[package.name])
	end

	for _, package in pairs(packagesToInstall) do
		if not fetchPackage(package) then
			if skipMissing then
				out("Fetching "..package.name.." failed, skipping", colors.red)
				table.insert(skippedPackages, package)
			else
				out("Fetching "..package.name.." failed", colors.red)
				return
			end
		end
	end

	for _, package in pairs(packagesToInstall) do
		local skip = false
		for skipped in ipairs(skippedPackages) do
			if skipped.name == package.name then
				skip = true
				break
			end
		end

		if not skip then
			out("Preparing to unpack "..package.name.." ["..package.versionName.."]", colors.white)

			local state = shell.run("/.ccpm/packages/"..package.name.."/install.lua", "install")

			if state then
				installedPackages[package.name] = sourceCache[package.name]
				out("Installed "..package.name.." successfully", colors.lime)
				fs.delete("/.ccpm/packages/"..package.name)
			else
				out("Installing "..package.name.." failed", colors.red)
			end
		end
	end

	out("Writing package list...", colors.gray, 1)
	writeFile("/.ccpm/packages.list", textutils.serialize(installedPackages))
elseif method == "list" then
	readConfigs(false, false, true)

	if cmds[1] == "upgradable" then
		readConfigs(false, true)

		if next(sourceCache) == nil then
			out("Package cache empty, do 'ccpm update' first", colors.red)
			return
		end

		out("Listing upgradable packages", colors.lightBlue)

		local diff = determineDifferences()

		for _, package in ipairs(diff) do
			local upgradable = sourceCache[package.name]

			term.setTextColor(colors.green)
			write(package.name)
			out("/"..package.source.." "..
				(upgradable.versionName or upgradable.version)..
				" [upgradable from "..
				(package.versionName or package.version)..
				"]")
		end
	else
		out("Listing installed packages", colors.lightBlue)

		for _, package in pairs(installedPackages) do
			term.setTextColor(colors.green)
			write(package.name)
			out("/"..package.source.." "..(package.versionName or package.version))
		end
	end
elseif method == "clean" then
	out("Cleaning package cache...", colors.lightBlue)
	fs.delete("/.ccpm/packages")
	fs.delete("/.ccpm/cache.list")
	out("Caches cleaned", colors.lime)
	return
elseif method == "show" then
	readConfigs(false, true, false)
	local package = sourceCache[cmds[1]]

	if not package then
		out("Package not found", colors.red)
		return
	end

	out("Showing package "..package.name, colors.lightBlue)

	for key, val in pairs(package) do
		out(key..": "..val)
	end
elseif method == "source" then
	local doSave = false
	readConfigs(true)

	if cmds[1] == "list" then
		out("Listing sources", colors.lightBlue)

		for i, source in ipairs(sources) do
			term.setTextColor(source.active and colors.lime or colors.red)
			write(i..": ")
			if source.name then
				out(source.name.." ("..source.url..")", colors.white)
			else
				out(source.url.." (NYP)", colors.white)
			end
		end
	elseif cmds[1] == "add" then
		if not ensureVariable(cmds[2], "URL") then return end

		out("Creating source with URL: "..cmds[2], colors.lightGray)
		source = {}
		source.url = cmds[2]
		source.active = true

		table.insert(sources, source)
		out("Added source; run 'ccpm update' to use", colors.lime)
		doSave = true
	elseif cmds[1] == "remove" then
		if not ensureVariable(cmds[2], "Source index") then return end

		for i, source in ipairs(sources) do
			if i == tonumber(cmds[2]) then
				table.remove(sources, i)
				out("Removed source with URL: "..source.url, colors.lime)
				doSave = true
				break
			end
		end
	elseif cmds[1] == "toggle" then
		if not ensureVariable(cmds[2], "Source index") then return end

		for i, source in ipairs(sources) do
			if i == tonumber(cmds[2]) then
				source.active = not source.active
				out((source.active and "Enabled" or "Disabled").." source with URL: "..source.url, colors.lime)
				doSave = true
				break
			end
		end
	elseif cmds[1] == "show" then
		if not ensureVariable(cmds[2], "Source index") then return end

		for i, source in ipairs(sources) do
			if i == tonumber(cmds[2]) then
				out("Showing source properties", colors.lightBlue)
				for key, val in pairs(source) do
					out(key..": "..tostring(val))
				end
				return
			end
		end
		out("Source with index "..cmds[2].." not found", colors.red)
	else
		out("Unknown argument"..(cmds[1] and ": "..cmds[1] or ""), colors.red)
	end

	if doSave then
		out("Writing sources...", colors.gray, 1)
		writeFile("/.ccpm/sources.list", textutils.serialize(sources))
	end
elseif method == "search" then
	readConfigs(false, true)
	if not ensureVariable(cmds[1], "Search string") then return end

	if next(sourceCache) == nil then
		out("Package cache empty, do 'ccpm update' first", colors.red)
		return
	end

	out("Searching package cache...", colors.lightBlue)

	for _, package in pairs(sourceCache) do
		if string.find(package.name:lower(), cmds[1]) then
			term.setTextColor(colors.green)
			write(package.name)
			out("/"..package.source.." "..(package.versionName or package.version))
			out("  "..package.description)
			print()
		end
	end

elseif method == "help" then
	outHelp()
	return
else
	if method == nil then
		outHelp()
		out("Nothing to do, exiting", colors.lightBlue)
	else
		out("Unknown command: "..method, colors.red)
	end
end
