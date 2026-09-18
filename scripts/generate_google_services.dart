import 'dart:convert';
import 'dart:io';

/// Script utilitario para generar android/app/google-services.json
/// a partir de las variables de entorno definidas en .env.
///
/// Uso:
///   dart run scripts/generate_google_services.dart
void main() {
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('ERROR: Archivo .env no encontrado en la raíz del proyecto.');
    print('Copia .env.example como .env y completa las credenciales de Firebase.');
    exit(1);
  }

  final lines = envFile.readAsLinesSync();
  final envMap = <String, String>{};

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final eqIndex = trimmed.indexOf('=');
    if (eqIndex != -1) {
      final key = trimmed.substring(0, eqIndex).trim();
      final value = trimmed.substring(eqIndex + 1).trim();
      envMap[key] = value;
    }
  }

  final projectNumber = envMap['FIREBASE_PROJECT_NUMBER'] ?? '';
  final projectId = envMap['FIREBASE_PROJECT_ID'] ?? '';
  final storageBucket = envMap['FIREBASE_STORAGE_BUCKET'] ?? '';
  final mobileAppId = envMap['FIREBASE_MOBILE_SDK_APP_ID'] ?? '';
  final apiKey = envMap['FIREBASE_API_KEY'] ?? '';
  final packageName = envMap['FIREBASE_PACKAGE_NAME'] ?? 'com.example.marth_app';

  if (apiKey.isEmpty || projectId.isEmpty) {
    print('ADVERTENCIA: Claves de Firebase vacías o incompletas en .env.');
  }

  final googleServicesJson = {
    "project_info": {
      "project_number": projectNumber,
      "project_id": projectId,
      "storage_bucket": storageBucket,
    },
    "client": [
      {
        "client_info": {
          "mobilesdk_app_id": mobileAppId,
          "android_client_info": {
            "package_name": packageName,
          }
        },
        "oauth_client": [],
        "api_key": [
          {
            "current_key": apiKey,
          }
        ],
        "services": {
          "appinvite_service": {
            "other_platform_oauth_client": []
          }
        }
      }
    ],
    "configuration_version": "1"
  };

  final targetFile = File('android/app/google-services.json');
  targetFile.parent.createSync(recursive: true);
  targetFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(googleServicesJson) + '\n',
  );

  print('EXITO: android/app/google-services.json generado correctamente desde .env.');
}
