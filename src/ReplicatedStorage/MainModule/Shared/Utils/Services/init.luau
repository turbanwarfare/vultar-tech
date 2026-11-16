--!strict
--!native
--!optimize 2

local Services = {}

Services.Registry = require(script.ServiceRegistry)
Services.Locator = require(script.ServiceLocator)
Services.LazyService = require(script.LazyService)
Services.ServiceTrove = require(script.ServiceTrove)

return Services
