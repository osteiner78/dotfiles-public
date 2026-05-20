Status:children_add(function(self)
	local h = self._current.hovered
	if h and h.link_to then
		return " -> " .. tostring(h.link_to)
	else
		return ""
	end
end, 3300, Status.LEFT)

local function format_time(ts)
	if ts == nil or ts <= 0 then
		return ""
	end
	local s = math.floor(tonumber(ts) or 0)
	local sec = s % 60
	local min = math.floor(s / 60) % 60
	local hour = math.floor(s / 3600) % 24
	local day = math.floor(s / 86400)

	local year = 1970
	while true do
		local diy = (year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)) and 366 or 365
		if day < diy then
			break
		end
		day = day - diy
		year = year + 1
	end

	local md = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
	if year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0) then
		md[2] = 29
	end

	local month = 1
	while month <= 12 do
		if day < md[month] then
			break
		end
		day = day - md[month]
		month = month + 1
	end

	return string.format("%04d-%02d-%02d %02d:%02d", year, month, day + 1, hour, min)
end

Status:children_add(function()
	local h = cx.active.current.hovered
	if h == nil or h.cha == nil then
		return ""
	end
	return format_time(h.cha.mtime) .. "     "
end, 500, Status.RIGHT)

require("full-border"):setup({
	-- Available values: ui.Border.PLAIN, ui.Border.ROUNDED
	type = ui.Border.ROUNDED,
})
