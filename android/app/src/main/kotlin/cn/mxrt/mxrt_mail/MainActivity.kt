package cn.mxrt.mxrt_mail

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "cn.mxrt/mail_setup"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "addImapAccount" -> {
                    val email = call.argument<String>("email").orEmpty()
                    val password = call.argument<String>("password").orEmpty()
                    val imapHost = call.argument<String>("imapHost").orEmpty()
                    val imapPort = call.argument<Int>("imapPort") ?: 993
                    val smtpHost = call.argument<String>("smtpHost").orEmpty()
                    val smtpPort = call.argument<Int>("smtpPort") ?: 465
                    val displayName = call.argument<String>("displayName").orEmpty()
                    val outcome = MailSetupBridge.addImapAccount(
                        this,
                        email,
                        password,
                        imapHost,
                        imapPort,
                        smtpHost,
                        smtpPort,
                        displayName,
                    )
                    result.success(outcome)
                }
                else -> result.notImplemented()
            }
        }
    }
}
