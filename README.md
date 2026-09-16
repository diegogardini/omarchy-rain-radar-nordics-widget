# Rain Forecast Denmark

![Rain forecast popup preview](preview.png)

## Introduction

Winter is coming... and rain with it. Let's get our raincoats ready and keep an eye on this handy rain forecast widget.

An Omarchy Shell bar widget for DMI (Danish Meteorological Institute)
forecasts across Denmark. Click the widget to see the next 12 hours of rain
in mm/h. This is an hourly weather-model forecast (DMI's HARMONIE model),
not a radar nowcast, so it won't catch a shower that starts and ends within
the hour.

## Location

Choose **Change location** (or press **C**) to open the map. Click a
city or any point on the map, then choose **Use selected location**.  
**Use automatic location** restores automatic lookup (IP based).

The forecast is provided by [DMI](https://www.dmi.dk/) and is limited to
Denmark. Coordinates are sent to `opendataapi.dmi.dk` when a forecast is
requested.

## Install

```bash
omarchy plugin add https://github.com/diegogardini/omarchy-rain-radar-denmark-widget.git --enable
```

## Remove

```bash
omarchy plugin remove io.github.diegogardini.omarchy-rain-radar-denmark-widget
```

To also remove the saved map choice, delete
`~/.local/state/omarchy/settings/rain-radar-location.json`.

## License and data

The plugin code is licensed under [MIT](LICENSE). It requires the Omarchy
Shell environment and `curl`, which is used to request forecasts from DMI
and approximate IP location from the configured providers. Rain forecast
data is provided by the Danish Meteorological Institute (DMI) under
[CC BY 4.0](https://www.dmi.dk/friedata/dokumentation/terms-of-use). The
bundled map outlines are Natural Earth public-domain data; see
[MAP-SOURCES.md](MAP-SOURCES.md).

The plugin reads Omarchy Weather's location file and only writes its own
`rain-radar-location.json` after the user explicitly saves a map selection.
It does not modify Omarchy configuration or other plugin state.


## Development

Validate the plugin and run the focused tests:

```bash
omarchy plugin validate .
node --test tests/*.test.cjs
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  /usr/lib/qt6/bin/qmltestrunner -input tests
```

`bash tests/check-panel.sh` runs an additional temporary Quickshell preview
with simulated forecasts. It does not modify the installed plugin.
