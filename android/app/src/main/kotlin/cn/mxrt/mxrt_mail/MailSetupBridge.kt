package cn.mxrt.mxrt_mail

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.util.Log

/**
 * Android 一键添加邮箱的原生桥接。
 *
 * 策略（逐级回退）：
 *   1. 尝试打开 Gmail 的"添加其他邮箱"流程（覆盖率最高，几乎所有 Android 手机都有 Gmail）
 *   2. 尝试打开系统自带邮件 App
 *   3. 兜底：打开系统"添加账户"设置页
 *
 * 返回值：
 *   "gmail" - Gmail 打开成功
 *   "system" - 系统邮件打开成功
 *   "settings" - 打开了设置页
 *   "failed" - 全部失败
 */
object MailSetupBridge {
    private const val TAG = "MailSetupBridge"

    fun addImapAccount(
        context: Context,
        email: String,
        password: String,
        imapHost: String,
        imapPort: Int,
        smtpHost: String,
        smtpPort: Int,
        displayName: String,
    ): String {

        // 方案1: Gmail - 用 mailto: intent 打开 Gmail，用户在 Gmail 里添加账户
        // Gmail 的"添加其他邮箱"支持 IMAP 配置
        if (tryOpenGmail(context, email)) {
            return "gmail"
        }

        // 方案2: 尝试各种系统邮件 App
        if (tryOpenSystemEmail(context, email)) {
            return "system"
        }

        // 方案3: 打开系统"添加账户"设置
        if (tryOpenAccountSettings(context)) {
            return "settings"
        }

        return "failed"
    }

    private fun tryOpenGmail(context: Context, email: String): Boolean {
        return try {
            // 方式A: 直接打开 Gmail 的账户管理
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("googlemail://accounts")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            try {
                // 方式B: 打开 Gmail App 主界面（用户可以从菜单添加账户）
                val intent = context.packageManager.getLaunchIntentForPackage("com.google.android.gm")
                if (intent != null) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    true
                } else {
                    false
                }
            } catch (e2: Exception) {
                false
            }
        } catch (e: Exception) {
            Log.w(TAG, "tryOpenGmail failed", e)
            false
        }
    }

    private fun tryOpenSystemEmail(context: Context, email: String): Boolean {
        // 尝试常见的系统邮件 App 包名
        val emailPackages = listOf(
            "com.android.email",      // AOSP / 小米 / OPPO
            "com.miui.email",         // 小米 MIUI
            "com.hihonor.email",      // 荣耀
            "com.huawei.email",       // 华为
            "com.vivo.email",         // vivo
            "com.samsung.android.email.provider", // 三星
            "com.coloros.email",      // OPPO ColorOS
        )

        for (pkg in emailPackages) {
            try {
                val intent = context.packageManager.getLaunchIntentForPackage(pkg)
                if (intent != null) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    Log.i(TAG, "Opened system email: $pkg")
                    return true
                }
            } catch (e: Exception) {
                continue
            }
        }
        return false
    }

    private fun tryOpenAccountSettings(context: Context): Boolean {
        return try {
            // 打开"添加账户"页面
            val intent = Intent(Settings.ACTION_ADD_ACCOUNT).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            try {
                // 兜底：打开同步设置
                val intent = Intent(Settings.ACTION_SYNC_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                true
            } catch (e2: Exception) {
                false
            }
        } catch (e: Exception) {
            Log.w(TAG, "tryOpenAccountSettings failed", e)
            false
        }
    }
}
