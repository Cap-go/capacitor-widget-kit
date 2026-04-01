package app.capgo.widgetkit;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

@CapacitorPlugin(name = "CapgoWidgetKit")
public class CapgoWidgetKitPlugin extends Plugin {

    private CapgoWidgetKit implementation;

    @Override
    public void load() {
        super.load();
        implementation = new CapgoWidgetKit(getContext());
    }

    @PluginMethod
    public void areActivitiesSupported(final PluginCall call) {
        try {
            call.resolve(toJsObject(implementation.areActivitiesSupported()));
        } catch (JSONException exception) {
            call.reject(exception.getMessage(), exception);
        }
    }

    @PluginMethod
    public void startTemplateActivity(final PluginCall call) {
        final JSObject definition = call.getObject("definition");
        final JSObject state = call.getObject("state");

        if (definition == null) {
            call.reject("The `definition` object is required.");
            return;
        }
        if (state == null) {
            call.reject("The `state` object is required.");
            return;
        }

        try {
            final JSONObject activity = implementation.startTemplateActivity(
                call.getString("activityId"),
                definition,
                state,
                call.getString("openUrl")
            );
            final JSObject result = new JSObject();
            result.put("activity", toJsObject(activity));
            call.resolve(result);
        } catch (JSONException exception) {
            call.reject(exception.getMessage(), exception);
        }
    }

    @PluginMethod
    public void updateTemplateActivity(final PluginCall call) {
        final String activityId = call.getString("activityId");
        if (activityId == null) {
            call.reject("The `activityId` is required.");
            return;
        }

        try {
            final JSONObject activity = implementation.updateTemplateActivity(
                activityId,
                call.getObject("definition"),
                call.getObject("state"),
                call.getString("openUrl")
            );
            final JSObject result = new JSObject();
            result.put("activity", activity == null ? JSObject.NULL : toJsObject(activity));
            call.resolve(result);
        } catch (JSONException exception) {
            call.reject(exception.getMessage(), exception);
        }
    }

    @PluginMethod
    public void endTemplateActivity(final PluginCall call) {
        final String activityId = call.getString("activityId");
        if (activityId == null) {
            call.reject("The `activityId` is required.");
            return;
        }

        try {
            implementation.endTemplateActivity(activityId, call.getObject("state"));
            call.resolve();
        } catch (JSONException exception) {
            call.reject(exception.getMessage(), exception);
        }
    }

    @PluginMethod
    public void performTemplateAction(final PluginCall call) {
        final String activityId = call.getString("activityId");
        final String actionId = call.getString("actionId");
        if (activityId == null) {
            call.reject("The `activityId` is required.");
            return;
        }
        if (actionId == null) {
            call.reject("The `actionId` is required.");
            return;
        }

        try {
            final TemplateRuntime.ActionResult result = implementation.performTemplateAction(
                activityId,
                actionId,
                call.getString("sourceId"),
                call.getObject("payload")
            );
            final JSObject payload = new JSObject();
            payload.put("activity", toJsObject(result.activity));
            payload.put("event", toJsObject(result.event));
            call.resolve(payload);
        } catch (JSONException exception) {
            call.reject(exception.getMessage(), exception);
        }
    }

    @PluginMethod
    public void getTemplateActivity(final PluginCall call) {
        final String activityId = call.getString("activityId");
        if (activityId == null) {
            call.reject("The `activityId` is required.");
            return;
        }

        try {
            final JSONObject activity = implementation.getTemplateActivity(activityId);
            final JSObject result = new JSObject();
            result.put("activity", activity == null ? JSObject.NULL : toJsObject(activity));
            call.resolve(result);
        } catch (JSONException exception) {
            call.reject(exception.getMessage(), exception);
        }
    }

    @PluginMethod
    public void listTemplateActivities(final PluginCall call) {
        try {
            final JSObject result = new JSObject();
            result.put("activities", toJsArray(implementation.listTemplateActivities()));
            call.resolve(result);
        } catch (JSONException exception) {
            call.reject(exception.getMessage(), exception);
        }
    }

    @PluginMethod
    public void listTemplateEvents(final PluginCall call) {
        try {
            final JSObject result = new JSObject();
            result.put(
                "events",
                toJsArray(implementation.listTemplateEvents(call.getString("activityId"), call.getBoolean("unacknowledgedOnly", false)))
            );
            call.resolve(result);
        } catch (JSONException exception) {
            call.reject(exception.getMessage(), exception);
        }
    }

    @PluginMethod
    public void acknowledgeTemplateEvents(final PluginCall call) {
        try {
            implementation.acknowledgeTemplateEvents(call.getString("activityId"), toJsonArray(call.getArray("eventIds")));
            call.resolve();
        } catch (JSONException exception) {
            call.reject(exception.getMessage(), exception);
        }
    }

    @PluginMethod
    public void getPluginVersion(final PluginCall call) {
        try {
            call.resolve(toJsObject(implementation.getPluginVersion()));
        } catch (JSONException exception) {
            call.reject(exception.getMessage(), exception);
        }
    }

    private JSObject toJsObject(final JSONObject object) throws JSONException {
        return new JSObject(object.toString());
    }

    private JSArray toJsArray(final JSONArray array) throws JSONException {
        return new JSArray(array.toString());
    }

    private JSONArray toJsonArray(final JSArray array) throws JSONException {
        return array == null ? null : new JSONArray(array.toString());
    }
}
