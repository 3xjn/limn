--!strict

local suites = {
	{ name = "Geometry", run = require("./Geometry.spec") },
	{ name = "Canvas", run = require("./Canvas.spec") },
	{ name = "InputRouter", run = require("./InputRouter.spec") },
	{ name = "RuntimeAdapters", run = require("./RuntimeAdapters.spec") },
	{ name = "Bundle", run = require("./Bundle.spec") },
}

for _, suite in suites do
	suite.run()
	print(string.format("PASS %s", suite.name))
end

print(string.format("%d suites passed", #suites))
