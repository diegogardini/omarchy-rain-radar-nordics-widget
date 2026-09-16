const { test } = require('node:test')
const assert = require('node:assert/strict')
const map = require('../MapModel.js')
const model = require('../Model.js')

test('Finland longitude threshold stays in sync between MapModel.js and Model.js', () => {
  assert.equal(model.finlandLongitudeThreshold, map.finlandLongitudeThreshold)
})

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

test('arbitrary points are labeled with their own coordinates, never a nearby city name', () => {
  for (const city of map.cities) {
    assert.deepEqual(map.pointLocation(city.latitude, city.longitude), {
      name: city.latitude.toFixed(4) + '°N, ' + city.longitude.toFixed(4) + '°E',
      latitude: city.latitude, longitude: city.longitude
    })
  }
  assert.deepEqual(map.pointLocation(59.95, 10.80), {
    name: '59.9500°N, 10.8000°E', latitude: 59.95, longitude: 10.80
  })
})

test('legacy generic names resolve to a coordinate label while explicit names stay intact', () => {
  assert.deepEqual(map.namedLocation({name:'Selected position', latitude:59.95, longitude:10.80}), {
    name: '59.9500°N, 10.8000°E', latitude:59.95, longitude:10.80
  })
  const city = {name:'Oslo', latitude:59.9139, longitude:10.7522}
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
  assert.equal(parsed.location.name, 'Oslo')
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

test('Nordic time labels use CET/CEST west of the Finland threshold and EET/EEST east of it', () => {
  // Oslo longitude: CET in winter (+1), CEST in summer (+2).
  assert.equal(model.nordicTimeLabel('2026-01-15T12:00:00Z', 10.75), '13:00')
  assert.equal(model.nordicTimeLabel('2026-07-15T12:00:00Z', 10.75), '14:00')
  // Helsinki longitude: EET in winter (+2), EEST in summer (+3).
  assert.equal(model.nordicTimeLabel('2026-01-15T12:00:00Z', 24.94), '14:00')
  assert.equal(model.nordicTimeLabel('2026-07-15T12:00:00Z', 24.94), '15:00')
  assert.equal(model.nordicTimeLabel('not-a-date', 10.75), '')
})

test('MET Norway Nowcast responses parse into sorted mm/time samples', () => {
  const payload = JSON.stringify({
    properties: {
      timeseries: [
        { time: '2026-01-15T13:00:00Z', data: { instant: { details: { precipitation_rate: 0.3 } } } },
        { time: '2026-01-15T12:00:00Z', data: { instant: { details: { precipitation_rate: 0.0 } } } },
        { time: '2026-01-15T12:30:00Z', data: { instant: { details: { precipitation_rate: 0.1 } } } }
      ]
    }
  })
  const samples = model.parseNowcastForecast(payload, 10.75)
  assert.equal(samples.length, 3)
  assert.equal(samples[0].time, '13:00')
  assert.equal(samples[1].time, '13:30')
  assert.equal(samples[2].time, '14:00')
  assert.equal(samples[0].mm, 0.0)
  assert.equal(samples[1].mm, 0.1)
  assert.equal(samples[2].mm, 0.3)
})

test('Nowcast parsing tolerates malformed entries and invalid input', () => {
  assert.deepEqual(model.parseNowcastForecast('', 10.75), [])
  assert.deepEqual(model.parseNowcastForecast('not json', 10.75), [])
  assert.deepEqual(model.parseNowcastForecast('{}', 10.75), [])
  const payload = JSON.stringify({
    properties: {
      timeseries: [
        { time: '2026-01-15T13:00:00Z', data: { instant: { details: { precipitation_rate: 0.3 } } } },
        { time: '2026-01-15T13:30:00Z', data: { instant: { details: {} } } },
        { data: { instant: { details: { precipitation_rate: 0.1 } } } },
        null
      ]
    }
  })
  const samples = model.parseNowcastForecast(payload, 10.75)
  assert.equal(samples.length, 1)
  assert.equal(samples[0].time, '14:00')
})
