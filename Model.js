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

// DMI's rain-precipitation-rate parameter is in kg per square metre per second.
// 1 kg/m^2 of water is 1 mm of depth, so multiplying by 3600 gives mm/h.
function dmiRateToMm(value) {
  var rate = finiteNumber(value)
  if (rate === null || rate < 0) return 0
  return rate * 3600
}

// Sundays are the EU's DST boundary; both switches happen at 01:00 UTC.
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

function copenhagenTimeLabel(isoStep) {
  var d = new Date(isoStep)
  if (isNaN(d.getTime())) return ""
  var offsetHours = isEuSummerTime(d) ? 2 : 1
  var local = new Date(d.getTime() + offsetHours * 3600000)
  var pad = function(n) { return (n < 10 ? "0" : "") + n }
  return pad(local.getUTCHours()) + ":" + pad(local.getUTCMinutes())
}

// DMI's forecastedr API returns a GeoJSON FeatureCollection; each feature's
// properties carry the parameter value plus a "step" forecast timestamp.
// Parsed defensively since the shape is documented, not observed live.
function parseDmiForecast(raw) {
  try {
    var data = JSON.parse(String(raw || "{}"))
    var features = Array.isArray(data.features) ? data.features : []
    var samples = []
    for (var i = 0; i < features.length; i++) {
      var feature = features[i] || {}
      var props = feature.properties || {}
      var step = props.step || feature.step
      var mm = dmiRateToMm(props["rain-precipitation-rate"])
      var time = copenhagenTimeLabel(step)
      if (!time) continue
      samples.push({ mm: mm, time: time, step: String(step) })
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
var bounds = { west: 7.9, east: 15.3, south: 54.4, north: 58.0 }

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
  dmiRateToMm: dmiRateToMm,
  isEuSummerTime: isEuSummerTime,
  copenhagenTimeLabel: copenhagenTimeLabel,
  parseDmiForecast: parseDmiForecast,
  intensity: intensity,
  formatMm: formatMm,
  bounds: bounds,
  inCoverage: inCoverage,
  locationKey: locationKey,
  parseSelection: parseSelection,
  forecastLocation: forecastLocation
}
