package app.capgo.widgetkit;

import android.content.Context;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public class CapgoTemplateWidgetBridge {

    private final TemplateActivityStore store;

    public CapgoTemplateWidgetBridge(final Context context) {
        store = new TemplateActivityStore(context);
    }

    public JSONObject loadActivity(final String activityId) throws JSONException {
        return store.loadActivity(activityId);
    }

    public JSONArray listActivities() throws JSONException {
        return store.listActivities();
    }

    public JSONObject resolveLayout(final String activityId, final String surface) throws JSONException {
        final JSONObject activity = store.loadActivity(activityId);
        if (activity == null) {
            return null;
        }
        return TemplateRuntime.resolveSurface(activity, surface, System.currentTimeMillis());
    }
}
