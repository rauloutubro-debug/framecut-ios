# FrameCut — editor nativo para iPhone e iPad

Implementação independente inicial inspirada no fluxo local de um editor de vídeo. Não é o código-fonte recuperado do CapCut e não possui paridade completa com ele. Não usa binários, ícones, fontes ou serviços privados do aplicativo analisado.

## Abrir no Mac

1. Abra `FrameCut.xcodeproj` no Xcode 15 ou posterior.
2. Selecione o scheme FrameCut e um simulador iPhone/iPad com iOS 17 ou posterior.
3. Execute com ⌘R. Para aparelho físico, selecione sua equipe em Signing & Capabilities e ajuste o bundle identifier se necessário.
4. Para gerar um IPA distribuível, configure sua assinatura Apple e use Product → Archive → Distribute App.

O projeto Xcode já está incluído. `make_project.py` permite regenerá-lo sem dependências Python externas. `project.yml` é uma alternativa para XcodeGen; não é necessário instalá-lo para abrir o projeto incluído.

## Implementado no código

- Biblioteca local com projetos persistidos em JSON e mídia copiada para Documents.
- Importação múltipla de vídeos pelo app Arquivos (inclui provedores iCloud disponíveis no dispositivo).
- Prévia com AVPlayer; montagem sequencial com AVMutableComposition.
- Corte por início/fim, divisão ao meio, reordenação e remoção de clipes.
- Áudio original com opção de silenciar por clipe.
- Texto fixo sobre toda a composição, incorporado ao MP4 via Core Animation.
- Exportação 1080 × 1920, 30 fps, com ajuste da imagem sem cortar e fundo preto.
- Compartilhamento do MP4 e salvamento em Fotos com solicitação de acesso somente para adicionar.
- Salvamento ao concluir e ao sair do editor. A mídia é mantida ao excluir projetos.

## Limites

Este ambiente Linux não tem Swift, Xcode, SDK iOS ou simulador. O código **não foi compilado nem executado em iOS**. Inspeção de arquivos e revisão estática não substituem testes de vídeo, orientação, áudio, memória, interface ou assinatura no Mac.

Não inclui legendas automáticas, catálogo de templates, efeitos/IA, música adicional, camadas de vídeo, transições, keyframes, conta, assinatura, nuvem ou integração TikTok. A interface é própria; o IPA não foi executado para observar as telas originais. A posição e a escala do texto na prévia são aproximadas; conferir o MP4 exportado. Dividir usa o ponto médio, não o cursor da prévia. Renderização usa uma composição integral na memória e pode ser cara em projetos longos. Arquivos temporários de exportação e mídias órfãs não têm coleta automática nesta versão.

## Validação necessária no Xcode

```sh
xcodebuild -project FrameCut.xcodeproj -scheme FrameCut -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Teste no aparelho: importar dois vídeos (um retrato e um paisagem), cortar ambos, dividir/reordenar, silenciar um clipe, inserir texto e exportar. Verifique duração, ordem, rotação, áudio e texto no MP4. Feche e abra o aplicativo para conferir os projetos. Confira cancelamento do importador, arquivo inválido e acesso a Fotos negado. Teste vídeos com e sem áudio e mídia de taxa variável antes de distribuir.

## Gerar IPA para assinatura por sideload

Em um Mac com Xcode completo instalado, execute na pasta do projeto:

```sh
bash scripts/build-ipa.sh
```

O script compila para iPhone/iPad e empacota `build/FrameCut-unsigned.ipa`. Esse arquivo ainda precisa de assinatura para instalar; pode ser entregue ao AltStore ou Sideloadly para assinatura com sua conta Apple. O script não foi executado neste ambiente Linux. Ele não transforma o ZIP do código em aplicativo sem compilação.

## Compilar na nuvem, sem Mac

O workflow `.github/workflows/build-ios.yml` usa um runner macOS do GitHub Actions para compilar e publicar o IPA sem assinatura como artifact. Ele executa em pushes para main ou manualmente. Não foi executado nesta entrega: a integração GitHub não pode criar repositórios e não há um repositório acessível selecionado.
