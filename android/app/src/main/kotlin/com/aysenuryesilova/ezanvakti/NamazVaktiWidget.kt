package com.aysenuryesilova.ezanvakti

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.ComponentName
import android.widget.RemoteViews

class NamazVaktiWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(appWidgetId, createViews(context))
        }
    }

    companion object {
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, NamazVaktiWidget::class.java)
            val ids = manager.getAppWidgetIds(component)
            for (id in ids) manager.updateAppWidget(id, createViews(context))
        }

        private fun createViews(context: Context): RemoteViews {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val location = prefs.getString("flutter.widget_location", "Konum seçin")
            val nextPrayer = prefs.getString("flutter.widget_next_prayer", "Vakitler güncelleniyor")
            val countdown = prefs.getString("flutter.widget_countdown", "--:--:--")
            return RemoteViews(context.packageName, R.layout.namaz_vakti_widget).apply {
                setTextViewText(R.id.widget_location, "🕌 $location")
                setTextViewText(R.id.widget_next_vakit, "Sıradaki vakit: $nextPrayer")
                setTextViewText(R.id.widget_countdown, countdown)
            }
        }
    }
}
