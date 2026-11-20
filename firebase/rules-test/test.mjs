import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, writeBatch, Timestamp, increment, collection, getDocs, query, where, serverTimestamp, deleteDoc } from 'firebase/firestore';

const env = await initializeTestEnvironment({
  projectId: 'demo-cleanpage',
  firestore: { rules: readFileSync(process.env.RULES_PATH || '../../../Poleznieprivichki/firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
});
const google = (uid) => env.authenticatedContext(uid, { firebase: { sign_in_provider: 'google.com' } }).firestore();
const anon = (uid) => env.authenticatedContext(uid, { firebase: { sign_in_provider: 'anonymous' } }).firestore();
let n = 0; const ok = async (name, p) => { await assertSucceeds(p); n++; console.log('✓', name); };
const no = async (name, p) => { await assertFails(p); n++; console.log('✓ (запрещено)', name); };
const exp = () => Timestamp.fromMillis(Date.now() + 23 * 3600e3);

const mom = google('mom'), dad = google('dad'), kidPhone = anon('kidPhone'), stranger = google('stranger');
const fid = 'fam1';

// 1. Создание семьи в Чистом Листе (как createHousehold)
let b = writeBatch(mom);
b.set(doc(mom, 'kidsFamilies', fid), { name: 'Дом', owner: 'mom', parents: { mom: 'Аня' }, challenges: [], rewards: [], createdAt: new Date().toISOString() });
b.set(doc(mom, 'kidsFamilies', fid, 'members', 'mom'), { role: 'parent', name: 'Аня' });
b.set(doc(mom, 'kidsUsers', 'mom'), { fid });
await ok('семья в формате YouBoost', b.commit());
b = writeBatch(mom);
b.set(doc(mom, 'households', fid), { ownerUid: 'mom', parentPinHash: 'h', inviteCode: null, inviteCodeExpires: null, modifiers: ['cat'], rooms: ['Кухня'], createdIn: 'cleanpage', createdAt: serverTimestamp() }, { merge: true });
b.set(doc(mom, 'households', fid, 'members', 'mom'), { uid: 'mom', name: 'Аня', petType: 'hedgehog', coinsBalance: increment(0), streakCount: increment(0) }, { merge: true });
await ok('надстройка households + статистика', b.commit());
await no('посторонний не создаёт households чужой семьи', setDoc(doc(stranger, 'households', 'fam1'), { rooms: [] }, { merge: true }));
await no('посторонний не читает households', getDoc(doc(stranger, 'households', fid)));

// 2. Ребёнок (как addChild)
b = writeBatch(mom);
b.set(doc(mom, 'kidsFamilies', fid, 'kids', 'kid1'), { name: 'Миша', age: 8, avatar: '🦁', color: '#ff8a3d', habits: [], marks: {}, approved: {}, requests: [], decisions: {}, bonus: [], chMarks: {}, pet: null, order: 0, createdAt: new Date().toISOString() });
b.set(doc(mom, 'households', fid, 'children', 'kid1'), { name: 'Миша', ageGroup: '7-10', petType: 'dragon', goldButtons: 0, streakCount: 0, wishes: [] });
await ok('ребёнок: карточка YouBoost + надстройка', b.commit());

// 3. Второй взрослый по коду (как joinAsParent)
await ok('код взрослого', setDoc(doc(mom, 'kidsCodes', 'ABC234'), { fid, role: 'parent', kidId: null, by: 'mom', expires: exp() }));
await ok('надстройка: inviteCode', setDoc(doc(mom, 'households', fid), { inviteCode: 'ABC234', inviteCodeExpires: exp() }, { merge: true }));
await ok('папа читает код', getDoc(doc(dad, 'kidsCodes', 'ABC234')));
await ok('папа → members', setDoc(doc(dad, 'kidsFamilies', fid, 'members', 'dad'), { role: 'parent', code: 'ABC234', name: 'Олег' }));
await ok('папа → kidsUsers', setDoc(doc(dad, 'kidsUsers', 'dad'), { fid }));
await ok('папа → parents', updateDoc(doc(dad, 'kidsFamilies', fid), { 'parents.dad': 'Олег' }));
await ok('папа → своя статистика', setDoc(doc(dad, 'households', fid, 'members', 'dad'), { uid: 'dad', name: 'Олег', petType: 'owl', coinsBalance: increment(0), streakCount: increment(0) }, { merge: true }));
await no('папа не меняет пуговицы мамы', setDoc(doc(dad, 'households', fid, 'members', 'mom'), { coinsBalance: increment(1000) }, { merge: true }));

// 4. Телефон ребёнка (как createLinkCode + linkDevice)
await ok('код ребёнка', setDoc(doc(mom, 'kidsCodes', 'KID234'), { fid, role: 'child', kidId: 'kid1', by: 'mom', expires: exp() }));
await ok('надстройка: linkCode', setDoc(doc(mom, 'households', fid, 'children', 'kid1'), { linkCode: 'KID234', linkCodeExpires: exp() }, { merge: true }));
await ok('телефон ребёнка → members', setDoc(doc(kidPhone, 'kidsFamilies', fid, 'members', 'kidPhone'), { role: 'child', kidId: 'kid1', code: 'KID234', name: 'Чистый Лист' }));
await ok('телефон ребёнка → kidsUsers', setDoc(doc(kidPhone, 'kidsUsers', 'kidPhone'), { fid }));
await ok('телефон ребёнка читает дом', getDoc(doc(kidPhone, 'households', fid)));

// 5. Квест
await ok('родитель выдаёт квест', setDoc(doc(mom, 'households', fid, 'child_quests', 'q1'), { childId: 'kid1', title: 'Носки', monster: 'Носочный Гоблин', emoji: '🧦', durationMinutes: 10, rewardButtons: 8, status: 'todo', photoUrl: null, parentComment: null }));
await setDoc(doc(mom, 'households', fid, 'child_quests', 'q2'), { childId: 'other', status: 'todo' });
await no('ребёнок не отправляет чужой квест', updateDoc(doc(kidPhone, 'households', fid, 'child_quests', 'q2'), { status: 'pending_approval', photoUrl: 'x' }));
await no('ребёнок не подтверждает квест сам', updateDoc(doc(kidPhone, 'households', fid, 'child_quests', 'q1'), { status: 'completed' }));
await no('ребёнок не меняет награду', updateDoc(doc(kidPhone, 'households', fid, 'child_quests', 'q1'), { status: 'pending_approval', rewardButtons: 999 }));
await ok('ребёнок отправляет фото на проверку', updateDoc(doc(kidPhone, 'households', fid, 'child_quests', 'q1'), { status: 'pending_approval', photoUrl: 'https://x', parentComment: null, submittedAt: serverTimestamp() }));
await no('ребёнок не начисляет себе пуговицы', setDoc(doc(kidPhone, 'households', fid, 'children', 'kid1'), { goldButtons: increment(100) }, { merge: true }));
b = writeBatch(mom);
b.update(doc(mom, 'households', fid, 'child_quests', 'q1'), { status: 'completed', approvedBy: 'mom' });
b.set(doc(mom, 'households', fid, 'children', 'kid1'), { goldButtons: increment(8), streakCount: 1, lastQuestDay: '2026-11-20' }, { merge: true });
b.set(doc(mom, 'households', fid, 'victory_album', 'p1'), { childId: 'kid1', childName: 'Миша', questTitle: 'Носки', photoUrl: 'https://x' });
await ok('«Принять ✨»: статус, пуговицы, альбом', b.commit());

// 5b. Ежедневные правила и мини-задача
await ok('мама отмечает свои правила дня', setDoc(doc(mom, 'households', fid, 'members', 'mom', 'days', '2026-11-20'), { rulesDone: ['bed'], allRulesRewarded: false }));
await no('папа не отмечает правила за маму', setDoc(doc(dad, 'households', fid, 'members', 'mom', 'days', '2026-11-20'), { rulesDone: ['bed', 'sink'] }));
await ok('папа читает отметки мамы', getDoc(doc(dad, 'households', fid, 'members', 'mom', 'days', '2026-11-20')));
await no('посторонний не читает отметки', getDoc(doc(stranger, 'households', fid, 'members', 'mom', 'days', '2026-11-20')));
await ok('родитель меняет правила дома', setDoc(doc(dad, 'households', fid), { dailyRules: [{ id: 'x', title: 'Вынести мусор', period: 'evening' }] }, { merge: true }));
await no('телефон ребёнка не меняет правила дома', setDoc(doc(kidPhone, 'households', fid), { dailyRules: [] }, { merge: true }));

// 6. Покупки
await ok('родитель добавляет покупку', setDoc(doc(dad, 'households', fid, 'shopping_items', 'i1'), { listType: 'household_supplies', title: 'Губки', isBought: true }));
await ok('список читается по запросу', getDocs(query(collection(mom, 'households', fid, 'shopping_items'), where('listType', '==', 'household_supplies'))));
await no('посторонний не читает покупки', getDocs(collection(stranger, 'households', fid, 'shopping_items')));
b = writeBatch(dad);
b.set(doc(dad, 'households', fid, 'shopping_trips', 't1'), { listType: 'household_supplies', itemCount: 1, reward: 25 });
b.delete(doc(dad, 'households', fid, 'shopping_items', 'i1'));
b.set(doc(dad, 'households', fid, 'members', 'dad'), { coinsBalance: increment(25) }, { merge: true });
await ok('«Завершить поход в магазин»', b.commit());

// 7. Семья, созданная в YouBoost (без надстройки) → донастройка
b = writeBatch(dad);
await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'kidsFamilies', 'yb'), { name: '', owner: 'yb1', parents: {}, rewards: [{ name: 'Кино' }], challenges: [] });
  await setDoc(doc(db, 'kidsFamilies', 'yb', 'members', 'yb1'), { role: 'parent', name: 'Папа' });
});
const yb1 = google('yb1');
b = writeBatch(yb1);
b.set(doc(yb1, 'households', 'yb'), { ownerUid: 'yb1', parentPinHash: 'h', rooms: ['Кухня'], modifiers: [], createdIn: 'youboost' }, { merge: true });
b.update(doc(yb1, 'kidsFamilies', 'yb'), { name: 'Дом у моря' });
b.set(doc(yb1, 'households', 'yb', 'members', 'yb1'), { uid: 'yb1', petType: 'owl' }, { merge: true });
await ok('донастройка семьи из YouBoost', b.commit());

// 8. YouBoost не затронут: старые правила работают как прежде
await ok('YouBoost: родитель меняет карточку ребёнка', updateDoc(doc(mom, 'kidsFamilies', fid, 'kids', 'kid1'), { habits: [{ id: 'h1', name: 'Зубы' }] }));
await ok('YouBoost: телефон ребёнка ставит отметку', updateDoc(doc(kidPhone, 'kidsFamilies', fid, 'kids', 'kid1'), { marks: { '2026-11-20': { h1: 1 } } }));
await no('YouBoost: телефон ребёнка не меняет имя', updateDoc(doc(kidPhone, 'kidsFamilies', fid, 'kids', 'kid1'), { name: 'Хакер' }));

console.log(`\nВсе проверки пройдены: ${n}`);
await env.cleanup();
process.exit(0);
