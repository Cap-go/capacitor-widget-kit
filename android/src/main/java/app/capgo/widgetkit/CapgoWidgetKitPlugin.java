package app.capgo.widgetkit;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "CapgoWidgetKit")
public class CapgoWidgetKitPlugin extends Plugin {

    private final CapgoWidgetKit implementation = new CapgoWidgetKit();

    @PluginMethod
    public void areActivitiesSupported(final PluginCall call) {
        final JSObject result = new JSObject();
        result.put("supported", implementation.isSupported());
        result.put("reason", "Android preview stub only. Native WidgetKit and ActivityKit features are iOS-specific.");
        call.resolve(result);
    }

    @PluginMethod
    public void startWorkoutLiveActivity(final PluginCall call) {
        call.reject("CapgoWidgetKit is only implemented natively on iOS.");
    }

    @PluginMethod
    public void updateWorkoutLiveActivity(final PluginCall call) {
        call.reject("CapgoWidgetKit is only implemented natively on iOS.");
    }

    @PluginMethod
    public void endWorkoutLiveActivity(final PluginCall call) {
        call.reject("CapgoWidgetKit is only implemented natively on iOS.");
    }

    @PluginMethod
    public void completeWorkoutSet(final PluginCall call) {
        call.reject("CapgoWidgetKit is only implemented natively on iOS.");
    }

    @PluginMethod
    public void getStoredWorkoutSession(final PluginCall call) {
        final JSObject result = new JSObject();
        result.put("session", JSObject.NULL);
        call.resolve(result);
    }

    @PluginMethod
    public void listWorkoutLiveActivities(final PluginCall call) {
        final JSObject result = new JSObject();
        result.put("activities", new JSArray());
        call.resolve(result);
    }

    @PluginMethod
    public void getPluginVersion(final PluginCall call) {
        final JSObject result = new JSObject();
        result.put("version", "android");
        call.resolve(result);
    }
}
