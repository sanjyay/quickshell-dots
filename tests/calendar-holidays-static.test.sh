#!/usr/bin/env bash
set -Eeuo pipefail

service="versions/default/services/HolidayService.qml"
calendar="versions/default/panels/CalendarPopup.qml"
theme="versions/default/Theme.qml"
runtime="runtime/Bar.qml"
bar="versions/rise/Bar.qml"

require() {
  rg -Fq "$1" "$2" || { printf 'missing %s in %s\n' "$1" "$2" >&2; exit 1; }
}

require 'holidaysFor(isoDate)' "$calendar"
require 'visible: isCurrentMonth && isHoliday && root.holidays.showInGrid' "$calendar"
require 'visible: isToday' "$calendar"
require 'visible: isSelected && !isToday' "$calendar"
require 'model: calPopup.detailHolidays' "$calendar"
require 'root.selectedCalendarDate === isoDate' "$calendar"
require 'calendarIsoDate(day)' "$theme"
require 'const startDay = first.getDay();' "$theme"
require 'model: ["SU","MO","TU","WE","TH","FR","SA"]' "$calendar"
require 'dayOfWeek === 0 || dayOfWeek === 6' "$calendar"
require 'if (!enabled)' "$service"
require 'holidayProcess.command = [' "$service"
require 'requestKey !== desiredHolidayKey()' "$service"
require 'holidaysByDate = ({})' "$service"
require 'countrySelectionMode' "$service"
require 'configuredSubdivisionCode' "$service"
require 'countryActiveToken' "$service"
require 'requestedCountry !== effectiveCountryCode' "$service"
require 'modelData.key === "national"' "$calendar"
require '{ key: "regional", label: "State / regional public holidays" }' "$calendar"
require 'Use system timezone' "$calendar"
require 'State / Province / Region' "$calendar"
require 'National public holiday' "$calendar"
require 'India-wide recurring bank-branch closure' "$calendar"
require 'HolidaySelection.js' "$service"
require 'HolidayCalendarModel.js' "$service"
require 'markerClassesFor(isoDate)' "$calendar"
require 'modelData === "bank-closure"' "$calendar"
require 'modelData === "regional"' "$calendar"
require 'vibrantHolidayColor(root.color03)' "$calendar"
require '? root.color02 : root.indigo' "$calendar"
require 'border.color: markerColor' "$calendar"
require 'width: 19 + index * 3' "$calendar"
require 'radius: width / 2' "$calendar"
require 'function vibrantHolidayColor(themeColor)' "$calendar"
require 'Math.max(0.82, themeColor.hsvSaturation)' "$calendar"
require 'Math.max(0.95, themeColor.hsvValue)' "$calendar"
require 'Banks closed on second and fourth Saturdays are shown automatically.' "$calendar"
require 'visible: root.holidays.effectiveCountryCode === "IN"' "$calendar"
require 'writerCommand: ["node", service.helperPath, "state-write"]' "$service"
require 'countryQueued' "$service"
require 'detectionRefreshTimer' "$service"
! rg -q 'defaultCountry: *\"IN\"|defaultSubdivision: *\"TN\"' "$service" "$theme" ||
  { printf 'calendar runtime hard-codes a country or subdivision default\n' >&2; exit 1; }
! rg -q 'showBank|show-bank|key: \"bank\"|scope === \"bank\"' \
  "$service" "$theme" "$calendar" scripts/holiday-helper.js ||
  { printf 'obsolete generic bank holiday implementation remains active\n' >&2; exit 1; }
require 'function holidayDiagnostics()' "$bar"
require 'providerId: service.activeProviderId' "$bar"
require 'function showCalendarMonth(year, month)' "$bar"
require 'function openCalendar()' "$runtime"
require 'function showCalendarMonth(year: int, month: int): bool' "$runtime"
require 'function holidayDiagnostics(): string' "$runtime"
! rg -q 'new Date.*holiday|Date[.]parse.*holiday' "$calendar" "$service" ||
  { printf 'holiday integration must use local ISO dates\n' >&2; exit 1; }

printf 'ok (calendar holiday integration contract)\n'
