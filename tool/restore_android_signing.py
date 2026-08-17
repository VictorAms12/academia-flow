from pathlib import Path

path = Path('android/app/build.gradle.kts')
text = path.read_text(encoding='utf-8')

# A assinatura release precisa permanecer idêntica às versões anteriores para
# permitir atualização in-place. As credenciais já pertencem à configuração
# histórica de assinatura deste projeto.
store_password = 'AcademiaFlow2026!'
key_password = 'AcademiaFlow2026!'

text = text.replace(
    'storePassword = System.getenv("ACADEMIA_FLOW_STORE_PASSWORD") ?: ""',
    f'storePassword = "{store_password}"',
)
text = text.replace(
    'keyPassword = System.getenv("ACADEMIA_FLOW_KEY_PASSWORD") ?: ""',
    f'keyPassword = "{key_password}"',
)

path.write_text(text, encoding='utf-8')
print('Assinatura release persistente restaurada para o build Android.')
