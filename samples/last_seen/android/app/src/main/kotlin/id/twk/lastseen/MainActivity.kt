package id.twk.lastseen

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The game, plus the app icon switch for Extras → App icon (lib/app_icons.dart).
 *
 * Each icon is a launcher entry in the manifest: this activity's own for the main icon, an activity-alias for each of
 * the others. Switching turns one on and the others off. Android closes the game when the entry it was opened through
 * goes off, even with DONT_KILL_APP, so the switch waits until the player leaves the game (Home, Recents, another app,
 * or Back out of it). A screen that turns off or a dialog on top doesn't count. The picked icon is kept until then,
 * across restarts too.
 */
class MainActivity : FlutterActivity() {
    private var userLeft = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "seawall/app_icon").setMethodCallHandler { call, result ->
            when (call.method) {
                "current" -> result.success(picked ?: launched())
                "set" -> {
                    val name = call.arguments as? String
                    if (name == null || name !in launchers) {
                        result.error("unknown_icon", "No app icon called $name", null)
                    } else {
                        picked = name.takeIf { it != launched() }
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        userLeft = false
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        userLeft = true
    }

    override fun onStop() {
        super.onStop()
        if (userLeft && !isChangingConfigurations) switchIcon()
    }

    override fun onDestroy() {
        if (isFinishing) switchIcon()
        super.onDestroy()
    }

    /**
     * The launcher entry of each app icon, by the name lib/app_icons.dart uses. The main icon is this activity's own
     * entry, on in the manifest. The others are the activity-aliases there, off in the manifest.
     */
    private val launchers = mapOf(
        MAIN_ICON to MainActivity::class.java.name,
        "lookback" to "$packagePrefix.IconLookback",
        "undelivered" to "$packagePrefix.IconUndelivered",
    )

    private val packagePrefix get() = MainActivity::class.java.name.substringBeforeLast('.')

    private val prefs get() = getSharedPreferences("app_icon", MODE_PRIVATE)

    /** The icon the player picked that isn't in the launcher yet. */
    private var picked: String?
        get() = prefs.getString("picked", null)
        set(name) = prefs.edit().putString("picked", name).apply()

    private fun component(name: String) = ComponentName(packageName, launchers.getValue(name))

    private fun isOn(name: String) = when (packageManager.getComponentEnabledSetting(component(name))) {
        PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> name == MAIN_ICON
        PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
        else -> false
    }

    /** The icon in the launcher now. */
    private fun launched() = launchers.keys.firstOrNull { it != MAIN_ICON && isOn(it) } ?: MAIN_ICON

    /**
     * Puts the picked icon in the launcher and takes the others out. The new entry goes on before the old ones go off,
     * so the app never has none. The main icon goes back to the manifest's state, so a reinstall over it behaves the
     * same.
     */
    private fun switchIcon() {
        val name = picked ?: return
        picked = null
        fun set(icon: String, on: Boolean) {
            val state = when {
                on == (icon == MAIN_ICON) -> PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
                on -> PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                else -> PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            packageManager.setComponentEnabledSetting(component(icon), state, PackageManager.DONT_KILL_APP)
        }
        set(name, true)
        launchers.keys.filter { it != name }.forEach { set(it, false) }
    }

    private companion object {
        const val MAIN_ICON = "seawall"
    }
}
