# Общая семья и единый аккаунт: Чистый Лист ↔ YouBoost

## Идея

Оба приложения работают с **одним Firebase-проектом `poleznie-privichki`**:

- **Единый аккаунт.** Вход через Google в любом приложении даёт один и тот же
  `uid`, так что пользователь один.
- **Общая семья.** Ядро семьи хранится в формате YouBoost Kids. Семью можно
  создать в любом из двух приложений, и она сразу появится в другом. Импорт
  не нужен: это те же документы.
- **Свои данные у каждого приложения.** Уборку Чистый Лист хранит в
  `households/{fid}` под тем же id, что и семья. YouBoost эти коллекции не
  читает и не меняет.

## Карта данных

| Что | Где лежит | Кто пишет |
|---|---|---|
| В какой семье пользователь | `kidsUsers/{uid}` → `{ fid }` | оба |
| Семья: название, владелец, родители | `kidsFamilies/{fid}` (`name`, `owner`, `parents`, `rewards`, `challenges`, `createdAt`) | оба |
| Участники: родители и телефоны детей | `kidsFamilies/{fid}/members/{uid}` (`role: parent\|child`, `name`, `kidId`, `code`) | оба |
| Общая карточка ребёнка | `kidsFamilies/{fid}/kids/{kidId}` (`name`, `age`, `avatar`, `color`, `habits`, …) | оба |
| Коды подключения | `kidsCodes/{code}` (6 символов `A–Z/2–9`, действуют сутки) | оба |
| Профиль пользователя | `users/{uid}` (`email`, `displayName`, `photoUrl`, `createdAt`; поля YouBoost не трогаются) | оба |
| Комнаты, модификаторы, PIN, код приглашения | `households/{fid}` | Чистый Лист |
| Питомец, пуговицы и серия взрослого | `households/{fid}/members/{uid}` | Чистый Лист |
| Возрастная группа, питомец, золотые пуговицы ребёнка, Банк желаний | `households/{fid}/children/{kidId}` | Чистый Лист |
| Квесты, Альбом Побед | `households/{fid}/child_quests`, `victory_album` | Чистый Лист |
| Списки покупок и архив походов | `households/{fid}/shopping_items`, `shopping_trips` | Чистый Лист |

### Отличия от исходной схемы задания

| В задании | В реализации | Почему |
|---|---|---|
| `users/{uid}.activeHouseholdId` | `kidsUsers/{uid}.fid` | так семья общая с YouBoost |
| `households/{id}/members/{memberId}.role` | роль `parent` из `kidsFamilies/.../members`; `admin` = владелец семьи (`owner`) | правила YouBoost: управлять семьёй может любой родитель |
| `households/{id}/children/{childId}` | общая карточка `kids/{kidId}` + надстройка `children/{kidId}` | ребёнок один на оба приложения |
| `linkedUid`, `isManagedLocally` | вычисляются по участникам `role: 'child'` с этим `kidId` | один источник правды, у ребёнка может быть несколько устройств |
| `inviteCode` / `linkCode` из 6 цифр, бессрочные | коды YouBoost (6 букв и цифр, сутки) | код из одного приложения работает в другом |

## Сценарии

- **Создать семью в Чистом Листе.** Записываются `kidsFamilies/{fid}`,
  `members/{uid}` (`parent`) и `kidsUsers/{uid}`, затем `households/{fid}`.
  YouBoost увидит семью на вкладке «Дети».
- **Семья уже есть в YouBoost.** При входе в Чистый Лист пользователь попадает
  на экран «Настройка Дома»: комнаты, модификаторы, питомец, PIN. Состав семьи
  и дети подтягиваются сами.
- **Второй взрослый.** Код приглашения создаётся в любом приложении и вводится
  в любом.
- **Ребёнок.** Если добавить его в Чистом Листе, он появится и в YouBoost (без
  привычек). Если его создали в YouBoost, Чистый Лист определит возрастную
  группу по `age`.
- **Телефон ребёнка.** Код «Привязать телефон» из Чистого Листа подходит и для
  YouBoost Kids, и наоборот.

## Что сделать в Firebase

1. **Зарегистрировать приложения.** В проекте `poleznie-privichki` добавить
   Android- и iOS-приложения Чистого Листа:
   `flutterfire configure --project=poleznie-privichki`.
2. **Правила Firestore.** Вставить [`firebase/firestore.cleanpage.rules`](../firebase/firestore.cleanpage.rules)
   в `firestore.rules` репозитория Poleznieprivichki, сразу после раздела
   «YouBoost Kids», и опубликовать оттуда. Публиковать правила из Housemagic
   нельзя: они затрут правила YouBoost.
3. **Storage.** Включить Cloud Storage и опубликовать
   [`firebase/storage.rules`](../firebase/storage.rules).
4. **Google-вход.** Добавить SHA-1/SHA-256 Android-приложения в Firebase.
   Домен веб-версии добавить в Authentication → Settings → Authorized domains.

## Возможные следующие шаги

- **Общая валюта.** Сейчас золотые пуговицы Чистого Листа и звёзды YouBoost
  считаются раздельно. Их можно объединить или сделать «обмен» в Банке желаний.
- **Квесты как задачи YouBoost.** Квест Чистого Листа можно показывать в
  YouBoost Kids как разовую задачу: `habits[]` с полем `once`, как делает
  `sendTask` в YouBoost.
