import './style.css';
import {
  CapgoWidgetKit,
  createWorkoutTemplateActivity,
  resolveTemplateSurface,
} from '@capgo/capacitor-widget-kit';

const app = document.getElementById('app');

app.innerHTML = `
  <main class="shell">
    <section class="hero">
      <p class="eyebrow">Capgo Widget Kit</p>
      <h1>Generic SVG activity engine</h1>
      <p class="lead">
        This demo uses a workout flow as an example helper, but the plugin itself stores generic SVG templates,
        declarative actions, timer bindings, and an event log. The same core runtime can drive any widget flow the
        user wants, while the host widget extension keeps full rendering freedom.
      </p>
      <div class="status-grid status-grid--triple">
        <div class="status-card">
          <span class="label">Native Support</span>
          <strong id="support-badge" class="badge">Checking</strong>
        </div>
        <div class="status-card">
          <span class="label">Activity</span>
          <strong id="activity-badge" class="badge">Not started</strong>
        </div>
        <div class="status-card">
          <span class="label">Events</span>
          <strong id="event-badge" class="badge">0 pending</strong>
        </div>
      </div>
    </section>

    <section class="panel controls">
      <div class="panel-heading">
        <div>
          <p class="eyebrow">Actions</p>
          <h2>Drive the generic template runtime</h2>
        </div>
        <p class="hint">
          The app and the overlay hotspot both call the same declarative action. Every execution is persisted as an
          event so the host app can process the result later.
        </p>
      </div>
      <div class="actions">
        <button id="check-support" class="ghost">Check Support</button>
        <button id="start-activity">Start Demo Template</button>
        <button id="complete-set" class="ghost" disabled>Run Action In App</button>
        <button id="read-store" class="ghost" disabled>Read Stored Activity</button>
        <button id="read-events" class="ghost" disabled>Read Event Log</button>
        <button id="ack-events" class="ghost" disabled>Acknowledge Events</button>
        <button id="end-activity" class="danger" disabled>End Activity</button>
        <button id="plugin-version" class="ghost">Get Plugin Version</button>
      </div>
    </section>

    <section class="workspace">
      <article class="panel preview">
        <div class="panel-heading">
          <div>
            <p class="eyebrow">Preview</p>
            <h2>Resolved SVG template</h2>
          </div>
          <p class="hint preview-hint">
            The SVG is resolved from the generic template plus current state and timer bindings. The overlay hotspot
            uses the same action id that a real WidgetKit button would execute.
          </p>
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
        <div class="event-log">
          <div class="panel-heading panel-heading--compact">
            <div>
              <p class="eyebrow">Events</p>
              <h2>Action log</h2>
            </div>
          </div>
          <ul id="event-list" class="event-list">
            <li class="event-empty">No widget/app actions have been recorded yet.</li>
          </ul>
        </div>
      </article>
    </section>
  </main>
`;

const supportBadge = document.getElementById('support-badge');
const activityBadge = document.getElementById('activity-badge');
const eventBadge = document.getElementById('event-badge');
const preview = document.getElementById('session-preview');
const output = document.getElementById('plugin-output');
const eventList = document.getElementById('event-list');

const completeButton = document.getElementById('complete-set');
const readStoreButton = document.getElementById('read-store');
const readEventsButton = document.getElementById('read-events');
const ackEventsButton = document.getElementById('ack-events');
const endButton = document.getElementById('end-activity');

let currentActivity = null;
let currentEvents = [];

const setOutput = (value) => {
  output.textContent = typeof value === 'string' ? value : JSON.stringify(value, null, 2);
};

const setSupportBadge = ({ supported, reason }) => {
  supportBadge.textContent = supported ? 'Supported' : 'Preview Only';
  supportBadge.dataset.supported = String(supported);
  supportBadge.title = reason ?? '';
};

const setActivityBadge = (activity) => {
  if (!activity || activity.status !== 'active') {
    activityBadge.textContent = 'Not started';
    activityBadge.dataset.active = 'false';
    return;
  }

  activityBadge.textContent = `Active · ${activity.activityId.slice(0, 8)}`;
  activityBadge.dataset.active = 'true';
};

const updateEventBadge = () => {
  const pending = currentEvents.filter((event) => event.acknowledgedAt == null).length;
  eventBadge.textContent = `${pending} pending`;
  eventBadge.dataset.active = String(pending > 0);
};

const updateActionState = () => {
  const active = Boolean(currentActivity && currentActivity.status === 'active');
  const hasActivity = Boolean(currentActivity);
  const hasEvents = currentEvents.length > 0;

  completeButton.disabled = !active;
  readStoreButton.disabled = !hasActivity;
  readEventsButton.disabled = !hasActivity;
  ackEventsButton.disabled = !hasEvents;
  endButton.disabled = !active;
};

const sampleSession = () => ({
  sessionId: 'session-1',
  title: 'Chest Day',
  startedAt: Date.now(),
  activeExerciseIndex: 0,
  activeSetIndex: 0,
  deepLinkUrl: 'widgetkitdemo://session/session-1',
  exercises: [
    {
      id: 'exercise-1',
      title: 'Arnold Press',
      subtitle: 'Dumbbells',
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

const renderEvents = () => {
  if (currentEvents.length === 0) {
    eventList.innerHTML = `<li class="event-empty">No widget/app actions have been recorded yet.</li>`;
    updateEventBadge();
    updateActionState();
    return;
  }

  eventList.innerHTML = currentEvents
    .map((event) => {
      return `
        <li class="event-item" data-pending="${String(event.acknowledgedAt == null)}">
          <div class="event-header">
            <strong>${event.eventName ?? event.actionId}</strong>
            <span>${new Date(event.createdAt).toLocaleTimeString()}</span>
          </div>
          <code>${event.sourceId ? `${event.actionId} · ${event.sourceId}` : event.actionId}</code>
        </li>
      `;
    })
    .join('');

  updateEventBadge();
  updateActionState();
};

const attachPreviewHotspots = () => {
  preview.querySelectorAll('[data-action-id]').forEach((button) => {
    button.addEventListener('click', async () => {
      if (!currentActivity) {
        return;
      }
      try {
        const hotspotPayload = button.dataset.payload
          ? JSON.parse(decodeURIComponent(button.dataset.payload))
          : null;
        const result = await CapgoWidgetKit.performTemplateAction({
          activityId: currentActivity.activityId,
          actionId: button.dataset.actionId,
          sourceId: button.dataset.sourceId,
          payload: {
            source: 'preview-hotspot',
            ...(hotspotPayload ?? {}),
          },
        });
        currentActivity = result.activity;
        currentEvents = [result.event, ...currentEvents];
        setActivityBadge(currentActivity);
        renderPreview();
        renderEvents();
        setOutput(result);
      } catch (error) {
        setOutput(`Error: ${error?.message ?? error}`);
      }
    });
  });
};

const renderPreview = () => {
  if (!currentActivity) {
    preview.innerHTML = `
      <div class="preview-empty">
        <p>No template activity has been started yet.</p>
        <p>Start the demo template to see how a generic SVG definition, action log, and timer bindings fit together.</p>
      </div>
    `;
    updateActionState();
    return;
  }

  const resolvedLayout = resolveTemplateSurface(currentActivity, 'homeScreen');
  if (!resolvedLayout) {
    preview.innerHTML = `
      <div class="preview-empty">
        <p>The home screen surface is missing from this activity.</p>
      </div>
    `;
    updateActionState();
    return;
  }

  const hotspotMarkup = resolvedLayout.hotspots
    .map((hotspot) => {
      const left = (hotspot.x / resolvedLayout.width) * 100;
      const top = (hotspot.y / resolvedLayout.height) * 100;
      const width = (hotspot.width / resolvedLayout.width) * 100;
      const height = (hotspot.height / resolvedLayout.height) * 100;
      return `
        <button
          class="hotspot-button"
          style="left:${left}%;top:${top}%;width:${width}%;height:${height}%;"
          data-action-id="${hotspot.actionId}"
          data-source-id="${hotspot.id}"
          data-payload="${hotspot.payload ? encodeURIComponent(JSON.stringify(hotspot.payload)) : ''}"
          aria-label="${hotspot.label ?? hotspot.actionId}"
          title="${hotspot.label ?? hotspot.actionId}"
        ></button>
      `;
    })
    .join('');

  preview.innerHTML = `
    <div class="preview-card preview-card--generic">
      <div class="preview-meta">
        <span class="summary-label">Template</span>
        <strong>${resolvedLayout.templateId}</strong>
      </div>
      <div class="svg-preview-stage" style="aspect-ratio:${resolvedLayout.width} / ${resolvedLayout.height}">
        <div class="svg-preview-markup">${resolvedLayout.svg}</div>
        ${hotspotMarkup}
      </div>
    </div>
  `;

  attachPreviewHotspots();
  updateActionState();
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

const startTemplate = async () => {
  try {
    const result = await CapgoWidgetKit.startTemplateWidget(createWorkoutTemplateActivity(sampleSession()));
    currentActivity = result.activity;
    currentEvents = [];
    setActivityBadge(currentActivity);
    renderPreview();
    renderEvents();
    setOutput(result);
  } catch (error) {
    setOutput(`Error: ${error?.message ?? error}`);
  }
};

const runActionFromApp = async () => {
  if (!currentActivity) {
    return;
  }

  try {
    const result = await CapgoWidgetKit.performTemplateAction({
      activityId: currentActivity.activityId,
      actionId: 'complete-set',
      sourceId: 'app-complete-set-button',
      payload: {
        source: 'app-button',
      },
    });
    currentActivity = result.activity;
    currentEvents = [result.event, ...currentEvents];
    setActivityBadge(currentActivity);
    renderPreview();
    renderEvents();
    setOutput(result);
  } catch (error) {
    setOutput(`Error: ${error?.message ?? error}`);
  }
};

const readStoredActivity = async () => {
  if (!currentActivity) {
    return;
  }

  try {
    const result = await CapgoWidgetKit.getTemplateActivity({
      activityId: currentActivity.activityId,
    });
    currentActivity = result.activity;
    setActivityBadge(currentActivity);
    renderPreview();
    setOutput(result);
  } catch (error) {
    setOutput(`Error: ${error?.message ?? error}`);
  }
};

const readEvents = async () => {
  if (!currentActivity) {
    return;
  }

  try {
    const result = await CapgoWidgetKit.listTemplateEvents({
      activityId: currentActivity.activityId,
    });
    currentEvents = result.events;
    renderEvents();
    setOutput(result);
  } catch (error) {
    setOutput(`Error: ${error?.message ?? error}`);
  }
};

const acknowledgeEvents = async () => {
  if (!currentActivity) {
    return;
  }

  try {
    await CapgoWidgetKit.acknowledgeTemplateEvents({
      activityId: currentActivity.activityId,
    });
    const refreshed = await CapgoWidgetKit.listTemplateEvents({
      activityId: currentActivity.activityId,
    });
    currentEvents = refreshed.events;
    renderEvents();
    setOutput(refreshed);
  } catch (error) {
    setOutput(`Error: ${error?.message ?? error}`);
  }
};

const endActivity = async () => {
  if (!currentActivity) {
    return;
  }

  try {
    await CapgoWidgetKit.endTemplateActivity({
      activityId: currentActivity.activityId,
      state: currentActivity.state,
    });
    currentActivity = {
      ...currentActivity,
      status: 'ended',
    };
    setActivityBadge(null);
    renderPreview();
    setOutput({ activityId: currentActivity.activityId, ended: true });
  } catch (error) {
    setOutput(`Error: ${error?.message ?? error}`);
  }
};

document.getElementById('check-support').addEventListener('click', checkSupport);
document.getElementById('start-activity').addEventListener('click', startTemplate);
document.getElementById('complete-set').addEventListener('click', runActionFromApp);
document.getElementById('read-store').addEventListener('click', readStoredActivity);
document.getElementById('read-events').addEventListener('click', readEvents);
document.getElementById('ack-events').addEventListener('click', acknowledgeEvents);
document.getElementById('end-activity').addEventListener('click', endActivity);
document.getElementById('plugin-version').addEventListener('click', async () => {
  try {
    const result = await CapgoWidgetKit.getPluginVersion();
    setOutput(result);
  } catch (error) {
    setOutput(`Error: ${error?.message ?? error}`);
  }
});

window.setInterval(() => {
  if (currentActivity) {
    renderPreview();
  }
}, 1000);

renderPreview();
renderEvents();
checkSupport();
