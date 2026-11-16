local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient"))

local Banner = require(script.Banner)
local Console = require(script.Console)
local Explosion = require(script.Explosion)
local Fly = require(script.Fly)
local Watch = require(script.Watch)

Console.Init(Cmdr)

Cmdr:HandleEvent("Banner", Banner.Show)
Cmdr:HandleEvent("Explosion", Explosion.Play)
Cmdr:HandleEvent("Fly", Fly.SetEnabled)
Cmdr:HandleEvent("Watch", Watch.SetTarget)
