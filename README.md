# Hanumaan — Sundara Kanda

An isometric 3D action RPG based on the *Sundara Kanda* of the Valmiki Ramayana, built in Godot 4.7 by the
[game factory](https://github.com/flypatang/game-factory). The full design is in [`docs/DESIGN.md`](docs/DESIGN.md).

## Develop
```sh
scripts/install-godot.sh          # verified Godot 4.7.2 + export templates into tools/
export GODOT=tools/godot/godot
scripts/check.sh                  # gate 1: static-typing script check
scripts/test.sh                   # gate 2: gdUnit4 unit tests
```

## Release
Pushing a `v*` tag runs the gates, exports Windows and Linux builds, and publishes them as a GitHub release.

Third-party: [gdUnit4](https://github.com/MikeSchulze/gdUnit4) (MIT) in `addons/gdUnit4`.
