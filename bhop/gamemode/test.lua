local AllFiles={"yolo/swag","yolo/fag","420","360/no/scope","!libs/somelib.lua"}
table.sort(AllFiles,function(a,b)--Files will run in alphabetical order, deepest files last
 if a and b then
  local NumSlashesA,NumSlashesB=select(2,a:gsub("/","/")),select(2,b:gsub("/","/"))
  return NumSlashesA==NumSlashesB and a<b or NumSlashesA<NumSlashesB
 end
end)
print(table.concat(AllFiles,","))