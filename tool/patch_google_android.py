from pathlib import Path

root = Path('android')
app_gradle = root / 'app' / 'build.gradle.kts'
text = app_gradle.read_text()
text = text.replace('minSdk = flutter.minSdkVersion', 'minSdk = 24')
app_gradle.write_text(text)

manifest = root / 'app' / 'src' / 'main' / 'AndroidManifest.xml'
m = manifest.read_text()
if 'android.permission.INTERNET' not in m:
    m = m.replace(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    <uses-permission android:name="android.permission.INTERNET"/>',
    )
manifest.write_text(m)

print('Google Android configurado: minSdk 24 e permissão de internet.')
