--!strict
--!native
--!optimize 2

export type DeviceInfo = {
	platform: string,
	osVersion: string?,
	deviceType: string,
	memoryMb: number?,
	cpuCores: number?,
	graphicsCard: string?,
}

export type FrameSample = {
	timestamp: number,
	deltaTime: number,
	fps: number,
	heartbeatTime: number,
	renderTime: number?,
	physicsTime: number?,
}

export type AggregateStats = {
	avgFps: number,
	minFps: number,
	maxFps: number,
	p1Fps: number,
	p5Fps: number,
	avgFrameTime: number,
	maxFrameTime: number,
	frameDrops: number,
	stutterCount: number,
}

export type MemorySnapshot = {
	timestamp: number,
	totalMb: number,
	scriptsMb: number?,
	physicsMb: number?,
	instancesMb: number?,
	graphicsMb: number?,
}

export type WorldSnapshot = {
	totalInstances: number,
	partCount: number,
	meshPartCount: number?,
	scriptCount: number?,
	connectionCount: number?,
	activeHumanoids: number?,
	activeAnimations: number?,
	physicsBodyCount: number?,
}

export type DiagnosticEvent = {
	timestamp: number,
	eventType: string,
	severity: string,
	message: string,
	stackTrace: string?,
}

export type DumpMetadata = {
	dumpId: string,
	requesterId: number,
	requesterName: string,
	targetId: number,
	targetName: string,
	serverId: string,
	placeId: number,
	placeVersion: number,
	serverUptime: number,
	timestamp: number,
}

export type DiagnosticDump = {
	metadata: DumpMetadata,
	device: DeviceInfo,
	frames: { FrameSample },
	aggregate: AggregateStats,
	memory: { MemorySnapshot },
	world: WorldSnapshot,
	events: { DiagnosticEvent },
	networkStats: {
		pingMs: number?,
		dataReceived: number?,
		dataSent: number?,
	}?,
}

return nil
