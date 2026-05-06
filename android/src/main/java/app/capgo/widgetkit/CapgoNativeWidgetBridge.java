package app.capgo.widgetkit;

import android.content.Context;
import android.content.SharedPreferences;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public class CapgoNativeWidgetBridge {

    public static final String DIRECTION_APP_TO_WIDGET = "appToWidget";
    public static final String DIRECTION_WIDGET_TO_APP = "widgetToApp";

    private static final String SESSION_IDS_KEY = "nativeSessionIds";
    private static final String MESSAGE_IDS_KEY = "nativeMessageIds";

    private final SharedPreferences preferences;

    public CapgoNativeWidgetBridge(final Context context) {
        preferences = context.getApplicationContext().getSharedPreferences(CapgoWidgetKitConstants.PREFS_NAME, Context.MODE_PRIVATE);
    }

    public JSONObject startSession(final String requestedWidgetId, final String kind, final JSONObject state, final JSONObject metadata)
        throws JSONException {
        final long nowMs = System.currentTimeMillis();
        final String widgetId =
            requestedWidgetId != null && !requestedWidgetId.isEmpty() ? requestedWidgetId : TemplateRuntime.createIdentifier("widget");
        final JSONObject session = new JSONObject()
            .put("widgetId", widgetId)
            .put("kind", kind == null ? JSONObject.NULL : kind)
            .put("state", TemplateJsonUtils.deepCopyValue(state != null ? state : new JSONObject()))
            .put("metadata", TemplateJsonUtils.deepCopyValue(metadata != null ? metadata : new JSONObject()))
            .put("status", "active")
            .put("createdAt", nowMs)
            .put("updatedAt", nowMs)
            .put("revision", 1);
        saveSession(session);
        return session;
    }

    public JSONObject updateSession(final String widgetId, final JSONObject state, final JSONObject metadata, final boolean merge)
        throws JSONException {
        final JSONObject session = loadSession(widgetId);
        if (session == null) {
            return null;
        }

        if (state != null) {
            session.put("state", merge ? mergeObjects(session.optJSONObject("state"), state) : TemplateJsonUtils.deepCopyObject(state));
        }
        if (metadata != null) {
            session.put(
                "metadata",
                merge ? mergeObjects(session.optJSONObject("metadata"), metadata) : TemplateJsonUtils.deepCopyObject(metadata)
            );
        }
        session.put("status", "active");
        session.put("updatedAt", System.currentTimeMillis());
        session.put("revision", session.optInt("revision") + 1);
        saveSession(session);
        return session;
    }

    public void stopSession(final String widgetId, final JSONObject state) throws JSONException {
        final JSONObject session = loadSession(widgetId);
        if (session == null) {
            return;
        }
        if (state != null) {
            session.put("state", TemplateJsonUtils.deepCopyObject(state));
        }
        session.put("status", "stopped");
        session.put("updatedAt", System.currentTimeMillis());
        session.put("revision", session.optInt("revision") + 1);
        saveSession(session);
    }

    public JSONObject loadSession(final String widgetId) throws JSONException {
        final String raw = preferences.getString(sessionKey(widgetId), null);
        return raw == null ? null : new JSONObject(raw);
    }

    public JSONArray listSessions() throws JSONException {
        final List<JSONObject> sessions = new ArrayList<>();
        for (String widgetId : listIds(SESSION_IDS_KEY)) {
            final JSONObject session = loadSession(widgetId);
            if (session != null) {
                sessions.add(session);
            }
        }
        sessions.sort((left, right) -> Long.compare(right.optLong("updatedAt"), left.optLong("updatedAt")));
        final JSONArray result = new JSONArray();
        for (JSONObject session : sessions) {
            result.put(session);
        }
        return result;
    }

    public JSONObject sendMessage(
        final String widgetId,
        final String direction,
        final String name,
        final JSONObject payload,
        final boolean expectsResponse
    ) throws JSONException {
        final long nowMs = System.currentTimeMillis();
        final JSONObject message = new JSONObject()
            .put("messageId", TemplateRuntime.createIdentifier("message"))
            .put("widgetId", widgetId)
            .put("direction", normalizeDirection(direction))
            .put("name", name)
            .put("payload", payload == null ? JSONObject.NULL : TemplateJsonUtils.deepCopyObject(payload))
            .put("expectsResponse", expectsResponse)
            .put("status", "pending")
            .put("createdAt", nowMs)
            .put("acknowledgedAt", JSONObject.NULL)
            .put("completedAt", JSONObject.NULL)
            .put("response", JSONObject.NULL)
            .put("error", JSONObject.NULL);
        saveMessage(message);
        return message;
    }

    public JSONArray listMessages(
        final String widgetId,
        final String direction,
        final boolean unacknowledgedOnly,
        final boolean pendingOnly
    ) throws JSONException {
        final List<JSONObject> messages = new ArrayList<>();
        final String normalizedDirection = direction == null ? null : normalizeDirection(direction);
        for (String messageId : listIds(MESSAGE_IDS_KEY)) {
            final JSONObject message = loadMessage(messageId);
            if (message == null) {
                continue;
            }
            if (widgetId != null && !widgetId.equals(message.optString("widgetId"))) {
                continue;
            }
            if (normalizedDirection != null && !normalizedDirection.equals(message.optString("direction"))) {
                continue;
            }
            if (unacknowledgedOnly && !message.isNull("acknowledgedAt")) {
                continue;
            }
            if (pendingOnly && !"pending".equals(message.optString("status"))) {
                continue;
            }
            messages.add(message);
        }
        messages.sort((left, right) -> Long.compare(right.optLong("createdAt"), left.optLong("createdAt")));
        final JSONArray result = new JSONArray();
        for (JSONObject message : messages) {
            result.put(message);
        }
        return result;
    }

    public void acknowledgeMessages(final JSONArray messageIds, final String widgetId, final String direction) throws JSONException {
        final Set<String> targetIds = toStringSet(messageIds);
        final String normalizedDirection = direction == null ? null : normalizeDirection(direction);
        final long nowMs = System.currentTimeMillis();
        for (String currentMessageId : listIds(MESSAGE_IDS_KEY)) {
            final JSONObject message = loadMessage(currentMessageId);
            if (message == null) {
                continue;
            }
            final boolean matchesMessageId = !targetIds.isEmpty() && targetIds.contains(message.optString("messageId"));
            final boolean matchesWidget = widgetId != null && widgetId.equals(message.optString("widgetId"));
            final boolean matchesDirection = normalizedDirection == null || normalizedDirection.equals(message.optString("direction"));
            if ((matchesMessageId || matchesWidget) && matchesDirection) {
                message.put("acknowledgedAt", nowMs);
                saveMessage(message);
            }
        }
    }

    public JSONObject completeMessage(final String messageId, final JSONObject response, final String error) throws JSONException {
        final JSONObject message = loadMessage(messageId);
        if (message == null) {
            return null;
        }
        message.put("status", error == null ? "completed" : "failed");
        message.put("completedAt", System.currentTimeMillis());
        message.put("response", response == null ? JSONObject.NULL : TemplateJsonUtils.deepCopyObject(response));
        message.put("error", error == null ? JSONObject.NULL : error);
        saveMessage(message);
        return message;
    }

    private void saveSession(final JSONObject session) throws JSONException {
        final String widgetId = session.getString("widgetId");
        preferences.edit().putString(sessionKey(widgetId), session.toString()).apply();
        final List<String> ids = listIds(SESSION_IDS_KEY);
        if (!ids.contains(widgetId)) {
            ids.add(widgetId);
            saveIds(SESSION_IDS_KEY, ids);
        }
    }

    private JSONObject loadMessage(final String messageId) throws JSONException {
        final String raw = preferences.getString(messageKey(messageId), null);
        return raw == null ? null : new JSONObject(raw);
    }

    private void saveMessage(final JSONObject message) throws JSONException {
        final String messageId = message.getString("messageId");
        preferences.edit().putString(messageKey(messageId), message.toString()).apply();
        final List<String> ids = listIds(MESSAGE_IDS_KEY);
        if (!ids.contains(messageId)) {
            ids.add(messageId);
            saveIds(MESSAGE_IDS_KEY, ids);
        }
    }

    private JSONObject mergeObjects(final JSONObject base, final JSONObject patch) throws JSONException {
        final JSONObject merged = base == null ? new JSONObject() : TemplateJsonUtils.deepCopyObject(base);
        final IteratorWrapper keys = new IteratorWrapper(patch.keys());
        while (keys.hasNext()) {
            final String key = keys.next();
            final Object current = merged.opt(key);
            final Object value = patch.opt(key);
            if (current instanceof JSONObject currentObject && value instanceof JSONObject patchObject) {
                merged.put(key, mergeObjects(currentObject, patchObject));
            } else {
                merged.put(key, TemplateJsonUtils.deepCopyValue(value));
            }
        }
        return merged;
    }

    private Set<String> toStringSet(final JSONArray values) {
        final Set<String> result = new HashSet<>();
        if (values == null) {
            return result;
        }
        for (int index = 0; index < values.length(); index += 1) {
            final String value = values.optString(index, null);
            if (value != null && !value.isEmpty()) {
                result.add(value);
            }
        }
        return result;
    }

    private List<String> listIds(final String key) {
        final String raw = preferences.getString(key, null);
        final List<String> ids = new ArrayList<>();
        if (raw == null) {
            return ids;
        }
        try {
            final JSONArray values = new JSONArray(raw);
            for (int index = 0; index < values.length(); index += 1) {
                final String value = values.optString(index, null);
                if (value != null && !value.isEmpty()) {
                    ids.add(value);
                }
            }
        } catch (JSONException ignored) {
            return new ArrayList<>();
        }
        return ids;
    }

    private void saveIds(final String key, final List<String> ids) {
        final JSONArray values = new JSONArray();
        for (String id : ids) {
            values.put(id);
        }
        preferences.edit().putString(key, values.toString()).apply();
    }

    private String normalizeDirection(final String direction) {
        return DIRECTION_WIDGET_TO_APP.equals(direction) ? DIRECTION_WIDGET_TO_APP : DIRECTION_APP_TO_WIDGET;
    }

    private String sessionKey(final String widgetId) {
        return "native-session:" + widgetId;
    }

    private String messageKey(final String messageId) {
        return "native-message:" + messageId;
    }

    private static final class IteratorWrapper {

        private final java.util.Iterator<String> iterator;

        IteratorWrapper(final java.util.Iterator<String> iterator) {
            this.iterator = iterator;
        }

        boolean hasNext() {
            return iterator.hasNext();
        }

        String next() {
            return iterator.next();
        }
    }
}
