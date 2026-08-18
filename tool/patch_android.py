from pathlib import Path

from PIL import Image, ImageDraw

root = Path('android')
app_gradle = root / 'app' / 'build.gradle.kts'
text = app_gradle.read_text()

if 'isCoreLibraryDesugaringEnabled = true' not in text:
    text = text.replace('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', 1)

if 'signingConfigs {' not in text:
    marker = '    buildTypes {'
    signing = '''    signingConfigs {\n        create("academiaFlow") {\n            storeFile = file("academia-flow-upload.jks")\n            storePassword = System.getenv("ACADEMIA_FLOW_STORE_PASSWORD") ?: ""\n            keyAlias = "academiaflow"\n            keyPassword = System.getenv("ACADEMIA_FLOW_KEY_PASSWORD") ?: ""\n        }\n    }\n\n'''
    text = text.replace(marker, signing + marker, 1)

text = text.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("academiaFlow")')

if 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")' not in text:
    text += '\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
app_gradle.write_text(text)

res = root / 'app' / 'src' / 'main' / 'res'

# O launcher é gerado de forma determinística durante a build: fundo preto
# puro e chapéu de formatura dourado em escala contida, semelhante ao símbolo
# utilizado na UI. Isso evita depender de assets binários históricos corrompidos.
def draw_cap(canvas_size: int, *, transparent: bool) -> Image.Image:
    bg = (0, 0, 0, 0) if transparent else (0, 0, 0, 255)
    image = Image.new('RGBA', (canvas_size, canvas_size), bg)
    draw = ImageDraw.Draw(image)

    gold = (214, 175, 55, 255)
    gold_light = (235, 199, 76, 255)
    gold_dark = (155, 119, 31, 255)
    shadow = (0, 0, 0, 70)

    # Área útil do símbolo: ~52% do ícone, deixando bastante respiro.
    cx = canvas_size / 2
    cap_w = canvas_size * 0.52
    top_y = canvas_size * 0.35
    top_h = canvas_size * 0.19

    # Sombra discreta abaixo do chapéu.
    draw.ellipse(
        (cx - cap_w * 0.34, canvas_size * 0.61, cx + cap_w * 0.34, canvas_size * 0.69),
        fill=shadow,
    )

    # Aba superior em losango.
    left = (cx - cap_w / 2, top_y + top_h / 2)
    top = (cx, top_y)
    right = (cx + cap_w / 2, top_y + top_h / 2)
    bottom = (cx, top_y + top_h)
    draw.polygon([left, top, right, bottom], fill=gold)
    draw.line([left, top, right], fill=gold_light, width=max(1, round(canvas_size * 0.012)))
    draw.line([left, bottom, right], fill=gold_dark, width=max(1, round(canvas_size * 0.010)))

    # Corpo/base do chapéu.
    base_left = cx - cap_w * 0.30
    base_right = cx + cap_w * 0.30
    base_top = canvas_size * 0.50
    base_bottom = canvas_size * 0.62
    radius = max(2, round(canvas_size * 0.025))
    draw.rounded_rectangle(
        (base_left, base_top, base_right, base_bottom),
        radius=radius,
        fill=gold_dark,
        outline=gold,
        width=max(1, round(canvas_size * 0.010)),
    )
    draw.polygon(
        [
            (base_left, base_top),
            (cx, base_top + canvas_size * 0.055),
            (base_right, base_top),
            (base_right, base_top + canvas_size * 0.045),
            (cx, base_top + canvas_size * 0.095),
            (base_left, base_top + canvas_size * 0.045),
        ],
        fill=gold,
    )

    # Botão central e tassel do lado direito.
    button_r = canvas_size * 0.025
    draw.ellipse((cx - button_r, top_y + top_h * 0.44 - button_r, cx + button_r, top_y + top_h * 0.44 + button_r), fill=gold_light)
    tassel_start = (cx + button_r * 0.5, top_y + top_h * 0.46)
    tassel_mid = (cx + cap_w * 0.34, top_y + top_h * 0.68)
    tassel_end = (cx + cap_w * 0.34, canvas_size * 0.59)
    line_w = max(2, round(canvas_size * 0.022))
    draw.line([tassel_start, tassel_mid, tassel_end], fill=gold, width=line_w, joint='curve')
    tassel_r = canvas_size * 0.026
    draw.ellipse((tassel_end[0] - tassel_r, tassel_end[1] - tassel_r, tassel_end[0] + tassel_r, tassel_end[1] + tassel_r), fill=gold_light)
    fringe_y = tassel_end[1] + tassel_r * 0.75
    for offset in (-1.4, -0.7, 0, 0.7, 1.4):
        x = tassel_end[0] + offset * tassel_r * 0.45
        draw.line((x, fringe_y, x + offset * tassel_r * 0.12, fringe_y + canvas_size * 0.065), fill=gold, width=max(1, round(canvas_size * 0.009)))

    return image

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

    for old_name in (
        'ic_launcher.png', 'ic_launcher.jpg',
        'ic_launcher_round.png', 'ic_launcher_round.jpg',
        'ic_launcher_foreground.png', 'ic_launcher_foreground.jpg',
    ):
        old = mipmap_dir / old_name
        if old.exists():
            old.unlink()

    legacy = draw_cap(size, transparent=False)
    legacy.save(mipmap_dir / 'ic_launcher.png', format='PNG', optimize=True)
    legacy.save(mipmap_dir / 'ic_launcher_round.png', format='PNG', optimize=True)

    foreground_size = adaptive_sizes[density]
    foreground = draw_cap(foreground_size, transparent=True)
    foreground.save(mipmap_dir / 'ic_launcher_foreground.png', format='PNG', optimize=True)

values_dir = res / 'values'
values_dir.mkdir(parents=True, exist_ok=True)
(values_dir / 'launcher_colors.xml').write_text(
    '''<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#000000</color>\n</resources>\n''',
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

if 'android:icon="@mipmap/ic_launcher"' not in m:
    m = m.replace('<application', '<application\n        android:icon="@mipmap/ic_launcher"', 1)
if 'android:roundIcon=' not in m:
    m = m.replace(
        'android:icon="@mipmap/ic_launcher"',
        'android:icon="@mipmap/ic_launcher"\n        android:roundIcon="@mipmap/ic_launcher_round"',
        1,
    )

if 'academia_flow.notification_icon_keep' not in m:
    m = m.replace(
        '    </application>',
        '        <meta-data android:name="academia_flow.notification_icon_keep" android:resource="@drawable/ic_stat_academia_flow" />\n    </application>',
    )

receivers = '''\n        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />\n        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\n            <intent-filter>\n                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>\n                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>\n            </intent-filter>\n        </receiver>\n'''
if 'ScheduledNotificationReceiver' not in m:
    m = m.replace('    </application>', receivers + '    </application>')
manifest.write_text(m)

print('Android configurado: assinatura persistente, notificações e launcher gerado nativamente.')
