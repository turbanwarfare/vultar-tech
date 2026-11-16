--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")

local MainModule = require(script.Parent.Game).get()
local Types = require(script.Types)
local Core = require(MainModule.Shared.Network.Core)

export type MouseBehaviorMode = Types.MouseBehaviorMode
export type GhostEntry = Types.GhostEntry
export type CameraPayload = Types.CameraPayload
export type CursorPayload = Types.CursorPayload
export type GhostPayload = Types.GhostPayload
export type InputPayload = Types.InputPayload
export type KeyHistoryPayload = Types.KeyHistoryPayload
export type HitPayload = Types.HitPayload
export type ConfigPayload = Types.ConfigPayload
export type StateSyncPayload = Types.StateSyncPayload

local ScreenWatchNetwork = {}
local NOOP_CONNECTION = { Disconnect = function() end }

local REMOTE_EXPORT_LOGS = "ScreenWatch_ExportLogs"

local function ensureServerRemotes()
	if RunService:IsServer() then
		Core.getOrCreateRemoteEvent(REMOTE_EXPORT_LOGS)
	end
end

ensureServerRemotes()

function ScreenWatchNetwork.sendCameraStreamTarget(payload: Types.CameraPayload): ()
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.CameraStreamTarget.Fire(payload)
end

function ScreenWatchNetwork.onCameraStreamTarget(
	callback: (player: Player, payload: Types.CameraPayload) -> ()
): { Disconnect: () -> () }
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.CameraStreamTarget.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.sendCameraStreamWatcher(watcher: Player, payload: Types.CameraPayload): ()
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.CameraStreamWatcher.Fire(watcher, payload)
end

function ScreenWatchNetwork.onCameraStreamWatcher(
	callback: (payload: Types.CameraPayload) -> ()
): { Disconnect: () -> () }
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.CameraStreamWatcher.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.sendGhostStreamTarget(payload: Types.GhostPayload): ()
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.GhostStreamTarget.Fire(payload)
end

function ScreenWatchNetwork.onGhostStreamTarget(
	callback: (player: Player, payload: Types.GhostPayload) -> ()
): { Disconnect: () -> () }
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.GhostStreamTarget.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.sendGhostStreamWatcher(watcher: Player, payload: Types.GhostPayload): ()
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.GhostStreamWatcher.Fire(watcher, payload)
end

function ScreenWatchNetwork.onGhostStreamWatcher(
	callback: (payload: Types.GhostPayload) -> ()
): { Disconnect: () -> () }
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.GhostStreamWatcher.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.sendCursorStreamTarget(payload: Types.CursorPayload): ()
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.CursorStreamTarget.Fire(payload)
end

function ScreenWatchNetwork.onCursorStreamTarget(
	callback: (player: Player, payload: Types.CursorPayload) -> ()
): { Disconnect: () -> () }
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.CursorStreamTarget.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.sendCursorStreamWatcher(watcher: Player, payload: Types.CursorPayload): ()
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.CursorStreamWatcher.Fire(watcher, payload)
end

function ScreenWatchNetwork.onCursorStreamWatcher(
	callback: (payload: Types.CursorPayload) -> ()
): { Disconnect: () -> () }
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.CursorStreamWatcher.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.sendInputEventTarget(payload: Types.InputPayload): ()
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.InputEventTarget.Fire(payload)
end

function ScreenWatchNetwork.onInputEventTarget(
	callback: (player: Player, payload: Types.InputPayload) -> ()
): { Disconnect: () -> () }
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.InputEventTarget.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.sendInputEventWatcher(watcher: Player, payload: Types.InputPayload): ()
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.InputEventWatcher.Fire(watcher, payload)
end

function ScreenWatchNetwork.onInputEventWatcher(
	callback: (payload: Types.InputPayload) -> ()
): { Disconnect: () -> () }
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.InputEventWatcher.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.sendKeyHistoryEventTarget(payload: Types.KeyHistoryPayload): ()
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.KeyHistoryEventTarget.Fire(payload)
end

function ScreenWatchNetwork.onKeyHistoryEventTarget(
	callback: (player: Player, payload: Types.KeyHistoryPayload) -> ()
): { Disconnect: () -> () }
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.KeyHistoryEventTarget.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.sendKeyHistoryEventWatcher(
	watcher: Player,
	payload: Types.KeyHistoryPayload
): ()
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.KeyHistoryEventWatcher.Fire(watcher, payload)
end

function ScreenWatchNetwork.onKeyHistoryEventWatcher(
	callback: (payload: Types.KeyHistoryPayload) -> ()
): { Disconnect: () -> () }
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.KeyHistoryEventWatcher.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.sendHitEventWatcher(
	watcher: Player,
	payload: Types.HitPayload
): ()
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.HitEventWatcher.Fire(watcher, payload)
end

function ScreenWatchNetwork.onHitEventWatcher(
	callback: (payload: Types.HitPayload) -> ()
): { Disconnect: () -> () }
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.HitEventWatcher.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.sendPreBufferStart(watcher: Player, seconds: number): ()
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.PreBufferStart.Fire(watcher, seconds)
end

function ScreenWatchNetwork.onPreBufferStart(callback: (seconds: number) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.PreBufferStart.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.sendPreBufferChunk(watcher: Player, chunk: Types.PreBufferChunk): ()
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.PreBufferChunk.Fire(watcher, chunk)
end

function ScreenWatchNetwork.onPreBufferChunk(callback: (chunk: Types.PreBufferChunk) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.PreBufferChunk.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.sendSubscribeWatch(targetUserId: number): ()
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.SubscribeWatch.Fire(targetUserId)
end

function ScreenWatchNetwork.onSubscribeWatch(
	callback: (player: Player, targetUserId: number) -> ()
): { Disconnect: () -> () }
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.SubscribeWatch.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.sendClientReady(): ()
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.ClientReady.Fire(nil :: any)
end

function ScreenWatchNetwork.onClientReady(callback: (player: Player) -> ()): { Disconnect: () -> () }
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.ClientReady.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.sendUnsubscribeWatch(targetUserId: number): ()
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.UnsubscribeWatch.Fire(targetUserId)
end

function ScreenWatchNetwork.onUnsubscribeWatch(
	callback: (player: Player, targetUserId: number) -> ()
): { Disconnect: () -> () }
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.UnsubscribeWatch.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.sendStartCapture(target: Player, config: Types.ConfigPayload): ()
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.StartCapture.Fire(target, config)
end

function ScreenWatchNetwork.onStartCapture(
	callback: (config: Types.ConfigPayload) -> ()
): { Disconnect: () -> () }
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.StartCapture.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.sendStopCapture(target: Player): ()
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.StopCapture.Fire(target, nil :: any)
end

function ScreenWatchNetwork.onStopCapture(
	callback: () -> ()
): { Disconnect: () -> () }
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.StopCapture.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.sendWatchStateSync(watcher: Player, payload: Types.StateSyncPayload): ()
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.WatchStateSync.Fire(watcher, payload)
end

function ScreenWatchNetwork.onWatchStateSync(
	callback: (payload: Types.StateSyncPayload) -> ()
): { Disconnect: () -> () }
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.WatchStateSync.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.sendOpenSelectMenu(player: Player): ()
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.OpenSelectMenu.Fire(player, nil :: any)
end

function ScreenWatchNetwork.onOpenSelectMenu(
	callback: () -> ()
): { Disconnect: () -> () }
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.OpenSelectMenu.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.sendExportLogs(
	chunks: { string },
	targetUserId: number,
	targetName: string,
	serialId: string?
): ()
	local remote = Core.getOrCreateRemoteEvent(REMOTE_EXPORT_LOGS)
	remote:FireServer({
		chunks = chunks,
		targetUserId = targetUserId,
		targetName = targetName,
		serialId = serialId,
	})
end

function ScreenWatchNetwork.onExportLogs(
	callback: (
		player: Player,
		data: { chunks: { string }, targetUserId: number, targetName: string, serialId: string? }
	) -> ()
): RBXScriptConnection
	local remote = Core.getOrCreateRemoteEvent(REMOTE_EXPORT_LOGS)
	return remote.OnServerEvent:Connect(function(player: Player, data: any)
		if typeof(data) == "table" and typeof(data.chunks) == "table" then
			callback(player, data)
		end
	end)
end

function ScreenWatchNetwork.sendAimSample(timestamp: number, origin: Vector3, direction: Vector3): ()
	local Blink = require(script.Generated.Client)
	Blink.ScreenWatch.AimSample.Fire(timestamp, origin, direction)
end

function ScreenWatchNetwork.onAimSample(
	callback: (player: Player, timestamp: number, origin: Vector3, direction: Vector3) -> ()
): { Disconnect: () -> () }
	local Blink = require(script.Generated.Server)
	Blink.ScreenWatch.AimSample.On(callback)
	return NOOP_CONNECTION
end

function ScreenWatchNetwork.init(): ()
	ensureServerRemotes()
end

return ScreenWatchNetwork
