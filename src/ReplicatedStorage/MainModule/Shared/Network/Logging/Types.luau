--!strict
--!native
--!optimize 2

export type LogSubmitData = {
	playerUsernames: { string },
	gameName: string,
}

export type LogSubmitResult = {
	success: boolean,
	error: string?,
}

export type LogPlayer = {
	name: string,
	userId: number,
	timeInServer: number,
}

return nil
