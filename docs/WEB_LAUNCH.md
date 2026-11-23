# Запуск веб-версии

Сайт собирается и публикуется сам при каждом пуше в `main`
(`.github/workflows/pages.yml`):

| Адрес | Что это |
|---|---|
| https://shusandrik23.github.io/Housemagic/ | приложение с настоящей базой (Firebase-проект `poleznie-privichki`) |
| https://shusandrik23.github.io/Housemagic/demo/ | демо без Firebase: тестовая семья, PIN родителя `1234` |

## Что нужно сделать один раз

1. **Включить GitHub Pages.** GitHub → Housemagic → Settings → Pages →
   Build and deployment → Source: **GitHub Actions**. Потом перезапустить
   последний запуск во вкладке Actions или сделать любой пуш в `main`.
2. **Разрешить вход через Google с этого адреса.** Firebase Console →
   `poleznie-privichki` → Authentication → Settings → Authorized domains →
   Add domain → `shusandrik23.github.io`.
3. **Опубликовать правила Firestore.** Применить патч с разделом Чистого
   Листа в репозитории Poleznieprivichki (`firestore.rules`) и опубликовать
   правила оттуда: `firebase deploy --only firestore:rules` или вставить
   файл в Firebase Console → Firestore → Rules. Без этого приложение не
   сможет создать Дом (ошибка `permission-denied`).
4. **Фото квестов (по желанию).** Firebase Console → Storage → Get started,
   затем вставить [`firebase/storage.rules`](../firebase/storage.rules) во
   вкладку Rules. Без Storage работает всё, кроме фото-отчётов детей.

## Проверка после запуска

- Открыть сайт, «Войти через Google». Должен открыться выбор «Создать
  новый Дом / Присоединиться».
- Создать Дом, затем открыть YouBoost тем же аккаунтом: семья должна
  быть там.
- Если вход не открывается или пишет `auth/unauthorized-domain`, значит не
  сделан шаг 2. Если при создании Дома ошибка `permission-denied`, значит
  не сделан шаг 3.
