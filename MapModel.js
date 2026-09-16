// A local equirectangular map, with longitude scaled at 60 degrees north
// (near where most of the region's population sits, from Oslo/Stockholm/
// Copenhagen/Helsinki northward). Both drawing and picking use this
// transform, including its letterboxing.
var bounds = { west: 4.5, east: 31.8, south: 54.4, north: 71.3 }
var longitudeScale = Math.cos(60 * Math.PI / 180)
var cities = [
  { name: "Oslo", latitude: 59.9139, longitude: 10.7522, dx: 9, dy: 0 },
  { name: "Bergen", latitude: 60.3913, longitude: 5.3221, dx: 9, dy: 0 },
  { name: "Trondheim", latitude: 63.4305, longitude: 10.3951, dx: 9, dy: 0 },
  { name: "Stavanger", latitude: 58.9700, longitude: 5.7331, dx: -9, dy: 12, align: "right" },
  { name: "Tromsø", latitude: 69.6492, longitude: 18.9553, dx: 9, dy: 0 },
  { name: "Stockholm", latitude: 59.3293, longitude: 18.0686, dx: 9, dy: 0 },
  { name: "Gothenburg", latitude: 57.7089, longitude: 11.9746, dx: -9, dy: -10, align: "right" },
  { name: "Malmö", latitude: 55.6050, longitude: 13.0038, dx: 9, dy: 9 },
  { name: "Uppsala", latitude: 59.8586, longitude: 17.6389, dx: 9, dy: -9 },
  { name: "Umeå", latitude: 63.8258, longitude: 20.2630, dx: 9, dy: 0 },
  { name: "Helsinki", latitude: 60.1699, longitude: 24.9384, dx: 9, dy: 0 },
  { name: "Tampere", latitude: 61.4978, longitude: 23.7610, dx: -9, dy: -10, align: "right" },
  { name: "Turku", latitude: 60.4518, longitude: 22.2666, dx: -9, dy: 10, align: "right" },
  { name: "Oulu", latitude: 65.0121, longitude: 25.4651, dx: 9, dy: 0 },
  { name: "Rovaniemi", latitude: 66.5039, longitude: 25.7294, dx: 9, dy: 0 },
  { name: "Copenhagen", latitude: 55.6761, longitude: 12.5683, dx: -9, dy: 12, align: "right" },
  { name: "Aarhus", latitude: 56.1629, longitude: 10.2039, dx: 9, dy: -9 },
  { name: "Odense", latitude: 55.4038, longitude: 10.4024, dx: -9, dy: 12, align: "right" },
  { name: "Aalborg", latitude: 57.0488, longitude: 9.9217, dx: -9, dy: -10, align: "right" }
]

// Finland's UTC offset (EET/EEST) is one hour ahead of Norway/Sweden/
// Denmark's (CET/CEST). There's no clean lat/lon split at the real border,
// but this longitude threshold correctly classifies every seeded city above
// and only misclassifies far northeastern Norway (e.g. Kirkenes), a sparse
// edge case — see Model.js's nordicTimeLabel.
var finlandLongitudeThreshold = 21.5

function viewport(width, height) {
  var scale = Math.max(0, Math.min((width - 32) / ((bounds.east - bounds.west) * longitudeScale), (height - 32) / (bounds.north - bounds.south)))
  return { scale: scale, x: (width - (bounds.east - bounds.west) * longitudeScale * scale) / 2,
    y: (height - (bounds.north - bounds.south) * scale) / 2 }
}

function project(latitude, longitude, width, height) {
  var v = viewport(width, height)
  return { x: v.x + (longitude - bounds.west) * longitudeScale * v.scale,
    y: v.y + (bounds.north - latitude) * v.scale }
}

function areaLocation(latitude, longitude) {
  var nearest = cities[0], minimum = Infinity
  var radians = Math.PI / 180
  for (var i = 0; i < cities.length; i++) {
    var city = cities[i]
    // Haversine distance ranks nearby cities without distorting longitude.
    var dLat = (city.latitude - latitude) * radians
    var dLon = (city.longitude - longitude) * radians
    var distance = Math.pow(Math.sin(dLat / 2), 2)
      + Math.cos(latitude * radians) * Math.cos(city.latitude * radians) * Math.pow(Math.sin(dLon / 2), 2)
    if (distance < minimum) { minimum = distance; nearest = city }
  }
  return { name: nearest.name + " Area", latitude: latitude, longitude: longitude }
}

function namedLocation(location) {
  if (location && location.name === "Selected position") return areaLocation(location.latitude, location.longitude)
  return location
}

function unproject(x, y, width, height) {
  var v = viewport(width, height)
  if (v.scale <= 0) return null
  var latitude = bounds.north - (y - v.y) / v.scale
  var longitude = bounds.west + (x - v.x) / (longitudeScale * v.scale)
  if (latitude < bounds.south || latitude > bounds.north || longitude < bounds.west || longitude > bounds.east) return null
  return areaLocation(Number(latitude.toFixed(5)), Number(longitude.toFixed(5)))
}

if (typeof module !== "undefined") module.exports = { bounds: bounds, cities: cities, finlandLongitudeThreshold: finlandLongitudeThreshold, project: project, unproject: unproject, areaLocation: areaLocation, namedLocation: namedLocation }
