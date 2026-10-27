# Widget Extension Sample

Add a Widget Extension target to the example iOS app, then use `ExampleWidgetBundle.swift` as the entry point.

The sample is intentionally generic:

- it reads the shared template activity through `CapgoTemplateWidgetBridge`
- it resolves the selected surface into `svg + hotspots + metadata`
- it renders the SVG with the built-in `CapgoTemplateSvgView`
- it wires hotspot buttons through `CapgoTemplateActionIntent`

The Home Screen widget and the Live Activity lock screen render the resolved SVG with the plugin's built-in `CapgoTemplateSvgView`. The placeholder card is shown only when no template activity is stored yet. Pass an `svgContent` closure to `CapgoTemplateHomeWidgetView` or `CapgoTemplateSurfaceView` if you want to wrap or replace the built-in renderer.

Required setup in both the app target and the widget extension target:

- Enable the same App Group capability.
- Add `CapgoWidgetKitAppGroup` to `Info.plist`.
- Add `NSSupportsLiveActivities` to the app `Info.plist`.

Example shared App Group:

```xml
<key>CapgoWidgetKitAppGroup</key>
<string>group.app.capgo.widgetkit.exampleapp.widgetkit</string>
```
