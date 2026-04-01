# Example App for `@capgo/capacitor-widget-kit`

This Vite app demonstrates the workout JSON flow used by the plugin:

- start a workout live activity
- complete sets from the app side
- read the stored session back from the shared store
- end the activity

## Run the browser preview

```bash
bun install
bun run start
```

The browser preview uses the plugin's web fallback store, so you can validate the state transitions without native tooling.

## Run the Maestro smoke test

From the plugin root:

```bash
bun run test:maestro
```

This starts the Vite preview server for the example app and runs a headless Maestro browser flow that covers:

- support detection
- starting the demo activity
- completing sets from the app
- reading the shared store back
- ending the activity
- checking the plugin version output

## Add iOS

```bash
bunx cap add ios
bunx cap sync ios
```

Then:

1. Add `NSSupportsLiveActivities` to the app `Info.plist`.
2. Add a shared App Group to the app and widget extension.
3. Set `CapgoWidgetKitAppGroup` in both `Info.plist` files.
4. Create a Widget Extension target and use the sample bundle in `widget-extension/ExampleWidgetBundle.swift`.
