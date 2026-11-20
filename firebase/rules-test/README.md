# Тест правил Firestore

Правила общие для YouBoost и Чистого Листа и лежат в репозитории
Poleznieprivichki (`firestore.rules`). Тест проверяет на эмуляторе сценарии
Чистого Листа и то, что правила YouBoost не сломались.

```bash
cd firebase/rules-test
npm install
RULES_PATH=/путь/к/Poleznieprivichki/firestore.rules npm test
```

Нужна Java 11 или новее (для эмулятора).
