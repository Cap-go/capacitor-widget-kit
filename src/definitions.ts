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
 * SVG layout variant for one WidgetKit surface.
 */
export interface SvgTemplateLayout {
  /**
   * Raw SVG template string.
   *
   * The runtime resolves `{{state.*}}`, `{{timers.*}}`, and `{{meta.*}}` placeholders before rendering.
   */
  svg: string;

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
  op: 'start' | 'stop' | 'restart' | 'setDuration';

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
   * Current timer duration in milliseconds.
   */
  durationMs: number;

  /**
   * Current timer status.
   */
  status: 'idle' | 'running' | 'finished' | 'stopped';

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
   * Return the platform implementation version marker.
   */
  getPluginVersion(): Promise<PluginVersionResult>;
}
