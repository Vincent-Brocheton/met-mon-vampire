import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, updateDoc, deleteDoc, writeBatch, serverTimestamp, collection, query, where } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const ev = (over) => ({
  type: 'intrigue', title: 'Son sire arrive', description: '', year: 2026, month: 2, day: 3,
  visibility: 'player', auto: false, byUid: 'lea', byName: 'lea', createdAt: new Date(), updatedAt: new Date(), ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur', max: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await setDoc(doc(db, 'characters/c1'), { name: 'Lucie', kind: 'pj', playerUid: 'zoe', status: 'active', version: 1 });
    await setDoc(doc(db, 'characters/c2'), { name: 'Léa joue', kind: 'pj', playerUid: 'lea', status: 'active', version: 1 });
    await setDoc(doc(db, 'characters/c1/events/pub'), ev({ visibility: 'public' }));
    await setDoc(doc(db, 'characters/c1/events/pl'), ev({ visibility: 'player' }));
    await setDoc(doc(db, 'characters/c1/events/st'), ev({ visibility: 'staff' }));
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

test('lecture : l’équipe voit tout, le joueur hors « conte seul », un autre joueur rien (Review Focus 1)', async () => {
  await assertSucceeds(getDocs(collection(as('julien'), 'characters/c1/events')));
  await assertSucceeds(getDoc(doc(as('zoe'), 'characters/c1/events/pub')));
  await assertSucceeds(getDoc(doc(as('zoe'), 'characters/c1/events/pl')));
  await assertFails(getDoc(doc(as('zoe'), 'characters/c1/events/st')));
  await assertSucceeds(getDocs(query(collection(as('zoe'), 'characters/c1/events'), where('visibility', 'in', ['public', 'player']))));
  await assertFails(getDocs(collection(as('zoe'), 'characters/c1/events')));
  await assertFails(getDoc(doc(as('max'), 'characters/c1/events/pl')));
});

test('écriture : le conte seulement, champs contrôlés (Review Focus 2 et 5)', async () => {
  const lea = as('lea');
  await assertSucceeds(setDoc(doc(lea, 'characters/c1/events/n1'), ev({})));
  await assertSucceeds(setDoc(doc(lea, 'characters/c1/events/n2'), ev({ month: null, day: null, year: 1974 })));
  await assertSucceeds(updateDoc(doc(lea, 'characters/c1/events/pl'), { title: 'Autre titre', byUid: 'lea', updatedAt: new Date() }));
  await assertFails(setDoc(doc(lea, 'characters/c1/events/n3'), ev({ type: 'inconnu' })));
  await assertFails(setDoc(doc(lea, 'characters/c1/events/n4'), ev({ month: null, day: 4 })));
  await assertFails(setDoc(doc(lea, 'characters/c1/events/n5'), ev({ title: '' })));
  await assertFails(setDoc(doc(lea, 'characters/c1/events/n6'), ev({ secret: 1 })));
  await assertFails(setDoc(doc(lea, 'characters/c1/events/n7'), ev({ byUid: 'julien' })));
  await assertFails(setDoc(doc(lea, 'characters/c1/events/n8'), ev({ year: 0 })));
  await assertFails(setDoc(doc(lea, 'characters/c1/events/n9'), ev({ visibility: 'tous' })));
  await assertFails(setDoc(doc(as('julien'), 'characters/c1/events/n10'), ev({ byUid: 'julien' })));
  await assertFails(setDoc(doc(as('zoe'), 'characters/c1/events/n11'), ev({ byUid: 'zoe' })));
  await assertFails(setDoc(doc(lea, 'characters/c2/events/n12'), ev({})));
  await assertFails(deleteDoc(doc(as('julien'), 'characters/c1/events/pl')));
  await assertSucceeds(deleteDoc(doc(lea, 'characters/c1/events/st')));
});

test('fiche créée par l’étreinte et son événement dans le même lot (Review Focus 4)', async () => {
  const lea = as('lea');
  const b = writeBatch(lea);
  b.set(doc(lea, 'characters/new1'), {
    name: 'Jeanne', kind: 'pnj', status: 'active', version: 1, lastHistoryId: 'h1',
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });
  b.set(doc(lea, 'characters/new1/history/h1'), { at: serverTimestamp(), byUid: 'lea', byName: 'lea', kind: 'creation', summary: ['Fiche créée'], reason: '' });
  b.set(doc(lea, 'characters/new1/events/e1'), ev({ type: 'embrace', title: 'Étreinte par Lucie', auto: true }));
  await assertSucceeds(b.commit());
});
