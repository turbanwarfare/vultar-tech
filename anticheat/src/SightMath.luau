--!strict

local SightMath = {}

export type TrackRun = { start: number, last: number, travel: number }
export type TrackConfig = { MaxGap: number, MinSeconds: number, MinTravelDeg: number }
export type FlickSample = { t: number, visible: boolean, err: number }
export type FlickConfig = { MinStartDeg: number, OnTargetDeg: number, MaxSeconds: number }

function SightMath.blockedSpan(segmentLength: number, forwardDistance: number, reverseDistance: number?): number
	return math.max(0, segmentLength - forwardDistance - (reverseDistance or 0))
end

function SightMath.stepTrack(run: TrackRun?, t: number, qualifies: boolean, travelDelta: number, config: TrackConfig): (TrackRun?, boolean)
	if not qualifies then
		return nil, false
	end
	local current = run
	if not current or t - current.last > config.MaxGap then
		current = { start = t, last = t, travel = 0 }
	else
		current.last = t
		current.travel += travelDelta
	end
	if current.last - current.start >= config.MinSeconds and current.travel >= config.MinTravelDeg then
		return nil, true
	end
	return current, false
end

function SightMath.classifyFlick(samples: { FlickSample }, config: FlickConfig): (boolean, number?, number?)
	local appear = 0
	for index = #samples, 2, -1 do
		if samples[index].visible and not samples[index - 1].visible then
			appear = index
			break
		end
	end
	if appear == 0 then
		return false, nil, nil
	end
	local startErr = samples[appear].err
	local hiddenAt = samples[appear - 1].t
	for index = appear, #samples do
		local sample = samples[index]
		if not sample.visible then
			return false, nil, startErr
		end
		if sample.err <= config.OnTargetDeg then
			local acquisition = sample.t - hiddenAt
			return startErr >= config.MinStartDeg and acquisition <= config.MaxSeconds, acquisition, startErr
		end
	end
	return false, nil, startErr
end

function SightMath.effectiveError(angleDeg: number, radius: number, distance: number): number
	if distance <= 0 then
		return angleDeg
	end
	return math.max(0, angleDeg - math.deg(math.atan(radius / distance)))
end

function SightMath.locate(count: number, timeAt: (number) -> number, t: number): (number, number, number)
	if count == 0 then
		return 0, 0, 0
	end
	if t <= timeAt(1) then
		return 1, 1, 0
	end
	if t >= timeAt(count) then
		return count, count, 0
	end
	local low, high = 1, count
	while high - low > 1 do
		local mid = (low + high) // 2
		if timeAt(mid) <= t then
			low = mid
		else
			high = mid
		end
	end
	local t0, t1 = timeAt(low), timeAt(high)
	local alpha = if t1 > t0 then (t - t0) / (t1 - t0) else 0
	return low, high, alpha
end

return SightMath
