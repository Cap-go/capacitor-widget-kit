import type { StartTemplateActivityOptions, SvgTemplateState } from '../definitions';
import { toJsonObject } from '../runtime';

export interface WorkoutTemplateSet {
  id?: string;
  title: string;
  recommendation?: string | null;
  completedAt?: number | null;
  timerDurationMs?: number | null;
  nextExerciseIndex?: number | null;
  nextSetIndex?: number | null;
}

export interface WorkoutTemplateExercise {
  id: string;
  title: string;
  subtitle?: string;
  sets: WorkoutTemplateSet[];
}

export interface WorkoutTemplateSession {
  sessionId: string;
  title: string;
  startedAt: number;
  activeExerciseIndex?: number | null;
  activeSetIndex?: number | null;
  deepLinkUrl?: string;
  exercises: WorkoutTemplateExercise[];
}

function getCurrentExercise(session: WorkoutTemplateSession): WorkoutTemplateExercise | null {
  if (session.activeExerciseIndex == null) {
    return null;
  }
  return session.exercises[session.activeExerciseIndex] ?? null;
}

function getCurrentSet(session: WorkoutTemplateSession): WorkoutTemplateSet | null {
  const currentExercise = getCurrentExercise(session);
  if (!currentExercise || session.activeSetIndex == null) {
    return null;
  }
  return currentExercise.sets[session.activeSetIndex] ?? null;
}

function createWorkoutTemplateState(session: WorkoutTemplateSession): SvgTemplateState {
  const currentExercise = getCurrentExercise(session);
  const currentSet = getCurrentSet(session);

  return {
    session: toJsonObject(session),
    currentExercise: currentExercise ? toJsonObject(currentExercise) : null,
    currentSet: currentSet ? toJsonObject(currentSet) : null,
    lastCompleted: null,
  };
}

/**
 * Convenience helper that maps the customer workout JSON into the generic SVG activity format.
 *
 * The plugin stays generic. This helper is only an example of how one product flow can be expressed
 * with declarative SVG templates, actions, and timer bindings.
 */
export function createWorkoutTemplateActivity(session: WorkoutTemplateSession): StartTemplateActivityOptions {
  return {
    activityId: session.sessionId,
    openUrl: session.deepLinkUrl,
    state: createWorkoutTemplateState(session),
    definition: {
      id: 'workout-live-activity-example',
      version: '1',
      timers: [
        {
          id: 'rest',
          durationPath: 'state.lastCompleted.timerDurationMs',
        },
      ],
      actions: [
        {
          id: 'complete-set',
          eventName: 'workout.set.completed',
          patches: [
            {
              op: 'set',
              path: 'lastCompleted',
              valuePath: 'state.currentSet',
            },
            {
              op: 'timestamp',
              path: 'session.exercises.{{state.session.activeExerciseIndex}}.sets.{{state.session.activeSetIndex}}.completedAt',
            },
            {
              op: 'set',
              path: 'session.activeExerciseIndex',
              valuePath: 'state.currentSet.nextExerciseIndex',
            },
            {
              op: 'set',
              path: 'session.activeSetIndex',
              valuePath: 'state.currentSet.nextSetIndex',
            },
            {
              op: 'set',
              path: 'currentExercise',
              valuePath: 'state.session.exercises.{{state.session.activeExerciseIndex}}',
            },
            {
              op: 'set',
              path: 'currentSet',
              valuePath: 'state.currentExercise.sets.{{state.session.activeSetIndex}}',
            },
          ],
          timerMutations: [
            {
              op: 'setDuration',
              timerId: 'rest',
              durationPath: 'state.lastCompleted.timerDurationMs',
            },
            {
              op: 'restart',
              timerId: 'rest',
              durationPath: 'state.lastCompleted.timerDurationMs',
            },
          ],
        },
      ],
      layouts: {
        lockScreen: {
          width: 100,
          height: 40,
          hotspots: [
            {
              id: 'complete-button',
              actionId: 'complete-set',
              x: 80,
              y: 24,
              width: 14,
              height: 10,
              label: 'Complete active set',
              role: 'button',
            },
          ],
          svg: `
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 40">
  <rect x="0" y="0" width="100" height="40" rx="6" fill="#05070b" />
  <rect x="0" y="0" width="{{timers.rest.progressPct}}" height="40" rx="6" fill="#00d69c" opacity="0.28" />
  <text x="5" y="8" fill="#9fb0c8" font-size="4">{{state.session.title}}</text>
  <text x="5" y="15" fill="#ffffff" font-size="6" font-weight="700">{{state.currentExercise.title}}</text>
  <text x="5" y="21" fill="#7f8da3" font-size="4">{{state.currentExercise.subtitle}}</text>
  <text x="5" y="31" fill="#ffffff" font-size="7" font-weight="700">{{state.currentSet.title}}</text>
  <text x="78" y="12" fill="#00d69c" font-size="6" font-weight="700">{{timers.rest.remainingText}}</text>
  <rect x="80" y="24" width="14" height="10" rx="3" fill="#00d69c" />
  <text x="85" y="31" fill="#ffffff" font-size="7" font-weight="700">✓</text>
</svg>`.trim(),
        },
      },
    },
  };
}
