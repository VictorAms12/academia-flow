from pathlib import Path
import shutil

root = Path('android')
app_gradle = root / 'app' / 'build.gradle.kts'
text = app_gradle.read_text()
text = text.replace('namespace = "com.example.academia_flow"', 'namespace = "com.example.academia_flow"')
text = text.replace('applicationId = "com.example.academia_flow"', 'applicationId = "com.example.academia_flow"')

if 'isCoreLibraryDesugaringEnabled = true' not in text:
    text = text.replace('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', 1)

if 'signingConfigs {' not in text:
    marker = '    buildTypes {'
    signing = '''    signingConfigs {\n        create("academiaFlow") {\n            storeFile = file("academia-flow-upload.jks")\n            storePassword = "AcademiaFlow2026!"\n            keyAlias = "academiaflow"\n            keyPassword = "AcademiaFlow2026!"\n        }\n    }\n\n'''
    text = text.replace(marker, signing + marker, 1)

text = text.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("academiaFlow")')

if 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")' not in text:
    text += '\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
app_gradle.write_text(text)

# Branding: aplica o ícone próprio depois do `flutter create`, evitando que o
# launcher volte a usar o ic_launcher padrão do Flutter em builds limpos.
# JPEG é usado aqui por compatibilidade direta com AAPT2.
icon_source = Path('tool/branding/academia_flow_icon.jpg')
if not icon_source.exists():
    raise FileNotFoundError(f'Ícone do Academia Flow não encontrado: {icon_source}')
icon_dir = root / 'app' / 'src' / 'main' / 'res' / 'drawable-nodpi'
icon_dir.mkdir(parents=True, exist_ok=True)
icon_target = icon_dir / 'academia_flow_icon.jpg'
shutil.copyfile(icon_source, icon_target)

# Ícone pequeno de notificação. O flutter_local_notifications precisa de um
# recurso Android próprio e não deve depender do ic_launcher do Flutter.
notification_icon_dir = root / 'app' / 'src' / 'main' / 'res' / 'drawable'
notification_icon_dir.mkdir(parents=True, exist_ok=True)
(notification_icon_dir / 'ic_stat_academia_flow.xml').write_text('''<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M12,3L1,9l11,6 9,-4.91V17h2V9L12,3zM12,12.82L5.24,9 12,5.18 18.76,9 12,12.82zM5,13.18v4L12,21l7,-3.82v-4L12,17 5,13.18z" />
</vector>
''', encoding='utf-8')

manifest = root / 'app' / 'src' / 'main' / 'AndroidManifest.xml'
m = manifest.read_text()
if 'android.permission.RECEIVE_BOOT_COMPLETED' not in m:
    m = m.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">', '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>')
m = m.replace('android:label="academia_flow"', 'android:label="Academia Flow"')
m = m.replace('android:icon="@mipmap/ic_launcher"', 'android:icon="@drawable/academia_flow_icon"')
m = m.replace('android:roundIcon="@mipmap/ic_launcher_round"', 'android:roundIcon="@drawable/academia_flow_icon"')
receivers = '''\n        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />\n        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\n            <intent-filter>\n                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>\n                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>\n            </intent-filter>\n        </receiver>\n'''
if 'ScheduledNotificationReceiver' not in m:
    m = m.replace('    </application>', receivers + '    </application>')
manifest.write_text(m)

print('Android configurado: package fixo, assinatura persistente, notificações e ícone Academia Flow.')
