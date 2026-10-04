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

const file = (over) => ({
  kind: 'animal', name: 'Rex', domitorId: 'c1', domitorName: 'Isaure', attachment: '', holderPlayers: ['zoe'],
  specialties: [], qualities: [], vitae: 2, bond: 1, lastDrink: null, description: '', releasedAt: null,
  version: 1, lastHistoryId: 'h1', ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur', max: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await setDoc(doc(db, 'servants/s1'), file({}));
    await setDoc(doc(db, 'servants/s1/private/note'), { text: 'Secret' });
    await setDoc(doc(db, 'servants/s1/history/h1'), { at: new Date(), byUid: 'lea', byName: 'lea', summary: ['Fiche créée'], reason: '' });
    await setDoc(doc(db, 'servants/m1'), file({ kind: 'mortal', name: 'Jeanne', domitorId: null, holderPlayers: [] }));
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

/// Fiche et son entrée d'historique dans un même lot.
function saved(uid, id, data, { history = true } = {}) {
  const db = as(uid);
  const b = writeBatch(db);
  b.set(doc(db, `servants/${id}`), { ...data, lastHistoryId: 'hx' });
  if (history) b.set(doc(db, `servants/${id}/history/hx`), { at: serverTimestamp(), byUid: uid, byName: uid, summary: [], reason: '' });
  return b.commit();
}

test('lecture : joueur du domitor, équipe ; ni les autres, ni la note, ni un mortel (Review Focus 3)', async () => {
  await assertSucceeds(getDoc(doc(as('zoe'), 'servants/s1')));
  await assertSucceeds(getDocs(query(collection(as('zoe'), 'servants'), where('holderPlayers', 'array-contains', 'zoe'))));
  await assertFails(getDoc(doc(as('max'), 'servants/s1')));
  await assertFails(getDoc(doc(as('zoe'), 'servants/m1')));
  await assertFails(getDoc(doc(as('zoe'), 'servants/s1/private/note')));
  await assertFails(getDoc(doc(as('zoe'), 'servants/s1/history/h1')));
  await assertSucceeds(getDoc(doc(as('julien'), 'servants/m1')));
  await assertSucceeds(getDoc(doc(as('julien'), 'servants/s1/private/note')));
});

test('modification : conte seulement, version + 1 et historique dans le même lot (Review Focus 4)', async () => {
  await assertFails(saved('lea', 's1', file({ version: 2 }), { history: false }));
  await assertFails(saved('lea', 's1', file({ version: 3 })));
  await assertFails(saved('julien', 's1', file({ version: 2 })));
  await assertFails(saved('zoe', 's1', file({ version: 2 })));
  await assertSucceeds(saved('lea', 's1', file({ version: 2, vitae: 3 })));
});

test('fiche invalide refusée, création valide, suppression par le conte', async () => {
  await assertFails(saved('lea', 's9', file({ vitae: 6 })));
  await assertFails(saved('lea', 's9', file({ bond: 4 })));
  await assertFails(saved('lea', 's9', file({ kind: 'dragon' })));
  await assertFails(saved('lea', 's9', file({ name: '' })));
  await assertFails(saved('lea', 's9', file({ version: 2 })));
  await assertSucceeds(saved('lea', 's9', file({})));
  await assertFails(deleteDoc(doc(as('julien'), 'servants/s9')));
  await assertFails(deleteDoc(doc(as('julien'), 'servants/s1/history/h1')));
  await assertSucceeds(deleteDoc(doc(as('lea'), 'servants/s1/history/h1')));
  await assertSucceeds(deleteDoc(doc(as('lea'), 'servants/s9')));
});
