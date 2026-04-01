import { WebPlugin } from '@capacitor/core';

import type {
  AcknowledgeTemplateEventsOptions,
  ActivitiesSupportedResult,
  CapgoWidgetKitPlugin,
  EndTemplateActivityOptions,
  GetTemplateActivityOptions,
  ListTemplateActivitiesResult,
  ListTemplateEventsOptions,
  ListTemplateEventsResult,
  PerformTemplateActionOptions,
  PerformTemplateActionResult,
  PluginVersionResult,
  StartTemplateActivityOptions,
  StartTemplateActivityResult,
  SvgTemplateActionEvent,
  SvgTemplateActivityRecord,
  TemplateActivityResult,
  UpdateTemplateActivityOptions,
} from './definitions';
import { acknowledgeEvents, applyTemplateAction, createTemplateActivityRecord, reconcileTimerStates } from './runtime';

type WebStore = {
  activities: Record<string, SvgTemplateActivityRecord>;
  events: Record<string, SvgTemplateActionEvent>;
};

const STORE_KEY = 'capgo-widget-kit-preview-store-v2';

function cloneJson<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

function loadStore(): WebStore {
  if (typeof localStorage === 'undefined') {
    return { activities: {}, events: {} };
  }

  const raw = localStorage.getItem(STORE_KEY);
  if (!raw) {
    return { activities: {}, events: {} };
  }

  try {
    const parsed = JSON.parse(raw) as WebStore;
    return {
      activities: parsed.activities ?? {},
      events: parsed.events ?? {},
    };
  } catch {
    return { activities: {}, events: {} };
  }
}

function saveStore(store: WebStore): void {
  if (typeof localStorage === 'undefined') {
    return;
  }
  localStorage.setItem(STORE_KEY, JSON.stringify(store));
}

function sortActivities(activities: SvgTemplateActivityRecord[]): SvgTemplateActivityRecord[] {
  return activities.sort((left, right) => right.updatedAt - left.updatedAt);
}

function sortEvents(events: SvgTemplateActionEvent[]): SvgTemplateActionEvent[] {
  return events.sort((left, right) => right.createdAt - left.createdAt);
}

function getActivityOrThrow(store: WebStore, activityId: string): SvgTemplateActivityRecord {
  const activity = store.activities[activityId];
  if (!activity) {
    throw new Error(`Activity ${activityId} was not found in the preview store.`);
  }
  return cloneJson(activity);
}

export class CapgoWidgetKitWeb extends WebPlugin implements CapgoWidgetKitPlugin {
  async areActivitiesSupported(): Promise<ActivitiesSupportedResult> {
    return {
      supported: false,
      reason:
        'WidgetKit preview mode only. The generic template runtime works in the browser, but native ActivityKit support is available on iOS 16.2+.',
    };
  }

  async startTemplateActivity(options: StartTemplateActivityOptions): Promise<StartTemplateActivityResult> {
    const store = loadStore();
    const activity = createTemplateActivityRecord(options.definition, options.state, {
      activityId: options.activityId,
      openUrl: options.openUrl,
    });
    store.activities[activity.activityId] = activity;
    saveStore(store);
    return { activity: cloneJson(activity) };
  }

  async updateTemplateActivity(options: UpdateTemplateActivityOptions): Promise<TemplateActivityResult> {
    const store = loadStore();
    const current = getActivityOrThrow(store, options.activityId);
    const now = Date.now();

    const nextActivity: SvgTemplateActivityRecord = {
      ...current,
      definition: cloneJson(options.definition ?? current.definition),
      state: cloneJson(options.state ?? current.state),
      openUrl: options.openUrl ?? current.openUrl,
      updatedAt: now,
      revision: current.revision + 1,
    };
    nextActivity.timers = reconcileTimerStates(
      nextActivity.definition,
      nextActivity.state,
      nextActivity.timers,
      nextActivity.activityId,
      nextActivity.status,
      now,
    );

    store.activities[nextActivity.activityId] = nextActivity;
    saveStore(store);
    return { activity: cloneJson(nextActivity) };
  }

  async endTemplateActivity(options: EndTemplateActivityOptions): Promise<void> {
    const store = loadStore();
    const current = getActivityOrThrow(store, options.activityId);
    const now = Date.now();

    const nextActivity: SvgTemplateActivityRecord = {
      ...current,
      state: cloneJson(options.state ?? current.state),
      status: 'ended',
      updatedAt: now,
      revision: current.revision + 1,
    };
    nextActivity.timers = reconcileTimerStates(
      nextActivity.definition,
      nextActivity.state,
      nextActivity.timers,
      nextActivity.activityId,
      nextActivity.status,
      now,
    );

    store.activities[nextActivity.activityId] = nextActivity;
    saveStore(store);
  }

  async performTemplateAction(options: PerformTemplateActionOptions): Promise<PerformTemplateActionResult> {
    const store = loadStore();
    const activity = getActivityOrThrow(store, options.activityId);
    const result = applyTemplateAction(activity, options);
    store.activities[result.activity.activityId] = result.activity;
    store.events[result.event.eventId] = result.event;
    saveStore(store);
    return {
      activity: cloneJson(result.activity),
      event: cloneJson(result.event),
    };
  }

  async getTemplateActivity(options: GetTemplateActivityOptions): Promise<TemplateActivityResult> {
    const store = loadStore();
    const activity = store.activities[options.activityId];
    return {
      activity: activity ? cloneJson(activity) : null,
    };
  }

  async listTemplateActivities(): Promise<ListTemplateActivitiesResult> {
    const store = loadStore();
    return {
      activities: sortActivities(Object.values(store.activities).map((activity) => cloneJson(activity))),
    };
  }

  async listTemplateEvents(options?: ListTemplateEventsOptions): Promise<ListTemplateEventsResult> {
    const store = loadStore();
    const filtered = Object.values(store.events).filter((event) => {
      if (options?.activityId && event.activityId !== options.activityId) {
        return false;
      }
      if (options?.unacknowledgedOnly && event.acknowledgedAt != null) {
        return false;
      }
      return true;
    });

    return {
      events: sortEvents(filtered.map((event) => cloneJson(event))),
    };
  }

  async acknowledgeTemplateEvents(options: AcknowledgeTemplateEventsOptions): Promise<void> {
    const store = loadStore();
    const nextEvents = acknowledgeEvents(Object.values(store.events), options);
    store.events = Object.fromEntries(nextEvents.map((event) => [event.eventId, event]));
    saveStore(store);
  }

  async getPluginVersion(): Promise<PluginVersionResult> {
    return {
      version: 'web-preview',
    };
  }
}
