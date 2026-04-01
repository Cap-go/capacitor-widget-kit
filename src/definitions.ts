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
   * Whether the current device and runtime can run the native workout live activity.
   */
  supported: boolean;

  /**
   * Human-readable reason when support is unavailable.
   */
  reason?: string;
}

/**
 * Notification behavior for workout timers or session completion.
 */
export interface WorkoutNotificationSettings {
  /**
   * Whether the notification is enabled.
   */
  enabled: boolean;

  /**
   * Optional custom title.
   */
  title?: string;

  /**
   * Optional custom body.
   */
  body?: string;
}

/**
 * Convenience type that accepts either a boolean or a full notification object.
 */
export type WorkoutNotificationPreference = boolean | WorkoutNotificationSettings;

/**
 * Individual set inside an exercise.
 */
export interface WorkoutSet {
  /**
   * Optional stable identifier.
   */
  id?: string;

  /**
   * Display label for the set.
   */
  title: string;

  /**
   * Optional recommendation pill shown above the active set.
   */
  recommendation?: string | null;

  /**
   * Millisecond timestamp when the set was completed.
   */
  completedAt?: number | null;

  /**
   * Optional rest timer duration in milliseconds that starts after this set is completed.
   */
  timerDurationMs?: number | null;

  /**
   * Index of the next active exercise after completing this set.
   */
  nextExerciseIndex?: number | null;

  /**
   * Index of the next active set after completing this set.
   */
  nextSetIndex?: number | null;
}

/**
 * Exercise block displayed inside the workout live activity.
 */
export interface WorkoutExercise {
  /**
   * Stable exercise identifier.
   */
  id: string;

  /**
   * Primary exercise title.
   */
  title: string;

  /**
   * Secondary exercise subtitle.
   */
  subtitle?: string;

  /**
   * Optional SF Symbol used when no bundled image is available.
   */
  iconSystemName?: string;

  /**
   * Optional bundled asset name for the exercise thumbnail.
   */
  imageAssetName?: string;

  /**
   * Ordered sets for the exercise.
   */
  sets: WorkoutSet[];
}

/**
 * Persisted workout session model used by the plugin and widget extension.
 */
export interface WorkoutSession {
  /**
   * Stable session identifier.
   */
  sessionId: string;

  /**
   * Session title shown in the completed state and widget metadata.
   */
  title: string;

  /**
   * Start timestamp in milliseconds.
   */
  startedAt: number;

  /**
   * Currently active exercise index. Set to `null` when the workout is complete.
   */
  activeExerciseIndex?: number | null;

  /**
   * Currently active set index. Set to `null` when the workout is complete.
   */
  activeSetIndex?: number | null;

  /**
   * Deep link opened when the live activity body is tapped.
   */
  deepLinkUrl?: string;

  /**
   * Timer notification settings. The plugin accepts either `true`/`false` or a full object.
   */
  timerNotifications?: WorkoutNotificationPreference;

  /**
   * Optional completion notification settings reserved for the host app.
   */
  sessionNotifications?: WorkoutNotificationPreference;

  /**
   * Ordered exercises in the workout.
   */
  exercises: WorkoutExercise[];
}

/**
 * Options for starting the workout live activity.
 */
export interface StartWorkoutLiveActivityOptions {
  /**
   * Full workout session payload that should be persisted and rendered.
   */
  session: WorkoutSession;
}

/**
 * Result when starting a workout live activity.
 */
export interface StartWorkoutLiveActivityResult {
  /**
   * ActivityKit activity identifier.
   */
  activityId: string;

  /**
   * Session identifier persisted in the shared App Group store.
   */
  sessionId: string;
}

/**
 * Optional native alert configuration for an activity update.
 */
export interface WidgetAlertConfiguration {
  /**
   * Alert title.
   */
  title: string;

  /**
   * Alert body.
   */
  body: string;
}

/**
 * Options for updating an existing workout live activity.
 */
export interface UpdateWorkoutLiveActivityOptions {
  /**
   * Activity identifier returned by `startWorkoutLiveActivity`.
   */
  activityId: string;

  /**
   * Full replacement session payload.
   */
  session: WorkoutSession;

  /**
   * Optional native alert shown as part of the update.
   */
  alertConfiguration?: WidgetAlertConfiguration;
}

/**
 * Options for ending a workout live activity.
 */
export interface EndWorkoutLiveActivityOptions {
  /**
   * Activity identifier returned by `startWorkoutLiveActivity`.
   */
  activityId: string;

  /**
   * Optional final session snapshot to persist before ending the activity.
   */
  session?: WorkoutSession;
}

/**
 * Options for retrieving a stored workout session.
 */
export interface GetStoredWorkoutSessionOptions {
  /**
   * Session identifier. Preferred lookup key.
   */
  sessionId?: string;

  /**
   * Activity identifier when only the activity is known.
   */
  activityId?: string;
}

/**
 * Stored workout session result payload.
 */
export interface StoredWorkoutSessionResult {
  /**
   * Persisted workout session, or `null` when no matching entry exists.
   */
  session: WorkoutSession | null;
}

/**
 * Options for completing the active set either from the app or from an interactive widget action.
 */
export interface CompleteWorkoutSetOptions {
  /**
   * Session identifier to mutate.
   */
  sessionId: string;

  /**
   * Optional activity identifier when it is already known.
   */
  activityId?: string;
}

/**
 * Metadata describing a currently known live activity.
 */
export interface LiveActivityRecord {
  /**
   * ActivityKit identifier.
   */
  activityId: string;

  /**
   * Associated workout session identifier.
   */
  sessionId: string;

  /**
   * Current activity state.
   */
  state: 'active' | 'ended';

  /**
   * Last update timestamp in milliseconds.
   */
  updatedAt: number;
}

/**
 * Result of listing known workout live activities.
 */
export interface ListWorkoutLiveActivitiesResult {
  /**
   * Activity records tracked by the plugin.
   */
  activities: LiveActivityRecord[];
}

/**
 * Capacitor bridge for an iOS-first WidgetKit / Live Activities plugin.
 *
 * This package intentionally uses a native workout session model instead of a raw SVG renderer.
 * Static SVG snapshots are fine for passive home widgets, but the requested workout experience
 * requires native ActivityKit features such as interactivity, countdown rendering, and shared
 * App Group persistence.
 */
export interface CapgoWidgetKitPlugin {
  /**
   * Check whether the native workout live activity can run on the current device.
   */
  areActivitiesSupported(): Promise<ActivitiesSupportedResult>;

  /**
   * Start the workout live activity and persist the session in the shared App Group store.
   */
  startWorkoutLiveActivity(options: StartWorkoutLiveActivityOptions): Promise<StartWorkoutLiveActivityResult>;

  /**
   * Replace the stored workout session and push a matching ActivityKit update.
   */
  updateWorkoutLiveActivity(options: UpdateWorkoutLiveActivityOptions): Promise<void>;

  /**
   * End the workout live activity while optionally persisting one last session snapshot.
   */
  endWorkoutLiveActivity(options: EndWorkoutLiveActivityOptions): Promise<void>;

  /**
   * Complete the current active set and advance to the next exercise/set pair.
   */
  completeWorkoutSet(options: CompleteWorkoutSetOptions): Promise<StoredWorkoutSessionResult>;

  /**
   * Read a session back from the shared store.
   */
  getStoredWorkoutSession(options: GetStoredWorkoutSessionOptions): Promise<StoredWorkoutSessionResult>;

  /**
   * List activity identifiers currently known by the plugin.
   */
  listWorkoutLiveActivities(): Promise<ListWorkoutLiveActivitiesResult>;

  /**
   * Return the platform implementation version marker.
   */
  getPluginVersion(): Promise<PluginVersionResult>;
}
