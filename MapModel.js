// A local equirectangular map, with longitude scaled at 56 degrees north.
// Both drawing and picking use this transform, including its letterboxing.
var bounds = { west: 7.9, east: 15.3, south: 54.4, north: 58.0 }
var longitudeScale = Math.cos(56 * Math.PI / 180)
var cities = [
  { name: "Copenhagen", latitude: 55.6761, longitude: 12.5683, dx: 9, dy: 0 },
  { name: "Aarhus", latitude: 56.1629, longitude: 10.2039, dx: 9, dy: 0 },
  { name: "Odense", latitude: 55.4038, longitude: 10.4024, dx: -9, dy: 12, align: "right" },
  { name: "Aalborg", latitude: 57.0488, longitude: 9.9217, dx: 9, dy: -9 },
  { name: "Esbjerg", latitude: 55.4765, longitude: 8.4594, dx: -9, dy: 0, align: "right" },
  { name: "Randers", latitude: 56.4607, longitude: 10.0369, dx: 9, dy: -7 },
  { name: "Kolding", latitude: 55.4904, longitude: 9.4721, dx: -9, dy: 12, align: "right" },
  { name: "Horsens", latitude: 55.8607, longitude: 9.8503, dx: 9, dy: 9 },
  { name: "Vejle", latitude: 55.7091, longitude: 9.5357, dx: -9, dy: -10, align: "right" },
  { name: "Roskilde", latitude: 55.6415, longitude: 12.0803, dx: -9, dy: -10, align: "right" },
  { name: "Herning", latitude: 56.1362, longitude: 8.9736, dx: -9, dy: 0, align: "right" },
  { name: "Silkeborg", latitude: 56.1697, longitude: 9.5453, dx: 9, dy: 12 },
  { name: "Næstved", latitude: 55.2299, longitude: 11.7607, dx: 9, dy: 9 },
  { name: "Frederikshavn", latitude: 57.4407, longitude: 10.5335, dx: 9, dy: -5 },
  { name: "Sønderborg", latitude: 54.9092, longitude: 9.7926, dx: 9, dy: 9 },
  { name: "Rønne", latitude: 55.1004, longitude: 14.7065, dx: 9, dy: 0 }
]

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

if (typeof module !== "undefined") module.exports = { bounds: bounds, cities: cities, project: project, unproject: unproject, areaLocation: areaLocation, namedLocation: namedLocation }
