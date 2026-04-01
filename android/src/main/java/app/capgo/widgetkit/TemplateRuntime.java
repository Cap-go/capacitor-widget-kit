package app.capgo.widgetkit;

import java.util.Iterator;
import java.util.UUID;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

final class TemplateRuntime {

    static final class ActionResult {

        final JSONObject activity;
        final JSONObject event;

        ActionResult(final JSONObject activity, final JSONObject event) {
            this.activity = activity;
            this.event = event;
        }
    }

    private TemplateRuntime() {}

    static JSONObject createActivityRecord(
        final String activityId,
        final JSONObject definition,
        final JSONObject state,
        final String openUrl,
        final long nowMs
    ) throws JSONException {
        final JSONObject record = new JSONObject()
            .put("activityId", activityId)
            .put("definition", TemplateJsonUtils.deepCopyObject(definition))
            .put("state", TemplateJsonUtils.deepCopyObject(state))
            .put("timers", new JSONObject())
            .put("status", "active")
            .put("openUrl", openUrl == null ? JSONObject.NULL : openUrl)
            .put("updatedAt", nowMs)
            .put("revision", 1);
        record.put("timers", reconcileTimerStates(record, nowMs));
        return record;
    }

    static JSONObject updateActivity(
        final JSONObject current,
        final JSONObject nextDefinition,
        final JSONObject nextState,
        final String openUrl,
        final long nowMs
    ) throws JSONException {
        final JSONObject updated = TemplateJsonUtils.deepCopyObject(current);
        if (nextDefinition != null) {
            updated.put("definition", TemplateJsonUtils.deepCopyObject(nextDefinition));
        }
        if (nextState != null) {
            updated.put("state", TemplateJsonUtils.deepCopyObject(nextState));
        }
        if (openUrl != null) {
            updated.put("openUrl", openUrl);
        }
        updated.put("updatedAt", nowMs);
        updated.put("revision", updated.optInt("revision") + 1);
        updated.put("timers", reconcileTimerStates(updated, nowMs));
        return updated;
    }

    static JSONObject endActivity(final JSONObject current, final JSONObject finalState, final long nowMs) throws JSONException {
        final JSONObject ended = TemplateJsonUtils.deepCopyObject(current);
        if (finalState != null) {
            ended.put("state", TemplateJsonUtils.deepCopyObject(finalState));
        }
        ended.put("status", "ended");
        ended.put("updatedAt", nowMs);
        ended.put("revision", ended.optInt("revision") + 1);
        ended.put("timers", reconcileTimerStates(ended, nowMs));
        return ended;
    }

    static ActionResult applyAction(
        final String actionId,
        final String sourceId,
        final JSONObject payload,
        final JSONObject current,
        final long nowMs
    ) throws JSONException {
        final JSONObject action = findActionDefinition(current.getJSONObject("definition"), actionId);
        if (action == null) {
            throw new JSONException(
                "Action " + actionId + " is not defined on template " + current.getJSONObject("definition").optString("id")
            );
        }

        final JSONObject nextActivity = TemplateJsonUtils.deepCopyObject(current);
        final JSONObject actionScope = new JSONObject()
            .put("id", actionId)
            .put("sourceId", sourceId == null ? JSONObject.NULL : sourceId)
            .put("payload", payload == null ? JSONObject.NULL : TemplateJsonUtils.deepCopyObject(payload));

        final JSONArray patches = action.optJSONArray("patches");
        if (patches != null) {
            for (int index = 0; index < patches.length(); index += 1) {
                final JSONObject patch = patches.optJSONObject(index);
                if (patch != null) {
                    applyStatePatch(nextActivity, patch, nowMs, actionScope);
                }
            }
        }

        final JSONArray timerMutations = action.optJSONArray("timerMutations");
        if (timerMutations != null) {
            for (int index = 0; index < timerMutations.length(); index += 1) {
                final JSONObject mutation = timerMutations.optJSONObject(index);
                if (mutation != null) {
                    applyTimerMutation(nextActivity, mutation, nowMs, actionScope);
                }
            }
        }

        nextActivity.put("timers", reconcileTimerStates(nextActivity, nowMs));
        nextActivity.put("updatedAt", nowMs);
        nextActivity.put("revision", nextActivity.optInt("revision") + 1);

        final JSONObject event = new JSONObject()
            .put("eventId", createIdentifier("event"))
            .put("activityId", nextActivity.optString("activityId"))
            .put("actionId", actionId)
            .put("eventName", action.has("eventName") ? action.opt("eventName") : JSONObject.NULL)
            .put("sourceId", sourceId == null ? JSONObject.NULL : sourceId)
            .put("createdAt", nowMs)
            .put("acknowledgedAt", JSONObject.NULL)
            .put("payload", payload == null ? JSONObject.NULL : TemplateJsonUtils.deepCopyObject(payload))
            .put("state", TemplateJsonUtils.deepCopyObject(nextActivity.getJSONObject("state")))
            .put("timers", TemplateJsonUtils.deepCopyObject(nextActivity.getJSONObject("timers")));

        return new ActionResult(nextActivity, event);
    }

    static JSONArray acknowledgeEvents(final JSONArray events, final String activityId, final JSONArray eventIds, final long acknowledgedAt)
        throws JSONException {
        final JSONArray nextEvents = new JSONArray();
        for (int index = 0; index < events.length(); index += 1) {
            final JSONObject event = events.optJSONObject(index);
            if (event == null) {
                continue;
            }

            final boolean matchesEventId = eventIds != null && containsString(eventIds, event.optString("eventId"));
            final boolean matchesActivity = activityId != null && activityId.equals(event.optString("activityId"));
            final JSONObject nextEvent = TemplateJsonUtils.deepCopyObject(event);
            if (matchesEventId || matchesActivity) {
                nextEvent.put("acknowledgedAt", acknowledgedAt);
            }
            nextEvents.put(nextEvent);
        }
        return nextEvents;
    }

    static JSONObject resolveSurface(final JSONObject record, final String surface, final long nowMs) throws JSONException {
        final JSONObject layouts = record.getJSONObject("definition").getJSONObject("layouts");
        final JSONObject layout = layouts.optJSONObject(surface);
        if (layout == null) {
            return null;
        }

        return new JSONObject()
            .put("surface", surface)
            .put("activityId", record.optString("activityId"))
            .put("templateId", record.getJSONObject("definition").optString("id"))
            .put("svg", TemplateJsonUtils.resolveTemplateString(layout.optString("svg", ""), record, nowMs, null))
            .put(
                "width",
                TemplateJsonUtils.coerceDouble(layout.opt("width")) != null ? TemplateJsonUtils.coerceDouble(layout.opt("width")) : 1D
            )
            .put(
                "height",
                TemplateJsonUtils.coerceDouble(layout.opt("height")) != null ? TemplateJsonUtils.coerceDouble(layout.opt("height")) : 1D
            )
            .put(
                "hotspots",
                TemplateJsonUtils.deepCopyValue(layout.optJSONArray("hotspots") != null ? layout.optJSONArray("hotspots") : new JSONArray())
            )
            .put("openUrl", record.has("openUrl") ? record.opt("openUrl") : JSONObject.NULL)
            .put("status", record.optString("status"))
            .put("revision", record.optInt("revision"))
            .put("updatedAt", record.optLong("updatedAt"));
    }

    static String createIdentifier(final String prefix) {
        return prefix + "-" + UUID.randomUUID().toString().toLowerCase();
    }

    private static JSONObject reconcileTimerStates(final JSONObject record, final long nowMs) throws JSONException {
        final JSONObject nextTimers = new JSONObject();
        final JSONObject existingTimers = record.optJSONObject("timers") != null ? record.optJSONObject("timers") : new JSONObject();
        final JSONArray timerDefinitions = TemplateJsonUtils.arrayOrEmpty(record.getJSONObject("definition"), "timers");

        for (int index = 0; index < timerDefinitions.length(); index += 1) {
            final JSONObject timerDefinition = timerDefinitions.optJSONObject(index);
            if (timerDefinition == null) {
                continue;
            }

            final String timerId = timerDefinition.optString("id", null);
            if (timerId == null || timerId.isEmpty()) {
                continue;
            }

            final JSONObject previousTimer = existingTimers.optJSONObject(timerId);
            final Long resolvedDuration = resolveTimerDuration(timerDefinition, record, nowMs);
            final long durationMs =
                resolvedDuration != null
                    ? resolvedDuration
                    : TemplateJsonUtils.coerceLong(previousTimer != null ? previousTimer.opt("durationMs") : null) != null
                        ? TemplateJsonUtils.coerceLong(previousTimer.opt("durationMs"))
                        : 0L;
            final Long startedAt =
                previousTimer != null && previousTimer.has("startedAt")
                    ? TemplateJsonUtils.coerceLong(previousTimer.opt("startedAt"))
                    : resolveTimerStartAt(timerDefinition, record, nowMs);
            final String initialStatus =
                previousTimer != null
                    ? previousTimer.optString("status", startedAt == null ? "idle" : "running")
                    : (startedAt == null ? "idle" : "running");

            final JSONObject timer = new JSONObject()
                .put("id", timerId)
                .put("startedAt", startedAt == null ? JSONObject.NULL : startedAt)
                .put("durationMs", durationMs)
                .put("status", initialStatus)
                .put("updatedAt", nowMs);
            timer.put("status", TemplateJsonUtils.timerStatus(timer, nowMs));
            nextTimers.put(timerId, timer);
        }

        return nextTimers;
    }

    private static Long resolveTimerDuration(final JSONObject timerDefinition, final JSONObject record, final long nowMs)
        throws JSONException {
        final Long explicitDuration = TemplateJsonUtils.coerceLong(timerDefinition.opt("durationMs"));
        if (explicitDuration != null) {
            return Math.max(0L, explicitDuration);
        }

        final String durationPath = timerDefinition.optString("durationPath", null);
        if (durationPath != null && !durationPath.isEmpty()) {
            final String resolvedPath = TemplateJsonUtils.resolveTemplateString(durationPath, record, nowMs, null);
            final Long resolvedValue = TemplateJsonUtils.coerceLong(TemplateJsonUtils.resolveReference(resolvedPath, record, nowMs, null));
            return Math.max(0L, resolvedValue != null ? resolvedValue : 0L);
        }

        return null;
    }

    private static Long resolveTimerStartAt(final JSONObject timerDefinition, final JSONObject record, final long nowMs)
        throws JSONException {
        final String startAtPath = timerDefinition.optString("startAtPath", null);
        if (startAtPath != null && !startAtPath.isEmpty()) {
            final String resolvedPath = TemplateJsonUtils.resolveTemplateString(startAtPath, record, nowMs, null);
            final Long resolvedValue = TemplateJsonUtils.coerceLong(TemplateJsonUtils.resolveReference(resolvedPath, record, nowMs, null));
            if (resolvedValue != null) {
                return resolvedValue;
            }
        }

        return timerDefinition.optBoolean("autoStart", false) ? nowMs : null;
    }

    private static void applyStatePatch(final JSONObject activity, final JSONObject patch, final long nowMs, final JSONObject actionScope)
        throws JSONException {
        final String targetPath = TemplateJsonUtils.resolveRuntimePath(patch.optString("path", ""), activity, nowMs, actionScope);
        if (targetPath.isEmpty()) {
            return;
        }

        final JSONObject state = activity.getJSONObject("state");
        final String operation = patch.optString("op", "");
        switch (operation) {
            case "set":
            case "timestamp":
                TemplateJsonUtils.setValueAtPath(state, targetPath, resolvePatchValue(activity, patch, nowMs, actionScope));
                break;
            case "increment":
                final Long currentValue = TemplateJsonUtils.coerceLong(TemplateJsonUtils.getValueAtPath(state, targetPath));
                final long amount =
                    TemplateJsonUtils.coerceLong(patch.opt("amount")) != null ? TemplateJsonUtils.coerceLong(patch.opt("amount")) : 1L;
                TemplateJsonUtils.setValueAtPath(state, targetPath, (currentValue != null ? currentValue : 0L) + amount);
                break;
            case "toggle":
                final Object currentFlag = TemplateJsonUtils.getValueAtPath(state, targetPath);
                final boolean nextValue = !(currentFlag instanceof Boolean && (Boolean) currentFlag);
                TemplateJsonUtils.setValueAtPath(state, targetPath, nextValue);
                break;
            case "unset":
                TemplateJsonUtils.deleteValueAtPath(state, targetPath);
                break;
            default:
                break;
        }
    }

    private static Object resolvePatchValue(
        final JSONObject activity,
        final JSONObject patch,
        final long nowMs,
        final JSONObject actionScope
    ) throws JSONException {
        final String operation = patch.optString("op", "");
        if ("timestamp".equals(operation)) {
            return nowMs;
        }

        final String valuePath = patch.optString("valuePath", null);
        if (valuePath != null && !valuePath.isEmpty()) {
            final String resolvedPath = TemplateJsonUtils.resolveTemplateString(valuePath, activity, nowMs, actionScope);
            return TemplateJsonUtils.deepCopyValue(TemplateJsonUtils.resolveReference(resolvedPath, activity, nowMs, actionScope));
        }

        final String valueTemplate = patch.optString("valueTemplate", null);
        if (valueTemplate != null && !valueTemplate.isEmpty()) {
            final Object exact = TemplateJsonUtils.exactTokenValue(valueTemplate, activity, nowMs, actionScope);
            if (exact != null) {
                return TemplateJsonUtils.deepCopyValue(exact);
            }
            return TemplateJsonUtils.resolveTemplateString(valueTemplate, activity, nowMs, actionScope);
        }

        if (patch.has("value")) {
            return TemplateJsonUtils.deepCopyValue(patch.opt("value"));
        }

        return JSONObject.NULL;
    }

    private static void applyTimerMutation(
        final JSONObject activity,
        final JSONObject mutation,
        final long nowMs,
        final JSONObject actionScope
    ) throws JSONException {
        final String timerId = mutation.optString("timerId", null);
        if (timerId == null || timerId.isEmpty()) {
            return;
        }

        final JSONObject timers = activity.optJSONObject("timers") != null ? activity.optJSONObject("timers") : new JSONObject();
        final JSONObject timer =
            timers.optJSONObject(timerId) != null
                ? TemplateJsonUtils.deepCopyObject(timers.optJSONObject(timerId))
                : new JSONObject()
                      .put("id", timerId)
                      .put("startedAt", JSONObject.NULL)
                      .put("durationMs", 0L)
                      .put("status", "idle")
                      .put("updatedAt", nowMs);

        final Long explicitDuration = TemplateJsonUtils.coerceLong(mutation.opt("durationMs"));
        final Long pathDuration;
        final String durationPath = mutation.optString("durationPath", null);
        if (durationPath != null && !durationPath.isEmpty()) {
            final String resolvedPath = TemplateJsonUtils.resolveTemplateString(durationPath, activity, nowMs, actionScope);
            pathDuration = TemplateJsonUtils.coerceLong(TemplateJsonUtils.resolveReference(resolvedPath, activity, nowMs, actionScope));
        } else {
            pathDuration = null;
        }
        final JSONObject timerDefinition = findTimerDefinition(activity.getJSONObject("definition"), timerId);
        final Long definitionDuration = timerDefinition != null ? resolveTimerDuration(timerDefinition, activity, nowMs) : null;
        final Long existingDuration = TemplateJsonUtils.coerceLong(timer.opt("durationMs"));
        final long durationMs =
            explicitDuration != null
                ? explicitDuration
                : pathDuration != null
                    ? pathDuration
                    : definitionDuration != null
                        ? definitionDuration
                        : existingDuration != null
                            ? existingDuration
                            : 0L;

        timer.put("durationMs", Math.max(0L, durationMs));
        timer.put("updatedAt", nowMs);

        final String operation = mutation.optString("op", "");
        switch (operation) {
            case "start":
            case "restart":
                timer.put("startedAt", nowMs);
                timer.put("status", durationMs > 0 ? "running" : "idle");
                break;
            case "stop":
                timer.put("startedAt", JSONObject.NULL);
                timer.put("status", "stopped");
                break;
            case "setDuration":
                timer.put("status", TemplateJsonUtils.timerStatus(timer, nowMs));
                break;
            default:
                break;
        }

        timer.put("status", TemplateJsonUtils.timerStatus(timer, nowMs));
        timers.put(timerId, timer);
        activity.put("timers", timers);
    }

    private static JSONObject findActionDefinition(final JSONObject definition, final String actionId) {
        final JSONArray actions = TemplateJsonUtils.arrayOrEmpty(definition, "actions");
        for (int index = 0; index < actions.length(); index += 1) {
            final JSONObject action = actions.optJSONObject(index);
            if (action != null && actionId.equals(action.optString("id"))) {
                return action;
            }
        }
        return null;
    }

    private static JSONObject findTimerDefinition(final JSONObject definition, final String timerId) {
        final JSONArray timers = TemplateJsonUtils.arrayOrEmpty(definition, "timers");
        for (int index = 0; index < timers.length(); index += 1) {
            final JSONObject timer = timers.optJSONObject(index);
            if (timer != null && timerId.equals(timer.optString("id"))) {
                return timer;
            }
        }
        return null;
    }

    private static boolean containsString(final JSONArray values, final String target) {
        for (int index = 0; index < values.length(); index += 1) {
            if (target.equals(values.optString(index))) {
                return true;
            }
        }
        return false;
    }
}
