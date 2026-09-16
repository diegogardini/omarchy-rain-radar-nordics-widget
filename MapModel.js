// A local equirectangular map, with longitude scaled at 60 degrees north
// (near where most of the region's population sits, from Oslo/Stockholm/
// Copenhagen/Helsinki northward). Both drawing and picking use this
// transform, including its letterboxing.
var bounds = { west: 4.5, east: 31.8, south: 54.4, north: 71.3 }
var longitudeScale = Math.cos(60 * Math.PI / 180)
var cities = [
  { name: "Oslo", latitude: 59.9139, longitude: 10.7522, dx: 9, dy: 0, country: "Norway" },
  { name: "Bergen", latitude: 60.3913, longitude: 5.3221, dx: 9, dy: 0, country: "Norway" },
  { name: "Trondheim", latitude: 63.4305, longitude: 10.3951, dx: 9, dy: 0, country: "Norway" },
  { name: "Stavanger", latitude: 58.9700, longitude: 5.7331, dx: -9, dy: 12, align: "right", country: "Norway" },
  { name: "Tromsø", latitude: 69.6492, longitude: 18.9553, dx: 9, dy: 0, country: "Norway" },
  { name: "Stockholm", latitude: 59.3293, longitude: 18.0686, dx: 9, dy: 0, country: "Sweden" },
  { name: "Gothenburg", latitude: 57.7089, longitude: 11.9746, dx: -9, dy: -10, align: "right", country: "Sweden" },
  { name: "Malmö", latitude: 55.6050, longitude: 13.0038, dx: 9, dy: 9, country: "Sweden" },
  { name: "Uppsala", latitude: 59.8586, longitude: 17.6389, dx: 9, dy: -9, country: "Sweden" },
  { name: "Umeå", latitude: 63.8258, longitude: 20.2630, dx: 9, dy: 0, country: "Sweden" },
  { name: "Helsinki", latitude: 60.1699, longitude: 24.9384, dx: 9, dy: 0, country: "Finland" },
  { name: "Tampere", latitude: 61.4978, longitude: 23.7610, dx: -9, dy: -10, align: "right", country: "Finland" },
  { name: "Turku", latitude: 60.4518, longitude: 22.2666, dx: -9, dy: 10, align: "right", country: "Finland" },
  { name: "Oulu", latitude: 65.0121, longitude: 25.4651, dx: 9, dy: 0, country: "Finland" },
  { name: "Rovaniemi", latitude: 66.5039, longitude: 25.7294, dx: 9, dy: 0, country: "Finland" },
  { name: "Copenhagen", latitude: 55.6761, longitude: 12.5683, dx: -9, dy: 12, align: "right", country: "Denmark" },
  { name: "Aarhus", latitude: 56.1629, longitude: 10.2039, dx: 9, dy: -9, country: "Denmark" },
  { name: "Odense", latitude: 55.4038, longitude: 10.4024, dx: -9, dy: 12, align: "right", country: "Denmark" },
  { name: "Aalborg", latitude: 57.0488, longitude: 9.9217, dx: -9, dy: -10, align: "right", country: "Denmark" }
]

// Finland's UTC offset (EET/EEST) is one hour ahead of Norway/Sweden/
// Denmark's (CET/CEST). There's no clean lat/lon split at the real border,
// but this longitude threshold correctly classifies every seeded city above
// and only misclassifies far northeastern Norway (e.g. Kirkenes), a sparse
// edge case — see Model.js's nordicTimeLabel.
var finlandLongitudeThreshold = 21.5

// Per-country zoom views for the location picker: Denmark's small footprint
// within the full Nordics bounds makes precise picking hard at that zoom
// level, so the picker can switch to one of these tighter views instead.
// Bounds are padded from each country's actual Natural Earth extent;
// longitudeScale is chosen per country's own mid-latitude.
var countryViews = {
  Denmark: { bounds: { west: 7.7, east: 15.5, south: 54.3, north: 58.1 }, longitudeScale: Math.cos(56 * Math.PI / 180) },
  Norway: { bounds: { west: 4.3, east: 31.5, south: 57.7, north: 71.6 }, longitudeScale: Math.cos(64 * Math.PI / 180) },
  Sweden: { bounds: { west: 10.6, east: 24.7, south: 54.9, north: 69.5 }, longitudeScale: Math.cos(62 * Math.PI / 180) },
  Finland: { bounds: { west: 20.1, east: 32.1, south: 59.4, north: 70.5 }, longitudeScale: Math.cos(65 * Math.PI / 180) }
}

// `view` optionally overrides {bounds, longitudeScale} for a country zoom;
// omitted (or falsy) means the full Nordics view above.
function resolveView(view) {
  return view || { bounds: bounds, longitudeScale: longitudeScale }
}

function viewport(width, height, view) {
  var v = resolveView(view)
  var scale = Math.max(0, Math.min((width - 32) / ((v.bounds.east - v.bounds.west) * v.longitudeScale), (height - 32) / (v.bounds.north - v.bounds.south)))
  return { scale: scale, x: (width - (v.bounds.east - v.bounds.west) * v.longitudeScale * scale) / 2,
    y: (height - (v.bounds.north - v.bounds.south) * scale) / 2 }
}

function project(latitude, longitude, width, height, view) {
  var v = resolveView(view)
  var vp = viewport(width, height, view)
  return { x: vp.x + (longitude - v.bounds.west) * v.longitudeScale * vp.scale,
    y: vp.y + (v.bounds.north - latitude) * vp.scale }
}

// A point the user clicked (rather than a named city) is labeled with its
// own coordinates, not a nearby city's name — the forecast is fetched for
// this exact point either way, and a "<City> Area" label previously implied
// the data was grouped or approximated by that city, which it never was.
function pointLocation(latitude, longitude) {
  var pad = function(n) { return n.toFixed(4) }
  return { name: pad(latitude) + "°N, " + pad(longitude) + "°E", latitude: latitude, longitude: longitude }
}

function namedLocation(location) {
  if (location && location.name === "Selected position") return pointLocation(location.latitude, location.longitude)
  return location
}

function unproject(x, y, width, height, view) {
  var v = resolveView(view)
  var vp = viewport(width, height, view)
  if (vp.scale <= 0) return null
  var latitude = v.bounds.north - (y - vp.y) / vp.scale
  var longitude = v.bounds.west + (x - vp.x) / (v.longitudeScale * vp.scale)
  if (latitude < v.bounds.south || latitude > v.bounds.north || longitude < v.bounds.west || longitude > v.bounds.east) return null
  return pointLocation(Number(latitude.toFixed(5)), Number(longitude.toFixed(5)))
}

if (typeof module !== "undefined") module.exports = { bounds: bounds, cities: cities, finlandLongitudeThreshold: finlandLongitudeThreshold, countryViews: countryViews, project: project, unproject: unproject, pointLocation: pointLocation, namedLocation: namedLocation }
