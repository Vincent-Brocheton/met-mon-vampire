import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDocs, updateDoc, deleteDoc, collection, writeBatch, serverTimestamp } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const sin = (over) => ({
  date: new Date('2026-09-20T00:00:00'), level: 2, what: 'A blessé un vigile', remorse: 'failed', lossApplied: false,
  byUid: 'lea', byName: 'lea', createdAt: new Date(), updatedAt: new Date(), ...over,
});
const ev = (over) => ({
  type: 'morality', title: 'Humanité 5 → 4, Distante', description: '', year: 2026, month: 9, day: 20,
  visibility: 'player', auto: true, byUid: 'lea', byName: 'lea', createdAt: new Date(), updatedAt: new Date(), ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur', max: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await setDoc(doc(db, 'characters/c1'), { name: 'Lucie', kind: 'pj', playerUid: 'zoe', status: 'active', version: 1 });
    await setDoc(doc(db, 'characters/c2'), { name: 'Léa joue', kind: 'pj', playerUid: 'lea', status: 'active', version: 1 });
    await setDoc(doc(db, 'characters/d1'), { name: 'Brouillon', kind: 'pj', playerUid: 'zoe', status: 'draft', version: 1, creation: {} });
    await setDoc(doc(db, 'characters/c1/sins/open'), sin({}));
    await setDoc(doc(db, 'characters/c1/sins/locked'), sin({ lossApplied: true }));
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

test('lecture : le joueur de la fiche et l’équipe, pas un autre joueur', async () => {
  await assertSucceeds(getDocs(collection(as('zoe'), 'characters/c1/sins')));
  await assertSucceeds(getDocs(collection(as('julien'), 'characters/c1/sins')));
  await assertFails(getDocs(collection(as('max'), 'characters/c1/sins')));
});

test('écriture : le conte seulement, champs contrôlés, jamais sur sa propre fiche', async () => {
  const lea = as('lea');
  await assertSucceeds(setDoc(doc(lea, 'characters/c1/sins/n1'), sin({})));
  await assertFails(setDoc(doc(lea, 'characters/c1/sins/n2'), sin({ level: 0 })));
  await assertFails(setDoc(doc(lea, 'characters/c1/sins/n3'), sin({ level: 11 })));
  await assertFails(setDoc(doc(lea, 'characters/c1/sins/n4'), sin({ remorse: 'peut-être' })));
  await assertFails(setDoc(doc(lea, 'characters/c1/sins/n5'), sin({ what: 'x'.repeat(501) })));
  await assertFails(setDoc(doc(lea, 'characters/c1/sins/n6'), sin({ date: '20/09/2026' })));
  await assertFails(setDoc(doc(lea, 'characters/c1/sins/n7'), sin({ secret: 1 })));
  await assertFails(setDoc(doc(lea, 'characters/c1/sins/n8'), sin({ byUid: 'julien' })));
  await assertFails(setDoc(doc(as('julien'), 'characters/c1/sins/n9'), sin({ byUid: 'julien' })));
  await assertFails(setDoc(doc(as('zoe'), 'characters/c1/sins/n10'), sin({ byUid: 'zoe' })));
  await assertFails(setDoc(doc(lea, 'characters/c2/sins/n11'), sin({})));
});

test('péché verrouillé après la perte (Review Focus 1)', async () => {
  const lea = as('lea');
  await assertSucceeds(updateDoc(doc(lea, 'characters/c1/sins/open'), { what: 'Autre', byUid: 'lea', updatedAt: new Date() }));
  await assertSucceeds(updateDoc(doc(lea, 'characters/c1/sins/open'), { lossApplied: true, byUid: 'lea', updatedAt: new Date() }));
  await assertFails(updateDoc(doc(lea, 'characters/c1/sins/locked'), { what: 'Autre', byUid: 'lea', updatedAt: new Date() }));
  await assertFails(deleteDoc(doc(lea, 'characters/c1/sins/locked')));
  await assertFails(deleteDoc(doc(as('julien'), 'characters/c1/sins/open')));
});

test('brouillon du joueur : path protégé ; événement « Moralité » accepté (Review Focus 3)', async () => {
  await assertSucceeds(updateDoc(doc(as('zoe'), 'characters/d1'), { concept: 'Avocate', version: 2 }));
  await assertFails(updateDoc(doc(as('zoe'), 'characters/d1'), { path: 'Voie de la Nuit', version: 3 }));
  await assertSucceeds(setDoc(doc(as('lea'), 'characters/c1/events/m1'), ev({})));
});

test('perte de la soirée en un lot : fiche, historique, deux péchés verrouillés, événement ; puis plus rien', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'characters/c1'), { name: 'Lucie', kind: 'pj', playerUid: 'zoe', status: 'active', version: 1, humanity: 5 });
  });
  const lea = as('lea');
  const lock = () => ({ lossApplied: true, byUid: 'lea', updatedAt: new Date() });
  const loss = (version, n) => {
    const b = writeBatch(lea);
    b.update(doc(lea, 'characters/c1'), { humanity: 4, version, lastHistoryId: `h${version}` });
    b.set(doc(lea, `characters/c1/history/h${version}`), {
      at: serverTimestamp(), byUid: 'lea', kind: 'edit', reason: 'Perte de la soirée du 20/09/2026', summary: ['Humanité 5 → 4'],
    });
    b.update(doc(lea, 'characters/c1/sins/open'), lock());
    b.update(doc(lea, 'characters/c1/sins/second'), lock());
    b.set(doc(lea, `characters/c1/events/m${n}`), ev({}));
    return b.commit();
  };
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'characters/c1/sins/second'), sin({ level: 3 }));
  });
  await assertSucceeds(loss(2, 1));
  // Les péchés sont verrouillés : le même lot ne passe plus.
  await assertFails(loss(3, 2));
});
