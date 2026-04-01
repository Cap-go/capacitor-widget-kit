import './style.css';
import { CapgoWidgetKit } from '@capgo/capacitor-widget-kit';

const app = document.getElementById('app');

app.innerHTML = `
  <main class="shell">
    <section class="hero">
      <p class="eyebrow">Capgo Widget Kit</p>
      <h1>Workout live activity reference app</h1>
      <p class="lead">
        This demo uses the same workout JSON shape discussed with the customer.
        In the browser it runs through the plugin's preview store. On iOS the same buttons drive
        the native ActivityKit implementation and the Widget Extension view shipped by the plugin.
      </p>
      <div class="status-grid">
        <div class="status-card">
          <span class="label">Native Support</span>
          <strong id="support-badge" class="badge">Checking</strong>
        </div>
        <div class="status-card">
          <span class="label">Activity</span>
          <strong id="activity-badge" class="badge">Not started</strong>
        </div>
      </div>
    </section>

    <section class="panel controls">
      <div class="panel-heading">
        <div>
          <p class="eyebrow">Actions</p>
          <h2>Drive the session lifecycle</h2>
        </div>
        <p class="hint">
          The green complete button inside the real live activity uses the same mutation as the
          "Complete Set In App" button below.
        </p>
      </div>
      <div class="actions">
        <button id="check-support" class="ghost">Check Support</button>
        <button id="start-activity">Start Demo Activity</button>
        <button id="complete-set" class="ghost" disabled>Complete Set In App</button>
        <button id="read-store" class="ghost" disabled>Read Shared Session</button>
        <button id="end-activity" class="danger" disabled>End Activity</button>
        <button id="plugin-version" class="ghost">Get Plugin Version</button>
      </div>
    </section>

    <section class="workspace">
      <article class="panel preview">
        <div class="panel-heading">
          <div>
            <p class="eyebrow">Preview</p>
            <h2>Current workout snapshot</h2>
          </div>
        </div>
        <div id="session-preview" class="phone-preview"></div>
      </article>

      <article class="panel output-panel">
        <div class="panel-heading">
          <div>
            <p class="eyebrow">Payload</p>
            <h2>Plugin response</h2>
          </div>
        </div>
        <pre id="plugin-output">Waiting for interaction…</pre>
      </article>
    </section>
  </main>
`;

const supportBadge = document.getElementById('support-badge');
const activityBadge = document.getElementById('activity-badge');
const preview = document.getElementById('session-preview');
const output = document.getElementById('plugin-output');

const startButton = document.getElementById('start-activity');
const completeButton = document.getElementById('complete-set');
const readStoreButton = document.getElementById('read-store');
const endButton = document.getElementById('end-activity');

let currentActivityId = null;
let currentSession = null;

const setOutput = (value) => {
  output.textContent = typeof value === 'string' ? value : JSON.stringify(value, null, 2);
};

const setSupportBadge = ({ supported, reason }) => {
  supportBadge.textContent = supported ? 'Supported' : 'Preview Only';
  supportBadge.dataset.supported = String(supported);
  supportBadge.title = reason ?? '';
};

const setActivityBadge = (activityId) => {
  activityBadge.textContent = activityId ? `Active · ${activityId.slice(0, 8)}` : 'Not started';
  activityBadge.dataset.active = String(Boolean(activityId));
};

const updateActionState = () => {
  const active = Boolean(currentActivityId && currentSession);
  completeButton.disabled = !active;
  readStoreButton.disabled = !currentSession;
  endButton.disabled = !active;
};

const sampleSession = () => ({
  sessionId: 'session-1',
  title: 'Chest Day',
  startedAt: Date.now(),
  activeExerciseIndex: 0,
  activeSetIndex: 0,
  deepLinkUrl: 'widgetkitdemo://session/session-1',
  timerNotifications: {
    enabled: true,
    title: 'Rest timer finished',
    body: 'Time for the next set.',
  },
  sessionNotifications: {
    enabled: false,
  },
  exercises: [
    {
      id: 'exercise-1',
      title: 'Arnold Press',
      subtitle: 'Dumbbells',
      iconSystemName: 'figure.strengthtraining.traditional',
      sets: [
        {
          id: 'exercise-1-set-1',
          title: '32 kg · 10 reps',
          recommendation: 'Try 34 kg next time',
          completedAt: null,
          timerDurationMs: 90000,
          nextExerciseIndex: 0,
          nextSetIndex: 1,
        },
        {
          id: 'exercise-1-set-2',
          title: '32 kg · 8 reps',
          recommendation: null,
          completedAt: null,
          timerDurationMs: null,
          nextExerciseIndex: 1,
          nextSetIndex: 0,
        },
      ],
    },
    {
      id: 'exercise-2',
      title: 'Bench Press',
      subtitle: 'Barbell',
      iconSystemName: 'bolt.heart.fill',
      sets: [
        {
          id: 'exercise-2-set-1',
          title: '80 kg · 8 reps',
          recommendation: 'Pause 1s at the bottom',
          completedAt: null,
          timerDurationMs: 60000,
          nextExerciseIndex: 1,
          nextSetIndex: 1,
        },
        {
          id: 'exercise-2-set-2',
          title: '80 kg · 7 reps',
          recommendation: null,
          completedAt: null,
          timerDurationMs: null,
          nextExerciseIndex: null,
          nextSetIndex: null,
        },
      ],
    },
  ],
});

const renderPreview = (session) => {
  if (!session) {
    preview.innerHTML = `
      <div class="preview-empty">
        <p>No session has been started yet.</p>
        <p>Start the demo activity to see the same JSON the native widget will render.</p>
      </div>
    `;
    return;
  }

  const activeExercise = session.activeExerciseIndex == null ? null : session.exercises[session.activeExerciseIndex];
  const activeSet =
    activeExercise && session.activeSetIndex != null ? activeExercise.sets[session.activeSetIndex] : null;

  const indicatorMarkup = session.exercises
    .map((exercise, exerciseIndex) => {
      if (exerciseIndex === session.activeExerciseIndex) {
        return `
          <div class="set-track">
            ${exercise.sets
              .map((set, setIndex) => {
                const state = set.completedAt
                  ? 'done'
                  : setIndex === session.activeSetIndex
                    ? 'active'
                    : 'todo';
                return `<span class="set-dot" data-state="${state}"></span>`;
              })
              .join('')}
          </div>
        `;
      }

      const exerciseDone =
        session.activeExerciseIndex == null
          ? true
          : exerciseIndex < session.activeExerciseIndex || exercise.sets.every((set) => set.completedAt);

      return `<span class="exercise-bar" data-done="${String(exerciseDone)}"></span>`;
    })
    .join('');

  const setsMarkup = session.exercises
    .map((exercise, exerciseIndex) => {
      return `
        <article class="exercise-card" data-active="${String(exerciseIndex === session.activeExerciseIndex)}">
          <header>
            <div>
              <h3>${exercise.title}</h3>
              <p>${exercise.subtitle ?? 'No subtitle'}</p>
            </div>
          </header>
          <ul class="set-list">
            ${exercise.sets
              .map((set, setIndex) => {
                const state = set.completedAt
                  ? 'done'
                  : exerciseIndex === session.activeExerciseIndex && setIndex === session.activeSetIndex
                    ? 'active'
                    : 'todo';
                return `
                  <li data-state="${state}">
                    <span>${set.title}</span>
                    <strong>${set.recommendation ?? 'No note'}</strong>
                  </li>
                `;
              })
              .join('')}
          </ul>
        </article>
      `;
    })
    .join('');

  preview.innerHTML = `
    <div class="preview-card">
      <div class="indicator-row">${indicatorMarkup}</div>
      <div class="preview-summary">
        <div>
          <p class="summary-label">${session.title}</p>
          <h3>${activeExercise?.title ?? 'Workout completed'}</h3>
          <p>${activeExercise?.subtitle ?? 'All sets completed'}</p>
        </div>
        <div class="summary-pill">${activeSet?.title ?? 'Finished'}</div>
      </div>
      <div class="exercise-grid">${setsMarkup}</div>
    </div>
  `;
};

const checkSupport = async () => {
  try {
    const result = await CapgoWidgetKit.areActivitiesSupported();
    setSupportBadge(result);
    setOutput(result);
  } catch (error) {
    setOutput(`Error: ${error?.message ?? error}`);
  }
};

const startActivity = async () => {
  try {
    currentSession = sampleSession();
    const result = await CapgoWidgetKit.startWorkoutLiveActivity({ session: currentSession });
    currentActivityId = result.activityId;
    setActivityBadge(currentActivityId);
    updateActionState();
    renderPreview(currentSession);
    setOutput(result);
  } catch (error) {
    setOutput(`Error: ${error?.message ?? error}`);
  }
};

const completeSetInApp = async () => {
  if (!currentSession || !currentActivityId) {
    return;
  }

  try {
    const result = await CapgoWidgetKit.completeWorkoutSet({
      sessionId: currentSession.sessionId,
      activityId: currentActivityId,
    });
    currentSession = result.session;
    renderPreview(currentSession);
    setOutput(result);
  } catch (error) {
    setOutput(`Error: ${error?.message ?? error}`);
  }
};

const readSharedStore = async () => {
  if (!currentSession) {
    return;
  }

  try {
    const result = await CapgoWidgetKit.getStoredWorkoutSession({
      sessionId: currentSession.sessionId,
    });
    currentSession = result.session;
    renderPreview(currentSession);
    setOutput(result);
  } catch (error) {
    setOutput(`Error: ${error?.message ?? error}`);
  }
};

const endActivity = async () => {
  if (!currentActivityId) {
    return;
  }

  try {
    await CapgoWidgetKit.endWorkoutLiveActivity({
      activityId: currentActivityId,
      session: currentSession,
    });
    setOutput({ activityId: currentActivityId, ended: true });
    currentActivityId = null;
    setActivityBadge(null);
    updateActionState();
  } catch (error) {
    setOutput(`Error: ${error?.message ?? error}`);
  }
};

document.getElementById('check-support').addEventListener('click', checkSupport);
document.getElementById('start-activity').addEventListener('click', startActivity);
document.getElementById('complete-set').addEventListener('click', completeSetInApp);
document.getElementById('read-store').addEventListener('click', readSharedStore);
document.getElementById('end-activity').addEventListener('click', endActivity);
document.getElementById('plugin-version').addEventListener('click', async () => {
  try {
    const result = await CapgoWidgetKit.getPluginVersion();
    setOutput(result);
  } catch (error) {
    setOutput(`Error: ${error?.message ?? error}`);
  }
});

updateActionState();
renderPreview(null);
checkSupport();
