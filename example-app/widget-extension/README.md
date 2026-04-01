# Widget Extension Sample

Add a Widget Extension target to the example iOS app, then use `ExampleWidgetBundle.swift` as the entry point.

Required setup in both the app target and the widget extension target:

- Enable the same App Group capability.
- Add `CapgoWidgetKitAppGroup` to `Info.plist`.
- Add `NSSupportsLiveActivities` to the app `Info.plist`.

Example shared App Group:

```xml
<key>CapgoWidgetKitAppGroup</key>
<string>group.app.capgo.widgetkit.exampleapp.widgetkit</string>
```
