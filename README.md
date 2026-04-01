# @capgo/capacitor-widget-kit
 <a href="https://capgo.app/"><img src='https://raw.githubusercontent.com/Cap-go/capgo/main/assets/capgo_banner.png' alt='Capgo - Instant updates for capacitor'/></a>

<div align="center">
  <h2><a href="https://capgo.app/?ref=plugin_widget_kit"> ➡️ Get Instant updates for your App with Capgo</a></h2>
  <h2><a href="https://capgo.app/consulting/?ref=plugin_widget_kit"> Missing a feature? We’ll build the plugin for you 💪</a></h2>
</div>

Create iOS WidgetKit and ActivityKit experiences from Capacitor with a native, shared-store bridge.

This private proof-of-concept focuses on the workout live-activity flow described by the customer. It deliberately does **not** try to render arbitrary SVG at runtime. SVG snapshots are a good fit for passive home widgets, but the requested workout experience depends on native ActivityKit capabilities:

- interactive completion buttons
- per-second countdown rendering
- Dynamic Island support
- shared App Group persistence between app, widget, and App Intent

For that reason the plugin uses a structured workout session model and native SwiftUI views.

## Install

```bash
bun add file:../capacitor-widget-kit
bunx cap sync ios
```

## iOS Requirements

- iOS 17+ is recommended for the interactive completion button.
- Add `NSSupportsLiveActivities` to the app `Info.plist`.
- Add the same App Group to the app target and the widget extension target.
- Set `CapgoWidgetKitAppGroup` in both `Info.plist` files to the shared App Group identifier.

Example App Group:

```xml
<key>CapgoWidgetKitAppGroup</key>
<string>group.app.capgo.widgetkit.exampleapp.widgetkit</string>
```

## Widget Extension

The plugin ships a reusable widget type. In your widget extension bundle:

```swift
import WidgetKit
import CapgoWidgetKitPlugin

@main
struct ExampleWidgetBundle: WidgetBundle {
    var body: some Widget {
        CapgoWorkoutLiveActivityWidget()
    }
}
```

## Usage

```ts
import { CapgoWidgetKit } from '@capgo/capacitor-widget-kit';

const { supported, reason } = await CapgoWidgetKit.areActivitiesSupported();

if (!supported) {
  console.warn(reason);
}

const { activityId } = await CapgoWidgetKit.startWorkoutLiveActivity({
  session: {
    sessionId: 'session-1',
    title: 'Chest Day',
    startedAt: Date.now(),
    activeExerciseIndex: 0,
    activeSetIndex: 0,
    deepLinkUrl: 'widgetkitdemo://session/session-1',
    timerNotifications: {
      enabled: true,
      title: 'Rest finished',
      body: 'Time for your next set.',
    },
    exercises: [
      {
        id: 'arnold-press',
        title: 'Arnold Press',
        subtitle: 'Dumbbells',
        iconSystemName: 'figure.strengthtraining.traditional',
        sets: [
          {
            title: '32 kg · 10 reps',
            recommendation: 'Try 34 kg next time',
            completedAt: null,
            timerDurationMs: 90000,
            nextExerciseIndex: 0,
            nextSetIndex: 1,
          },
          {
            title: '32 kg · 8 reps',
            recommendation: null,
            completedAt: null,
            timerDurationMs: null,
            nextExerciseIndex: 1,
            nextSetIndex: 0,
          },
        ],
      },
    ],
  },
});
```

## Example App

The `example-app/` folder is a lightweight Vite demo for the workout data flow. It runs in the browser using a preview store and on iOS through the native plugin. The widget extension bundle file is provided by the plugin module itself, so the host app only needs to add a Widget Extension target and include `CapgoWorkoutLiveActivityWidget()` in the bundle.

## API

<docgen-index>

* [`areActivitiesSupported()`](#areactivitiessupported)
* [`startWorkoutLiveActivity(...)`](#startworkoutliveactivity)
* [`updateWorkoutLiveActivity(...)`](#updateworkoutliveactivity)
* [`endWorkoutLiveActivity(...)`](#endworkoutliveactivity)
* [`completeWorkoutSet(...)`](#completeworkoutset)
* [`getStoredWorkoutSession(...)`](#getstoredworkoutsession)
* [`listWorkoutLiveActivities()`](#listworkoutliveactivities)
* [`getPluginVersion()`](#getpluginversion)
* [Interfaces](#interfaces)
* [Type Aliases](#type-aliases)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

Capacitor bridge for an iOS-first WidgetKit / Live Activities plugin.

This package intentionally uses a native workout session model instead of a raw SVG renderer.
Static SVG snapshots are fine for passive home widgets, but the requested workout experience
requires native ActivityKit features such as interactivity, countdown rendering, and shared
App Group persistence.

### areActivitiesSupported()

```typescript
areActivitiesSupported() => Promise<ActivitiesSupportedResult>
```

Check whether the native workout live activity can run on the current device.

**Returns:** <code>Promise&lt;<a href="#activitiessupportedresult">ActivitiesSupportedResult</a>&gt;</code>

--------------------


### startWorkoutLiveActivity(...)

```typescript
startWorkoutLiveActivity(options: StartWorkoutLiveActivityOptions) => Promise<StartWorkoutLiveActivityResult>
```

Start the workout live activity and persist the session in the shared App Group store.

| Param         | Type                                                                                        |
| ------------- | ------------------------------------------------------------------------------------------- |
| **`options`** | <code><a href="#startworkoutliveactivityoptions">StartWorkoutLiveActivityOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#startworkoutliveactivityresult">StartWorkoutLiveActivityResult</a>&gt;</code>

--------------------


### updateWorkoutLiveActivity(...)

```typescript
updateWorkoutLiveActivity(options: UpdateWorkoutLiveActivityOptions) => Promise<void>
```

Replace the stored workout session and push a matching ActivityKit update.

| Param         | Type                                                                                          |
| ------------- | --------------------------------------------------------------------------------------------- |
| **`options`** | <code><a href="#updateworkoutliveactivityoptions">UpdateWorkoutLiveActivityOptions</a></code> |

--------------------


### endWorkoutLiveActivity(...)

```typescript
endWorkoutLiveActivity(options: EndWorkoutLiveActivityOptions) => Promise<void>
```

End the workout live activity while optionally persisting one last session snapshot.

| Param         | Type                                                                                    |
| ------------- | --------------------------------------------------------------------------------------- |
| **`options`** | <code><a href="#endworkoutliveactivityoptions">EndWorkoutLiveActivityOptions</a></code> |

--------------------


### completeWorkoutSet(...)

```typescript
completeWorkoutSet(options: CompleteWorkoutSetOptions) => Promise<StoredWorkoutSessionResult>
```

Complete the current active set and advance to the next exercise/set pair.

| Param         | Type                                                                            |
| ------------- | ------------------------------------------------------------------------------- |
| **`options`** | <code><a href="#completeworkoutsetoptions">CompleteWorkoutSetOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#storedworkoutsessionresult">StoredWorkoutSessionResult</a>&gt;</code>

--------------------


### getStoredWorkoutSession(...)

```typescript
getStoredWorkoutSession(options: GetStoredWorkoutSessionOptions) => Promise<StoredWorkoutSessionResult>
```

Read a session back from the shared store.

| Param         | Type                                                                                      |
| ------------- | ----------------------------------------------------------------------------------------- |
| **`options`** | <code><a href="#getstoredworkoutsessionoptions">GetStoredWorkoutSessionOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#storedworkoutsessionresult">StoredWorkoutSessionResult</a>&gt;</code>

--------------------


### listWorkoutLiveActivities()

```typescript
listWorkoutLiveActivities() => Promise<ListWorkoutLiveActivitiesResult>
```

List activity identifiers currently known by the plugin.

**Returns:** <code>Promise&lt;<a href="#listworkoutliveactivitiesresult">ListWorkoutLiveActivitiesResult</a>&gt;</code>

--------------------


### getPluginVersion()

```typescript
getPluginVersion() => Promise<PluginVersionResult>
```

Return the platform implementation version marker.

**Returns:** <code>Promise&lt;<a href="#pluginversionresult">PluginVersionResult</a>&gt;</code>

--------------------


### Interfaces


#### ActivitiesSupportedResult

Result of a Live Activities capability check.

| Prop            | Type                 | Description                                                                      |
| --------------- | -------------------- | -------------------------------------------------------------------------------- |
| **`supported`** | <code>boolean</code> | Whether the current device and runtime can run the native workout live activity. |
| **`reason`**    | <code>string</code>  | Human-readable reason when support is unavailable.                               |


#### StartWorkoutLiveActivityResult

Result when starting a workout live activity.

| Prop             | Type                | Description                                                 |
| ---------------- | ------------------- | ----------------------------------------------------------- |
| **`activityId`** | <code>string</code> | ActivityKit activity identifier.                            |
| **`sessionId`**  | <code>string</code> | Session identifier persisted in the shared App Group store. |


#### StartWorkoutLiveActivityOptions

Options for starting the workout live activity.

| Prop          | Type                                                      | Description                                                         |
| ------------- | --------------------------------------------------------- | ------------------------------------------------------------------- |
| **`session`** | <code><a href="#workoutsession">WorkoutSession</a></code> | Full workout session payload that should be persisted and rendered. |


#### WorkoutSession

Persisted workout session model used by the plugin and widget extension.

| Prop                       | Type                                                                                    | Description                                                                             |
| -------------------------- | --------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **`sessionId`**            | <code>string</code>                                                                     | Stable session identifier.                                                              |
| **`title`**                | <code>string</code>                                                                     | Session title shown in the completed state and widget metadata.                         |
| **`startedAt`**            | <code>number</code>                                                                     | Start timestamp in milliseconds.                                                        |
| **`activeExerciseIndex`**  | <code>number \| null</code>                                                             | Currently active exercise index. Set to `null` when the workout is complete.            |
| **`activeSetIndex`**       | <code>number \| null</code>                                                             | Currently active set index. Set to `null` when the workout is complete.                 |
| **`deepLinkUrl`**          | <code>string</code>                                                                     | Deep link opened when the live activity body is tapped.                                 |
| **`timerNotifications`**   | <code><a href="#workoutnotificationpreference">WorkoutNotificationPreference</a></code> | Timer notification settings. The plugin accepts either `true`/`false` or a full object. |
| **`sessionNotifications`** | <code><a href="#workoutnotificationpreference">WorkoutNotificationPreference</a></code> | Optional completion notification settings reserved for the host app.                    |
| **`exercises`**            | <code>WorkoutExercise[]</code>                                                          | Ordered exercises in the workout.                                                       |


#### WorkoutNotificationSettings

Notification behavior for workout timers or session completion.

| Prop          | Type                 | Description                          |
| ------------- | -------------------- | ------------------------------------ |
| **`enabled`** | <code>boolean</code> | Whether the notification is enabled. |
| **`title`**   | <code>string</code>  | Optional custom title.               |
| **`body`**    | <code>string</code>  | Optional custom body.                |


#### WorkoutExercise

Exercise block displayed inside the workout live activity.

| Prop                 | Type                      | Description                                                 |
| -------------------- | ------------------------- | ----------------------------------------------------------- |
| **`id`**             | <code>string</code>       | Stable exercise identifier.                                 |
| **`title`**          | <code>string</code>       | Primary exercise title.                                     |
| **`subtitle`**       | <code>string</code>       | Secondary exercise subtitle.                                |
| **`iconSystemName`** | <code>string</code>       | Optional SF Symbol used when no bundled image is available. |
| **`imageAssetName`** | <code>string</code>       | Optional bundled asset name for the exercise thumbnail.     |
| **`sets`**           | <code>WorkoutSet[]</code> | Ordered sets for the exercise.                              |


#### WorkoutSet

Individual set inside an exercise.

| Prop                    | Type                        | Description                                                                           |
| ----------------------- | --------------------------- | ------------------------------------------------------------------------------------- |
| **`id`**                | <code>string</code>         | Optional stable identifier.                                                           |
| **`title`**             | <code>string</code>         | Display label for the set.                                                            |
| **`recommendation`**    | <code>string \| null</code> | Optional recommendation pill shown above the active set.                              |
| **`completedAt`**       | <code>number \| null</code> | Millisecond timestamp when the set was completed.                                     |
| **`timerDurationMs`**   | <code>number \| null</code> | Optional rest timer duration in milliseconds that starts after this set is completed. |
| **`nextExerciseIndex`** | <code>number \| null</code> | Index of the next active exercise after completing this set.                          |
| **`nextSetIndex`**      | <code>number \| null</code> | Index of the next active set after completing this set.                               |


#### UpdateWorkoutLiveActivityOptions

Options for updating an existing workout live activity.

| Prop                     | Type                                                                          | Description                                                 |
| ------------------------ | ----------------------------------------------------------------------------- | ----------------------------------------------------------- |
| **`activityId`**         | <code>string</code>                                                           | Activity identifier returned by `startWorkoutLiveActivity`. |
| **`session`**            | <code><a href="#workoutsession">WorkoutSession</a></code>                     | Full replacement session payload.                           |
| **`alertConfiguration`** | <code><a href="#widgetalertconfiguration">WidgetAlertConfiguration</a></code> | Optional native alert shown as part of the update.          |


#### WidgetAlertConfiguration

Optional native alert configuration for an activity update.

| Prop        | Type                | Description  |
| ----------- | ------------------- | ------------ |
| **`title`** | <code>string</code> | Alert title. |
| **`body`**  | <code>string</code> | Alert body.  |


#### EndWorkoutLiveActivityOptions

Options for ending a workout live activity.

| Prop             | Type                                                      | Description                                                            |
| ---------------- | --------------------------------------------------------- | ---------------------------------------------------------------------- |
| **`activityId`** | <code>string</code>                                       | Activity identifier returned by `startWorkoutLiveActivity`.            |
| **`session`**    | <code><a href="#workoutsession">WorkoutSession</a></code> | Optional final session snapshot to persist before ending the activity. |


#### StoredWorkoutSessionResult

Stored workout session result payload.

| Prop          | Type                                                              | Description                                                         |
| ------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------- |
| **`session`** | <code><a href="#workoutsession">WorkoutSession</a> \| null</code> | Persisted workout session, or `null` when no matching entry exists. |


#### CompleteWorkoutSetOptions

Options for completing the active set either from the app or from an interactive widget action.

| Prop             | Type                | Description                                            |
| ---------------- | ------------------- | ------------------------------------------------------ |
| **`sessionId`**  | <code>string</code> | Session identifier to mutate.                          |
| **`activityId`** | <code>string</code> | Optional activity identifier when it is already known. |


#### GetStoredWorkoutSessionOptions

Options for retrieving a stored workout session.

| Prop             | Type                | Description                                          |
| ---------------- | ------------------- | ---------------------------------------------------- |
| **`sessionId`**  | <code>string</code> | Session identifier. Preferred lookup key.            |
| **`activityId`** | <code>string</code> | Activity identifier when only the activity is known. |


#### ListWorkoutLiveActivitiesResult

Result of listing known workout live activities.

| Prop             | Type                              | Description                             |
| ---------------- | --------------------------------- | --------------------------------------- |
| **`activities`** | <code>LiveActivityRecord[]</code> | Activity records tracked by the plugin. |


#### LiveActivityRecord

Metadata describing a currently known live activity.

| Prop             | Type                             | Description                            |
| ---------------- | -------------------------------- | -------------------------------------- |
| **`activityId`** | <code>string</code>              | ActivityKit identifier.                |
| **`sessionId`**  | <code>string</code>              | Associated workout session identifier. |
| **`state`**      | <code>'active' \| 'ended'</code> | Current activity state.                |
| **`updatedAt`**  | <code>number</code>              | Last update timestamp in milliseconds. |


#### PluginVersionResult

Result payload for plugin version queries.

| Prop          | Type                | Description                           |
| ------------- | ------------------- | ------------------------------------- |
| **`version`** | <code>string</code> | Native implementation version marker. |


### Type Aliases


#### WorkoutNotificationPreference

Convenience type that accepts either a boolean or a full notification object.

<code>boolean | <a href="#workoutnotificationsettings">WorkoutNotificationSettings</a></code>

</docgen-api>
