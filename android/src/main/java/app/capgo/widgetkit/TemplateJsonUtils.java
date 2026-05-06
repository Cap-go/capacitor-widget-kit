package app.capgo.widgetkit;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

final class TemplateJsonUtils {

    private static final Pattern TOKEN_PATTERN = Pattern.compile("\\{\\{\\s*([^{}]+?)\\s*\\}\\}");
    private static final Pattern EXACT_TOKEN_PATTERN = Pattern.compile("^\\{\\{\\s*([^{}]+?)\\s*\\}\\}$");

    private TemplateJsonUtils() {}

    static JSONObject deepCopyObject(final JSONObject value) throws JSONException {
        return new JSONObject(value.toString());
    }

    static JSONArray deepCopyArray(final JSONArray value) throws JSONException {
        return new JSONArray(value.toString());
    }

    static Object deepCopyValue(final Object value) throws JSONException {
        if (value == null || value == JSONObject.NULL) {
            return JSONObject.NULL;
        }
        if (value instanceof JSONObject object) {
            return deepCopyObject(object);
        }
        if (value instanceof JSONArray array) {
            return deepCopyArray(array);
        }
        return value;
    }

    static boolean isNull(final Object value) {
        return value == null || value == JSONObject.NULL;
    }

    static String stringifyValue(final Object value) throws JSONException {
        if (isNull(value)) {
            return "";
        }
        if (value instanceof String || value instanceof Number || value instanceof Boolean) {
            return String.valueOf(value);
        }
        return JSONObject.wrap(value).toString();
    }

    static List<String> splitPath(final String path) {
        final String[] rawSegments = path.split("\\.");
        final List<String> segments = new ArrayList<>();
        for (String segment : rawSegments) {
            final String trimmed = segment.trim();
            if (!trimmed.isEmpty()) {
                segments.add(trimmed);
            }
        }
        return segments;
    }

    static boolean isIndexSegment(final String segment) {
        return segment.matches("\\d+");
    }

    static Object getValueAtPath(final Object root, final String path) throws JSONException {
        Object current = root;
        for (String segment : splitPath(path)) {
            if (current instanceof JSONObject object) {
                current = object.has(segment) ? object.opt(segment) : null;
                continue;
            }
            if (current instanceof JSONArray array && isIndexSegment(segment)) {
                final int index = Integer.parseInt(segment);
                current = index < array.length() ? array.opt(index) : null;
                continue;
            }
            return null;
        }
        return current;
    }

    static void setValueAtPath(final JSONObject root, final String path, final Object value) throws JSONException {
        final List<String> segments = splitPath(path);
        if (segments.isEmpty()) {
            return;
        }

        Object current = root;
        for (int index = 0; index < segments.size() - 1; index += 1) {
            final String segment = segments.get(index);
            final String nextSegment = segments.get(index + 1);
            current = ensureContainer(current, segment, nextSegment);
        }

        final String lastSegment = segments.get(segments.size() - 1);
        if (current instanceof JSONObject object) {
            object.put(lastSegment, deepCopyValue(value));
        } else if (current instanceof JSONArray array && isIndexSegment(lastSegment)) {
            final int arrayIndex = Integer.parseInt(lastSegment);
            ensureArraySize(array, arrayIndex + 1);
            array.put(arrayIndex, deepCopyValue(value));
        }
    }

    static void deleteValueAtPath(final JSONObject root, final String path) throws JSONException {
        final List<String> segments = splitPath(path);
        if (segments.isEmpty()) {
            return;
        }

        Object current = root;
        for (int index = 0; index < segments.size() - 1; index += 1) {
            final String segment = segments.get(index);
            if (current instanceof JSONObject object) {
                current = object.opt(segment);
                continue;
            }
            if (current instanceof JSONArray array && isIndexSegment(segment)) {
                final int arrayIndex = Integer.parseInt(segment);
                current = arrayIndex < array.length() ? array.opt(arrayIndex) : null;
                continue;
            }
            return;
        }

        final String lastSegment = segments.get(segments.size() - 1);
        if (current instanceof JSONObject object) {
            object.remove(lastSegment);
        } else if (current instanceof JSONArray array && isIndexSegment(lastSegment)) {
            array.remove(Integer.parseInt(lastSegment));
        }
    }

    static Long coerceLong(final Object value) {
        if (value == null || value == JSONObject.NULL) {
            return null;
        }
        if (value instanceof Number number) {
            return Math.round(number.doubleValue());
        }
        if (value instanceof String string && !string.trim().isEmpty()) {
            try {
                return Math.round(Double.parseDouble(string.trim()));
            } catch (NumberFormatException ignored) {
                return null;
            }
        }
        return null;
    }

    static Double coerceDouble(final Object value) {
        if (value == null || value == JSONObject.NULL) {
            return null;
        }
        if (value instanceof Number number) {
            return number.doubleValue();
        }
        if (value instanceof String string && !string.trim().isEmpty()) {
            try {
                return Double.parseDouble(string.trim());
            } catch (NumberFormatException ignored) {
                return null;
            }
        }
        return null;
    }

    static String normalizeStatePath(final String path) {
        return path.startsWith("state.") ? path.substring("state.".length()) : path;
    }

    static Object exactTokenValue(final String template, final JSONObject record, final long nowMs, final JSONObject actionScope)
        throws JSONException {
        final Matcher matcher = EXACT_TOKEN_PATTERN.matcher(template.trim());
        if (!matcher.matches()) {
            return null;
        }
        return resolveReference(matcher.group(1), record, nowMs, actionScope);
    }

    static String resolveTemplateString(final String template, final JSONObject record, final long nowMs, final JSONObject actionScope)
        throws JSONException {
        final Matcher matcher = TOKEN_PATTERN.matcher(template);
        final StringBuffer buffer = new StringBuffer();
        while (matcher.find()) {
            final Object value = resolveReference(matcher.group(1).trim(), record, nowMs, actionScope);
            matcher.appendReplacement(buffer, Matcher.quoteReplacement(stringifyValue(value)));
        }
        matcher.appendTail(buffer);
        return buffer.toString();
    }

    static String resolveRuntimePath(final String path, final JSONObject record, final long nowMs, final JSONObject actionScope)
        throws JSONException {
        return normalizeStatePath(resolveTemplateString(path, record, nowMs, actionScope));
    }

    static JSONObject objectOrEmpty(final JSONObject object, final String key) {
        final JSONObject nested = object.optJSONObject(key);
        return nested != null ? nested : new JSONObject();
    }

    static JSONArray arrayOrEmpty(final JSONObject object, final String key) {
        final JSONArray nested = object.optJSONArray(key);
        return nested != null ? nested : new JSONArray();
    }

    static JSONObject buildMeta(final JSONObject record, final long nowMs) throws JSONException {
        final JSONObject definition = record.getJSONObject("definition");
        final JSONObject template = new JSONObject()
            .put("id", definition.optString("id", record.optString("activityId")))
            .put("version", definition.has("version") ? definition.opt("version") : JSONObject.NULL)
            .put(
                "metadata",
                deepCopyValue(definition.optJSONObject("metadata") != null ? definition.optJSONObject("metadata") : new JSONObject())
            );

        return new JSONObject()
            .put("nowMs", nowMs)
            .put("activityId", record.optString("activityId"))
            .put("status", record.optString("status"))
            .put("openUrl", record.has("openUrl") ? record.opt("openUrl") : JSONObject.NULL)
            .put("revision", record.optInt("revision"))
            .put("updatedAt", record.optLong("updatedAt"))
            .put("template", template);
    }

    static long timerElapsedMs(final JSONObject timer, final long nowMs) {
        final Long savedElapsedMs = coerceLong(timer.opt("elapsedMs"));
        final long elapsedMs = Math.max(0L, savedElapsedMs != null ? savedElapsedMs : 0L);
        final Long durationMs = coerceLong(timer.opt("durationMs"));
        if ("finished".equals(timer.optString("status")) && durationMs != null && durationMs > 0L) {
            return durationMs;
        }

        final Long startedAt = coerceLong(timer.opt("startedAt"));
        if ("running".equals(timer.optString("status")) && startedAt != null) {
            return elapsedMs + Math.max(0L, nowMs - startedAt);
        }
        return elapsedMs;
    }

    static JSONObject buildTimerBinding(final JSONObject timer, final long nowMs) throws JSONException {
        final long durationMs = coerceLong(timer.opt("durationMs")) != null ? coerceLong(timer.opt("durationMs")) : 0L;
        final String status = timerStatus(timer, nowMs);
        final Long startedAt = "running".equals(status) ? coerceLong(timer.opt("startedAt")) : null;
        final long elapsedMs = Math.min(timerElapsedMs(timer, nowMs), durationMs > 0L ? durationMs : Long.MAX_VALUE);
        final long remainingMs = durationMs > 0 ? Math.max(0L, durationMs - elapsedMs) : 0L;
        final double progress = durationMs > 0 ? Math.min(Math.max((double) elapsedMs / (double) durationMs, 0D), 1D) : 0D;
        final int totalSeconds = Math.max(0, (int) Math.ceil((double) remainingMs / 1000D));
        final int minutes = totalSeconds / 60;
        final int seconds = totalSeconds % 60;
        final Long savedElapsedMs = coerceLong(timer.opt("elapsedMs"));

        return new JSONObject()
            .put("id", timer.optString("id"))
            .put("startedAtMs", startedAt == null ? JSONObject.NULL : startedAt)
            .put("durationMs", durationMs)
            .put("status", status)
            .put("elapsedMs", elapsedMs)
            .put("remainingMs", remainingMs)
            .put("progress", progress)
            .put("progressPct", Math.round(progress * 10_000D) / 100D)
            .put("isActive", "running".equals(status))
            .put("isPaused", "paused".equals(status))
            .put("remainingText", String.format(Locale.US, "%d:%02d", minutes, seconds))
            .put(
                "endsAtMs",
                startedAt == null ? JSONObject.NULL : startedAt + Math.max(0L, durationMs - (savedElapsedMs != null ? savedElapsedMs : 0L))
            );
    }

    static JSONObject buildRuntimeScope(final JSONObject record, final long nowMs, final JSONObject actionScope) throws JSONException {
        final JSONObject timers = new JSONObject();
        final JSONObject timerState = objectOrEmpty(record, "timers");
        final Iterator<String> timerKeys = timerState.keys();
        while (timerKeys.hasNext()) {
            final String timerId = timerKeys.next();
            final JSONObject timer = timerState.optJSONObject(timerId);
            if (timer != null) {
                timers.put(timerId, buildTimerBinding(timer, nowMs));
            }
        }

        final JSONObject scope = new JSONObject()
            .put("state", deepCopyObject(record.getJSONObject("state")))
            .put("timers", timers)
            .put("meta", buildMeta(record, nowMs));

        if (actionScope != null) {
            scope.put("action", deepCopyObject(actionScope));
        }

        return scope;
    }

    static Object resolveReference(final String expression, final JSONObject record, final long nowMs, final JSONObject actionScope)
        throws JSONException {
        final JSONObject scope = buildRuntimeScope(record, nowMs, actionScope);
        if (
            expression.startsWith("state.") ||
            expression.startsWith("timers.") ||
            expression.startsWith("meta.") ||
            expression.startsWith("action.")
        ) {
            return getValueAtPath(scope, expression);
        }
        return getValueAtPath(record.getJSONObject("state"), expression);
    }

    static String timerStatus(final JSONObject timer, final long nowMs) {
        final String currentStatus = timer.optString("status", "idle");
        if ("stopped".equals(currentStatus)) {
            return "stopped";
        }

        final long elapsedMs = timerElapsedMs(timer, nowMs);
        final long durationMs = coerceLong(timer.opt("durationMs")) != null ? coerceLong(timer.opt("durationMs")) : 0L;

        if (durationMs <= 0) {
            return "idle";
        }
        if (elapsedMs >= durationMs) {
            return "finished";
        }
        if ("paused".equals(currentStatus)) {
            return "paused";
        }
        if (coerceLong(timer.opt("startedAt")) != null) {
            return "running";
        }
        return elapsedMs > 0L ? "paused" : "idle";
    }

    private static Object ensureContainer(final Object parent, final String segment, final String nextSegment) throws JSONException {
        final boolean createArray = nextSegment != null && isIndexSegment(nextSegment);
        if (parent instanceof JSONObject object) {
            Object child = object.opt(segment);
            if (child == null || child == JSONObject.NULL || (!(child instanceof JSONObject) && !(child instanceof JSONArray))) {
                child = createArray ? new JSONArray() : new JSONObject();
                object.put(segment, child);
            }
            return child;
        }
        if (parent instanceof JSONArray array && isIndexSegment(segment)) {
            final int index = Integer.parseInt(segment);
            ensureArraySize(array, index + 1);
            Object child = array.opt(index);
            if (child == null || child == JSONObject.NULL || (!(child instanceof JSONObject) && !(child instanceof JSONArray))) {
                child = createArray ? new JSONArray() : new JSONObject();
                array.put(index, child);
            }
            return child;
        }
        return new JSONObject();
    }

    private static void ensureArraySize(final JSONArray array, final int size) {
        while (array.length() < size) {
            array.put(JSONObject.NULL);
        }
    }
}
