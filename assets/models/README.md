# Vehicle model asset

`ev_health_car.glb` is the Khronos Group glTF Sample Asset `ToyCar.glb`.
It is a generic interactive vehicle illustration, not a model of a registered
vehicle. The sample is dedicated to the public domain under CC0 1.0 Universal:

- Source: https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/ToyCar
- License: https://creativecommons.org/publicdomain/zero/1.0/

Replace this asset with a properly licensed, vehicle-specific GLB when one is
available. The sample's body mesh is not split into real battery, motor, brake,
or tire meshes, so the health screen does not display fake component hotspots.
The oversized `Fabric` scene node in the original sample is omitted so the
uncovered vehicle is the visible model.

The GLB is declared as a Flutter asset in `pubspec.yaml`. On Flutter web, app
assets are served below `assets/assets/`; the health screen resolves the model
URL against the app's base URL so it also works when deployed under a path
prefix. The web viewer uses `model_viewer_plus`'s HTML renderer and listens to
the model-viewer's native load/error events. The native viewer uses
`model_viewer_pro` and its embedded WebView asset loader.
