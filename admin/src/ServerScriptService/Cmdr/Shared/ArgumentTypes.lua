return function(registry)
	registry:RegisterType("rankLength", registry.Cmdr.Util.MakeEnumType("rank length", { "perm", "temp" }))
end
