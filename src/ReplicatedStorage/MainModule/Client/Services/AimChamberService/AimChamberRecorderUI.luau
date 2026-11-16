local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Iris = require(Packages:WaitForChild("iris", 5))

return function(props: {
	VisibleState: any,
	ConfirmExportState: any,
	IsRecording: boolean,
	RecordedChunks: { string },
	FrameCount: number,
	ElapsedTime: number,
	OnStartRecording: () -> (),
	OnStopRecording: () -> (),
	OnExportDiscord: () -> (),
})


	Iris.Window({ [1] = "Movement Recorder", [Iris.Args.Window.NoCollapse] = true }, { isOpened = props.VisibleState })

	Iris.PushConfig({ TextColor = props.IsRecording and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(200, 200, 200) })
	Iris.Text({ "Status: " .. (props.IsRecording and "RECORDING" or "IDLE") })
	Iris.PopConfig()

	if props.IsRecording then
		Iris.PushConfig({ ButtonColor = Color3.fromRGB(200, 50, 50) })
		if Iris.Button({ "STOP RECORDING" }).clicked() then
			props.OnStopRecording()
		end
		Iris.PopConfig()
	else
		Iris.PushConfig({ ButtonColor = Color3.fromRGB(60, 60, 60) })
		if Iris.Button({ "START RECORDING" }).clicked() then
			props.OnStartRecording()
		end
		Iris.PopConfig()
	end

	Iris.Separator()

	Iris.Text({ "Recorded Frames: " .. props.FrameCount })
	Iris.Text({ "Recorded Time: " .. string.format("%.2f", props.ElapsedTime) .. "s" })

	Iris.Separator()

	Iris.PushConfig({ ButtonColor = Color3.fromRGB(88, 101, 242) })
	if Iris.Button({ "Export to VDI" }).clicked() then
		props.OnExportDiscord()
	end
	Iris.PopConfig()

	Iris.SeparatorText({ "Preview" })

	local chunkPreview = "No data recorded"
	if props.RecordedChunks and #props.RecordedChunks > 0 then
		if #props.RecordedChunks > 1 then
			chunkPreview = "-- Displaying chunk 1 of " .. #props.RecordedChunks .. " due to TextBox limits.\n" .. props.RecordedChunks[1]
		else
			chunkPreview = props.RecordedChunks[1]
		end
	end

	Iris.InputText({ [1] = "", [2] = chunkPreview, [Iris.Args.InputText.ReadOnly] = true })

	Iris.End()
end
