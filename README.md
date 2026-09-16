# Rain Forecast Nordics

![Rain forecast popup preview](preview.png)

## Introduction

Winter is coming... and rain with it. Let's get our raincoats ready and keep an eye on this handy rain forecast widget.

An Omarchy Shell bar widget for MET Norway (Yr) rain nowcasts across
Norway, Sweden, Finland and Denmark. Click the widget to see the next 2
hours of rain in mm/h, refreshed every 5 minutes from live radar data.

## Location

Choose **Change location** (or press **C**) to open the map. Click a
city or any point on the map, then choose **Use selected location**.  
**Use automatic location** restores automatic lookup (IP based).

The forecast is provided by [MET Norway](https://www.met.no/) (published
via [Yr](https://www.yr.no/)) and is limited to the Nordic area (Norway,
Sweden, Finland and Denmark). Coordinates are sent to `api.met.no` when a
forecast is requested.

## Install

```bash
omarchy plugin add https://github.com/diegogardini/omarchy-rain-radar-nordics-widget.git --enable
```

## Remove

```bash
omarchy plugin remove io.github.diegogardini.omarchy-rain-radar-nordics-widget
```

To also remove the saved map choice, delete
`~/.local/state/omarchy/settings/rain-radar-location.json`.

## License and data

The plugin code is licensed under [MIT](LICENSE). It requires the Omarchy
Shell environment and `curl`, which is used to request forecasts from MET
Norway and approximate IP location from the configured providers. Rain
forecast data is provided by MET Norway under
[CC BY 4.0](https://api.met.no/doc/TermsOfService). The bundled map
outlines are Natural Earth public-domain data; see
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
