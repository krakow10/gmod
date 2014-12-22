local next=next
local include=include
local AddCSLuaFile=AddCSLuaFile
local ff=file.Find
local ROOT=GM.FolderName.."/gamemode/"
local function ScanFiles(files,folders)
	local Nfiles=#files
	for i=1,#folders do
		local found=ScanFiles(ff(ROOT..folders[i].."*","LUA"))
		for j=1,#found do
			files[Nfiles+j]=found[j]
		end
		Nfiles=Nfiles+#found
	end
end
local AllFiles=ScanFiles(ff(ROOT))
table.sort(AllFiles,function(a,b)--Files will run in alphabetical order, deepest files last
	if a and b then
		local NumSlashesA,NumSlashesB=select(2,a:gsub("/","/")),select(2,b:gsub("/","/"))
		return NumSlashesA==NumSlashesB and a<b or NumSlashesA<NumSlashesB
	end
end)
local Handlers={
	sv_=function(filename)
		if filename:sub(-4):lower()==".lua" then
			if SERVER then
				include(filename)
			end
		end
	end,
	cl_=function(filename)
		if filename:sub(-4):lower()==".lua" then
			if CLIENT then
				include(filename)
			elseif SERVER then
				AddCSLuaFile(filename)
			end
		end
	end,
	sh_=function(filename)
		if filename:sub(-4):lower()==".lua" then
			if CLIENT then
				include(filename)
			elseif SERVER then
				AddCSLuaFile(filename)
				include(filename)
			end
		end
	end
}
for i=1,AllFiles do
	local filename=AllFiles[i]
	for p,f in next,Handlers do
		if filename:sub(1,#p)==p then --If the beginning of the file matches the index, run the corresponding function
			f(filename)
		end
	end
end
