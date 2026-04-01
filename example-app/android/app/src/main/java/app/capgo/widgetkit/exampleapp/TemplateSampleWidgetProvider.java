package app.capgo.widgetkit.exampleapp;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.view.View;
import android.widget.RemoteViews;
import app.capgo.widgetkit.CapgoTemplateActionReceiver;
import app.capgo.widgetkit.CapgoTemplateSvgBitmapRenderer;
import app.capgo.widgetkit.CapgoTemplateWidgetBridge;
import app.capgo.widgetkit.CapgoWidgetKitConstants;
import org.json.JSONArray;
import org.json.JSONObject;

public class TemplateSampleWidgetProvider extends AppWidgetProvider {

    private static final String SURFACE_LOCK_SCREEN = "lockScreen";
    private static final int PREVIEW_WIDTH_PX = 720;
    private static final int PREVIEW_HEIGHT_PX = 360;

    @Override
    public void onUpdate(final Context context, final AppWidgetManager appWidgetManager, final int[] appWidgetIds) {
        updateWidgets(context, appWidgetManager, appWidgetIds);
    }

    @Override
    public void onReceive(final Context context, final Intent intent) {
        super.onReceive(context, intent);
        if (intent != null && CapgoWidgetKitConstants.ACTION_TEMPLATE_STORE_CHANGED.equals(intent.getAction())) {
            updateAllWidgets(context);
        }
    }

    private void updateAllWidgets(final Context context) {
        final AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
        final ComponentName componentName = new ComponentName(context, TemplateSampleWidgetProvider.class);
        updateWidgets(context, appWidgetManager, appWidgetManager.getAppWidgetIds(componentName));
    }

    private void updateWidgets(final Context context, final AppWidgetManager appWidgetManager, final int[] appWidgetIds) {
        final RemoteViews views = buildViews(context);
        for (int appWidgetId : appWidgetIds) {
            appWidgetManager.updateAppWidget(appWidgetId, views);
        }
    }

    private RemoteViews buildViews(final Context context) {
        final RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_template_sample);
        final PendingIntent openAppIntent = openAppPendingIntent(context);
        if (openAppIntent != null) {
            views.setOnClickPendingIntent(R.id.widget_root, openAppIntent);
            views.setOnClickPendingIntent(R.id.widget_open_app, openAppIntent);
        }

        try {
            final CapgoTemplateWidgetBridge bridge = new CapgoTemplateWidgetBridge(context);
            final JSONArray activities = bridge.listActivities();
            final JSONObject activity = selectActivity(activities);
            if (activity == null) {
                renderEmptyState(views);
                return views;
            }

            final JSONObject layout = bridge.resolveLayout(activity.optString("activityId"), SURFACE_LOCK_SCREEN);
            if (layout == null) {
                renderEmptyState(views);
                return views;
            }

            renderLayout(views, context, activity, layout, openAppIntent);
        } catch (Exception ignored) {
            renderEmptyState(views);
        }

        return views;
    }

    private void renderLayout(
        final RemoteViews views,
        final Context context,
        final JSONObject activity,
        final JSONObject layout,
        final PendingIntent openAppIntent
    ) throws Exception {
        views.setViewVisibility(R.id.widget_empty, View.GONE);
        views.setViewVisibility(R.id.widget_surface, View.VISIBLE);
        views.setViewVisibility(R.id.widget_action_row, View.VISIBLE);
        views.setTextViewText(R.id.widget_title, layout.optString("templateId", "Template"));
        views.setTextViewText(R.id.widget_subtitle, activity.optString("status", "active") + " · rev " + activity.optInt("revision"));

        try {
            final Bitmap bitmap = CapgoTemplateSvgBitmapRenderer.render(layout, PREVIEW_WIDTH_PX, PREVIEW_HEIGHT_PX);
            views.setImageViewBitmap(R.id.widget_surface, bitmap);
        } catch (Exception ignored) {
            views.setImageViewResource(R.id.widget_surface, android.R.color.transparent);
        }

        final JSONArray hotspots = layout.optJSONArray("hotspots");
        configureHotspotButton(
            views,
            context,
            openAppIntent,
            activity.optString("activityId"),
            hotspots != null ? hotspots.optJSONObject(0) : null,
            R.id.widget_action_primary
        );
        configureHotspotButton(
            views,
            context,
            openAppIntent,
            activity.optString("activityId"),
            hotspots != null ? hotspots.optJSONObject(1) : null,
            R.id.widget_action_secondary
        );
    }

    private void renderEmptyState(final RemoteViews views) {
        views.setTextViewText(R.id.widget_title, "Capgo Widget Kit");
        views.setTextViewText(R.id.widget_subtitle, "Start the demo template in the app");
        views.setViewVisibility(R.id.widget_empty, View.VISIBLE);
        views.setViewVisibility(R.id.widget_surface, View.GONE);
        views.setViewVisibility(R.id.widget_action_row, View.GONE);
    }

    private void configureHotspotButton(
        final RemoteViews views,
        final Context context,
        final PendingIntent openAppIntent,
        final String activityId,
        final JSONObject hotspot,
        final int viewId
    ) {
        if (hotspot == null) {
            views.setViewVisibility(viewId, View.GONE);
            return;
        }

        views.setViewVisibility(viewId, View.VISIBLE);
        views.setTextViewText(viewId, hotspot.optString("label", hotspot.optString("actionId", "Action")));
        final PendingIntent pendingIntent = hotspotPendingIntent(context, activityId, hotspot);
        if (pendingIntent != null) {
            views.setOnClickPendingIntent(viewId, pendingIntent);
        } else if (openAppIntent != null) {
            views.setOnClickPendingIntent(viewId, openAppIntent);
        }
    }

    private PendingIntent hotspotPendingIntent(final Context context, final String activityId, final JSONObject hotspot) {
        final String actionId = hotspot.optString("actionId", null);
        if (actionId == null || actionId.isEmpty()) {
            return null;
        }

        final Intent intent = new Intent(context, CapgoTemplateActionReceiver.class)
            .setAction(CapgoWidgetKitConstants.ACTION_PERFORM_TEMPLATE_ACTION)
            .putExtra(CapgoWidgetKitConstants.EXTRA_ACTIVITY_ID, activityId)
            .putExtra(CapgoWidgetKitConstants.EXTRA_ACTION_ID, actionId)
            .putExtra(CapgoWidgetKitConstants.EXTRA_SOURCE_ID, hotspot.optString("id", null));

        final JSONObject payload = hotspot.optJSONObject("payload");
        if (payload != null) {
            intent.putExtra(CapgoWidgetKitConstants.EXTRA_PAYLOAD_JSON, payload.toString());
        }

        final int requestCode = (activityId + ":" + actionId + ":" + hotspot.optString("id", "")).hashCode();
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
    }

    private PendingIntent openAppPendingIntent(final Context context) {
        final Intent launchIntent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        if (launchIntent == null) {
            return null;
        }
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        return PendingIntent.getActivity(context, 1, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private JSONObject selectActivity(final JSONArray activities) {
        JSONObject fallback = null;
        for (int index = 0; index < activities.length(); index += 1) {
            final JSONObject activity = activities.optJSONObject(index);
            if (activity == null) {
                continue;
            }
            if ("active".equals(activity.optString("status"))) {
                return activity;
            }
            if (fallback == null) {
                fallback = activity;
            }
        }
        return fallback;
    }
}
