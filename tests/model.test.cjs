const { test } = require('node:test')
const assert = require('node:assert/strict')
const map = require('../MapModel.js')
const model = require('../Model.js')

test('map bounds stay in sync between MapModel.js and Model.js', () => {
  assert.deepEqual(model.bounds, map.bounds)
})

test('map clicks round-trip city coordinates at different sizes', () => {
  for (const [width, height] of [[560, 330], [300, 330], [900, 600]]) {
    for (const city of map.cities) {
      const point = map.project(city.latitude, city.longitude, width, height)
      const location = map.unproject(point.x, point.y, width, height)
      assert.ok(Math.abs(location.latitude - city.latitude) < 0.00001)
      assert.ok(Math.abs(location.longitude - city.longitude) < 0.00001)
      assert.ok(model.inCoverage(location.latitude, location.longitude))
    }
  }
})

test('clicks outside map bounds cannot create a location', () => {
  assert.equal(map.unproject(0, 0, 560, 330), null)
  assert.equal(map.unproject(560, 330, 560, 330), null)
  assert.equal(map.unproject(10, 10, 0, 0), null)
})

test('arbitrary points use the nearest mapped city without snapping coordinates', () => {
  for (const city of map.cities) {
    assert.deepEqual(map.areaLocation(city.latitude, city.longitude), {
      name: city.name + ' Area', latitude: city.latitude, longitude: city.longitude
    })
  }
  assert.deepEqual(map.areaLocation(55.63, 12.60), {
    name: 'Copenhagen Area', latitude: 55.63, longitude: 12.60
  })
  assert.equal(map.areaLocation(56.18, 10.22).name, 'Aarhus Area')
})

test('legacy generic names gain an area label while explicit names stay intact', () => {
  assert.deepEqual(map.namedLocation({name:'Selected position', latitude:55.63, longitude:12.60}), {
    name:'Copenhagen Area', latitude:55.63, longitude:12.60
  })
  const city = {name:'Copenhagen', latitude:55.6761, longitude:12.5683}
  assert.equal(map.namedLocation(city), city)
  assert.equal(map.namedLocation(null), null)
})

test('saved selection rejects corrupt and out-of-coverage coordinates', () => {
  for (const text of ['', '{', 'null', '{}', '{"mode":"selected"}',
    '{"mode":"selected","location":{"latitude":90,"longitude":11}}',
    '{"mode":"selected","location":{"latitude":"bad","longitude":11}}']) {
    assert.equal(model.parseSelection(text), null)
  }
  const saved = {mode: 'selected', location: map.cities[0], settingsKey: '["","",""]'}
  const parsed = model.parseSelection(JSON.stringify(saved))
  assert.equal(parsed.location.name, 'Copenhagen')
  assert.equal(parsed.settingsKey, saved.settingsKey)
})

test('manual choice survives automatic lookup and automatic mode ignores old coordinate overrides', () => {
  const selected = map.cities[0], automatic = map.cities[1], configured = map.cities[2]
  assert.equal(model.forecastLocation({mode:'selected', location:selected}, configured, automatic), selected)
  assert.equal(model.forecastLocation({mode:'automatic'}, configured, automatic), automatic)
  assert.equal(model.forecastLocation(null, configured, automatic), configured)
  assert.equal(model.forecastLocation(null, null, automatic), automatic)
  assert.equal(model.forecastLocation({mode:'automatic'}, configured, null), null)
})

test('forecast request keys depend on coordinates rather than names', () => {
  assert.equal(model.locationKey({...map.cities[0], name:'Renamed'}), model.locationKey(map.cities[0]))
  assert.notEqual(model.locationKey(map.cities[0]), model.locationKey(map.cities[1]))
  assert.notEqual(model.locationKey(null), model.locationKey(map.cities[0]))
})

test('DMI rain rate (kg/m^2/s) converts to mm/h', () => {
  assert.equal(model.dmiRateToMm(0), 0)
  assert.equal(model.dmiRateToMm(-1), 0)
  assert.equal(model.dmiRateToMm(null), 0)
  assert.equal(model.dmiRateToMm('bad'), 0)
  assert.ok(Math.abs(model.dmiRateToMm(0.0003) - 1.08) < 1e-9)
})

test('EU summer time boundaries land on the last Sunday of March/October at 01:00 UTC', () => {
  assert.equal(model.isEuSummerTime(new Date('2026-01-15T12:00:00Z')), false)
  assert.equal(model.isEuSummerTime(new Date('2026-07-15T12:00:00Z')), true)
  assert.equal(model.isEuSummerTime(new Date('2026-12-15T12:00:00Z')), false)
  // Last Sunday of March 2026 is the 29th; last Sunday of October 2026 is the 25th.
  assert.equal(model.isEuSummerTime(new Date('2026-03-29T00:59:00Z')), false)
  assert.equal(model.isEuSummerTime(new Date('2026-03-29T01:00:00Z')), true)
  assert.equal(model.isEuSummerTime(new Date('2026-10-25T00:59:00Z')), true)
  assert.equal(model.isEuSummerTime(new Date('2026-10-25T01:00:00Z')), false)
})

test('Copenhagen time labels apply the correct UTC offset', () => {
  assert.equal(model.copenhagenTimeLabel('2026-01-15T12:00:00Z'), '13:00')
  assert.equal(model.copenhagenTimeLabel('2026-07-15T12:00:00Z'), '14:00')
  assert.equal(model.copenhagenTimeLabel('not-a-date'), '')
})

test('DMI GeoJSON forecast responses parse into sorted mm/time samples', () => {
  const geojson = JSON.stringify({
    type: 'FeatureCollection',
    features: [
      { properties: { 'rain-precipitation-rate': 0.0006, step: '2026-01-15T14:00:00Z' } },
      { properties: { 'rain-precipitation-rate': 0, step: '2026-01-15T12:00:00Z' } },
      { properties: { 'rain-precipitation-rate': 0.0003, step: '2026-01-15T13:00:00Z' } }
    ]
  })
  const samples = model.parseDmiForecast(geojson)
  assert.equal(samples.length, 3)
  assert.equal(samples[0].time, '13:00')
  assert.equal(samples[1].time, '14:00')
  assert.equal(samples[2].time, '15:00')
  assert.ok(Math.abs(samples[0].mm - 0) < 1e-9)
  assert.ok(Math.abs(samples[1].mm - 1.08) < 1e-9)
  assert.ok(Math.abs(samples[2].mm - 2.16) < 1e-9)
})

test('DMI forecast parsing tolerates malformed features and invalid input', () => {
  assert.deepEqual(model.parseDmiForecast(''), [])
  assert.deepEqual(model.parseDmiForecast('not json'), [])
  assert.deepEqual(model.parseDmiForecast('{}'), [])
  const geojson = JSON.stringify({
    features: [
      { properties: { 'rain-precipitation-rate': 0.0003, step: '2026-01-15T13:00:00Z' } },
      { properties: {} },
      null,
      { properties: { 'rain-precipitation-rate': 0.0001, step: 'not-a-date' } }
    ]
  })
  const samples = model.parseDmiForecast(geojson)
  assert.equal(samples.length, 1)
  assert.equal(samples[0].time, '14:00')
})
