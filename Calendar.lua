function Initialize()
    local now = os.date("*t")
    SKIN:Bang('!SetVariable', 'CURRENTYEAR', now.year)
    SKIN:Bang('!SetVariable', 'CURRENTMONTH', now.month)
end

function getNoteStatus(fullPath)
    local f = io.open(fullPath, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()

    local hasUnchecked = false
    local hasChecked = false

    for line in content:gmatch("[^\r\n]+") do
        -- Убираем начальные пробелы
        local trimmed = line:match("^%s*(.*)") or line
        -- Проверяем чекбоксы с возможными пробелами внутри скобок
        if trimmed:match("^%-%s*%[%s*%]") then
            hasUnchecked = true
        elseif trimmed:match("^%-%s*%[%s*[xX]%s*%]") then
            hasChecked = true
        end
    end

    if hasUnchecked then
        return "incomplete"
    elseif hasChecked then
        return "complete"
    else
        return "nochecklist"
    end
end

function Update()
    local now = os.date("*t")
    local year, month, today = now.year, now.month, now.day

    SKIN:Bang('!SetVariable', 'CURRENTYEAR', year)
    SKIN:Bang('!SetVariable', 'CURRENTMONTH', month)
    SKIN:Bang('!SetVariable', 'CURRENTDAY', today)

    local monthName = os.date("%B", os.time{year=year, month=month, day=1})
    SKIN:Bang('!SetOption', 'MeterTitle', 'Text', monthName .. " " .. year)

    local firstDayWday = tonumber(os.date("%w", os.time{year=year, month=month, day=1}))
    local firstDayOffset = (firstDayWday == 0) and 6 or (firstDayWday - 1)
    local daysInMonth = getDaysInMonth(year, month)

    SKIN:Bang("!HideMeterGroup", "Days")
    SKIN:Bang("!HideMeterGroup", "NoteIndicators")
    SKIN:Bang("!HideMeterGroup", "Weeks")

    drawDays(year, month, today, daysInMonth, firstDayOffset, now)
    drawWeeks(year, month, daysInMonth, firstDayOffset)
    return ""
end

function drawDays(year, month, today, daysInMonth, firstDayOffset, now)
    for day = 1, daysInMonth do
        local index = (day - 1) + firstDayOffset
        local row = math.floor(index / 7)
        local col = index % 7
        local x = 50 + col * 30
        local y = 65 + row * 25
        local meterName = "Day" .. day
        local highlightName = "HighlightDay" .. day
        local indicatorName = "NoteIndicator" .. day

        local vaultPath = "C:\\Users\\Lucky\\Documents\\Obsidian Vault\\daily-notes"
        local noteName = string.format("%04d-%02d-%02d.md", year, month, day)
        local fullPath = vaultPath .. "\\" .. noteName

        local fileExists = false
        local f = io.open(fullPath, "r")
        if f then
            fileExists = true
            f:close()
        end

        SKIN:Bang('!SetOption', meterName, 'X', x)
        SKIN:Bang('!SetOption', meterName, 'Y', y)
        SKIN:Bang('!SetOption', highlightName, 'X', x - 13)
        SKIN:Bang('!SetOption', highlightName, 'Y', y)
        local isToday = (day == today and month == now.month and year == now.year)
        local fontColor
        if isToday then
            fontColor = SKIN:GetVariable("TodayColor")
        elseif col == 5 or col == 6 then
            fontColor = SKIN:GetVariable("WeekendColor")
        else
            fontColor = SKIN:GetVariable("FontColor")
        end
        SKIN:Bang('!SetOption', meterName, 'FontColor', fontColor)
        SKIN:Bang('!SetOption', meterName, 'Text', tostring(day))
        SKIN:Bang('!SetOption', meterName, 'Group', 'Days')
        SKIN:Bang('!ShowMeter', meterName)

        SKIN:Bang('!SetOption', highlightName, 'Group', 'Highlights')

        SKIN:Bang('!SetOption', indicatorName, 'X', x )
        SKIN:Bang('!SetOption', indicatorName, 'Y', y + 20)
        SKIN:Bang('!SetOption', indicatorName, 'Group', 'NoteIndicators')

        if fileExists then
            local status = getNoteStatus(fullPath)
            local color
            if status == "incomplete" then
                color = SKIN:GetVariable("NoteIncompleteColor")
            elseif status == "complete" then
                color = SKIN:GetVariable("NoteCompleteColor")
            else -- "nochecklist"
                color = SKIN:GetVariable("NoteNoChecklistColor")
            end
            SKIN:Bang('!SetOption', indicatorName, 'Shape', 'Rectangle -6,0,12,1 | Fill Color ' .. color .. ' | StrokeWidth 0')
            SKIN:Bang('!ShowMeter', indicatorName)
        else
            SKIN:Bang('!HideMeter', indicatorName)
        end

    end
end

function drawWeeks(year, month, daysInMonth, firstDayOffset)
    for day = 1, daysInMonth do
        local index = (day - 1) + firstDayOffset
        local row = math.floor(index / 7)
        local col = index % 7

        if col == 0 or (day == 1 and firstDayOffset ~= 0) then
            local acadWeek = getAcademicWeek(year, month, day)
            if acadWeek then
                local weekMeter = "Week" .. (row + 1)
                local x = 17                        --координаты
                local y = 65 + row * 25
                SKIN:Bang('!SetOption', weekMeter, 'X', x)
                SKIN:Bang('!SetOption', weekMeter, 'Y', y)
                SKIN:Bang('!SetOption', weekMeter, 'Text', tostring(acadWeek))
                SKIN:Bang('!ShowMeter', weekMeter)
            end
        end
    end
end

function getDaysInMonth(y, m)
    if m == 2 then
        if (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0) then
            return 29
        else
            return 28
        end
    end
    local days = {31,28,31,30,31,30,31,31,30,31,30,31}
    return days[m]
end

function getAcademicWeek(y, m, d)
    local dateTs = os.time{year=y, month=m, day=d}
    local acadYear = (m >= 9) and y or (y - 1)
    local sep1 = os.time{year=acadYear, month=9, day=1}
    local wday = tonumber(os.date("%w", sep1))
    if wday == 0 then wday = 7 end
    local acadStart = sep1 - (wday - 1) * 86400
    if dateTs < acadStart then return nil end
    local diff = dateTs - acadStart
    return math.floor(diff / (7*86400)) + 1
end

function openDailyNote(y, m, d)
    local vaultFolder = "Obsidian Vault"
    local vaultPath = "C:\\Users\\Lucky\\Documents\\Obsidian Vault\\daily-notes"
    local noteName = string.format("%04d-%02d-%02d.md", y, m, d)
    local fullPath = vaultPath .. "\\" .. noteName

    local f = io.open(fullPath, "r")
    if not f then
        f = io.open(fullPath, "w")
        if f then
            -- f:write("# " .. string.format("%04d-%02d-%02d", y, m, d) .. "\n\n")
            f:close()
        end
    else
        f:close()
    end

    local relativePath = "daily-notes/" .. string.format("%04d-%02d-%02d", y, m, d)

    local function uriEncode(s)
        s = string.gsub(s, " ", "%%20")
        s = string.gsub(s, "%.", "%%2E")
        s = string.gsub(s, "_", "%%5F")
        s = string.gsub(s, "-", "%%2D")
        s = string.gsub(s, "/", "%%2F")
        return s
    end

    local uri = "obsidian://open?vault=" .. uriEncode(vaultFolder) .. "&file=" .. uriEncode(relativePath)

    SKIN:Bang('!SetOption', 'MeasureOpenURI', 'Parameter', 'cmd /c start "" "' .. uri .. '"')
    SKIN:Bang('!UpdateMeasure', 'MeasureOpenURI')
    SKIN:Bang('!CommandMeasure', 'MeasureOpenURI', 'Run')
end