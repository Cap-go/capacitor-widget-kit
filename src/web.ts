import { WebPlugin } from '@capacitor/core';

import type {
  AcknowledgeTemplateEventsOptions,
  AcknowledgeWidgetMessagesOptions,
  ActivitiesSupportedResult,
  CapgoWidgetKitPlugin,
  CompleteWidgetMessageOptions,
  EndTemplateActivityOptions,
  GetTemplateActivityOptions,
  GetWidgetSessionOptions,
  JsonObject,
  ListTemplateActivitiesResult,
  ListTemplateEventsOptions,
  ListTemplateEventsResult,
  ListWidgetMessagesOptions,
  ListWidgetMessagesResult,
  ListWidgetSessionsResult,
  PerformTemplateActionOptions,
  PerformTemplateActionResult,
  PluginVersionResult,
  SendWidgetMessageOptions,
  StartTemplateActivityOptions,
  StartTemplateActivityResult,
  StartWidgetSessionOptions,
  StartWidgetSessionResult,
  StopWidgetSessionOptions,
  SvgTemplateActionEvent,
  SvgTemplateActivityRecord,
  TemplateActivityResult,
  UpdateTemplateActivityOptions,
  UpdateWidgetSessionOptions,
  WidgetBridgeMessage,
  SendWidgetMessageResult,
  WidgetMessageResult,
  WidgetSessionRecord,
  WidgetSessionResult,
} from './definitions';
import {
  acknowledgeEvents,
  applyTemplateAction,
  createRuntimeId,
  createTemplateActivityRecord,
  reconcileTimerStates,
} from './runtime';

type WebStore = {
  activities: Record<string, SvgTemplateActivityRecord>;
  events: Record<string, SvgTemplateActionEvent>;
  sessions: Record<string, WidgetSessionRecord>;
  messages: Record<string, WidgetBridgeMessage>;
};

const STORE_KEY = 'capgo-widget-kit-preview-store-v2';

function cloneJson<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

function loadStore(): WebStore {
  if (typeof localStorage === 'undefined') {
    return { activities: {}, events: {}, sessions: {}, messages: {} };
  }

  const raw = localStorage.getItem(STORE_KEY);
  if (!raw) {
    return { activities: {}, events: {}, sessions: {}, messages: {} };
  }

  try {
    const parsed = JSON.parse(raw) as WebStore;
    return {
      activities: parsed.activities ?? {},
      events: parsed.events ?? {},
      sessions: parsed.sessions ?? {},
      messages: parsed.messages ?? {},
    };
  } catch {
    return { activities: {}, events: {}, sessions: {}, messages: {} };
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

function sortSessions(sessions: WidgetSessionRecord[]): WidgetSessionRecord[] {
  return sessions.sort((left, right) => right.updatedAt - left.updatedAt);
}

function sortMessages(messages: WidgetBridgeMessage[]): WidgetBridgeMessage[] {
  return messages.sort((left, right) => right.createdAt - left.createdAt);
}

function mergeJsonObject(base: JsonObject, patch: JsonObject): JsonObject {
  const merged = cloneJson(base);
  for (const [key, value] of Object.entries(patch)) {
    const current = merged[key];
    if (
      current &&
      typeof current === 'object' &&
      !Array.isArray(current) &&
      value &&
      typeof value === 'object' &&
      !Array.isArray(value)
    ) {
      merged[key] = mergeJsonObject(current as JsonObject, value as JsonObject);
    } else {
      merged[key] = cloneJson(value);
    }
  }
  return merged;
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

  async startWidgetSession(options: StartWidgetSessionOptions): Promise<StartWidgetSessionResult> {
    const store = loadStore();
    const now = Date.now();
    const widgetId = options.widgetId && options.widgetId.length > 0 ? options.widgetId : createRuntimeId('widget');
    const session: WidgetSessionRecord = {
      widgetId,
      kind: options.kind,
      state: cloneJson(options.state ?? {}),
      metadata: cloneJson(options.metadata ?? {}),
      status: 'active',
      createdAt: now,
      updatedAt: now,
      revision: 1,
    };
    store.sessions[widgetId] = session;
    saveStore(store);
    return { session: cloneJson(session) };
  }

  async updateWidgetSession(options: UpdateWidgetSessionOptions): Promise<WidgetSessionResult> {
    const store = loadStore();
    const current = store.sessions[options.widgetId];
    if (!current) {
      return { session: null };
    }

    const nextSession: WidgetSessionRecord = {
      ...cloneJson(current),
      state:
        options.state == null
          ? cloneJson(current.state)
          : options.merge
            ? mergeJsonObject(current.state, options.state)
            : cloneJson(options.state),
      metadata:
        options.metadata == null
          ? cloneJson(current.metadata ?? {})
          : options.merge
            ? mergeJsonObject(current.metadata ?? {}, options.metadata)
            : cloneJson(options.metadata),
      status: 'active',
      updatedAt: Date.now(),
      revision: current.revision + 1,
    };
    store.sessions[nextSession.widgetId] = nextSession;
    saveStore(store);
    return { session: cloneJson(nextSession) };
  }

  async stopWidgetSession(options: StopWidgetSessionOptions): Promise<void> {
    const store = loadStore();
    const current = store.sessions[options.widgetId];
    if (!current) {
      return;
    }

    const nextSession: WidgetSessionRecord = {
      ...cloneJson(current),
      state: cloneJson(options.state ?? current.state),
      status: 'stopped',
      updatedAt: Date.now(),
      revision: current.revision + 1,
    };
    store.sessions[nextSession.widgetId] = nextSession;
    saveStore(store);
  }

  async getWidgetSession(options: GetWidgetSessionOptions): Promise<WidgetSessionResult> {
    const store = loadStore();
    const session = store.sessions[options.widgetId];
    return { session: session ? cloneJson(session) : null };
  }

  async listWidgetSessions(): Promise<ListWidgetSessionsResult> {
    const store = loadStore();
    return { sessions: sortSessions(Object.values(store.sessions).map((session) => cloneJson(session))) };
  }

  async sendWidgetMessage(options: SendWidgetMessageOptions): Promise<SendWidgetMessageResult> {
    const store = loadStore();
    const now = Date.now();
    const message: WidgetBridgeMessage = {
      messageId: createRuntimeId('message'),
      widgetId: options.widgetId,
      direction: options.direction ?? 'appToWidget',
      name: options.name,
      payload: options.payload ? cloneJson(options.payload) : null,
      expectsResponse: options.expectsResponse ?? false,
      status: 'pending',
      createdAt: now,
      acknowledgedAt: null,
      completedAt: null,
      response: null,
      error: null,
    };
    store.messages[message.messageId] = message;
    saveStore(store);
    return { message: cloneJson(message) };
  }

  async listWidgetMessages(options?: ListWidgetMessagesOptions): Promise<ListWidgetMessagesResult> {
    const store = loadStore();
    const messages = Object.values(store.messages).filter((message) => {
      if (options?.widgetId && message.widgetId !== options.widgetId) {
        return false;
      }
      if (options?.direction && message.direction !== options.direction) {
        return false;
      }
      if (options?.unacknowledgedOnly && message.acknowledgedAt != null) {
        return false;
      }
      if (options?.pendingOnly && message.status !== 'pending') {
        return false;
      }
      return true;
    });

    return { messages: sortMessages(messages.map((message) => cloneJson(message))) };
  }

  async acknowledgeWidgetMessages(options: AcknowledgeWidgetMessagesOptions): Promise<void> {
    const store = loadStore();
    const now = Date.now();
    const messageIds = new Set(options.messageIds ?? []);
    for (const message of Object.values(store.messages)) {
      const matchesMessageId = messageIds.size > 0 && messageIds.has(message.messageId);
      const matchesWidget = options.widgetId != null && message.widgetId === options.widgetId;
      const matchesDirection = !options.direction || message.direction === options.direction;
      if ((matchesMessageId || matchesWidget) && matchesDirection) {
        message.acknowledgedAt = now;
      }
    }
    saveStore(store);
  }

  async completeWidgetMessage(options: CompleteWidgetMessageOptions): Promise<WidgetMessageResult> {
    const store = loadStore();
    const message = store.messages[options.messageId];
    if (!message) {
      return { message: null };
    }
    if (message.status !== 'pending' || message.completedAt != null) {
      return { message: cloneJson(message) };
    }

    const nextMessage: WidgetBridgeMessage = {
      ...cloneJson(message),
      status: options.error ? 'failed' : 'completed',
      completedAt: Date.now(),
      response: options.response ? cloneJson(options.response) : null,
      error: options.error ?? null,
    };
    store.messages[nextMessage.messageId] = nextMessage;
    saveStore(store);
    return { message: cloneJson(nextMessage) };
  }

  async getPluginVersion(): Promise<PluginVersionResult> {
    return {
      version: 'web-preview',
    };
  }
}
