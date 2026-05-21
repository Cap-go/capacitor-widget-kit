package app.capgo.widgetkit;

import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public class CapgoWidgetKit {

    private final Context context;
    private final TemplateActivityStore store;
    private final CapgoNativeWidgetBridge nativeWidgetBridge;

    public CapgoWidgetKit(final Context context) {
        this.context = context.getApplicationContext();
        this.store = new TemplateActivityStore(this.context);
        this.nativeWidgetBridge = new CapgoNativeWidgetBridge(this.context);
    }

    public JSONObject areActivitiesSupported() throws JSONException {
        return new JSONObject()
            .put("supported", true)
            .put(
                "reason",
                "Android support uses the generic template store and widget bridge. Render the resolved SVG and hotspots in your AppWidget or Glance UI."
            );
    }

    public JSONObject startTemplateActivity(
        final String requestedActivityId,
        final JSONObject definitionObject,
        final JSONObject stateObject,
        final String openUrl
    ) throws JSONException {
        final String activityId =
            requestedActivityId != null && !requestedActivityId.isEmpty()
                ? requestedActivityId
                : TemplateRuntime.createIdentifier("activity");
        final JSONObject activity = TemplateRuntime.createActivityRecord(
            activityId,
            definitionObject,
            stateObject,
            openUrl,
            System.currentTimeMillis()
        );
        store.saveActivity(activity);
        notifyStoreChanged(activityId);
        return activity;
    }

    public JSONObject updateTemplateActivity(
        final String activityId,
        final JSONObject definitionObject,
        final JSONObject stateObject,
        final String openUrl
    ) throws JSONException {
        final JSONObject current = store.loadActivity(activityId);
        if (current == null) {
            return null;
        }

        final JSONObject updated = TemplateRuntime.updateActivity(
            current,
            definitionObject,
            stateObject,
            openUrl,
            System.currentTimeMillis()
        );
        store.saveActivity(updated);
        notifyStoreChanged(activityId);
        return updated;
    }

    public void endTemplateActivity(final String activityId, final JSONObject stateObject) throws JSONException {
        final JSONObject current = store.loadActivity(activityId);
        if (current == null) {
            return;
        }

        final JSONObject ended = TemplateRuntime.endActivity(current, stateObject, System.currentTimeMillis());
        store.saveActivity(ended);
        notifyStoreChanged(activityId);
    }

    public TemplateRuntime.ActionResult performTemplateAction(
        final String activityId,
        final String actionId,
        final String sourceId,
        final JSONObject payloadObject
    ) throws JSONException {
        final JSONObject current = store.loadActivity(activityId);
        if (current == null) {
            throw new JSONException("No stored template activity found for " + activityId + ".");
        }

        final TemplateRuntime.ActionResult result = TemplateRuntime.applyAction(
            actionId,
            sourceId,
            payloadObject,
            current,
            System.currentTimeMillis()
        );
        store.saveActivity(result.activity);
        store.appendEvent(result.event);
        notifyStoreChanged(activityId);
        return result;
    }

    public JSONObject getTemplateActivity(final String activityId) throws JSONException {
        return store.loadActivity(activityId);
    }

    public JSONArray listTemplateActivities() throws JSONException {
        return store.listActivities();
    }

    public JSONArray listTemplateEvents(final String activityId, final boolean unacknowledgedOnly) throws JSONException {
        return store.loadEvents(activityId, unacknowledgedOnly);
    }

    public void acknowledgeTemplateEvents(final String activityId, final JSONArray eventIds) throws JSONException {
        store.acknowledgeEvents(activityId, eventIds, System.currentTimeMillis());
        notifyStoreChanged(activityId);
    }

    public JSONObject startWidgetSession(final String widgetId, final String kind, final JSONObject state, final JSONObject metadata)
        throws JSONException {
        final JSONObject session = nativeWidgetBridge.startSession(widgetId, kind, state, metadata);
        notifyWidgetBridgeChanged(session.optString("widgetId"), null);
        return session;
    }

    public JSONObject updateWidgetSession(final String widgetId, final JSONObject state, final JSONObject metadata, final boolean merge)
        throws JSONException {
        final JSONObject session = nativeWidgetBridge.updateSession(widgetId, state, metadata, merge);
        notifyWidgetBridgeChanged(widgetId, null);
        return session;
    }

    public void stopWidgetSession(final String widgetId, final JSONObject state) throws JSONException {
        nativeWidgetBridge.stopSession(widgetId, state);
        notifyWidgetBridgeChanged(widgetId, null);
    }

    public JSONObject getWidgetSession(final String widgetId) throws JSONException {
        return nativeWidgetBridge.loadSession(widgetId);
    }

    public JSONArray listWidgetSessions() throws JSONException {
        return nativeWidgetBridge.listSessions();
    }

    public JSONObject sendWidgetMessage(
        final String widgetId,
        final String direction,
        final String name,
        final JSONObject payload,
        final boolean expectsResponse
    ) throws JSONException {
        final JSONObject message = nativeWidgetBridge.sendMessage(widgetId, direction, name, payload, expectsResponse);
        notifyWidgetBridgeChanged(widgetId, message.optString("messageId"));
        return message;
    }

    public JSONArray listWidgetMessages(
        final String widgetId,
        final String direction,
        final boolean unacknowledgedOnly,
        final boolean pendingOnly
    ) throws JSONException {
        return nativeWidgetBridge.listMessages(widgetId, direction, unacknowledgedOnly, pendingOnly);
    }

    public void acknowledgeWidgetMessages(final JSONArray messageIds, final String widgetId, final String direction) throws JSONException {
        nativeWidgetBridge.acknowledgeMessages(messageIds, widgetId, direction);
        notifyWidgetBridgeChanged(widgetId, null);
    }

    public JSONObject completeWidgetMessage(final String messageId, final JSONObject response, final String error) throws JSONException {
        final JSONObject message = nativeWidgetBridge.completeMessage(messageId, response, error);
        notifyWidgetBridgeChanged(message == null ? null : message.optString("widgetId"), messageId);
        return message;
    }

    public void reloadWidgets(final String kind) {
        notifyStoreChanged(null);
        notifyWidgetBridgeChanged(null, null);
    }

    public JSONObject getPluginVersion() throws JSONException {
        String versionName = "android";
        try {
            final PackageManager packageManager = context.getPackageManager();
            final PackageInfo packageInfo = packageManager.getPackageInfo(context.getPackageName(), 0);
            versionName = packageInfo.versionName != null ? packageInfo.versionName : versionName;
        } catch (PackageManager.NameNotFoundException ignored) {
            // Ignore and keep the fallback.
        }

        return new JSONObject().put("version", versionName);
    }

    private void notifyStoreChanged(final String activityId) {
        final Intent intent = new Intent(CapgoWidgetKitConstants.ACTION_TEMPLATE_STORE_CHANGED).setPackage(context.getPackageName());
        if (activityId != null) {
            intent.putExtra(CapgoWidgetKitConstants.EXTRA_ACTIVITY_ID, activityId);
        }
        context.sendBroadcast(intent);
    }

    private void notifyWidgetBridgeChanged(final String widgetId, final String messageId) {
        final Intent intent = new Intent(CapgoWidgetKitConstants.ACTION_NATIVE_WIDGET_BRIDGE_CHANGED).setPackage(context.getPackageName());
        if (widgetId != null) {
            intent.putExtra(CapgoWidgetKitConstants.EXTRA_WIDGET_ID, widgetId);
        }
        if (messageId != null) {
            intent.putExtra(CapgoWidgetKitConstants.EXTRA_MESSAGE_ID, messageId);
        }
        context.sendBroadcast(intent);
    }
}
