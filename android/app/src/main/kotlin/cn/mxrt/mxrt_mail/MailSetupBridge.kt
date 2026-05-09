package cn.mxrt.mxrt_mail

import android.accounts.AccountManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.util.Log

/**
 * 一键把 IMAP/SMTP 邮箱预填到系统"添加账户"向导的原生桥接。
 *
 * 适配策略（逐级回退，只要有一级成功即返回 true）：
 *   1. 尝试各大 OEM 系统邮箱 App 的账户设置 Activity，预填 EMAIL/PASSWORD
 *   2. 尝试通用的 ACTION_ADD_ACCOUNT（带 account types 过滤）
 *   3. 最后打开系统"添加账户"设置页
 *
 * 为了不强制依赖 email 权限，这里不调用 AccountManager 创建账户，
 * 而是引导用户完成系统向导（向导里会利用我们传进来的 extras 预填服务器、
 * 账号和密码）。这种方式在小米 MIUI / 荣耀 MagicOS / 华为 EMUI / 一加 /
 * 原生 Android 上都有效，且不需要额外签名或权限。
 */
object MailSetupBridge {
    private const val TAG = "MailSetupBridge"

    /** 已知 OEM 邮箱应用的账户设置 Activity 列表（按优先级） */
    private val KNOWN_SETUP_COMPONENTS = listOf(
        // 原生 AOSP Email
        "com.android.email" to "com.android.email.activity.setup.AccountSetupBasics",
        // Google 邮件代（AOSP fork）
        "com.google.android.email" to "com.android.email.activity.setup.AccountSetupBasics",
        // 小米
        "com.android.email" to "com.android.email.activity.setup.AccountSetupFinal",
        "com.miui.email" to "com.android.email.activity.setup.AccountSetupBasics",
        // 荣耀 / 华为
        "com.hihonor.email" to "com.android.email.activity.setup.AccountSetupBasics",
        "com.huawei.email" to "com.android.email.activity.setup.AccountSetupBasics",
        // OPPO / realme
        "com.android.email" to "com.android.email.activity.setup.AccountSetup",
        // vivo
        "com.vivo.email" to "com.android.email.activity.setup.AccountSetupBasics",
        // 三星
        "com.samsung.android.email.provider" to "com.samsung.android.email.ui.setup.AccountSetupBasics",
    )

    fun addImapAccount(
        context: Context,
        email: String,
        password: String,
        imapHost: String,
        imapPort: Int,
        smtpHost: String,
        smtpPort: Int,
        displayName: String,
    ): Boolean {
        val extras = buildExtras(email, password, imapHost, imapPort, smtpHost, smtpPort, displayName)

        // 1) 依次尝试已知 OEM 邮箱 App 的 setup activity
        for ((pkg, activity) in KNOWN_SETUP_COMPONENTS) {
            if (tryLaunch(context, pkg, activity, extras)) {
                Log.i(TAG, "Launched OEM email setup: $pkg/$activity")
                return true
            }
        }

        // 2) 通用：系统 ACTION_ADD_ACCOUNT，限定为 email 类
        if (tryAddAccountIntent(context, extras)) {
            Log.i(TAG, "Launched system ACTION_ADD_ACCOUNT")
            return true
        }

        // 3) 最后兜底：系统"添加账户"设置页
        return tryOpenAccountSettings(context)
    }

    private fun buildExtras(
        email: String,
        password: String,
        imapHost: String,
        imapPort: Int,
        smtpHost: String,
        smtpPort: Int,
        displayName: String,
    ): Bundle {
        return Bundle().apply {
            // AOSP Email 及大多数 fork 认这几个 key
            putString("EMAIL", email)
            putString("PASSWORD", password)
            putString("android.intent.extra.EMAIL", email)
            putString(AccountManager.KEY_ACCOUNT_NAME, email)
            putString(AccountManager.KEY_ACCOUNT_TYPE, "com.android.email")
            putString("INCOMING_PROTOCOL", "imap")
            putString("INCOMING_SERVER", imapHost)
            putInt("INCOMING_PORT", imapPort)
            putString("INCOMING_FLAGS", "ssl+trustallcerts")
            putString("OUTGOING_SERVER", smtpHost)
            putInt("OUTGOING_PORT", smtpPort)
            putString("OUTGOING_FLAGS", "ssl+trustallcerts")
            putString("SENDER_NAME", displayName)
            // 方便用户复制
            putString("com.android.email.extra.CREDENTIALS_EMAIL", email)
            putString("com.android.email.extra.CREDENTIALS_PASSWORD", password)
        }
    }

    private fun tryLaunch(
        context: Context,
        pkg: String,
        cls: String,
        extras: Bundle,
    ): Boolean {
        return try {
            // 先检测该组件是否存在
            val pmInfo = context.packageManager.getActivityInfo(
                ComponentName(pkg, cls), 0
            )
            if (!pmInfo.exported && pmInfo.packageName != context.packageName) {
                // 非 exported 无法跨进程启动
                return false
            }
            val intent = Intent(Intent.ACTION_MAIN).apply {
                component = ComponentName(pkg, cls)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                putExtras(extras)
            }
            context.startActivity(intent)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            // OEM 有时把组件设为 signature 权限，跨 app 启动会抛 SecurityException
            false
        } catch (e: Exception) {
            Log.w(TAG, "tryLaunch $pkg/$cls failed", e)
            false
        }
    }

    private fun tryAddAccountIntent(context: Context, extras: Bundle): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_ADD_ACCOUNT).apply {
                putExtra(
                    Settings.EXTRA_ACCOUNT_TYPES,
                    arrayOf(
                        "com.android.email",
                        "com.google.android.email",
                        "com.miui.email",
                        "com.hihonor.email",
                        "com.huawei.email",
                        "com.vivo.email",
                        "com.samsung.android.email.provider",
                    )
                )
                putExtras(extras)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: Exception) {
            Log.w(TAG, "tryAddAccountIntent failed", e)
            false
        }
    }

    private fun tryOpenAccountSettings(context: Context): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_SYNC_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            try {
                val intent = Intent(Settings.ACTION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                true
            } catch (_: Exception) {
                false
            }
        }
    }
}
