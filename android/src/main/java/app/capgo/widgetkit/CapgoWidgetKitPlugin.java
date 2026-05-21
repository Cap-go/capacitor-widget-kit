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
    public void startWidgetSession(final PluginCall call) {
        try {
            final JSONObject session = implementation.startWidgetSession(
                call.getString("widgetId"),
                call.getString("kind"),
                call.getObject("state"),
                call.getObject("metadata")
            );
            final JSObject result = new JSObject();
            result.put("session", toJsObject(session));
            call.resolve(result);
        } catch (JSONException exception) {
            call.reject(exception.getMessage(), exception);
        }
    }

    @PluginMethod
    public void updateWidgetSession(final PluginCall call) {
        final String widgetId = call.getString("widgetId");
        if (widgetId == null) {
            call.reject("The `widgetId` is required.");
            return;
        }

        try {
            final JSONObject session = implementation.updateWidgetSession(
                widgetId,
                call.getObject("state"),
                call.getObject("metadata"),
                call.getBoolean("merge", false)
            );
            final JSObject result = new JSObject();
            result.put("session", session == null ? JSObject.NULL : toJsObject(session));
            call.resolve(result);
        } catch (JSONException exception) {
            call.reject(exception.getMessage(), exception);
        }
    }

    @PluginMethod
    public void stopWidgetSession(final PluginCall call) {
        final String widgetId = call.getString("widgetId");
        if (widgetId == null) {
            call.reject("The `widgetId` is required.");
            return;
        }

        try {
            implementation.stopWidgetSession(widgetId, call.getObject("state"));
            call.resolve();
        } catch (JSONException exception) {
            call.reject(exception.getMessage(), exception);
        }
    }

    @PluginMethod
    public void getWidgetSession(final PluginCall call) {
        final String widgetId = call.getString("widgetId");
        if (widgetId == null) {
            call.reject("The `widgetId` is required.");
            return;
        }

        try {
            final JSONObject session = implementation.getWidgetSession(widgetId);
            final JSObject result = new JSObject();
            result.put("session", session == null ? JSObject.NULL : toJsObject(session));
            call.resolve(result);
        } catch (JSONException exception) {
            call.reject(exception.getMessage(), exception);
        }
    }

    @PluginMethod
    public void listWidgetSessions(final PluginCall call) {
        try {
            final JSObject result = new JSObject();
            result.put("sessions", toJsArray(implementation.listWidgetSessions()));
            call.resolve(result);
        } catch (JSONException exception) {
            call.reject(exception.getMessage(), exception);
        }
    }

    @PluginMethod
    public void sendWidgetMessage(final PluginCall call) {
        final String widgetId = call.getString("widgetId");
        final String name = call.getString("name");
        if (widgetId == null) {
            call.reject("The `widgetId` is required.");
            return;
        }
        if (name == null) {
            call.reject("The `name` is required.");
            return;
        }

        try {
            final JSONObject message = implementation.sendWidgetMessage(
                widgetId,
                call.getString("direction"),
                name,
                call.getObject("payload"),
                call.getBoolean("expectsResponse", false)
            );
            final JSObject result = new JSObject();
            result.put("message", toJsObject(message));
            call.resolve(result);
        } catch (JSONException exception) {
            call.reject(exception.getMessage(), exception);
        }
    }

    @PluginMethod
    public void listWidgetMessages(final PluginCall call) {
        try {
            final JSObject result = new JSObject();
            result.put(
                "messages",
                toJsArray(
                    implementation.listWidgetMessages(
                        call.getString("widgetId"),
                        call.getString("direction"),
                        call.getBoolean("unacknowledgedOnly", false),
                        call.getBoolean("pendingOnly", false)
                    )
                )
            );
            call.resolve(result);
        } catch (JSONException exception) {
            call.reject(exception.getMessage(), exception);
        }
    }

    @PluginMethod
    public void acknowledgeWidgetMessages(final PluginCall call) {
        try {
            implementation.acknowledgeWidgetMessages(
                toJsonArray(call.getArray("messageIds")),
                call.getString("widgetId"),
                call.getString("direction")
            );
            call.resolve();
        } catch (JSONException exception) {
            call.reject(exception.getMessage(), exception);
        }
    }

    @PluginMethod
    public void completeWidgetMessage(final PluginCall call) {
        final String messageId = call.getString("messageId");
        if (messageId == null) {
            call.reject("The `messageId` is required.");
            return;
        }

        try {
            final JSONObject message = implementation.completeWidgetMessage(messageId, call.getObject("response"), call.getString("error"));
            final JSObject result = new JSObject();
            result.put("message", message == null ? JSObject.NULL : toJsObject(message));
            call.resolve(result);
        } catch (JSONException exception) {
            call.reject(exception.getMessage(), exception);
        }
    }

    @PluginMethod
    public void reloadWidgets(final PluginCall call) {
        implementation.reloadWidgets(call.getString("kind"));
        call.resolve();
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
