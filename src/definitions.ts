/**
 * Result payload for plugin version queries.
 */
export interface PluginVersionResult {
  /**
   * Native implementation version marker.
   */
  version: string;
}

/**
 * Result of a Live Activities capability check.
 */
export interface ActivitiesSupportedResult {
  /**
   * Whether the current device and runtime can run the native template activity bridge.
   */
  supported: boolean;

  /**
   * Human-readable reason when support is unavailable.
   */
  reason?: string;
}

/**
 * JSON-safe primitive value.
 */
export type JsonPrimitive = string | number | boolean | null;

/**
 * JSON-safe object used as activity state.
 */
export interface JsonObject {
  [key: string]: JsonValue;
}

/**
 * JSON-safe array used as activity state.
 */
export type JsonArray = JsonValue[];

/**
 * Any JSON-safe value accepted by the plugin.
 */
export type JsonValue = JsonPrimitive | JsonObject | JsonArray;

/**
 * Structured state payload persisted for an activity.
 */
export type SvgTemplateState = JsonObject;

/**
 * Interactive region overlaid on top of a rendered SVG layout.
 */
export interface SvgTemplateHotspot {
  /**
   * Stable hotspot identifier.
   */
  id: string;

  /**
   * Action identifier executed when the region is tapped.
   */
  actionId: string;

  /**
   * X position in the SVG coordinate space.
   */
  x: number;

  /**
   * Y position in the SVG coordinate space.
   */
  y: number;

  /**
   * Hotspot width in the SVG coordinate space.
   */
  width: number;

  /**
   * Hotspot height in the SVG coordinate space.
   */
  height: number;

  /**
   * Optional accessibility label for the interactive region.
   */
  label?: string;

  /**
   * Optional semantic role.
   */
  role?: 'button' | 'link';

  /**
   * Optional static payload forwarded when the hotspot triggers its action.
   */
  payload?: JsonObject;
}

/**
 * Named SVG frame that can be selected by activity state.
 */
export interface SvgTemplateFrame {
  /**
   * Stable frame identifier.
   */
  id: string;

  /**
   * Raw SVG template string for this frame.
   *
   * The runtime resolves `{{state.*}}`, `{{timers.*}}`, and `{{meta.*}}` placeholders before rendering.
   */
  svg: string;

  /**
   * Optional frame-specific interactive regions.
   *
   * When omitted, the parent layout hotspots are used.
   */
  hotspots?: SvgTemplateHotspot[];
}

/**
 * SVG layout variant for one WidgetKit surface.
 */
export interface SvgTemplateLayout {
  /**
   * Raw SVG template string used when no frame is selected.
   *
   * The runtime resolves `{{state.*}}`, `{{timers.*}}`, and `{{meta.*}}` placeholders before rendering.
   */
  svg?: string;

  /**
   * Optional named SVG frames for click-driven or timer-driven frame changes.
   */
  frames?: SvgTemplateFrame[];

  /**
   * Optional state/runtime path that resolves to the active frame id.
   *
   * Examples: `state.frame`, `state.widgets.{{state.activeIndex}}.frame`, or `{{state.frame}}`.
   */
  frameIdPath?: string;

  /**
   * Frame id used when `frameIdPath` is missing or resolves to an unknown frame.
   */
  defaultFrameId?: string;

  /**
   * Nominal SVG width used for scaling hotspots.
   */
  width: number;

  /**
   * Nominal SVG height used for scaling hotspots.
   */
  height: number;

  /**
   * Interactive overlay regions.
   */
  hotspots?: SvgTemplateHotspot[];
}

/**
 * Bundle of optional WidgetKit surface layouts.
 */
export interface SvgTemplateLayouts {
  /**
   * Primary lock-screen / banner layout.
   */
  lockScreen: SvgTemplateLayout;

  /**
   * Optional expanded Dynamic Island layout.
   */
  dynamicIslandExpanded?: SvgTemplateLayout;

  /**
   * Optional compact leading Dynamic Island layout.
   */
  dynamicIslandCompactLeading?: SvgTemplateLayout;

  /**
   * Optional compact trailing Dynamic Island layout.
   */
  dynamicIslandCompactTrailing?: SvgTemplateLayout;

  /**
   * Optional minimal Dynamic Island layout.
   */
  dynamicIslandMinimal?: SvgTemplateLayout;
}

/**
 * Named WidgetKit surface for one SVG layout variant.
 */
export type SvgTemplateSurface =
  | 'lockScreen'
  | 'dynamicIslandExpanded'
  | 'dynamicIslandCompactLeading'
  | 'dynamicIslandCompactTrailing'
  | 'dynamicIslandMinimal';

/**
 * Fully resolved SVG layout ready for rendering by the app or widget extension.
 */
export interface ResolvedSvgTemplateLayout {
  /**
   * Surface that was resolved.
   */
  surface: SvgTemplateSurface;

  /**
   * Activity identifier that owns the layout.
   */
  activityId: string;

  /**
   * Template identifier that produced the layout.
   */
  templateId: string;

  /**
   * Selected frame identifier when the layout was resolved from `frames`.
   */
  frameId?: string;

  /**
   * Render-ready SVG markup with every placeholder already resolved.
   */
  svg: string;

  /**
   * Nominal width of the SVG coordinate space.
   */
  width: number;

  /**
   * Nominal height of the SVG coordinate space.
   */
  height: number;

  /**
   * Interactive regions associated with the layout.
   */
  hotspots: SvgTemplateHotspot[];

  /**
   * Optional widget body deep link.
   */
  openUrl?: string;

  /**
   * Current activity status.
   */
  status: 'active' | 'ended';

  /**
   * Activity revision used to invalidate stale renders.
   */
  revision: number;

  /**
   * Last update timestamp.
   */
  updatedAt: number;
}

/**
 * Timer binding exposed to SVG templates.
 */
export interface SvgTemplateTimerDefinition {
  /**
   * Stable timer identifier.
   */
  id: string;

  /**
   * Optional fixed duration in milliseconds.
   */
  durationMs?: number;

  /**
   * Optional state path that resolves to a duration in milliseconds.
   *
   * The path may itself contain `{{...}}` placeholders.
   */
  durationPath?: string;

  /**
   * Optional state path that resolves to the timer start timestamp in milliseconds.
   *
   * The path may itself contain `{{...}}` placeholders.
   */
  startAtPath?: string;

  /**
   * When true, the timer starts automatically when the activity is created.
   */
  autoStart?: boolean;
}

/**
 * Declarative mutation applied to the stored activity state.
 */
export interface SvgTemplateStatePatch {
  /**
   * Mutation operation.
   */
  op: 'set' | 'increment' | 'toggle' | 'unset' | 'timestamp';

  /**
   * Destination state path.
   *
   * The path may itself contain `{{...}}` placeholders.
   */
  path: string;

  /**
   * Optional literal value used by the mutation.
   */
  value?: JsonValue;

  /**
   * Optional source path used to copy a value from the current runtime scope.
   *
   * The path may itself contain `{{...}}` placeholders.
   */
  valuePath?: string;

  /**
   * Optional template-resolved value.
   *
   * If the string is a single `{{...}}` token, the raw referenced JSON value is copied.
   * Otherwise the resolved string is stored.
   */
  valueTemplate?: string;

  /**
   * Increment amount for `increment`.
   */
  amount?: number;
}

/**
 * Declarative timer mutation triggered by an action.
 */
export interface SvgTemplateTimerMutation {
  /**
   * Mutation operation.
   */
  op: 'start' | 'stop' | 'restart' | 'pause' | 'resume' | 'toggle' | 'reset' | 'setDuration';

  /**
   * Target timer identifier.
   */
  timerId: string;

  /**
   * Optional fixed duration override in milliseconds.
   */
  durationMs?: number;

  /**
   * Optional path that resolves to a duration override in milliseconds.
   *
   * The path may itself contain `{{...}}` placeholders.
   */
  durationPath?: string;
}

/**
 * Declarative frame mutation triggered by an action.
 */
export interface SvgTemplateFrameMutation {
  /**
   * Mutation operation.
   */
  op: 'set' | 'next' | 'previous' | 'toggle';

  /**
   * Destination state path that stores the active frame id.
   *
   * The path may itself contain `{{...}}` placeholders.
   */
  path: string;

  /**
   * Frame id used by `set`, or the alternate frame id used by `toggle`.
   *
   * The value may contain `{{...}}` placeholders.
   */
  frameId?: string;

  /**
   * Ordered frame ids used by `next`, `previous`, and `toggle`.
   *
   * When omitted, `surface` can be used to read frame ids from a layout definition.
   */
  frameIds?: string[];

  /**
   * Optional surface whose layout frames should be used when `frameIds` is omitted.
   */
  surface?: SvgTemplateSurface;

  /**
   * Whether `next` and `previous` wrap at the ends.
   *
   * Defaults to `true`.
   */
  wrap?: boolean;
}

/**
 * Declarative action attached to one or more hotspots.
 */
export interface SvgTemplateActionDefinition {
  /**
   * Stable action identifier.
   */
  id: string;

  /**
   * Optional event name used in the action log.
   */
  eventName?: string;

  /**
   * Optional UI label.
   */
  label?: string;

  /**
   * Ordered state mutations executed when the action runs.
   */
  patches?: SvgTemplateStatePatch[];

  /**
   * Ordered timer mutations executed when the action runs.
   */
  timerMutations?: SvgTemplateTimerMutation[];

  /**
   * Ordered frame mutations executed when the action runs.
   */
  frameMutations?: SvgTemplateFrameMutation[];

  /**
   * Optional deep link opened by the host widget when the action runs.
   */
  openUrl?: string;
}

/**
 * Generic SVG template definition stored by the plugin.
 */
export interface SvgTemplateDefinition {
  /**
   * Stable template identifier.
   */
  id: string;

  /**
   * Optional version marker for migrations.
   */
  version?: string;

  /**
   * Available WidgetKit layouts.
   */
  layouts: SvgTemplateLayouts;

  /**
   * Optional declarative actions.
   */
  actions?: SvgTemplateActionDefinition[];

  /**
   * Optional timer definitions exposed to the template runtime.
   */
  timers?: SvgTemplateTimerDefinition[];

  /**
   * Optional JSON metadata mirrored in the runtime scope under `meta.template`.
   */
  metadata?: JsonObject;
}

/**
 * Persisted timer runtime state.
 */
export interface SvgTemplateTimerState {
  /**
   * Timer identifier.
   */
  id: string;

  /**
   * Start timestamp in milliseconds, or `null` when the timer is idle.
   */
  startedAt?: number | null;

  /**
   * Elapsed milliseconds already accumulated before the current run.
   *
   * This is used to preserve timer progress while paused.
   */
  elapsedMs?: number;

  /**
   * Current timer duration in milliseconds.
   */
  durationMs: number;

  /**
   * Current timer status.
   */
  status: 'idle' | 'running' | 'paused' | 'finished' | 'stopped';

  /**
   * Last update timestamp.
   */
  updatedAt: number;
}

/**
 * Stored activity snapshot returned by the plugin.
 */
export interface SvgTemplateActivityRecord {
  /**
   * Stable plugin activity identifier.
   */
  activityId: string;

  /**
   * Full template definition.
   */
  definition: SvgTemplateDefinition;

  /**
   * Persisted JSON state.
   */
  state: SvgTemplateState;

  /**
   * Timer runtime state keyed by timer id.
   */
  timers: Record<string, SvgTemplateTimerState>;

  /**
   * Current lifecycle status.
   */
  status: 'active' | 'ended';

  /**
   * Optional deep link opened when the widget body is tapped.
   */
  openUrl?: string;

  /**
   * Last update timestamp.
   */
  updatedAt: number;

  /**
   * Monotonic revision incremented on every state change.
   */
  revision: number;
}

/**
 * Event emitted whenever a declarative action is executed.
 */
export interface SvgTemplateActionEvent {
  /**
   * Stable event identifier.
   */
  eventId: string;

  /**
   * Activity identifier associated with the event.
   */
  activityId: string;

  /**
   * Action identifier that produced the event.
   */
  actionId: string;

  /**
   * Optional event name copied from the action definition.
   */
  eventName?: string;

  /**
   * Optional source identifier, typically the hotspot id that triggered the action.
   */
  sourceId?: string;

  /**
   * Event creation timestamp in milliseconds.
   */
  createdAt: number;

  /**
   * Timestamp in milliseconds when the app acknowledged the event.
   */
  acknowledgedAt?: number | null;

  /**
   * Optional caller-provided payload.
   */
  payload?: JsonObject | null;

  /**
   * State snapshot after the action was applied.
   */
  state: SvgTemplateState;

  /**
   * Timer snapshot after the action was applied.
   */
  timers: Record<string, SvgTemplateTimerState>;
}

/**
 * Options for starting a generic SVG template activity.
 */
export interface StartTemplateActivityOptions {
  /**
   * Optional explicit activity identifier. When omitted, the native runtime creates one.
   */
  activityId?: string;

  /**
   * Generic SVG template definition.
   */
  definition: SvgTemplateDefinition;

  /**
   * Initial JSON state exposed under `state.*`.
   */
  state: SvgTemplateState;

  /**
   * Optional deep link used when the widget body is tapped.
   */
  openUrl?: string;
}

/**
 * Result when starting a generic template activity.
 */
export interface StartTemplateActivityResult {
  /**
   * Stored activity snapshot.
   */
  activity: SvgTemplateActivityRecord;
}

/**
 * Options for updating an existing template activity.
 */
export interface UpdateTemplateActivityOptions {
  /**
   * Activity identifier returned by `startTemplateActivity`.
   */
  activityId: string;

  /**
   * Optional replacement definition.
   */
  definition?: SvgTemplateDefinition;

  /**
   * Optional replacement state.
   */
  state?: SvgTemplateState;

  /**
   * Optional replacement deep link.
   */
  openUrl?: string;
}

/**
 * Result when reading or updating a single activity.
 */
export interface TemplateActivityResult {
  /**
   * Stored activity snapshot, or `null` when not found.
   */
  activity: SvgTemplateActivityRecord | null;
}

/**
 * Options for ending a template activity.
 */
export interface EndTemplateActivityOptions {
  /**
   * Activity identifier returned by `startTemplateActivity`.
   */
  activityId: string;

  /**
   * Optional final state persisted before ending.
   */
  state?: SvgTemplateState;
}

/**
 * Options for executing a declarative action.
 */
export interface PerformTemplateActionOptions {
  /**
   * Activity identifier returned by `startTemplateActivity`.
   */
  activityId: string;

  /**
   * Action identifier declared in the template definition.
   */
  actionId: string;

  /**
   * Optional source identifier, typically the hotspot id that triggered the action.
   */
  sourceId?: string;

  /**
   * Optional payload stored with the emitted event and exposed to declarative patches under `{{action.payload.*}}`.
   */
  payload?: JsonObject;
}

/**
 * Result after executing an action.
 */
export interface PerformTemplateActionResult {
  /**
   * Updated activity snapshot.
   */
  activity: SvgTemplateActivityRecord;

  /**
   * Action event emitted by the runtime.
   */
  event: SvgTemplateActionEvent;
}

/**
 * Options for reading one stored activity.
 */
export interface GetTemplateActivityOptions {
  /**
   * Activity identifier to load.
   */
  activityId: string;
}

/**
 * Result when listing stored activities.
 */
export interface ListTemplateActivitiesResult {
  /**
   * Stored activity snapshots.
   */
  activities: SvgTemplateActivityRecord[];
}

/**
 * Options when listing action events.
 */
export interface ListTemplateEventsOptions {
  /**
   * Optional activity filter.
   */
  activityId?: string;

  /**
   * When true, only unacknowledged events are returned.
   */
  unacknowledgedOnly?: boolean;
}

/**
 * Result when listing action events.
 */
export interface ListTemplateEventsResult {
  /**
   * Matching action events.
   */
  events: SvgTemplateActionEvent[];
}

/**
 * Options for acknowledging events after the host app processes them.
 */
export interface AcknowledgeTemplateEventsOptions {
  /**
   * Optional explicit event ids to acknowledge.
   */
  eventIds?: string[];

  /**
   * Optional activity id shortcut that acknowledges every event for the activity.
   */
  activityId?: string;
}

/**
 * Stored full-native widget session.
 */
export interface WidgetSessionRecord {
  /**
   * Stable widget/session identifier.
   */
  widgetId: string;

  /**
   * Optional product-defined session kind.
   */
  kind?: string;

  /**
   * JSON state shared synchronously between the app and native widget code.
   */
  state: JsonObject;

  /**
   * Optional JSON metadata for native widget code.
   */
  metadata?: JsonObject;

  /**
   * Current session status.
   */
  status: 'active' | 'stopped';

  /**
   * Creation timestamp.
   */
  createdAt: number;

  /**
   * Last update timestamp.
   */
  updatedAt: number;

  /**
   * Monotonic revision incremented on every session state change.
   */
  revision: number;
}

/**
 * Options for starting a full-native widget session.
 */
export interface StartWidgetSessionOptions {
  /**
   * Optional explicit widget/session identifier. When omitted, the native runtime creates one.
   */
  widgetId?: string;

  /**
   * Optional product-defined session kind.
   */
  kind?: string;

  /**
   * Initial shared state.
   */
  state?: JsonObject;

  /**
   * Optional metadata for native widget code.
   */
  metadata?: JsonObject;
}

/**
 * Result when starting a full-native widget session.
 */
export interface StartWidgetSessionResult {
  /**
   * Stored session snapshot.
   */
  session: WidgetSessionRecord;
}

/**
 * Options for updating a full-native widget session.
 */
export interface UpdateWidgetSessionOptions {
  /**
   * Widget/session identifier returned by `startWidgetSession`.
   */
  widgetId: string;

  /**
   * Replacement or merge patch for shared state.
   */
  state?: JsonObject;

  /**
   * Replacement or merge patch for metadata.
   */
  metadata?: JsonObject;

  /**
   * When true, object values are deep-merged instead of replaced.
   */
  merge?: boolean;
}

/**
 * Result when reading or updating one full-native widget session.
 */
export interface WidgetSessionResult {
  /**
   * Stored session snapshot, or `null` when not found.
   */
  session: WidgetSessionRecord | null;
}

/**
 * Options for stopping a full-native widget session.
 */
export interface StopWidgetSessionOptions {
  /**
   * Widget/session identifier returned by `startWidgetSession`.
   */
  widgetId: string;

  /**
   * Optional final shared state.
   */
  state?: JsonObject;
}

/**
 * Options for reading one full-native widget session.
 */
export interface GetWidgetSessionOptions {
  /**
   * Widget/session identifier to load.
   */
  widgetId: string;
}

/**
 * Result when listing full-native widget sessions.
 */
export interface ListWidgetSessionsResult {
  /**
   * Stored session snapshots.
   */
  sessions: WidgetSessionRecord[];
}

/**
 * Message direction for the full-native widget bridge.
 */
export type WidgetMessageDirection = 'appToWidget' | 'widgetToApp';

/**
 * Completion status for a full-native widget bridge message.
 */
export type WidgetMessageStatus = 'pending' | 'completed' | 'failed';

/**
 * Queued message used for async app/widget jobs.
 */
export interface WidgetBridgeMessage {
  /**
   * Stable message identifier.
   */
  messageId: string;

  /**
   * Widget/session identifier associated with the message.
   */
  widgetId: string;

  /**
   * Message direction.
   */
  direction: WidgetMessageDirection;

  /**
   * Product-defined message or job name.
   */
  name: string;

  /**
   * Optional JSON payload.
   */
  payload?: JsonObject | null;

  /**
   * Whether the sender expects a later response.
   */
  expectsResponse: boolean;

  /**
   * Current message status.
   */
  status: WidgetMessageStatus;

  /**
   * Message creation timestamp.
   */
  createdAt: number;

  /**
   * Timestamp in milliseconds when the receiver acknowledged the message.
   */
  acknowledgedAt?: number | null;

  /**
   * Timestamp in milliseconds when the message was completed or failed.
   */
  completedAt?: number | null;

  /**
   * Optional JSON response for async jobs.
   */
  response?: JsonObject | null;

  /**
   * Optional failure message for async jobs.
   */
  error?: string | null;
}

/**
 * Options for sending a full-native widget bridge message.
 */
export interface SendWidgetMessageOptions {
  /**
   * Widget/session identifier associated with the message.
   */
  widgetId: string;

  /**
   * Product-defined message or job name.
   */
  name: string;

  /**
   * Optional message direction.
   *
   * Defaults to `appToWidget` when called from the app.
   */
  direction?: WidgetMessageDirection;

  /**
   * Optional JSON payload.
   */
  payload?: JsonObject;

  /**
   * Whether the sender expects a later response.
   */
  expectsResponse?: boolean;
}

/**
 * Result after sending or completing a widget bridge message.
 */
export interface WidgetMessageResult {
  /**
   * Stored message snapshot, or `null` when not found.
   */
  message: WidgetBridgeMessage | null;
}

/**
 * Options when listing full-native widget bridge messages.
 */
export interface ListWidgetMessagesOptions {
  /**
   * Optional widget/session filter.
   */
  widgetId?: string;

  /**
   * Optional direction filter.
   */
  direction?: WidgetMessageDirection;

  /**
   * When true, only unacknowledged messages are returned.
   */
  unacknowledgedOnly?: boolean;

  /**
   * When true, only pending messages are returned.
   */
  pendingOnly?: boolean;
}

/**
 * Result when listing full-native widget bridge messages.
 */
export interface ListWidgetMessagesResult {
  /**
   * Matching messages.
   */
  messages: WidgetBridgeMessage[];
}

/**
 * Options for acknowledging widget bridge messages after processing them.
 */
export interface AcknowledgeWidgetMessagesOptions {
  /**
   * Optional explicit message ids to acknowledge.
   */
  messageIds?: string[];

  /**
   * Optional widget/session shortcut that acknowledges matching messages.
   */
  widgetId?: string;

  /**
   * Optional direction filter.
   */
  direction?: WidgetMessageDirection;
}

/**
 * Options for completing an async widget bridge message.
 */
export interface CompleteWidgetMessageOptions {
  /**
   * Message identifier returned by `sendWidgetMessage`.
   */
  messageId: string;

  /**
   * Optional JSON response payload.
   */
  response?: JsonObject;

  /**
   * Optional error string. When set, the message status becomes `failed`.
   */
  error?: string;
}

/**
 * Capacitor bridge for an iOS-first WidgetKit / Live Activities plugin.
 *
 * The core abstraction is a generic SVG template activity:
 * - raw SVG templates with binding placeholders
 * - declarative action patches
 * - timer bindings exposed to the template scope
 * - event logging so the host app can process button results later
 *
 * The plugin owns shared persistence, declarative action execution, and event retrieval.
 * The host widget extension keeps full freedom over actual WidgetKit rendering.
 *
 * Full-native widgets can use widget sessions for synchronous shared state and widget messages
 * for asynchronous app/widget jobs without adopting the SVG template renderer.
 */
export interface CapgoWidgetKitPlugin {
  /**
   * Check whether the native template activity bridge can run on the current device.
   */
  areActivitiesSupported(): Promise<ActivitiesSupportedResult>;

  /**
   * Persist a generic SVG template activity and start the matching native Live Activity bridge.
   */
  startTemplateActivity(options: StartTemplateActivityOptions): Promise<StartTemplateActivityResult>;

  /**
   * Replace part or all of the stored activity definition/state.
   */
  updateTemplateActivity(options: UpdateTemplateActivityOptions): Promise<TemplateActivityResult>;

  /**
   * End a running activity while optionally persisting one last state snapshot.
   */
  endTemplateActivity(options: EndTemplateActivityOptions): Promise<void>;

  /**
   * Execute one declarative action and record the resulting event.
   */
  performTemplateAction(options: PerformTemplateActionOptions): Promise<PerformTemplateActionResult>;

  /**
   * Read one activity back from the shared store.
   */
  getTemplateActivity(options: GetTemplateActivityOptions): Promise<TemplateActivityResult>;

  /**
   * List every activity currently known by the plugin.
   */
  listTemplateActivities(): Promise<ListTemplateActivitiesResult>;

  /**
   * List stored action events so the app can react to widget interactions later.
   */
  listTemplateEvents(options?: ListTemplateEventsOptions): Promise<ListTemplateEventsResult>;

  /**
   * Mark previously processed events as acknowledged.
   */
  acknowledgeTemplateEvents(options: AcknowledgeTemplateEventsOptions): Promise<void>;

  /**
   * Start a full-native widget session backed by shared JSON state.
   */
  startWidgetSession(options: StartWidgetSessionOptions): Promise<StartWidgetSessionResult>;

  /**
   * Update a full-native widget session.
   */
  updateWidgetSession(options: UpdateWidgetSessionOptions): Promise<WidgetSessionResult>;

  /**
   * Stop a full-native widget session.
   */
  stopWidgetSession(options: StopWidgetSessionOptions): Promise<void>;

  /**
   * Read one full-native widget session.
   */
  getWidgetSession(options: GetWidgetSessionOptions): Promise<WidgetSessionResult>;

  /**
   * List every full-native widget session currently known by the plugin.
   */
  listWidgetSessions(): Promise<ListWidgetSessionsResult>;

  /**
   * Queue a message between the app and native widget code.
   */
  sendWidgetMessage(options: SendWidgetMessageOptions): Promise<WidgetMessageResult>;

  /**
   * List queued full-native widget bridge messages.
   */
  listWidgetMessages(options?: ListWidgetMessagesOptions): Promise<ListWidgetMessagesResult>;

  /**
   * Mark widget bridge messages as acknowledged after processing.
   */
  acknowledgeWidgetMessages(options: AcknowledgeWidgetMessagesOptions): Promise<void>;

  /**
   * Complete or fail an async widget bridge message.
   */
  completeWidgetMessage(options: CompleteWidgetMessageOptions): Promise<WidgetMessageResult>;

  /**
   * Return the platform implementation version marker.
   */
  getPluginVersion(): Promise<PluginVersionResult>;
}
