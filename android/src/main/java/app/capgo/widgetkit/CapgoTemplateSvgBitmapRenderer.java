package app.capgo.widgetkit;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import com.caverock.androidsvg.SVG;
import org.json.JSONObject;

public final class CapgoTemplateSvgBitmapRenderer {

    private CapgoTemplateSvgBitmapRenderer() {}

    public static Bitmap render(final JSONObject layout, final int targetWidthPx, final int targetHeightPx) throws Exception {
        final String svgMarkup = layout.optString("svg", "");
        final SVG svg = SVG.getFromString(svgMarkup);
        svg.setDocumentWidth("100%");
        svg.setDocumentHeight("100%");

        final int width = Math.max(1, targetWidthPx);
        final int height = Math.max(1, targetHeightPx);
        final Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        final Canvas canvas = new Canvas(bitmap);
        svg.renderToCanvas(canvas);
        return bitmap;
    }
}
