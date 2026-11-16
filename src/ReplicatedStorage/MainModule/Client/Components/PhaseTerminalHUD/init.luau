--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Maps = require(MainModule.Shared.Config.Maps)
local MataroLayout = require(script.MataroLayout)

export type PhaseOwner = "Defenders" | "Raiders" | nil

type LayoutModule = {
	init: (parent: PlayerGui) -> (),
	setVisible: (visible: boolean) -> (),
	setPhaseState: (phase: number, official: boolean) -> (),
	setElapsedTime: (seconds: number) -> (),
	setTermTimeRemaining: (seconds: number) -> (),
	setTermProgress: (progress: number) -> (),
	setOwner: (owner: PhaseOwner) -> (),
	setCaptureState: (progress: number, team: PhaseOwner) -> (),
	setPayloadProgress: (progress: number, team: PhaseOwner) -> (),
	setConquestActive: (active: boolean) -> (),
	setOvertime: (active: boolean) -> (),
	resetPhaseData: () -> (),
	destroy: () -> (),
}

local LAYOUTS: { [string]: LayoutModule } = {
	Mataro = MataroLayout,
	Testing = MataroLayout,
}

local PhaseTerminalHUD = {}

local activeLayout: LayoutModule = MataroLayout

function PhaseTerminalHUD.init(parent: PlayerGui): ()
	local mapName = Maps.getMapName()
	activeLayout = (mapName and LAYOUTS[mapName]) or MataroLayout
	activeLayout.init(parent)
end

function PhaseTerminalHUD.setVisible(visible: boolean): ()
	activeLayout.setVisible(visible)
end

function PhaseTerminalHUD.setPhaseState(phase: number, official: boolean): ()
	activeLayout.setPhaseState(phase, official)
end

function PhaseTerminalHUD.setElapsedTime(seconds: number): ()
	activeLayout.setElapsedTime(seconds)
end

function PhaseTerminalHUD.setTermTimeRemaining(seconds: number): ()
	activeLayout.setTermTimeRemaining(seconds)
end

function PhaseTerminalHUD.setTermProgress(progress: number): ()
	activeLayout.setTermProgress(progress)
end

function PhaseTerminalHUD.setOwner(owner: PhaseOwner): ()
	activeLayout.setOwner(owner)
end

function PhaseTerminalHUD.setCaptureState(progress: number, team: PhaseOwner): ()
	activeLayout.setCaptureState(progress, team)
end

function PhaseTerminalHUD.setPayloadProgress(progress: number, team: PhaseOwner): ()
	activeLayout.setPayloadProgress(progress, team)
end

function PhaseTerminalHUD.setConquestActive(active: boolean): ()
	activeLayout.setConquestActive(active)
end

function PhaseTerminalHUD.setOvertime(active: boolean): ()
	activeLayout.setOvertime(active)
end

function PhaseTerminalHUD.resetPhaseData(): ()
	activeLayout.resetPhaseData()
end

function PhaseTerminalHUD.destroy(): ()
	activeLayout.destroy()
end

return PhaseTerminalHUD
