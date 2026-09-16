function trim(value) {
  return String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
}

function finiteNumber(value) {
  var number = parseFloat(trim(value))
  return isFinite(number) ? number : null
}

function parseWeatherLocation(raw) {
  try {
    var location = JSON.parse(String(raw || "{}"))
    var latitude = finiteNumber(location.latitude)
    var longitude = finiteNumber(location.longitude)
    if (latitude === null || longitude === null) return null
    return { name: trim(location.name), latitude: latitude, longitude: longitude }
  } catch (e) {
    return null
  }
}

function parseIpLocation(raw) {
  try {
    var location = JSON.parse(String(raw || "{}"))
    var latitude = finiteNumber(location.latitude)
    var longitude = finiteNumber(location.longitude)
    if (latitude === null || longitude === null) return null
    return {
      name: trim(location.city) || trim(location.region) || "Current position",
      latitude: latitude,
      longitude: longitude,
      country: trim(location.country_code).toUpperCase()
    }
  } catch (e) {
    return null
  }
}

// Sundays are the EU's DST boundary; both switches happen at 01:00 UTC.
// Applies to all four Nordic countries (CET/CEST and EET/EEST alike).
function lastSundayUtc(year, month) {
  var d = new Date(Date.UTC(year, month + 1, 1))
  d.setUTCDate(d.getUTCDate() - 1)
  d.setUTCDate(d.getUTCDate() - d.getUTCDay())
  return d
}

function isEuSummerTime(utcDate) {
  var year = utcDate.getUTCFullYear()
  var start = lastSundayUtc(year, 2)
  start.setUTCHours(1, 0, 0, 0)
  var end = lastSundayUtc(year, 9)
  end.setUTCHours(1, 0, 0, 0)
  return utcDate >= start && utcDate < end
}

// Norway, Sweden and Denmark use CET/CEST (UTC+1/+2); Finland uses EET/EEST
// (UTC+2/+3), one hour ahead. There's no clean coordinate split at the real
// border, so longitude is used as a simplification. Kept in sync with
// MapModel.js's identical constant by a test (same no-cross-import pattern
// as bounds above).
var finlandLongitudeThreshold = 21.5

function nordicTimeLabel(isoStep, longitude) {
  var d = new Date(isoStep)
  if (isNaN(d.getTime())) return ""
  var baseOffset = finiteNumber(longitude) !== null && longitude >= finlandLongitudeThreshold ? 2 : 1
  var offsetHours = baseOffset + (isEuSummerTime(d) ? 1 : 0)
  var local = new Date(d.getTime() + offsetHours * 3600000)
  var pad = function(n) { return (n < 10 ? "0" : "") + n }
  return pad(local.getUTCHours()) + ":" + pad(local.getUTCMinutes())
}

// MET Norway's Nowcast API already reports precipitation_rate in mm/h, so no
// unit conversion is needed (unlike DMI's kg/m^2/s HARMONIE output, which
// this widget used to rely on before switching to MET Norway's 5-minute
// radar nowcast). Each timeseries entry nests the value under
// data.instant.details.precipitation_rate. Parsed defensively since a
// malformed or partial entry shouldn't break the whole forecast.
function parseNowcastForecast(raw, longitude) {
  try {
    var data = JSON.parse(String(raw || "{}"))
    var series = Array.isArray(data.properties && data.properties.timeseries) ? data.properties.timeseries : []
    var samples = []
    for (var i = 0; i < series.length; i++) {
      var entry = series[i] || {}
      var details = entry.data && entry.data.instant && entry.data.instant.details
      var mm = finiteNumber(details && details.precipitation_rate)
      var time = nordicTimeLabel(entry.time, longitude)
      if (mm === null || !time) continue
      samples.push({ mm: mm, time: time, step: String(entry.time) })
    }
    samples.sort(function(a, b) { return a.step < b.step ? -1 : (a.step > b.step ? 1 : 0) })
    return samples
  } catch (e) {
    return []
  }
}

function intensity(mm) {
  var value = finiteNumber(mm)
  if (value === null || value < 0.1) return "Dry"
  if (value < 1) return "Drizzle"
  if (value < 2.5) return "Light rain"
  if (value < 10) return "Rain"
  return "Heavy rain"
}

function formatMm(mm) {
  var value = finiteNumber(mm)
  if (value === null) return "—"
  if (value < 0.05) return "0"
  if (value < 1) return value.toFixed(2)
  if (value < 10) return value.toFixed(1)
  return String(Math.round(value))
}

// Kept in sync with MapModel.js's bounds by a test, since there is no
// cross-.js-file import between them (same pattern the original code used).
// This rectangle is a rough approximation of the four Nordic countries'
// combined extent, not their actual (non-rectangular) shape or the real
// Nowcast coverage polygon — the live API's own 422 response is the
// authoritative check for a specific point.
var bounds = { west: 4.5, east: 31.8, south: 54.4, north: 71.3 }

function inCoverage(latitude, longitude) {
  var lat = finiteNumber(latitude)
  var lon = finiteNumber(longitude)
  return lat !== null && lon !== null && lat >= bounds.south && lat <= bounds.north && lon >= bounds.west && lon <= bounds.east
}

function locationKey(location) {
  return location ? location.latitude + "," + location.longitude : ""
}

function parseSelection(raw) {
  try {
    var state = JSON.parse(raw)
    if (state.mode === "automatic") return { mode: "automatic", settingsKey: state.settingsKey }
    var location = parseWeatherLocation(JSON.stringify(state.location))
    if (state.mode !== "selected" || !location || !inCoverage(location.latitude, location.longitude)) return null
    return { mode: "selected", location: location, settingsKey: state.settingsKey }
  } catch (e) { return null }
}

function forecastLocation(selection, configured, automatic) {
  if (selection) return selection.mode === "selected" ? selection.location : automatic
  return configured || automatic
}

if (typeof module !== "undefined") module.exports = {
  finiteNumber: finiteNumber,
  parseWeatherLocation: parseWeatherLocation,
  parseIpLocation: parseIpLocation,
  isEuSummerTime: isEuSummerTime,
  finlandLongitudeThreshold: finlandLongitudeThreshold,
  nordicTimeLabel: nordicTimeLabel,
  parseNowcastForecast: parseNowcastForecast,
  intensity: intensity,
  formatMm: formatMm,
  bounds: bounds,
  inCoverage: inCoverage,
  locationKey: locationKey,
  parseSelection: parseSelection,
  forecastLocation: forecastLocation
}
