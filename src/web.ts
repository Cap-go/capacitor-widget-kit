import { WebPlugin } from '@capacitor/core';

import type {
  ActivitiesSupportedResult,
  CapgoWidgetKitPlugin,
  CompleteWorkoutSetOptions,
  EndWorkoutLiveActivityOptions,
  GetStoredWorkoutSessionOptions,
  ListWorkoutLiveActivitiesResult,
  LiveActivityRecord,
  PluginVersionResult,
  StartWorkoutLiveActivityOptions,
  StartWorkoutLiveActivityResult,
  StoredWorkoutSessionResult,
  UpdateWorkoutLiveActivityOptions,
  WorkoutSession,
  WorkoutSet,
} from './definitions';

type WebActivityState = {
  activityId: string;
  sessionId: string;
  state: 'active' | 'ended';
  updatedAt: number;
};

type WebStore = {
  activities: Record<string, WebActivityState>;
  sessions: Record<string, WorkoutSession>;
};

const STORE_KEY = 'capgo-widget-kit-preview-store';

function cloneSession<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

function loadStore(): WebStore {
  if (typeof localStorage === 'undefined') {
    return { activities: {}, sessions: {} };
  }
  const raw = localStorage.getItem(STORE_KEY);
  if (!raw) {
    return { activities: {}, sessions: {} };
  }
  try {
    const parsed = JSON.parse(raw) as WebStore;
    return {
      activities: parsed.activities ?? {},
      sessions: parsed.sessions ?? {},
    };
  } catch {
    return { activities: {}, sessions: {} };
  }
}

function saveStore(store: WebStore): void {
  if (typeof localStorage === 'undefined') {
    return;
  }
  localStorage.setItem(STORE_KEY, JSON.stringify(store));
}

function getSessionId(options: GetStoredWorkoutSessionOptions, store: WebStore): string | undefined {
  if (options.sessionId) {
    return options.sessionId;
  }
  if (options.activityId) {
    return store.activities[options.activityId]?.sessionId;
  }
  return undefined;
}

function completeActiveSet(session: WorkoutSession): WorkoutSession {
  const nextSession = cloneSession(session);
  const exerciseIndex = nextSession.activeExerciseIndex;
  const setIndex = nextSession.activeSetIndex;

  if (exerciseIndex == null || setIndex == null) {
    return nextSession;
  }

  const exercise = nextSession.exercises[exerciseIndex];
  const workoutSet: WorkoutSet | undefined = exercise?.sets[setIndex];
  if (!exercise || !workoutSet) {
    return nextSession;
  }

  const now = Date.now();
  workoutSet.completedAt = now;
  nextSession.activeExerciseIndex = workoutSet.nextExerciseIndex ?? null;
  nextSession.activeSetIndex = workoutSet.nextSetIndex ?? null;

  return nextSession;
}

export class CapgoWidgetKitWeb extends WebPlugin implements CapgoWidgetKitPlugin {
  async areActivitiesSupported(): Promise<ActivitiesSupportedResult> {
    return {
      supported: false,
      reason: 'WidgetKit preview mode only. Run the example app on iOS 17+ for native ActivityKit behavior.',
    };
  }

  async startWorkoutLiveActivity(options: StartWorkoutLiveActivityOptions): Promise<StartWorkoutLiveActivityResult> {
    const activityId = crypto.randomUUID();
    const updatedAt = Date.now();
    const store = loadStore();

    store.sessions[options.session.sessionId] = cloneSession(options.session);
    store.activities[activityId] = {
      activityId,
      sessionId: options.session.sessionId,
      state: 'active',
      updatedAt,
    };
    saveStore(store);

    return {
      activityId,
      sessionId: options.session.sessionId,
    };
  }

  async updateWorkoutLiveActivity(options: UpdateWorkoutLiveActivityOptions): Promise<void> {
    const store = loadStore();
    const activity = store.activities[options.activityId];
    if (!activity) {
      throw new Error(`Activity ${options.activityId} not found in preview store.`);
    }

    store.sessions[options.session.sessionId] = cloneSession(options.session);
    activity.updatedAt = Date.now();
    activity.sessionId = options.session.sessionId;
    saveStore(store);
  }

  async endWorkoutLiveActivity(options: EndWorkoutLiveActivityOptions): Promise<void> {
    const store = loadStore();
    const activity = store.activities[options.activityId];
    if (!activity) {
      return;
    }
    if (options.session) {
      store.sessions[options.session.sessionId] = cloneSession(options.session);
      activity.sessionId = options.session.sessionId;
    }
    activity.state = 'ended';
    activity.updatedAt = Date.now();
    saveStore(store);
  }

  async completeWorkoutSet(options: CompleteWorkoutSetOptions): Promise<StoredWorkoutSessionResult> {
    const store = loadStore();
    const session = store.sessions[options.sessionId];
    if (!session) {
      return { session: null };
    }

    const nextSession = completeActiveSet(session);
    store.sessions[options.sessionId] = nextSession;

    const activity = options.activityId
      ? store.activities[options.activityId]
      : Object.values(store.activities).find(
          (candidate) => candidate.sessionId === options.sessionId && candidate.state === 'active',
        );

    if (activity) {
      activity.updatedAt = Date.now();
    }

    saveStore(store);
    return { session: cloneSession(nextSession) };
  }

  async getStoredWorkoutSession(options: GetStoredWorkoutSessionOptions): Promise<StoredWorkoutSessionResult> {
    const store = loadStore();
    const sessionId = getSessionId(options, store);
    return {
      session: sessionId ? cloneSession(store.sessions[sessionId] ?? null) : null,
    };
  }

  async listWorkoutLiveActivities(): Promise<ListWorkoutLiveActivitiesResult> {
    const store = loadStore();
    const activities: LiveActivityRecord[] = Object.values(store.activities).map((activity) => ({
      activityId: activity.activityId,
      sessionId: activity.sessionId,
      state: activity.state,
      updatedAt: activity.updatedAt,
    }));
    return { activities };
  }

  async getPluginVersion(): Promise<PluginVersionResult> {
    return {
      version: 'web-preview',
    };
  }
}
