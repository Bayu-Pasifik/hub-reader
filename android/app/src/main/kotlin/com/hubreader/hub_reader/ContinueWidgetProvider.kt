package com.hubreader.hub_reader

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/// Widget layar utama "Lanjut baca": judul + bab terakhir; ketuk membuka
/// bab itu lewat tautan hubreader:// (ditangani MainActivity / DeepLinks).
class ContinueWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val title = widgetData.getString("continue_title", null)
        val subtitle = widgetData.getString("continue_subtitle", null)
        val link = widgetData.getString("continue_link", null)
        // Teks tetap dikirim dari Dart supaya mengikuti bahasa aplikasi.
        val label = widgetData.getString("widget_label", null) ?: context.getString(R.string.widget_label)
        val emptyTitle = widgetData.getString("widget_empty_title", null) ?: context.getString(R.string.widget_empty_title)
        val emptySubtitle = widgetData.getString("widget_empty_subtitle", null) ?: context.getString(R.string.widget_empty_subtitle)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_continue)
            views.setTextViewText(R.id.widget_label, label)
            views.setTextViewText(R.id.widget_title, title ?: emptyTitle)
            views.setTextViewText(R.id.widget_subtitle, subtitle ?: emptySubtitle)

            val intent = if (link != null) {
                Intent(Intent.ACTION_VIEW, Uri.parse(link)).setPackage(context.packageName)
            } else {
                Intent(context, MainActivity::class.java)
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            val pending = PendingIntent.getActivity(
                context,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
