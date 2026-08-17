from pathlib import Path

from PIL import Image

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

# Branding Android: gera PNGs reais nas densidades oficiais do launcher.
# Isso evita o fallback de alguns launchers/instaladores Xiaomi para o ícone
# genérico quando um JPEG é usado como recurso do aplicativo.
icon_source = Path('tool/branding/academia_flow_icon.png')
if not icon_source.exists():
    raise FileNotFoundError(f'Ícone do Academia Flow não encontrado: {icon_source}')

res = root / 'app' / 'src' / 'main' / 'res'
source = Image.open(icon_source).convert('RGBA')

legacy_sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
}
adaptive_sizes = {
    'mdpi': 108,
    'hdpi': 162,
    'xhdpi': 216,
    'xxhdpi': 324,
    'xxxhdpi': 432,
}

for density, size in legacy_sizes.items():
    mipmap_dir = res / f'mipmap-{density}'
    mipmap_dir.mkdir(parents=True, exist_ok=True)

    # Remove qualquer recurso antigo com o mesmo nome, inclusive os JPEGs
    # usados nas builds anteriores.
    for old_name in (
        'ic_launcher.png', 'ic_launcher.jpg',
        'ic_launcher_round.png', 'ic_launcher_round.jpg',
        'ic_launcher_foreground.png', 'ic_launcher_foreground.jpg',
    ):
        old = mipmap_dir / old_name
        if old.exists():
            old.unlink()

    legacy = source.resize((size, size), Image.Resampling.LANCZOS)
    legacy.save(mipmap_dir / 'ic_launcher.png', format='PNG', optimize=True)
    legacy.save(mipmap_dir / 'ic_launcher_round.png', format='PNG', optimize=True)

    foreground_size = adaptive_sizes[density]
    foreground = source.resize(
        (foreground_size, foreground_size),
        Image.Resampling.LANCZOS,
    )
    foreground.save(
        mipmap_dir / 'ic_launcher_foreground.png',
        format='PNG',
        optimize=True,
    )

# Adaptive icon padrão para Android 8+.
values_dir = res / 'values'
values_dir.mkdir(parents=True, exist_ok=True)
(values_dir / 'launcher_colors.xml').write_text(
    '''<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#111315</color>\n</resources>\n''',
    encoding='utf-8',
)

adaptive_dir = res / 'mipmap-anydpi-v26'
adaptive_dir.mkdir(parents=True, exist_ok=True)
adaptive_xml = '''<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
'''
(adaptive_dir / 'ic_launcher.xml').write_text(adaptive_xml, encoding='utf-8')
(adaptive_dir / 'ic_launcher_round.xml').write_text(adaptive_xml, encoding='utf-8')

# Ícone monocromático pequeno exclusivo das notificações.
notification_icon_dir = res / 'drawable'
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
    m = m.replace(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>',
    )
m = m.replace('android:label="academia_flow"', 'android:label="Academia Flow"')

# O package sempre aponta para os recursos de launcher padrão do Android.
m = m.replace('android:icon="@drawable/academia_flow_icon"', 'android:icon="@mipmap/ic_launcher"')
if 'android:icon="@mipmap/ic_launcher"' not in m:
    m = m.replace('<application', '<application\n        android:icon="@mipmap/ic_launcher"', 1)

m = m.replace('android:roundIcon="@drawable/academia_flow_icon"', 'android:roundIcon="@mipmap/ic_launcher_round"')
if 'android:roundIcon=' not in m:
    m = m.replace(
        'android:icon="@mipmap/ic_launcher"',
        'android:icon="@mipmap/ic_launcher"\n        android:roundIcon="@mipmap/ic_launcher_round"',
        1,
    )

# Garante que o resource shrinker preserve o ícone encontrado pelo plugin de
# notificações dinamicamente em runtime.
if 'academia_flow.notification_icon_keep' not in m:
    m = m.replace(
        '    </application>',
        '        <meta-data android:name="academia_flow.notification_icon_keep" android:resource="@drawable/ic_stat_academia_flow" />\n    </application>',
    )

receivers = '''\n        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />\n        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\n            <intent-filter>\n                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>\n                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>\n            </intent-filter>\n        </receiver>\n'''
if 'ScheduledNotificationReceiver' not in m:
    m = m.replace('    </application>', receivers + '    </application>')
manifest.write_text(m)

print('Android configurado: assinatura persistente, notificações e launcher PNG/adaptativo Academia Flow.')
