# @capgo/capacitor-widget-kit
 <a href="https://capgo.app/"><img src='https://raw.githubusercontent.com/Cap-go/capgo/main/assets/capgo_banner.png' alt='Capgo - Instant updates for capacitor'/></a>

<div align="center">
  <h2><a href="https://capgo.app/?ref=plugin_widget_kit"> ➡️ Get Instant updates for your App with Capgo</a></h2>
  <h2><a href="https://capgo.app/consulting/?ref=plugin_widget_kit"> Missing a feature? We’ll build the plugin for you 💪</a></h2>
</div>

Create iOS WidgetKit and ActivityKit experiences from Capacitor with a generic SVG-template bridge.

The plugin is intentionally generic:

- store raw SVG templates for lock screen and Dynamic Island surfaces
- resolve `{{state.*}}`, `{{timers.*}}`, `{{meta.*}}`, and `{{action.*}}` bindings
- attach declarative actions to hotspots or app-side buttons
- persist every interaction in an event log so the app can process results later
- expose a shared App Group bridge so the widget extension can load resolved layouts without knowing the internal storage format

The included workout flow is only an example helper built on top of the generic abstraction.

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

The plugin ships the native pieces a widget extension needs:

- `CapgoTemplateActivityAttributes` for the Live Activity bridge
- `CapgoTemplateActionIntent` for interactive buttons
- `CapgoTemplateWidgetBridge` to load a stored activity and resolve one SVG surface into `svg + width/height + hotspots + metadata`

In your widget extension bundle:

```swift
import ActivityKit
import SwiftUI
import WidgetKit
import CapgoWidgetKitPlugin

@main
struct ExampleWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.2, *) {
            ExampleTemplateLiveActivityWidget()
        }
    }
}
```

See [`example-app/widget-extension/ExampleWidgetBundle.swift`](/Users/martindonadieu/Projects/capgo_all/capgo_plugins/capacitor-widget-kit/example-app/widget-extension/ExampleWidgetBundle.swift) for a complete scaffold. The sample intentionally uses a placeholder card so you can plug in your own SVG renderer while keeping the same bridge and action intent wiring.

## Usage

```ts
import { CapgoWidgetKit } from '@capgo/capacitor-widget-kit';

const { supported, reason } = await CapgoWidgetKit.areActivitiesSupported();

if (!supported) {
  console.warn(reason);
}

const { activity } = await CapgoWidgetKit.startTemplateActivity({
  activityId: 'session-1',
  openUrl: 'widgetkitdemo://session/session-1',
  state: {
    title: 'Chest Day',
    count: 0,
  },
  definition: {
    id: 'generic-session-card',
    timers: [
      {
        id: 'rest',
        durationPath: 'state.restDurationMs',
      },
    ],
    actions: [
      {
        id: 'complete-set',
        eventName: 'workout.set.completed',
        patches: [
          { op: 'increment', path: 'count', amount: 1 },
          { op: 'set', path: 'lastButton', valueTemplate: '{{action.sourceId}}' },
          { op: 'set', path: 'lastNote', valueTemplate: '{{action.payload.note}}' },
        ],
        timerMutations: [
          { op: 'setDuration', timerId: 'rest', durationPath: 'action.payload.durationMs' },
          { op: 'restart', timerId: 'rest', durationPath: 'action.payload.durationMs' },
        ],
      },
    ],
    layouts: {
      lockScreen: {
        width: 100,
        height: 40,
        hotspots: [
          {
            id: 'primary-complete-button',
            actionId: 'complete-set',
            x: 76,
            y: 24,
            width: 18,
            height: 10,
            label: 'Complete active set',
            role: 'button',
            payload: {
              note: 'Completed from widget',
              durationMs: 90000,
            },
          },
        ],
        svg: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 40">
  <rect x="0" y="0" width="100" height="40" rx="6" fill="#05070b" />
  <text x="6" y="10" fill="#ffffff">{{state.title}}</text>
  <text x="6" y="30" fill="#00d69c">{{timers.rest.remainingText}}</text>
</svg>`,
      },
    },
  },
});

const result = await CapgoWidgetKit.performTemplateAction({
  activityId: activity.activityId,
  actionId: 'complete-set',
  sourceId: 'app-complete-set-button',
  payload: {
    note: 'Completed from the app',
    durationMs: 45000,
  },
});

const pendingEvents = await CapgoWidgetKit.listTemplateEvents({
  activityId: activity.activityId,
  unacknowledgedOnly: true,
});
```

## Example App

The `example-app/` folder is a lightweight Vite demo for the generic template flow. It runs in the browser using the preview store and demonstrates:

- starting one SVG template activity
- resolving the lock-screen surface
- running an action from the app and from a hotspot overlay
- reading the stored activity back
- reading and acknowledging the event log
- ending the activity

The workout helper is only used there as an example template factory.

## API

<docgen-index>

* [`areActivitiesSupported()`](#areactivitiessupported)
* [`startTemplateActivity(...)`](#starttemplateactivity)
* [`updateTemplateActivity(...)`](#updatetemplateactivity)
* [`endTemplateActivity(...)`](#endtemplateactivity)
* [`performTemplateAction(...)`](#performtemplateaction)
* [`getTemplateActivity(...)`](#gettemplateactivity)
* [`listTemplateActivities()`](#listtemplateactivities)
* [`listTemplateEvents(...)`](#listtemplateevents)
* [`acknowledgeTemplateEvents(...)`](#acknowledgetemplateevents)
* [`getPluginVersion()`](#getpluginversion)
* [Interfaces](#interfaces)
* [Type Aliases](#type-aliases)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

Capacitor bridge for an iOS-first WidgetKit / Live Activities plugin.

The core abstraction is a generic SVG template activity:
- raw SVG templates with binding placeholders
- declarative action patches
- timer bindings exposed to the template scope
- event logging so the host app can process button results later

The plugin owns shared persistence, declarative action execution, and event retrieval.
The host widget extension keeps full freedom over actual WidgetKit rendering.

### areActivitiesSupported()

```typescript
areActivitiesSupported() => Promise<ActivitiesSupportedResult>
```

Check whether the native template activity bridge can run on the current device.

**Returns:** <code>Promise&lt;<a href="#activitiessupportedresult">ActivitiesSupportedResult</a>&gt;</code>

--------------------


### startTemplateActivity(...)

```typescript
startTemplateActivity(options: StartTemplateActivityOptions) => Promise<StartTemplateActivityResult>
```

Persist a generic SVG template activity and start the matching native Live Activity bridge.

| Param         | Type                                                                                  |
| ------------- | ------------------------------------------------------------------------------------- |
| **`options`** | <code><a href="#starttemplateactivityoptions">StartTemplateActivityOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#starttemplateactivityresult">StartTemplateActivityResult</a>&gt;</code>

--------------------


### updateTemplateActivity(...)

```typescript
updateTemplateActivity(options: UpdateTemplateActivityOptions) => Promise<TemplateActivityResult>
```

Replace part or all of the stored activity definition/state.

| Param         | Type                                                                                    |
| ------------- | --------------------------------------------------------------------------------------- |
| **`options`** | <code><a href="#updatetemplateactivityoptions">UpdateTemplateActivityOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#templateactivityresult">TemplateActivityResult</a>&gt;</code>

--------------------


### endTemplateActivity(...)

```typescript
endTemplateActivity(options: EndTemplateActivityOptions) => Promise<void>
```

End a running activity while optionally persisting one last state snapshot.

| Param         | Type                                                                              |
| ------------- | --------------------------------------------------------------------------------- |
| **`options`** | <code><a href="#endtemplateactivityoptions">EndTemplateActivityOptions</a></code> |

--------------------


### performTemplateAction(...)

```typescript
performTemplateAction(options: PerformTemplateActionOptions) => Promise<PerformTemplateActionResult>
```

Execute one declarative action and record the resulting event.

| Param         | Type                                                                                  |
| ------------- | ------------------------------------------------------------------------------------- |
| **`options`** | <code><a href="#performtemplateactionoptions">PerformTemplateActionOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#performtemplateactionresult">PerformTemplateActionResult</a>&gt;</code>

--------------------


### getTemplateActivity(...)

```typescript
getTemplateActivity(options: GetTemplateActivityOptions) => Promise<TemplateActivityResult>
```

Read one activity back from the shared store.

| Param         | Type                                                                              |
| ------------- | --------------------------------------------------------------------------------- |
| **`options`** | <code><a href="#gettemplateactivityoptions">GetTemplateActivityOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#templateactivityresult">TemplateActivityResult</a>&gt;</code>

--------------------


### listTemplateActivities()

```typescript
listTemplateActivities() => Promise<ListTemplateActivitiesResult>
```

List every activity currently known by the plugin.

**Returns:** <code>Promise&lt;<a href="#listtemplateactivitiesresult">ListTemplateActivitiesResult</a>&gt;</code>

--------------------


### listTemplateEvents(...)

```typescript
listTemplateEvents(options?: ListTemplateEventsOptions | undefined) => Promise<ListTemplateEventsResult>
```

List stored action events so the app can react to widget interactions later.

| Param         | Type                                                                            |
| ------------- | ------------------------------------------------------------------------------- |
| **`options`** | <code><a href="#listtemplateeventsoptions">ListTemplateEventsOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#listtemplateeventsresult">ListTemplateEventsResult</a>&gt;</code>

--------------------


### acknowledgeTemplateEvents(...)

```typescript
acknowledgeTemplateEvents(options: AcknowledgeTemplateEventsOptions) => Promise<void>
```

Mark previously processed events as acknowledged.

| Param         | Type                                                                                          |
| ------------- | --------------------------------------------------------------------------------------------- |
| **`options`** | <code><a href="#acknowledgetemplateeventsoptions">AcknowledgeTemplateEventsOptions</a></code> |

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

| Prop            | Type                 | Description                                                                         |
| --------------- | -------------------- | ----------------------------------------------------------------------------------- |
| **`supported`** | <code>boolean</code> | Whether the current device and runtime can run the native template activity bridge. |
| **`reason`**    | <code>string</code>  | Human-readable reason when support is unavailable.                                  |


#### StartTemplateActivityResult

Result when starting a generic template activity.

| Prop           | Type                                                                            | Description               |
| -------------- | ------------------------------------------------------------------------------- | ------------------------- |
| **`activity`** | <code><a href="#svgtemplateactivityrecord">SvgTemplateActivityRecord</a></code> | Stored activity snapshot. |


#### SvgTemplateActivityRecord

Stored activity snapshot returned by the plugin.

| Prop             | Type                                                                                                                | Description                                               |
| ---------------- | ------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| **`activityId`** | <code>string</code>                                                                                                 | Stable plugin activity identifier.                        |
| **`definition`** | <code><a href="#svgtemplatedefinition">SvgTemplateDefinition</a></code>                                             | Full template definition.                                 |
| **`state`**      | <code><a href="#svgtemplatestate">SvgTemplateState</a></code>                                                       | Persisted JSON state.                                     |
| **`timers`**     | <code><a href="#record">Record</a>&lt;string, <a href="#svgtemplatetimerstate">SvgTemplateTimerState</a>&gt;</code> | Timer runtime state keyed by timer id.                    |
| **`status`**     | <code>'active' \| 'ended'</code>                                                                                    | Current lifecycle status.                                 |
| **`openUrl`**    | <code>string</code>                                                                                                 | Optional deep link opened when the widget body is tapped. |
| **`updatedAt`**  | <code>number</code>                                                                                                 | Last update timestamp.                                    |
| **`revision`**   | <code>number</code>                                                                                                 | Monotonic revision incremented on every state change.     |


#### SvgTemplateDefinition

Generic SVG template definition stored by the plugin.

| Prop           | Type                                                              | Description                                                                 |
| -------------- | ----------------------------------------------------------------- | --------------------------------------------------------------------------- |
| **`id`**       | <code>string</code>                                               | Stable template identifier.                                                 |
| **`version`**  | <code>string</code>                                               | Optional version marker for migrations.                                     |
| **`layouts`**  | <code><a href="#svgtemplatelayouts">SvgTemplateLayouts</a></code> | Available WidgetKit layouts.                                                |
| **`actions`**  | <code>SvgTemplateActionDefinition[]</code>                        | Optional declarative actions.                                               |
| **`timers`**   | <code>SvgTemplateTimerDefinition[]</code>                         | Optional timer definitions exposed to the template runtime.                 |
| **`metadata`** | <code><a href="#jsonobject">JsonObject</a></code>                 | Optional JSON metadata mirrored in the runtime scope under `meta.template`. |


#### SvgTemplateLayouts

Bundle of optional WidgetKit surface layouts.

| Prop                               | Type                                                            | Description                                      |
| ---------------------------------- | --------------------------------------------------------------- | ------------------------------------------------ |
| **`lockScreen`**                   | <code><a href="#svgtemplatelayout">SvgTemplateLayout</a></code> | Primary lock-screen / banner layout.             |
| **`dynamicIslandExpanded`**        | <code><a href="#svgtemplatelayout">SvgTemplateLayout</a></code> | Optional expanded Dynamic Island layout.         |
| **`dynamicIslandCompactLeading`**  | <code><a href="#svgtemplatelayout">SvgTemplateLayout</a></code> | Optional compact leading Dynamic Island layout.  |
| **`dynamicIslandCompactTrailing`** | <code><a href="#svgtemplatelayout">SvgTemplateLayout</a></code> | Optional compact trailing Dynamic Island layout. |
| **`dynamicIslandMinimal`**         | <code><a href="#svgtemplatelayout">SvgTemplateLayout</a></code> | Optional minimal Dynamic Island layout.          |


#### SvgTemplateLayout

SVG layout variant for one WidgetKit surface.

| Prop           | Type                              | Description                                                                                                                  |
| -------------- | --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| **`svg`**      | <code>string</code>               | Raw SVG template string. The runtime resolves `{{state.*}}`, `{{timers.*}}`, and `{{meta.*}}` placeholders before rendering. |
| **`width`**    | <code>number</code>               | Nominal SVG width used for scaling hotspots.                                                                                 |
| **`height`**   | <code>number</code>               | Nominal SVG height used for scaling hotspots.                                                                                |
| **`hotspots`** | <code>SvgTemplateHotspot[]</code> | Interactive overlay regions.                                                                                                 |


#### SvgTemplateHotspot

Interactive region overlaid on top of a rendered SVG layout.

| Prop           | Type                                              | Description                                                             |
| -------------- | ------------------------------------------------- | ----------------------------------------------------------------------- |
| **`id`**       | <code>string</code>                               | Stable hotspot identifier.                                              |
| **`actionId`** | <code>string</code>                               | Action identifier executed when the region is tapped.                   |
| **`x`**        | <code>number</code>                               | X position in the SVG coordinate space.                                 |
| **`y`**        | <code>number</code>                               | Y position in the SVG coordinate space.                                 |
| **`width`**    | <code>number</code>                               | Hotspot width in the SVG coordinate space.                              |
| **`height`**   | <code>number</code>                               | Hotspot height in the SVG coordinate space.                             |
| **`label`**    | <code>string</code>                               | Optional accessibility label for the interactive region.                |
| **`role`**     | <code>'button' \| 'link'</code>                   | Optional semantic role.                                                 |
| **`payload`**  | <code><a href="#jsonobject">JsonObject</a></code> | Optional static payload forwarded when the hotspot triggers its action. |


#### JsonObject

JSON-safe object used as activity state.


#### SvgTemplateActionDefinition

Declarative action attached to one or more hotspots.

| Prop                 | Type                                    | Description                                                        |
| -------------------- | --------------------------------------- | ------------------------------------------------------------------ |
| **`id`**             | <code>string</code>                     | Stable action identifier.                                          |
| **`eventName`**      | <code>string</code>                     | Optional event name used in the action log.                        |
| **`label`**          | <code>string</code>                     | Optional UI label.                                                 |
| **`patches`**        | <code>SvgTemplateStatePatch[]</code>    | Ordered state mutations executed when the action runs.             |
| **`timerMutations`** | <code>SvgTemplateTimerMutation[]</code> | Ordered timer mutations executed when the action runs.             |
| **`openUrl`**        | <code>string</code>                     | Optional deep link opened by the host widget when the action runs. |


#### SvgTemplateStatePatch

Declarative mutation applied to the stored activity state.

| Prop                | Type                                                                    | Description                                                                                                                                                    |
| ------------------- | ----------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`op`**            | <code>'set' \| 'increment' \| 'toggle' \| 'unset' \| 'timestamp'</code> | Mutation operation.                                                                                                                                            |
| **`path`**          | <code>string</code>                                                     | Destination state path. The path may itself contain `{{...}}` placeholders.                                                                                    |
| **`value`**         | <code><a href="#jsonvalue">JsonValue</a></code>                         | Optional literal value used by the mutation.                                                                                                                   |
| **`valuePath`**     | <code>string</code>                                                     | Optional source path used to copy a value from the current runtime scope. The path may itself contain `{{...}}` placeholders.                                  |
| **`valueTemplate`** | <code>string</code>                                                     | Optional template-resolved value. If the string is a single `{{...}}` token, the raw referenced JSON value is copied. Otherwise the resolved string is stored. |
| **`amount`**        | <code>number</code>                                                     | Increment amount for `increment`.                                                                                                                              |


#### SvgTemplateTimerMutation

Declarative timer mutation triggered by an action.

| Prop               | Type                                                         | Description                                                                                                             |
| ------------------ | ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| **`op`**           | <code>'start' \| 'stop' \| 'restart' \| 'setDuration'</code> | Mutation operation.                                                                                                     |
| **`timerId`**      | <code>string</code>                                          | Target timer identifier.                                                                                                |
| **`durationMs`**   | <code>number</code>                                          | Optional fixed duration override in milliseconds.                                                                       |
| **`durationPath`** | <code>string</code>                                          | Optional path that resolves to a duration override in milliseconds. The path may itself contain `{{...}}` placeholders. |


#### SvgTemplateTimerDefinition

Timer binding exposed to SVG templates.

| Prop               | Type                 | Description                                                                                                                         |
| ------------------ | -------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| **`id`**           | <code>string</code>  | Stable timer identifier.                                                                                                            |
| **`durationMs`**   | <code>number</code>  | Optional fixed duration in milliseconds.                                                                                            |
| **`durationPath`** | <code>string</code>  | Optional state path that resolves to a duration in milliseconds. The path may itself contain `{{...}}` placeholders.                |
| **`startAtPath`**  | <code>string</code>  | Optional state path that resolves to the timer start timestamp in milliseconds. The path may itself contain `{{...}}` placeholders. |
| **`autoStart`**    | <code>boolean</code> | When true, the timer starts automatically when the activity is created.                                                             |


#### SvgTemplateTimerState

Persisted timer runtime state.

| Prop             | Type                                                        | Description                                                        |
| ---------------- | ----------------------------------------------------------- | ------------------------------------------------------------------ |
| **`id`**         | <code>string</code>                                         | Timer identifier.                                                  |
| **`startedAt`**  | <code>number \| null</code>                                 | Start timestamp in milliseconds, or `null` when the timer is idle. |
| **`durationMs`** | <code>number</code>                                         | Current timer duration in milliseconds.                            |
| **`status`**     | <code>'idle' \| 'running' \| 'finished' \| 'stopped'</code> | Current timer status.                                              |
| **`updatedAt`**  | <code>number</code>                                         | Last update timestamp.                                             |


#### StartTemplateActivityOptions

Options for starting a generic SVG template activity.

| Prop             | Type                                                                    | Description                                                                          |
| ---------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| **`activityId`** | <code>string</code>                                                     | Optional explicit activity identifier. When omitted, the native runtime creates one. |
| **`definition`** | <code><a href="#svgtemplatedefinition">SvgTemplateDefinition</a></code> | Generic SVG template definition.                                                     |
| **`state`**      | <code><a href="#svgtemplatestate">SvgTemplateState</a></code>           | Initial JSON state exposed under `state.*`.                                          |
| **`openUrl`**    | <code>string</code>                                                     | Optional deep link used when the widget body is tapped.                              |


#### TemplateActivityResult

Result when reading or updating a single activity.

| Prop           | Type                                                                                    | Description                                         |
| -------------- | --------------------------------------------------------------------------------------- | --------------------------------------------------- |
| **`activity`** | <code><a href="#svgtemplateactivityrecord">SvgTemplateActivityRecord</a> \| null</code> | Stored activity snapshot, or `null` when not found. |


#### UpdateTemplateActivityOptions

Options for updating an existing template activity.

| Prop             | Type                                                                    | Description                                              |
| ---------------- | ----------------------------------------------------------------------- | -------------------------------------------------------- |
| **`activityId`** | <code>string</code>                                                     | Activity identifier returned by `startTemplateActivity`. |
| **`definition`** | <code><a href="#svgtemplatedefinition">SvgTemplateDefinition</a></code> | Optional replacement definition.                         |
| **`state`**      | <code><a href="#svgtemplatestate">SvgTemplateState</a></code>           | Optional replacement state.                              |
| **`openUrl`**    | <code>string</code>                                                     | Optional replacement deep link.                          |


#### EndTemplateActivityOptions

Options for ending a template activity.

| Prop             | Type                                                          | Description                                              |
| ---------------- | ------------------------------------------------------------- | -------------------------------------------------------- |
| **`activityId`** | <code>string</code>                                           | Activity identifier returned by `startTemplateActivity`. |
| **`state`**      | <code><a href="#svgtemplatestate">SvgTemplateState</a></code> | Optional final state persisted before ending.            |


#### PerformTemplateActionResult

Result after executing an action.

| Prop           | Type                                                                            | Description                          |
| -------------- | ------------------------------------------------------------------------------- | ------------------------------------ |
| **`activity`** | <code><a href="#svgtemplateactivityrecord">SvgTemplateActivityRecord</a></code> | Updated activity snapshot.           |
| **`event`**    | <code><a href="#svgtemplateactionevent">SvgTemplateActionEvent</a></code>       | Action event emitted by the runtime. |


#### SvgTemplateActionEvent

Event emitted whenever a declarative action is executed.

| Prop                 | Type                                                                                                                | Description                                                                     |
| -------------------- | ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| **`eventId`**        | <code>string</code>                                                                                                 | Stable event identifier.                                                        |
| **`activityId`**     | <code>string</code>                                                                                                 | Activity identifier associated with the event.                                  |
| **`actionId`**       | <code>string</code>                                                                                                 | Action identifier that produced the event.                                      |
| **`eventName`**      | <code>string</code>                                                                                                 | Optional event name copied from the action definition.                          |
| **`sourceId`**       | <code>string</code>                                                                                                 | Optional source identifier, typically the hotspot id that triggered the action. |
| **`createdAt`**      | <code>number</code>                                                                                                 | Event creation timestamp in milliseconds.                                       |
| **`acknowledgedAt`** | <code>number \| null</code>                                                                                         | Timestamp in milliseconds when the app acknowledged the event.                  |
| **`payload`**        | <code><a href="#jsonobject">JsonObject</a> \| null</code>                                                           | Optional caller-provided payload.                                               |
| **`state`**          | <code><a href="#svgtemplatestate">SvgTemplateState</a></code>                                                       | State snapshot after the action was applied.                                    |
| **`timers`**         | <code><a href="#record">Record</a>&lt;string, <a href="#svgtemplatetimerstate">SvgTemplateTimerState</a>&gt;</code> | Timer snapshot after the action was applied.                                    |


#### PerformTemplateActionOptions

Options for executing a declarative action.

| Prop             | Type                                              | Description                                                                                                     |
| ---------------- | ------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| **`activityId`** | <code>string</code>                               | Activity identifier returned by `startTemplateActivity`.                                                        |
| **`actionId`**   | <code>string</code>                               | Action identifier declared in the template definition.                                                          |
| **`sourceId`**   | <code>string</code>                               | Optional source identifier, typically the hotspot id that triggered the action.                                 |
| **`payload`**    | <code><a href="#jsonobject">JsonObject</a></code> | Optional payload stored with the emitted event and exposed to declarative patches under `{{action.payload.*}}`. |


#### GetTemplateActivityOptions

Options for reading one stored activity.

| Prop             | Type                | Description                  |
| ---------------- | ------------------- | ---------------------------- |
| **`activityId`** | <code>string</code> | Activity identifier to load. |


#### ListTemplateActivitiesResult

Result when listing stored activities.

| Prop             | Type                                     | Description                |
| ---------------- | ---------------------------------------- | -------------------------- |
| **`activities`** | <code>SvgTemplateActivityRecord[]</code> | Stored activity snapshots. |


#### ListTemplateEventsResult

Result when listing action events.

| Prop         | Type                                  | Description             |
| ------------ | ------------------------------------- | ----------------------- |
| **`events`** | <code>SvgTemplateActionEvent[]</code> | Matching action events. |


#### ListTemplateEventsOptions

Options when listing action events.

| Prop                     | Type                 | Description                                         |
| ------------------------ | -------------------- | --------------------------------------------------- |
| **`activityId`**         | <code>string</code>  | Optional activity filter.                           |
| **`unacknowledgedOnly`** | <code>boolean</code> | When true, only unacknowledged events are returned. |


#### AcknowledgeTemplateEventsOptions

Options for acknowledging events after the host app processes them.

| Prop             | Type                  | Description                                                                   |
| ---------------- | --------------------- | ----------------------------------------------------------------------------- |
| **`eventIds`**   | <code>string[]</code> | Optional explicit event ids to acknowledge.                                   |
| **`activityId`** | <code>string</code>   | Optional activity id shortcut that acknowledges every event for the activity. |


#### PluginVersionResult

Result payload for plugin version queries.

| Prop          | Type                | Description                           |
| ------------- | ------------------- | ------------------------------------- |
| **`version`** | <code>string</code> | Native implementation version marker. |


### Type Aliases


#### JsonValue

Any JSON-safe value accepted by the plugin.

<code><a href="#jsonprimitive">JsonPrimitive</a> | <a href="#jsonobject">JsonObject</a> | <a href="#jsonarray">JsonArray</a></code>


#### JsonPrimitive

JSON-safe primitive value.

<code>string | number | boolean | null</code>


#### JsonArray

JSON-safe array used as activity state.

<code>JsonValue[]</code>


#### SvgTemplateState

Structured state payload persisted for an activity.

<code><a href="#jsonobject">JsonObject</a></code>


#### Record

Construct a type with a set of properties K of type T

<code>{ [P in K]: T; }</code>

</docgen-api>
