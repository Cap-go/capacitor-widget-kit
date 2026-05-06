import type {
  JsonArray,
  JsonObject,
  JsonValue,
  PerformTemplateActionOptions,
  PerformTemplateActionResult,
  ResolvedSvgTemplateLayout,
  SvgTemplateActionDefinition,
  SvgTemplateActivityRecord,
  SvgTemplateActionEvent,
  SvgTemplateDefinition,
  SvgTemplateFrameMutation,
  SvgTemplateLayout,
  SvgTemplateSurface,
  SvgTemplateState,
  SvgTemplateStatePatch,
  SvgTemplateTimerDefinition,
  SvgTemplateTimerMutation,
  SvgTemplateTimerState,
} from './definitions';

type ActionRuntimeScope = {
  actionId: string;
  sourceId?: string;
  payload?: JsonObject | null;
};

const TOKEN_PATTERN = /{{\s*([^{}]+?)\s*}}/g;
const EXACT_TOKEN_PATTERN = /^{{\s*([^{}]+?)\s*}}$/;

function cloneJson<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

export function toJsonValue<T>(value: T): JsonValue {
  return cloneJson(value) as JsonValue;
}

export function toJsonObject<T extends object>(value: T): JsonObject {
  return cloneJson(value) as JsonObject;
}

function isObject(value: JsonValue | undefined): value is JsonObject {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isArray(value: JsonValue | undefined): value is JsonArray {
  return Array.isArray(value);
}

function isNumber(value: JsonValue | undefined): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

function isBoolean(value: JsonValue | undefined): value is boolean {
  return typeof value === 'boolean';
}

function stringifyValue(value: JsonValue | undefined): string {
  if (value == null) {
    return '';
  }
  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
    return String(value);
  }
  return JSON.stringify(value);
}

function splitPath(path: string): string[] {
  return path
    .split('.')
    .map((segment) => segment.trim())
    .filter(Boolean);
}

function isIndexSegment(segment: string): boolean {
  return /^\d+$/.test(segment);
}

export function getValueAtPath(root: JsonValue | undefined, path: string): JsonValue | undefined {
  const segments = splitPath(path);
  let current: JsonValue | undefined = root;

  for (const segment of segments) {
    if (isObject(current)) {
      current = current[segment];
      continue;
    }

    if (isArray(current) && isIndexSegment(segment)) {
      current = current[Number(segment)];
      continue;
    }

    return undefined;
  }

  return current;
}

function ensureContainer(parent: JsonObject | JsonArray, segment: string, nextSegment?: string): JsonValue {
  const createArray = nextSegment != null && isIndexSegment(nextSegment);

  if (isArray(parent) && isIndexSegment(segment)) {
    const index = Number(segment);
    if (parent[index] == null) {
      parent[index] = createArray ? [] : {};
    }
    return parent[index] as JsonValue;
  }

  if (isObject(parent)) {
    if (parent[segment] == null) {
      parent[segment] = createArray ? [] : {};
    }
    return parent[segment] as JsonValue;
  }

  return {};
}

export function setValueAtPath(root: JsonObject, path: string, value: JsonValue): void {
  const segments = splitPath(path);
  if (segments.length === 0) {
    return;
  }

  let current: JsonObject | JsonArray = root;
  for (let index = 0; index < segments.length - 1; index += 1) {
    const segment = segments[index];
    const next = ensureContainer(current, segment, segments[index + 1]);
    if (!isObject(next) && !isArray(next)) {
      const replacement: JsonValue = isIndexSegment(segments[index + 1]) ? [] : {};
      if (isArray(current) && isIndexSegment(segment)) {
        current[Number(segment)] = replacement;
      } else if (isObject(current)) {
        current[segment] = replacement;
      }
      current = replacement as JsonObject | JsonArray;
    } else {
      current = next;
    }
  }

  const lastSegment = segments[segments.length - 1];
  if (isArray(current) && isIndexSegment(lastSegment)) {
    current[Number(lastSegment)] = cloneJson(value);
    return;
  }
  if (isObject(current)) {
    current[lastSegment] = cloneJson(value);
  }
}

export function deleteValueAtPath(root: JsonObject, path: string): void {
  const segments = splitPath(path);
  if (segments.length === 0) {
    return;
  }

  let current: JsonValue | undefined = root;
  for (let index = 0; index < segments.length - 1; index += 1) {
    const segment = segments[index];
    if (isObject(current)) {
      current = current[segment];
      continue;
    }
    if (isArray(current) && isIndexSegment(segment)) {
      current = current[Number(segment)];
      continue;
    }
    return;
  }

  const lastSegment = segments[segments.length - 1];
  if (isObject(current)) {
    delete current[lastSegment];
  } else if (isArray(current) && isIndexSegment(lastSegment)) {
    current.splice(Number(lastSegment), 1);
  }
}

function coerceInt(value: JsonValue | undefined): number | undefined {
  if (isNumber(value)) {
    return Math.round(value);
  }
  if (typeof value === 'string' && value.trim() !== '') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? Math.round(parsed) : undefined;
  }
  return undefined;
}

function timerElapsedMs(timer: SvgTemplateTimerState, nowMs: number): number {
  const savedElapsedMs = Math.max(0, Math.round(timer.elapsedMs ?? 0));
  if (timer.status === 'finished' && timer.durationMs > 0) {
    return timer.durationMs;
  }
  if (timer.status === 'running' && timer.startedAt != null) {
    return savedElapsedMs + Math.max(0, nowMs - timer.startedAt);
  }
  return savedElapsedMs;
}

function timerStatus(timer: SvgTemplateTimerState, nowMs: number): SvgTemplateTimerState['status'] {
  if (timer.status === 'stopped') {
    return 'stopped';
  }

  const elapsedMs = timerElapsedMs(timer, nowMs);
  if (timer.durationMs <= 0) {
    return 'idle';
  }
  if (elapsedMs >= timer.durationMs) {
    return 'finished';
  }
  if (timer.status === 'paused') {
    return 'paused';
  }
  if (timer.startedAt != null) {
    return 'running';
  }
  return elapsedMs > 0 ? 'paused' : 'idle';
}

function buildTimerBinding(timer: SvgTemplateTimerState, nowMs: number): JsonObject {
  const status = timerStatus(timer, nowMs);
  const startedAt = status === 'running' ? (timer.startedAt ?? null) : null;
  const durationMs = timer.durationMs;
  const elapsedMs = Math.min(timerElapsedMs(timer, nowMs), durationMs > 0 ? durationMs : Number.MAX_SAFE_INTEGER);
  const remainingMs = durationMs > 0 ? Math.max(0, durationMs - elapsedMs) : 0;
  const progress = durationMs > 0 ? Math.min(Math.max(elapsedMs / durationMs, 0), 1) : 0;
  const totalSeconds = Math.max(0, Math.ceil(remainingMs / 1000));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;

  return {
    id: timer.id,
    startedAtMs: startedAt,
    durationMs,
    status,
    elapsedMs,
    remainingMs,
    progress,
    progressPct: Math.round(progress * 10000) / 100,
    isActive: status === 'running',
    isPaused: status === 'paused',
    remainingText: `${minutes}:${String(seconds).padStart(2, '0')}`,
    endsAtMs: startedAt == null ? null : startedAt + Math.max(0, durationMs - (timer.elapsedMs ?? 0)),
  };
}

function buildMeta(activity: SvgTemplateActivityRecord, nowMs: number): JsonObject {
  return {
    nowMs,
    activityId: activity.activityId,
    status: activity.status,
    openUrl: activity.openUrl ?? null,
    revision: activity.revision,
    updatedAt: activity.updatedAt,
    template: {
      id: activity.definition.id,
      version: activity.definition.version ?? null,
      metadata: cloneJson(activity.definition.metadata ?? {}),
    },
  };
}

function buildRuntimeScope(
  activity: SvgTemplateActivityRecord,
  nowMs: number,
  action?: ActionRuntimeScope,
): JsonObject {
  const timers: JsonObject = {};
  for (const [timerId, timerState] of Object.entries(activity.timers)) {
    timers[timerId] = buildTimerBinding(timerState, nowMs);
  }

  const scope: JsonObject = {
    state: cloneJson(activity.state),
    timers,
    meta: buildMeta(activity, nowMs),
  };

  if (action) {
    scope.action = {
      id: action.actionId,
      sourceId: action.sourceId ?? null,
      payload: cloneJson(action.payload ?? null),
    };
  }

  return scope;
}

function normalizeStatePath(path: string): string {
  return path.startsWith('state.') ? path.slice('state.'.length) : path;
}

function resolveReference(
  expression: string,
  activity: SvgTemplateActivityRecord,
  nowMs: number,
  action?: ActionRuntimeScope,
): JsonValue | undefined {
  const scope = buildRuntimeScope(activity, nowMs, action);
  if (
    expression.startsWith('state.') ||
    expression.startsWith('timers.') ||
    expression.startsWith('meta.') ||
    expression.startsWith('action.')
  ) {
    return getValueAtPath(scope, expression);
  }
  return getValueAtPath(activity.state, expression);
}

function exactTokenValue(
  template: string,
  activity: SvgTemplateActivityRecord,
  nowMs: number,
  action?: ActionRuntimeScope,
): JsonValue | undefined {
  const match = template.trim().match(EXACT_TOKEN_PATTERN);
  if (!match) {
    return undefined;
  }
  return resolveReference(match[1], activity, nowMs, action);
}

function resolveTemplateString(
  template: string,
  activity: SvgTemplateActivityRecord,
  nowMs: number,
  action?: ActionRuntimeScope,
): string {
  return template.replace(TOKEN_PATTERN, (_match, expression: string) => {
    return stringifyValue(resolveReference(expression.trim(), activity, nowMs, action));
  });
}

function resolveRuntimePath(
  path: string,
  activity: SvgTemplateActivityRecord,
  nowMs: number,
  action?: ActionRuntimeScope,
): string {
  return normalizeStatePath(resolveTemplateString(path, activity, nowMs, action));
}

function resolveDuration(
  definition: SvgTemplateTimerDefinition,
  activity: SvgTemplateActivityRecord,
  nowMs: number,
): number {
  const explicit = definition.durationMs;
  if (typeof explicit === 'number' && Number.isFinite(explicit)) {
    return Math.max(0, Math.round(explicit));
  }
  if (definition.durationPath) {
    const resolvedValue = resolveReference(
      resolveTemplateString(definition.durationPath, activity, nowMs),
      activity,
      nowMs,
    );
    return Math.max(0, coerceInt(resolvedValue) ?? 0);
  }
  return 0;
}

function resolveStartAt(
  definition: SvgTemplateTimerDefinition,
  activity: SvgTemplateActivityRecord,
  nowMs: number,
): number | null {
  if (definition.startAtPath) {
    const resolvedValue = resolveReference(
      resolveTemplateString(definition.startAtPath, activity, nowMs),
      activity,
      nowMs,
    );
    const startAt = coerceInt(resolvedValue);
    if (typeof startAt === 'number') {
      return startAt;
    }
  }
  if (definition.autoStart) {
    return nowMs;
  }
  return null;
}

export function reconcileTimerStates(
  definition: SvgTemplateDefinition,
  state: SvgTemplateState,
  existing: Record<string, SvgTemplateTimerState> = {},
  activityId = 'preview',
  status: SvgTemplateActivityRecord['status'] = 'active',
  nowMs = Date.now(),
): Record<string, SvgTemplateTimerState> {
  const activity: SvgTemplateActivityRecord = {
    activityId,
    definition,
    state,
    timers: cloneJson(existing),
    status,
    updatedAt: nowMs,
    revision: 0,
  };

  const nextTimers: Record<string, SvgTemplateTimerState> = {};
  for (const timerDefinition of definition.timers ?? []) {
    const previous = existing[timerDefinition.id];
    const durationMs = resolveDuration(timerDefinition, activity, nowMs) || previous?.durationMs || 0;
    const startedAt = previous ? (previous.startedAt ?? null) : resolveStartAt(timerDefinition, activity, nowMs);
    const timer: SvgTemplateTimerState = {
      id: timerDefinition.id,
      startedAt,
      elapsedMs: Math.max(0, Math.round(previous?.elapsedMs ?? 0)),
      durationMs,
      status: previous?.status ?? (startedAt == null ? 'idle' : 'running'),
      updatedAt: nowMs,
    };
    timer.status = timerStatus(timer, nowMs);
    if (timer.status === 'finished') {
      timer.startedAt = null;
      timer.elapsedMs = timer.durationMs;
    }
    nextTimers[timer.id] = timer;
    activity.timers[timer.id] = timer;
  }

  return nextTimers;
}

function resolvePatchValue(
  patch: SvgTemplateStatePatch,
  activity: SvgTemplateActivityRecord,
  nowMs: number,
  action?: ActionRuntimeScope,
): JsonValue {
  if (patch.op === 'timestamp') {
    return nowMs;
  }

  if (patch.valuePath) {
    const resolvedPath = resolveTemplateString(patch.valuePath, activity, nowMs, action);
    return cloneJson(resolveReference(resolvedPath, activity, nowMs, action) ?? null);
  }

  if (patch.valueTemplate) {
    const exact = exactTokenValue(patch.valueTemplate, activity, nowMs, action);
    if (exact !== undefined) {
      return cloneJson(exact);
    }
    return resolveTemplateString(patch.valueTemplate, activity, nowMs, action);
  }

  if (patch.value !== undefined) {
    return cloneJson(patch.value);
  }

  return null;
}

function applyStatePatch(
  activity: SvgTemplateActivityRecord,
  patch: SvgTemplateStatePatch,
  nowMs: number,
  action?: ActionRuntimeScope,
): void {
  const targetPath = resolveRuntimePath(patch.path, activity, nowMs, action);
  if (!targetPath) {
    return;
  }

  switch (patch.op) {
    case 'set':
    case 'timestamp':
      setValueAtPath(activity.state, targetPath, resolvePatchValue(patch, activity, nowMs, action));
      return;
    case 'increment': {
      const current = getValueAtPath(activity.state, targetPath);
      const nextValue = (coerceInt(current) ?? 0) + (patch.amount ?? 1);
      setValueAtPath(activity.state, targetPath, nextValue);
      return;
    }
    case 'toggle': {
      const current = getValueAtPath(activity.state, targetPath);
      setValueAtPath(activity.state, targetPath, !isBoolean(current) ? true : !current);
      return;
    }
    case 'unset':
      deleteValueAtPath(activity.state, targetPath);
      return;
    default:
      return;
  }
}

function findTimerDefinition(
  activity: SvgTemplateActivityRecord,
  timerId: string,
): SvgTemplateTimerDefinition | undefined {
  return activity.definition.timers?.find((candidate) => candidate.id === timerId);
}

function resolveFrameId(
  frameIdTemplate: string | undefined,
  activity: SvgTemplateActivityRecord,
  nowMs: number,
  action?: ActionRuntimeScope,
): string | undefined {
  if (!frameIdTemplate) {
    return undefined;
  }

  const exact = exactTokenValue(frameIdTemplate, activity, nowMs, action);
  if (exact !== undefined) {
    return stringifyValue(exact);
  }

  const resolved = resolveTemplateString(frameIdTemplate, activity, nowMs, action);
  const referenced = resolveReference(resolved, activity, nowMs, action);
  if (referenced !== undefined) {
    return stringifyValue(referenced);
  }
  return resolved || undefined;
}

function frameIdsForMutation(activity: SvgTemplateActivityRecord, mutation: SvgTemplateFrameMutation): string[] {
  if (mutation.frameIds && mutation.frameIds.length > 0) {
    return mutation.frameIds;
  }

  const surface = mutation.surface;
  if (!surface) {
    return [];
  }

  return activity.definition.layouts[surface]?.frames?.map((frame) => frame.id) ?? [];
}

function applyFrameMutation(
  activity: SvgTemplateActivityRecord,
  mutation: SvgTemplateFrameMutation,
  nowMs: number,
  action?: ActionRuntimeScope,
): void {
  const targetPath = resolveRuntimePath(mutation.path, activity, nowMs, action);
  if (!targetPath) {
    return;
  }

  const frameIds = frameIdsForMutation(activity, mutation);
  const currentValue = stringifyValue(getValueAtPath(activity.state, targetPath));
  const currentIndex = frameIds.indexOf(currentValue);
  const wraps = mutation.wrap ?? true;
  let nextFrameId: string | undefined;

  switch (mutation.op) {
    case 'set':
      nextFrameId = resolveFrameId(mutation.frameId, activity, nowMs, action);
      break;
    case 'toggle': {
      const alternateFrameId = resolveFrameId(mutation.frameId, activity, nowMs, action);
      if (frameIds.length >= 2) {
        nextFrameId = currentValue === frameIds[0] ? frameIds[1] : frameIds[0];
      } else if (alternateFrameId) {
        nextFrameId = currentValue === alternateFrameId ? frameIds[0] : alternateFrameId;
      }
      break;
    }
    case 'next': {
      if (frameIds.length === 0) {
        break;
      }
      const nextIndex = currentIndex < 0 ? 0 : currentIndex + 1;
      nextFrameId = frameIds[nextIndex] ?? (wraps ? frameIds[0] : currentValue);
      break;
    }
    case 'previous': {
      if (frameIds.length === 0) {
        break;
      }
      const nextIndex = currentIndex < 0 ? frameIds.length - 1 : currentIndex - 1;
      nextFrameId = frameIds[nextIndex] ?? (wraps ? frameIds[frameIds.length - 1] : currentValue);
      break;
    }
    default:
      break;
  }

  if (nextFrameId) {
    setValueAtPath(activity.state, targetPath, nextFrameId);
  }
}

function pauseTimer(timer: SvgTemplateTimerState, nowMs: number): void {
  timer.elapsedMs = Math.min(timer.durationMs, timerElapsedMs(timer, nowMs));
  timer.startedAt = null;
  timer.status = timerStatus(timer, nowMs);
}

function resumeTimer(timer: SvgTemplateTimerState, nowMs: number): void {
  if (timer.status !== 'paused') {
    timer.elapsedMs = 0;
  }
  timer.startedAt = nowMs;
  timer.status = timer.durationMs > 0 ? 'running' : 'idle';
}

function applyTimerMutation(
  activity: SvgTemplateActivityRecord,
  mutation: SvgTemplateTimerMutation,
  nowMs: number,
  action?: ActionRuntimeScope,
): void {
  const timer = activity.timers[mutation.timerId] ?? {
    id: mutation.timerId,
    startedAt: null,
    elapsedMs: 0,
    durationMs: 0,
    status: 'idle' as const,
    updatedAt: nowMs,
  };

  const timerDefinition = findTimerDefinition(activity, mutation.timerId);
  const activityWithTimer = {
    ...activity,
    timers: {
      ...activity.timers,
      [mutation.timerId]: timer,
    },
  };

  const resolvedDuration =
    mutation.durationMs ??
    (mutation.durationPath
      ? coerceInt(
          resolveReference(
            resolveTemplateString(mutation.durationPath, activityWithTimer, nowMs, action),
            activityWithTimer,
            nowMs,
            action,
          ),
        )
      : undefined) ??
    (timerDefinition ? resolveDuration(timerDefinition, activityWithTimer, nowMs) : undefined) ??
    timer.durationMs;

  timer.durationMs = Math.max(0, Math.round(resolvedDuration));
  timer.elapsedMs = Math.max(0, Math.round(timer.elapsedMs ?? 0));
  timer.updatedAt = nowMs;

  switch (mutation.op) {
    case 'start':
    case 'restart':
      timer.elapsedMs = 0;
      timer.startedAt = nowMs;
      timer.status = timer.durationMs > 0 ? 'running' : 'idle';
      break;
    case 'pause':
      pauseTimer(timer, nowMs);
      break;
    case 'resume':
      resumeTimer(timer, nowMs);
      break;
    case 'toggle':
      if (timerStatus(timer, nowMs) === 'running') {
        pauseTimer(timer, nowMs);
      } else {
        resumeTimer(timer, nowMs);
      }
      break;
    case 'stop':
      timer.elapsedMs = 0;
      timer.startedAt = null;
      timer.status = 'stopped';
      break;
    case 'reset':
      timer.elapsedMs = 0;
      timer.startedAt = null;
      timer.status = 'idle';
      break;
    case 'setDuration':
      timer.status = timerStatus(timer, nowMs);
      break;
    default:
      break;
  }

  timer.status = timerStatus(timer, nowMs);
  if (timer.status === 'finished') {
    timer.elapsedMs = timer.durationMs;
    timer.startedAt = null;
  }
  activity.timers[mutation.timerId] = timer;
}

function resolveLayoutFrame(
  layout: SvgTemplateLayout,
  activity: SvgTemplateActivityRecord,
  nowMs: number,
): { frameId?: string; svg: string; hotspots: SvgTemplateLayout['hotspots'] } {
  const frames = layout.frames ?? [];
  const requestedFrameId = resolveFrameId(layout.frameIdPath, activity, nowMs);
  const selectedFrame =
    frames.find((frame) => frame.id === requestedFrameId) ??
    frames.find((frame) => frame.id === layout.defaultFrameId) ??
    frames[0];

  return {
    frameId: selectedFrame?.id,
    svg: selectedFrame?.svg ?? layout.svg ?? '',
    hotspots: selectedFrame?.hotspots ?? layout.hotspots ?? [],
  };
}

export function resolveSvgLayout(
  layout: SvgTemplateLayout,
  activity: SvgTemplateActivityRecord,
  nowMs = Date.now(),
): string {
  return resolveTemplateString(resolveLayoutFrame(layout, activity, nowMs).svg, activity, nowMs);
}

export function getTemplateLayout(
  activity: SvgTemplateActivityRecord,
  surface: SvgTemplateSurface,
): SvgTemplateLayout | null {
  return activity.definition.layouts[surface] ?? null;
}

export function resolveTemplateSurface(
  activity: SvgTemplateActivityRecord,
  surface: SvgTemplateSurface,
  nowMs = Date.now(),
): ResolvedSvgTemplateLayout | null {
  const layout = getTemplateLayout(activity, surface);
  if (!layout) {
    return null;
  }

  const resolvedFrame = resolveLayoutFrame(layout, activity, nowMs);

  return {
    surface,
    activityId: activity.activityId,
    templateId: activity.definition.id,
    frameId: resolvedFrame.frameId,
    svg: resolveTemplateString(resolvedFrame.svg, activity, nowMs),
    width: layout.width,
    height: layout.height,
    hotspots: cloneJson(resolvedFrame.hotspots ?? []),
    openUrl: activity.openUrl,
    status: activity.status,
    revision: activity.revision,
    updatedAt: activity.updatedAt,
  };
}

export function createTemplateActivityRecord(
  definition: SvgTemplateDefinition,
  state: SvgTemplateState,
  options: {
    activityId?: string;
    openUrl?: string;
    status?: SvgTemplateActivityRecord['status'];
    revision?: number;
    updatedAt?: number;
    timers?: Record<string, SvgTemplateTimerState>;
  } = {},
): SvgTemplateActivityRecord {
  const nowMs = options.updatedAt ?? Date.now();
  return {
    activityId: options.activityId ?? createRuntimeId('activity'),
    definition: cloneJson(definition),
    state: cloneJson(state),
    timers: reconcileTimerStates(
      definition,
      cloneJson(state),
      options.timers,
      options.activityId ?? 'preview',
      options.status ?? 'active',
      nowMs,
    ),
    status: options.status ?? 'active',
    openUrl: options.openUrl,
    updatedAt: nowMs,
    revision: options.revision ?? 1,
  };
}

export function applyTemplateAction(
  activity: SvgTemplateActivityRecord,
  options: PerformTemplateActionOptions,
  nowMs = Date.now(),
): PerformTemplateActionResult {
  const definition: SvgTemplateActionDefinition | undefined = activity.definition.actions?.find(
    (candidate) => candidate.id === options.actionId,
  );

  if (!definition) {
    throw new Error(`Action ${options.actionId} is not defined on template ${activity.definition.id}.`);
  }

  const actionScope: ActionRuntimeScope = {
    actionId: definition.id,
    sourceId: options.sourceId,
    payload: options.payload ?? null,
  };

  const nextActivity = cloneJson(activity);
  for (const patch of definition.patches ?? []) {
    applyStatePatch(nextActivity, patch, nowMs, actionScope);
  }
  for (const mutation of definition.frameMutations ?? []) {
    applyFrameMutation(nextActivity, mutation, nowMs, actionScope);
  }
  for (const mutation of definition.timerMutations ?? []) {
    applyTimerMutation(nextActivity, mutation, nowMs, actionScope);
  }

  nextActivity.timers = reconcileTimerStates(
    nextActivity.definition,
    nextActivity.state,
    nextActivity.timers,
    nextActivity.activityId,
    nextActivity.status,
    nowMs,
  );
  nextActivity.updatedAt = nowMs;
  nextActivity.revision += 1;

  const event: SvgTemplateActionEvent = {
    eventId: createRuntimeId('event'),
    activityId: nextActivity.activityId,
    actionId: definition.id,
    eventName: definition.eventName,
    sourceId: options.sourceId,
    createdAt: nowMs,
    acknowledgedAt: null,
    payload: options.payload ? cloneJson(options.payload) : null,
    state: cloneJson(nextActivity.state),
    timers: cloneJson(nextActivity.timers),
  };

  return {
    activity: nextActivity,
    event,
  };
}

export function acknowledgeEvents(
  events: SvgTemplateActionEvent[],
  options: {
    eventIds?: string[];
    activityId?: string;
    acknowledgedAt?: number;
  },
): SvgTemplateActionEvent[] {
  const acknowledgedAt = options.acknowledgedAt ?? Date.now();
  const eventIds = new Set(options.eventIds ?? []);
  return events.map((event) => {
    const matchesEventId = eventIds.size > 0 && eventIds.has(event.eventId);
    const matchesActivity = options.activityId != null && event.activityId === options.activityId;
    if (!matchesEventId && !matchesActivity) {
      return event;
    }
    return {
      ...event,
      acknowledgedAt,
    };
  });
}

export function createRuntimeId(prefix: string): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Math.random().toString(36).slice(2)}${Date.now().toString(36)}`;
}
