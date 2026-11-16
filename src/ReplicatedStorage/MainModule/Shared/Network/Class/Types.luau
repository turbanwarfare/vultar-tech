--!strict
--!native
--!optimize 2

export type ClassSelectResult = {
	success: boolean,
	error: string?,
	className: string?,
}

export type ClassSlotData = {
	current: number,
	max: number,
	players: { string },
}

export type ClassSlotsState = {
	[string]: ClassSlotData,
}

return nil
