# Widget Extension Sample

Add a Widget Extension target to the example iOS app, then use `ExampleWidgetBundle.swift` as the entry point.

The sample is intentionally generic:

- it reads the shared template activity through `CapgoTemplateWidgetBridge`
- it resolves the selected surface into `svg + hotspots + metadata`
- it wires hotspot buttons through `CapgoTemplateActionIntent`

The sample view uses a placeholder card instead of a full SVG renderer. Replace the placeholder body with your renderer of choice while keeping the same bridge and action intent wiring.

Required setup in both the app target and the widget extension target:

- Enable the same App Group capability.
- Add `CapgoWidgetKitAppGroup` to `Info.plist`.
- Add `NSSupportsLiveActivities` to the app `Info.plist`.

Example shared App Group:

```xml
<key>CapgoWidgetKitAppGroup</key>
<string>group.app.capgo.widgetkit.exampleapp.widgetkit</string>
```
