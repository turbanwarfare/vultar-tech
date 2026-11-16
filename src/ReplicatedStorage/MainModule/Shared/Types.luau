--!strict
--!native
--!optimize 2

export type ServiceDefinition = {
	Name: string,
	init: (self: ServiceDefinition) -> (),
	start: (self: ServiceDefinition) -> (),
}

export type FusionValue<T> = {
	type: "State",
	kind: "Value",
	get: (self: FusionValue<T>) -> T,
	set: (self: FusionValue<T>, newValue: T) -> (),
}

export type FusionComputed<T> = {
	type: "State",
	kind: "Computed",
	get: (self: FusionComputed<T>) -> T,
}

export type FusionSpring<T> = {
	type: "State",
	kind: "Spring",
	get: (self: FusionSpring<T>) -> T,
}

export type FusionObserver = {
	onChange: (self: FusionObserver, callback: () -> ()) -> () -> (),
	onBind: (self: FusionObserver, callback: () -> ()) -> () -> (),
}

export type FusionCanBeState<T> = T | FusionValue<T> | FusionComputed<T> | FusionSpring<T>

export type FusionUseFn = <T>(target: FusionCanBeState<T>) -> T

export type FusionPeek = <T>(target: FusionCanBeState<T>) -> T

export type FusionNewFn = (self: FusionScope, className: string) -> (props: any) -> any

export type FusionScope = {
	Value: <T>(self: FusionScope, initial: T) -> FusionValue<T>,
	Computed: <T>(self: FusionScope, processor: (use: FusionUseFn, scope: FusionScope) -> T) -> FusionComputed<T>,
	Spring: <T>(self: FusionScope, goal: FusionCanBeState<T>, speed: number?, damping: number?) -> FusionSpring<T>,
	Observer: (self: FusionScope, watching: FusionCanBeState<any>) -> FusionObserver,
	New: FusionNewFn,
	ForValues: <VI, VO>(
		self: FusionScope,
		input: FusionCanBeState<{ VI }>,
		processor: (use: FusionUseFn, scope: FusionScope, value: VI) -> VO
	) -> FusionComputed<{ VO }>,
	ForPairs: <KI, VI, KO, VO>(
		self: FusionScope,
		input: FusionCanBeState<{ [KI]: VI }>,
		processor: (use: FusionUseFn, scope: FusionScope, key: KI, value: VI) -> (KO, VO)
	) -> FusionComputed<{ [KO]: VO }>,
}

export type ReplicationTarget = {
	Source: Folder,
	Destination: Instance,
	SkipExisting: boolean,
}

export type ReplicationResult = {
	Success: boolean,
	ItemsReplicated: number,
	ItemsSkipped: number,
	Errors: { string },
}

export type LoadingState = {
	IsLoading: boolean,
	IsComplete: boolean,
	Progress: number,
	CurrentStep: string,
}

export type RetryConfig = {
	MaxAttempts: number,
	InitialDelay: number,
	MaxDelay: number,
	BackoffMultiplier: number,
}

export type Faction = "Defenders" | "Raiders" | "Neutral"

export type TopPlayer = {
	UserId: number,
	DisplayName: string,
	Value: number,
}

export type TeamTopPlayers = {
	Kills: TopPlayer?,
	Damage: TopPlayer?,
	Heals: TopPlayer?,
}

export type VictoryData = {
	WinningTeam: "Defenders" | "Hostiles",
	DefenderTopPlayers: TeamTopPlayers,
	HostileTopPlayers: TeamTopPlayers,
	DefenderScore: number,
	HostileScore: number,
}

return nil
