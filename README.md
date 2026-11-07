# Álbum de Casamento (Flutter – Android & iOS)

Álbum com música de fundo, navegação entre fotos, zoom (pinça/duplo toque), slideshow e proteção contra print/gravação.

## Pastas
- `assets/fotos/` – coloque as fotos (.jpg, .png, .webp)
- `assets/musicas/` – coloque as músicas (.mp3, .m4a, .aac, .wav)

Tudo é detectado automaticamente em ordem alfabética.

## Primeiros passos
Instale o [Flutter](https://docs.flutter.dev/get-started/install) e, na raiz:

```
flutter create --project-name album_casamento --org com.seudominio --platforms android,ios .
flutter pub get
flutter run
```
(`flutter create .` gera as pastas `android/` e `ios/` sem sobrescrever `lib/` e `pubspec.yaml`.)

iOS: `just_audio` e `screen_protector` exigem iOS 12+ (ajuste `platform :ios, '13.0'` no `ios/Podfile`).

## Proteção
- **Android**: `FLAG_SECURE` – print e gravação de tela ficam pretos.
- **iOS**: o sistema não permite bloquear screenshot; o app oculta o conteúdo em gravação/espelhamento e no seletor de apps.
- O app não oferece salvar, compartilhar ou copiar.

> Nenhuma proteção é 100%: fotografar a tela com outro aparelho é impossível de impedir. Para reduzir riscos, use fotos com resolução moderada e, se publicar, considere marca d'água.

## Hospedagem
Publique o app nas lojas (Google Play / App Store ou TestFlight / distribuição interna). Quem tiver o app verá o álbum embutido. Para atualizar fotos sem republicar, seria necessário um backend (ex.: Firebase Storage com autenticação).
