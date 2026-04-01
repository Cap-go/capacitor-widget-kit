package app.capgo.widgetkit;

import android.content.Context;
import android.content.SharedPreferences;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

final class TemplateActivityStore {

    private final SharedPreferences preferences;

    TemplateActivityStore(final Context context) {
        preferences = context.getApplicationContext().getSharedPreferences(CapgoWidgetKitConstants.PREFS_NAME, Context.MODE_PRIVATE);
    }

    JSONObject loadActivity(final String activityId) throws JSONException {
        final String raw = preferences.getString(activityKey(activityId), null);
        return raw == null ? null : new JSONObject(raw);
    }

    void saveActivity(final JSONObject activity) {
        final String activityId = activity.optString("activityId");
        preferences.edit().putString(activityKey(activityId), activity.toString()).apply();

        final List<String> ids = listActivityIds();
        if (!ids.contains(activityId)) {
            ids.add(activityId);
            saveActivityIds(ids);
        }
    }

    void deleteActivity(final String activityId) {
        preferences.edit().remove(activityKey(activityId)).remove(eventsKey(activityId)).apply();
        final List<String> ids = listActivityIds();
        ids.remove(activityId);
        saveActivityIds(ids);
    }

    JSONArray listActivities() throws JSONException {
        final JSONArray activities = new JSONArray();
        final List<JSONObject> records = new ArrayList<>();
        for (String activityId : listActivityIds()) {
            final JSONObject record = loadActivity(activityId);
            if (record != null) {
                records.add(record);
            }
        }

        records.sort((left, right) -> Long.compare(right.optLong("updatedAt"), left.optLong("updatedAt")));
        for (JSONObject record : records) {
            activities.put(record);
        }
        return activities;
    }

    void appendEvent(final JSONObject event) throws JSONException {
        final String activityId = event.optString("activityId");
        final JSONArray existing = loadEvents(activityId);
        final JSONArray updated = new JSONArray();
        updated.put(event);
        for (int index = 0; index < existing.length(); index += 1) {
            updated.put(existing.opt(index));
        }
        preferences.edit().putString(eventsKey(activityId), updated.toString()).apply();
    }

    JSONArray loadEvents(final String activityId) throws JSONException {
        final String raw = preferences.getString(eventsKey(activityId), null);
        return raw == null ? new JSONArray() : new JSONArray(raw);
    }

    JSONArray loadEvents(final String activityId, final boolean unacknowledgedOnly) throws JSONException {
        if (activityId != null) {
            return filterEvents(loadEvents(activityId), unacknowledgedOnly);
        }

        final JSONArray events = new JSONArray();
        final List<JSONObject> collected = new ArrayList<>();
        for (String currentActivityId : listActivityIds()) {
            final JSONArray activityEvents = loadEvents(currentActivityId);
            for (int index = 0; index < activityEvents.length(); index += 1) {
                final JSONObject event = activityEvents.optJSONObject(index);
                if (event != null && (!unacknowledgedOnly || event.isNull("acknowledgedAt"))) {
                    collected.add(event);
                }
            }
        }
        collected.sort((left, right) -> Long.compare(right.optLong("createdAt"), left.optLong("createdAt")));
        for (JSONObject event : collected) {
            events.put(event);
        }
        return events;
    }

    void acknowledgeEvents(final String activityId, final JSONArray eventIds, final long acknowledgedAt) throws JSONException {
        if (activityId != null) {
            final JSONArray updated = TemplateRuntime.acknowledgeEvents(loadEvents(activityId), activityId, eventIds, acknowledgedAt);
            preferences.edit().putString(eventsKey(activityId), updated.toString()).apply();
            return;
        }

        if (eventIds == null || eventIds.length() == 0) {
            return;
        }

        for (String currentActivityId : listActivityIds()) {
            final JSONArray updated = TemplateRuntime.acknowledgeEvents(loadEvents(currentActivityId), null, eventIds, acknowledgedAt);
            preferences.edit().putString(eventsKey(currentActivityId), updated.toString()).apply();
        }
    }

    private JSONArray filterEvents(final JSONArray events, final boolean unacknowledgedOnly) {
        if (!unacknowledgedOnly) {
            return events;
        }

        final JSONArray filtered = new JSONArray();
        for (int index = 0; index < events.length(); index += 1) {
            final JSONObject event = events.optJSONObject(index);
            if (event != null && event.isNull("acknowledgedAt")) {
                filtered.put(event);
            }
        }
        return filtered;
    }

    private List<String> listActivityIds() {
        final String raw = preferences.getString(CapgoWidgetKitConstants.ACTIVITY_IDS_KEY, null);
        if (raw == null) {
            return new ArrayList<>();
        }

        try {
            final JSONArray ids = new JSONArray(raw);
            final List<String> values = new ArrayList<>();
            for (int index = 0; index < ids.length(); index += 1) {
                final String value = ids.optString(index, null);
                if (value != null && !value.isEmpty()) {
                    values.add(value);
                }
            }
            return values;
        } catch (JSONException ignored) {
            return new ArrayList<>();
        }
    }

    private void saveActivityIds(final List<String> ids) {
        final JSONArray values = new JSONArray();
        for (String id : ids) {
            values.put(id);
        }
        preferences.edit().putString(CapgoWidgetKitConstants.ACTIVITY_IDS_KEY, values.toString()).apply();
    }

    private String activityKey(final String activityId) {
        return "activity:" + activityId;
    }

    private String eventsKey(final String activityId) {
        return "events:" + activityId;
    }
}
