# Academia Flow 2.7.0 — Consolidação e Polimento

A versão 2.7.0 consolida a base do Academia Flow sem remover recursos existentes e prioriza segurança, previsibilidade de navegação, integridade dos dados, desempenho de inicialização e qualidade de build.

## Principais correções

- A chave de assinatura Android não fica mais versionada no código atual.
- O pipeline Android usa GitHub Actions Secrets para assinatura persistente quando configurados.
- Sem secrets de assinatura, o CI ainda produz um APK release instalável para testes, usando a assinatura de desenvolvimento gerada pelo Flutter.
- Flutter fixado na versão 3.47.0 nas pipelines Android e Windows.
- `flutter analyze` passa a ser obrigatório sem ignorar warnings.
- Navegação principal preserva estado de telas, abas e scroll ao alternar entre as cinco áreas principais.
- Notificações de atividades passam a direcionar para a atividade correspondente.
- Reset completo e limpeza acadêmica também limpam o estado da Rotina Inteligente.
- Windows informa explicitamente que notificações locais não estão disponíveis nesta versão.
- Anexos passam a ter limite de 50 MB para reduzir risco de pressão de memória no Android.
- Rotas animadas respeitam a configuração de redução de animações do sistema.
- Inicialização pesada de sessões futuras e reagendamento de notificações é concluída após a abertura da interface.
- Criações concorrentes idênticas são deduplicadas para reduzir registros duplicados por toques repetidos.
- Matérias sem histórico deixam de aparecer visualmente como 100% de frequência.
- Tarefas passam a registrar o momento de conclusão, permitindo calcular corretamente a taxa de entregas no prazo.
- Banco SQLite atualizado para a versão 5 com migration não destrutiva de `completed_at` em atividades.
- Versão atualizada para `2.7.0+24`.

## Assinatura Android

Para manter uma linha de atualização persistente, configure no repositório os seguintes GitHub Actions Secrets:

- `ACADEMIA_FLOW_KEYSTORE_B64`: keystore de upload codificado em Base64.
- `ACADEMIA_FLOW_STORE_PASSWORD`: senha do keystore.
- `ACADEMIA_FLOW_KEY_PASSWORD`: senha da chave `academiaflow`.

A chave usada anteriormente foi exposta no histórico do repositório e deve ser considerada comprometida. Para uma distribuição de produção, gere/registre uma nova chave de upload conforme o canal de distribuição adotado e remova o material antigo também do histórico Git, se necessário.

> A rotação de uma chave muda a assinatura do APK. Instalações feitas com uma assinatura anterior podem exigir desinstalação antes de instalar um APK assinado por uma nova chave, salvo quando a plataforma de distribuição oferece um fluxo formal de rotação de chave.

## Compatibilidade

A migration mantém os dados existentes. O aplicativo continua sendo gerado como APK Android e pacote portátil Windows pelas GitHub Actions.
