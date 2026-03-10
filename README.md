# Telegram Downloader - App Multiplataforma

Aplicacion Flutter multiplataforma (Android, Windows, macOS, Linux) para gestionar descargas de Telegram. Se conecta al backend del servidor Telegram Torznab mediante la API REST v2.

## Descargas

Binarios precompilados disponibles en [GitHub Releases](https://github.com/kno/telegram-downloader-app/releases/latest):

| Plataforma | Archivo |
|------------|---------|
| Android | `telegram-downloader-android-vX.X.X.apk` |
| Linux | `telegram-downloader-linux-vX.X.X.zip` |
| macOS | `telegram-downloader-macos-vX.X.X.zip` |
| Windows | `telegram-downloader-windows-vX.X.X.zip` |

Cada push a `main` genera automaticamente una nueva release con binarios para las 4 plataformas.

## Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.2.0
- Para Android: Android SDK, JDK 17+
- Para Windows: Visual Studio 2022 con "Desktop development with C++"
- Para macOS: Xcode 14+
- Para Linux: clang, cmake, ninja-build, pkg-config, libgtk-3-dev, liblzma-dev

## Instalacion

```bash
# Instalar dependencias
flutter pub get

# Verificar que todo esta correcto
flutter doctor
```

## Ejecucion

```bash
# Android (emulador o dispositivo conectado)
flutter run -d android

# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux

# Modo debug con hot-reload
flutter run
```

## Compilacion

```bash
# APK para Android
flutter build apk --release

# App Bundle para Google Play
flutter build appbundle --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

## Configuracion

1. Abre la app
2. Ve a **Ajustes**
3. Introduce la **API Key** (la misma que `TORZNAB_APIKEY` del servidor)
4. Introduce la **URL del servidor** (ej: `http://192.168.1.100:9117`)
5. Pulsa **Probar conexion** para verificar
6. Pulsa **Guardar**

## API Backend (v2)

La app usa los endpoints REST JSON en `/api/v2/`:

| Endpoint | Metodo | Descripcion |
|----------|--------|-------------|
| `/api/v2/health` | GET | Health check |
| `/api/v2/channels` | GET | Listar canales |
| `/api/v2/search` | GET | Buscar en canales |
| `/api/v2/downloads` | GET | Listar descargas |
| `/api/v2/stats` | GET | Estadisticas |
| `/api/v2/downloads` | POST | Iniciar descarga |
| `/api/v2/downloads/{id}` | DELETE | Eliminar descarga |
| `/api/v2/downloads/{id}/pause` | POST | Pausar |
| `/api/v2/downloads/{id}/resume` | POST | Reanudar |
| `/api/v2/downloads/{id}/file` | GET | Descargar archivo |
| `/api/v2/ws/downloads` | WS | Progreso en tiempo real |

Todos los endpoints (excepto health) requieren `?apikey=TU_API_KEY`.

## Estructura del proyecto

```
lib/
  main.dart                    # Entry point + MaterialApp + navegacion
  models/
    channel.dart               # Modelo de canal
    download.dart              # Modelo de descarga con constantes de estado
    search_result.dart         # Modelo de resultado de busqueda
    session_stats.dart         # Estadisticas de sesion
  services/
    api_service.dart           # Cliente HTTP para API v2
    websocket_service.dart     # WebSocket con auto-reconexion
    storage_service.dart       # Persistencia local (SharedPreferences)
  providers/
    settings_provider.dart     # API key, URL del servidor
    channels_provider.dart     # Canales con estado enabled/disabled
    downloads_provider.dart    # Descargas con WebSocket
    theme_provider.dart        # Tema claro/oscuro
  screens/
    dashboard_screen.dart      # Inicio: stats + descargas activas
    search_screen.dart         # Buscar con filtros temporada/episodio
    downloads_screen.dart      # Todas las descargas con progreso
    channels_screen.dart       # Gestionar canales habilitados
    settings_screen.dart       # Configuracion + test conexion
  widgets/
    search_result_card.dart    # Tarjeta de resultado con boton descargar
    download_row.dart          # Fila de descarga con acciones
  utils/
    formatters.dart            # formatSize, formatSpeed, formatEta, formatDate
```
