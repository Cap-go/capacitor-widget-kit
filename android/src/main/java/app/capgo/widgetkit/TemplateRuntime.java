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

        final JSONArray frameMutations = action.optJSONArray("frameMutations");
        if (frameMutations != null) {
            for (int index = 0; index < frameMutations.length(); index += 1) {
                final JSONObject mutation = frameMutations.optJSONObject(index);
                if (mutation != null) {
                    applyFrameMutation(nextActivity, mutation, nowMs, actionScope);
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
        final JSONObject layout = layoutForSurface(layouts, surface);
        if (layout == null) {
            return null;
        }

        final JSONObject resolvedLayout = resolveLayoutFrame(layout, record, nowMs);

        return new JSONObject()
            .put("surface", surface)
            .put("activityId", record.optString("activityId"))
            .put("templateId", record.getJSONObject("definition").optString("id"))
            .put("frameId", resolvedLayout.has("frameId") ? resolvedLayout.opt("frameId") : JSONObject.NULL)
            .put("svg", TemplateJsonUtils.resolveTemplateString(resolvedLayout.optString("svg", ""), record, nowMs, null))
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
                TemplateJsonUtils.deepCopyValue(
                    resolvedLayout.optJSONArray("hotspots") != null ? resolvedLayout.optJSONArray("hotspots") : new JSONArray()
                )
            )
            .put("openUrl", record.has("openUrl") ? record.opt("openUrl") : JSONObject.NULL)
            .put("status", record.optString("status"))
            .put("revision", record.optInt("revision"))
            .put("updatedAt", record.optLong("updatedAt"));
    }

    private static JSONObject resolveLayoutFrame(final JSONObject layout, final JSONObject record, final long nowMs) throws JSONException {
        final JSONArray frames = TemplateJsonUtils.arrayOrEmpty(layout, "frames");
        final String requestedFrameId = resolveFrameId(layout.optString("frameIdPath", null), record, nowMs, null, true);
        final String defaultFrameId = layout.optString("defaultFrameId", null);
        JSONObject selectedFrame = null;

        for (int index = 0; index < frames.length(); index += 1) {
            final JSONObject frame = frames.optJSONObject(index);
            if (frame != null && frame.optString("id").equals(requestedFrameId)) {
                selectedFrame = frame;
                break;
            }
        }
        if (selectedFrame == null && defaultFrameId != null) {
            for (int index = 0; index < frames.length(); index += 1) {
                final JSONObject frame = frames.optJSONObject(index);
                if (frame != null && frame.optString("id").equals(defaultFrameId)) {
                    selectedFrame = frame;
                    break;
                }
            }
        }
        final boolean hasBaseSvg = layout.has("svg") && !layout.isNull("svg");
        if (selectedFrame == null && !hasBaseSvg && frames.length() > 0) {
            selectedFrame = frames.optJSONObject(0);
        }

        final JSONObject resolved = new JSONObject()
            .put("frameId", selectedFrame == null ? JSONObject.NULL : selectedFrame.optString("id"))
            .put("svg", selectedFrame == null ? layout.optString("svg", "") : selectedFrame.optString("svg", layout.optString("svg", "")));
        final JSONArray hotspots =
            selectedFrame != null && selectedFrame.optJSONArray("hotspots") != null
                ? selectedFrame.optJSONArray("hotspots")
                : layout.optJSONArray("hotspots");
        resolved.put("hotspots", hotspots != null ? hotspots : new JSONArray());
        return resolved;
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
            final Long previousStartedAt = TemplateJsonUtils.coerceLong(previousTimer != null ? previousTimer.opt("startedAt") : null);
            final String startAtPath = timerDefinition.optString("startAtPath", "");
            final boolean shouldResolveStartAt = previousTimer == null || (previousStartedAt == null && !startAtPath.isEmpty());
            final Long startedAt =
                previousStartedAt != null
                    ? previousStartedAt
                    : (shouldResolveStartAt ? resolveTimerStartAt(timerDefinition, record, nowMs) : null);
            final String initialStatus =
                previousTimer != null
                    ? previousTimer.optString("status", startedAt == null ? "idle" : "running")
                    : (startedAt == null ? "idle" : "running");
            final Long elapsedMs = TemplateJsonUtils.coerceLong(previousTimer != null ? previousTimer.opt("elapsedMs") : null);

            final JSONObject timer = new JSONObject()
                .put("id", timerId)
                .put("startedAt", startedAt == null ? JSONObject.NULL : startedAt)
                .put("elapsedMs", elapsedMs == null ? 0L : Math.max(0L, elapsedMs))
                .put("durationMs", durationMs)
                .put("status", initialStatus)
                .put("updatedAt", nowMs);
            timer.put("status", TemplateJsonUtils.timerStatus(timer, nowMs));
            if ("finished".equals(timer.optString("status"))) {
                timer.put("startedAt", JSONObject.NULL);
                timer.put("elapsedMs", durationMs);
            }
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

    private static String resolveFrameId(
        final String frameIdTemplate,
        final JSONObject activity,
        final long nowMs,
        final JSONObject actionScope,
        final boolean dereferenceReferences
    ) throws JSONException {
        if (frameIdTemplate == null || frameIdTemplate.isEmpty()) {
            return null;
        }

        final Object exact = TemplateJsonUtils.exactTokenValue(frameIdTemplate, activity, nowMs, actionScope);
        if (exact != null) {
            return TemplateJsonUtils.stringifyValue(exact);
        }

        final String resolved = TemplateJsonUtils.resolveTemplateString(frameIdTemplate, activity, nowMs, actionScope);
        if (dereferenceReferences) {
            final Object referenced = TemplateJsonUtils.resolveReference(resolved, activity, nowMs, actionScope);
            if (referenced != null) {
                return TemplateJsonUtils.stringifyValue(referenced);
            }
        }
        return resolved.isEmpty() ? null : resolved;
    }

    private static JSONArray frameIdsForMutation(final JSONObject activity, final JSONObject mutation) throws JSONException {
        final JSONArray explicitFrameIds = mutation.optJSONArray("frameIds");
        if (explicitFrameIds != null && explicitFrameIds.length() > 0) {
            return explicitFrameIds;
        }

        final String surface = mutation.optString("surface", null);
        if (surface == null || surface.isEmpty()) {
            return new JSONArray();
        }

        final JSONObject layout = layoutForSurface(activity.getJSONObject("definition").getJSONObject("layouts"), surface);
        final JSONArray frames = layout != null ? TemplateJsonUtils.arrayOrEmpty(layout, "frames") : new JSONArray();
        final JSONArray frameIds = new JSONArray();
        for (int index = 0; index < frames.length(); index += 1) {
            final JSONObject frame = frames.optJSONObject(index);
            if (frame != null && !frame.optString("id").isEmpty()) {
                frameIds.put(frame.optString("id"));
            }
        }
        return frameIds;
    }

    private static JSONObject layoutForSurface(final JSONObject layouts, final String surface) {
        final JSONObject layout = layouts.optJSONObject(surface);
        if (layout != null) {
            return layout;
        }
        return "homeScreen".equals(surface) ? layouts.optJSONObject("lockScreen") : null;
    }

    private static int indexOfString(final JSONArray values, final String target) {
        for (int index = 0; index < values.length(); index += 1) {
            if (target.equals(values.optString(index))) {
                return index;
            }
        }
        return -1;
    }

    private static String normalizeFrameMutationId(final String frameId, final JSONArray frameIds) {
        if (frameId == null || frameId.isEmpty()) {
            return null;
        }
        return frameIds.length() == 0 || indexOfString(frameIds, frameId) >= 0 ? frameId : null;
    }

    private static void applyFrameMutation(
        final JSONObject activity,
        final JSONObject mutation,
        final long nowMs,
        final JSONObject actionScope
    ) throws JSONException {
        final String targetPath = TemplateJsonUtils.resolveRuntimePath(mutation.optString("path", ""), activity, nowMs, actionScope);
        if (targetPath.isEmpty()) {
            return;
        }

        final JSONArray frameIds = frameIdsForMutation(activity, mutation);
        final String currentValue = TemplateJsonUtils.stringifyValue(
            TemplateJsonUtils.getValueAtPath(activity.getJSONObject("state"), targetPath)
        );
        final int currentIndex = indexOfString(frameIds, currentValue);
        final boolean wraps = !mutation.has("wrap") || mutation.optBoolean("wrap", true);
        String nextFrameId = null;

        final String operation = mutation.optString("op", "");
        switch (operation) {
            case "set":
                nextFrameId = resolveFrameId(mutation.optString("frameId", null), activity, nowMs, actionScope, false);
                break;
            case "toggle": {
                final String alternateFrameId = resolveFrameId(mutation.optString("frameId", null), activity, nowMs, actionScope, false);
                if (frameIds.length() >= 2) {
                    nextFrameId = currentValue.equals(frameIds.optString(0)) ? frameIds.optString(1) : frameIds.optString(0);
                } else if (alternateFrameId != null) {
                    nextFrameId = currentValue.equals(alternateFrameId) && frameIds.length() > 0 ? frameIds.optString(0) : alternateFrameId;
                }
                break;
            }
            case "next": {
                if (frameIds.length() == 0) {
                    break;
                }
                final int nextIndex = currentIndex < 0 ? 0 : currentIndex + 1;
                nextFrameId =
                    nextIndex < frameIds.length() ? frameIds.optString(nextIndex) : (wraps ? frameIds.optString(0) : currentValue);
                break;
            }
            case "previous": {
                if (frameIds.length() == 0) {
                    break;
                }
                final int nextIndex = currentIndex < 0 ? frameIds.length() - 1 : currentIndex - 1;
                nextFrameId =
                    nextIndex >= 0 ? frameIds.optString(nextIndex) : (wraps ? frameIds.optString(frameIds.length() - 1) : currentValue);
                break;
            }
            default:
                break;
        }

        nextFrameId = normalizeFrameMutationId(nextFrameId, frameIds);
        if (nextFrameId != null && !nextFrameId.isEmpty()) {
            TemplateJsonUtils.setValueAtPath(activity.getJSONObject("state"), targetPath, nextFrameId);
        }
    }

    private static void pauseTimer(final JSONObject timer, final long nowMs) throws JSONException {
        final Long durationMs = TemplateJsonUtils.coerceLong(timer.opt("durationMs"));
        timer.put("elapsedMs", Math.min(durationMs != null ? durationMs : 0L, TemplateJsonUtils.timerElapsedMs(timer, nowMs)));
        timer.put("startedAt", JSONObject.NULL);
        timer.put("status", TemplateJsonUtils.timerStatus(timer, nowMs));
    }

    private static void resumeTimer(final JSONObject timer, final long nowMs) throws JSONException {
        final String status = timer.optString("status");
        if ("stopped".equals(status)) {
            return;
        }
        if (!"paused".equals(status)) {
            timer.put("elapsedMs", 0L);
        }
        final Long durationMs = TemplateJsonUtils.coerceLong(timer.opt("durationMs"));
        timer.put("startedAt", nowMs);
        timer.put("status", durationMs != null && durationMs > 0L ? "running" : "idle");
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
                      .put("elapsedMs", 0L)
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
        timer.put(
            "elapsedMs",
            Math.max(
                0L,
                TemplateJsonUtils.coerceLong(timer.opt("elapsedMs")) != null ? TemplateJsonUtils.coerceLong(timer.opt("elapsedMs")) : 0L
            )
        );
        timer.put("updatedAt", nowMs);

        final String operation = mutation.optString("op", "");
        switch (operation) {
            case "start":
            case "restart":
                timer.put("elapsedMs", 0L);
                timer.put("startedAt", nowMs);
                timer.put("status", durationMs > 0 ? "running" : "idle");
                break;
            case "pause":
                pauseTimer(timer, nowMs);
                break;
            case "resume":
                resumeTimer(timer, nowMs);
                break;
            case "toggle":
                if ("running".equals(TemplateJsonUtils.timerStatus(timer, nowMs))) {
                    pauseTimer(timer, nowMs);
                } else {
                    resumeTimer(timer, nowMs);
                }
                break;
            case "stop":
                timer.put("elapsedMs", 0L);
                timer.put("startedAt", JSONObject.NULL);
                timer.put("status", "stopped");
                break;
            case "reset":
                timer.put("elapsedMs", 0L);
                timer.put("startedAt", JSONObject.NULL);
                timer.put("status", "idle");
                break;
            case "setDuration":
                timer.put("status", TemplateJsonUtils.timerStatus(timer, nowMs));
                break;
            default:
                break;
        }

        timer.put("status", TemplateJsonUtils.timerStatus(timer, nowMs));
        if ("finished".equals(timer.optString("status"))) {
            timer.put("elapsedMs", timer.optLong("durationMs"));
            timer.put("startedAt", JSONObject.NULL);
        }
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
