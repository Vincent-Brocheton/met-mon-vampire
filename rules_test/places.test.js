import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, deleteDoc, writeBatch, serverTimestamp, collection, query, where } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const place = (over) => ({
  name: 'Opéra municipal', type: 'prestige', rank: 4, qualities: [], holders: [{ id: 'c1', name: 'Isaure' }],
  holderIds: ['c1'], holderPlayers: ['zoe'], public: false, known: '', version: 1, lastHistoryId: 'h1', ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur', max: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await setDoc(doc(db, 'places/p1'), place({}));
    await setDoc(doc(db, 'places/p1/private/note'), { text: 'Secret' });
    await setDoc(doc(db, 'places/p1/history/h1'), { at: new Date(), byUid: 'lea', byName: 'lea', summary: ['Lieu créé'], reason: '' });
    await setDoc(doc(db, 'publicPlaces/p2'), { name: 'Hôtel de ville', type: 'prestige', known: 'La mairie.' });
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

/// Lieu et son entrée d'historique dans un même lot.
function saved(uid, id, data, { history = true } = {}) {
  const db = as(uid);
  const b = writeBatch(db);
  b.set(doc(db, `places/${id}`), { ...data, lastHistoryId: 'hx' });
  if (history) b.set(doc(db, `places/${id}/history/hx`), { at: serverTimestamp(), byUid: uid, byName: uid, summary: [], reason: '' });
  return b.commit();
}

test('lecture : le joueur du personnage attribué, l’équipe ; pas les autres (Review Focus 2)', async () => {
  await assertSucceeds(getDoc(doc(as('zoe'), 'places/p1')));
  await assertSucceeds(getDocs(query(collection(as('zoe'), 'places'), where('holderPlayers', 'array-contains', 'zoe'))));
  await assertFails(getDoc(doc(as('max'), 'places/p1')));
  await assertSucceeds(getDoc(doc(as('julien'), 'places/p1')));
  await assertFails(getDoc(doc(as('zoe'), 'places/p1/private/note')));
  await assertFails(getDoc(doc(as('zoe'), 'places/p1/history/h1')));
  await assertSucceeds(getDoc(doc(as('julien'), 'places/p1/private/note')));
  await assertSucceeds(getDoc(doc(as('julien'), 'places/p1/history/h1')));
});

test('résumés publics : lus par tous, écrits par le conte avec trois clés (Review Focus 1)', async () => {
  await assertSucceeds(getDoc(doc(as('max'), 'publicPlaces/p2')));
  await assertFails(setDoc(doc(as('zoe'), 'publicPlaces/p3'), { name: 'X', type: 'standard', known: '' }));
  await assertFails(setDoc(doc(as('lea'), 'publicPlaces/p3'), { name: 'X', type: 'standard', known: '', holders: [] }));
  await assertSucceeds(setDoc(doc(as('lea'), 'publicPlaces/p3'), { name: 'X', type: 'standard', known: '' }));
  await assertFails(deleteDoc(doc(as('zoe'), 'publicPlaces/p3')));
  await assertSucceeds(deleteDoc(doc(as('lea'), 'publicPlaces/p3')));
});

test('modification : version + 1 et historique dans le même lot (Review Focus 2 et 3)', async () => {
  await assertFails(saved('lea', 'p1', place({ version: 2 }), { history: false }));
  await assertFails(saved('lea', 'p1', place({ version: 3 })));
  await assertFails(saved('julien', 'p1', place({ version: 2 })));
  await assertFails(saved('zoe', 'p1', place({ version: 2 })));
  await assertSucceeds(saved('lea', 'p1', place({ version: 2, holders: [], holderIds: [], holderPlayers: [] })));
  await assertFails(getDoc(doc(as('zoe'), 'places/p1')));
});

test('lieu invalide refusé, création valide acceptée, suppression par le conte', async () => {
  await assertFails(saved('lea', 'p9', place({ rank: 6 })));
  await assertFails(saved('lea', 'p9', place({ type: 'castle' })));
  await assertFails(saved('lea', 'p9', place({ name: '' })));
  await assertFails(saved('lea', 'p9', place({ version: 2 })));
  await assertSucceeds(saved('lea', 'p9', place({})));
  await assertFails(deleteDoc(doc(as('julien'), 'places/p9')));
  await assertSucceeds(deleteDoc(doc(as('lea'), 'places/p9')));
});
