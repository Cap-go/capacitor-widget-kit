package app.capgo.widgetkit;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;
import org.json.JSONException;
import org.json.JSONObject;

public class CapgoTemplateActionReceiver extends BroadcastReceiver {

    private static final String LOG_TAG = "CapgoWidgetKit";

    @Override
    public void onReceive(final Context context, final Intent intent) {
        if (intent == null || !CapgoWidgetKitConstants.ACTION_PERFORM_TEMPLATE_ACTION.equals(intent.getAction())) {
            return;
        }

        final String activityId = intent.getStringExtra(CapgoWidgetKitConstants.EXTRA_ACTIVITY_ID);
        final String actionId = intent.getStringExtra(CapgoWidgetKitConstants.EXTRA_ACTION_ID);
        final String sourceId = intent.getStringExtra(CapgoWidgetKitConstants.EXTRA_SOURCE_ID);
        final String payloadJson = intent.getStringExtra(CapgoWidgetKitConstants.EXTRA_PAYLOAD_JSON);

        if (activityId == null || actionId == null) {
            return;
        }

        try {
            final JSONObject payload = payloadJson != null && !payloadJson.isEmpty() ? new JSONObject(payloadJson) : null;
            new CapgoWidgetKit(context).performTemplateAction(activityId, actionId, sourceId, payload);
        } catch (JSONException exception) {
            Log.e(LOG_TAG, "Failed to execute template action from widget receiver", exception);
        }
    }
}
