# Example App for `@capgo/capacitor-widget-kit`

This Capacitor example app demonstrates the generic SVG template flow used by the plugin:

- start a template activity
- resolve the lock-screen SVG surface
- trigger declarative actions from the app and hotspot overlays
- inspect the stored activity and event log
- acknowledge processed events
- end the activity

The included workout flow is just one helper built on top of the generic API.

## Run the native iOS example

```bash
bun install
bunx cap sync ios
open ios/App/App.xcodeproj
```

The native iOS host is configured to launch a real Live Activity through the plugin. The widget extension sample lives in `widget-extension/ExampleWidgetBundle.swift`.

## Run the native Android example

```bash
bun install
bunx cap sync android
open android
```

The Android host updates the shared template store. If the sample widget provider has been added to the home screen, it refreshes from that stored template state.

## Run the native Maestro smoke tests

From the plugin root:

```bash
bun run test:maestro:ios
```

If you have an Android emulator already running:

```bash
bun run test:maestro:android
```

The native flows cover:

- support detection
- starting the demo template
- triggering declarative actions from the native host app
- reading the stored activity and event log
- acknowledging events
- ending the activity
- checking the plugin version output

## Native wiring notes

1. Add `NSSupportsLiveActivities` to the iOS app `Info.plist`.
2. Add the same shared App Group to the iOS app target and widget extension target.
3. Set `CapgoWidgetKitAppGroup` in both iOS `Info.plist` files.
4. Use the sample iOS widget bundle in `widget-extension/ExampleWidgetBundle.swift` and replace the placeholder view with your SVG renderer.
5. On Android, add the sample `TemplateSampleWidgetProvider` to your app and place the widget on the home screen. The plugin updates the stored template state, and the provider resolves and renders it.
