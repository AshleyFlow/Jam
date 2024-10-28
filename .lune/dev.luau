--!strict
local process = require("@lune/process")
local stdio = require("@lune/stdio")

if stdio.prompt("confirm", "Install wally packages?", false) then
	print("Installing Wally Packages ...")

	process.spawn("wally", { "install" }, {
		stdio = "forward",
	})
end

print("Generating Sourcemap ...")

process.spawn("rojo", { "sourcemap", "dev.project.json", "-o", "sourcemap.json" }, {
	stdio = "forward",
})

print("Running Wally-Package-Types ...")

if
	not process.spawn("wally-package-types", { "--sourcemap", "sourcemap.json", "Packages" }, {
		stdio = "forward",
	}).ok
then
	print("Wally-Package-Types failed\n\tPackages most likely already have Types")
end
