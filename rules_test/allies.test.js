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

const file = (over) => ({
  name: 'Me Castan', characterId: 'c1', characterName: 'Isaure', holderPlayers: ['zoe'],
  usedAt: null, returnAt: null, lastUse: '', version: 1, ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur', max: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await setDoc(doc(db, 'allies/a1'), file({ lastHistoryId: 'h1' }));
    await setDoc(doc(db, 'allies/a1/history/h1'), { at: new Date(), byUid: 'lea', byName: 'lea', summary: ['Utilisé'], reason: '' });
    await setDoc(doc(db, 'characters/d1'), { name: 'Brouillon', playerUid: 'zoe', kind: 'pj', status: 'draft', version: 1, creation: {} });
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

function saved(uid, id, data, { history = true } = {}) {
  const db = as(uid);
  const b = writeBatch(db);
  b.set(doc(db, `allies/${id}`), { ...data, lastHistoryId: 'hx' });
  if (history) b.set(doc(db, `allies/${id}/history/hx`), { at: serverTimestamp(), byUid: uid, byName: uid, summary: [], reason: '' });
  return b.commit();
}

test('suivi : lu par le joueur du personnage et l’équipe ; historique à l’équipe', async () => {
  await assertSucceeds(getDoc(doc(as('zoe'), 'allies/a1')));
  await assertSucceeds(getDocs(query(collection(as('zoe'), 'allies'), where('holderPlayers', 'array-contains', 'zoe'))));
  await assertFails(getDoc(doc(as('max'), 'allies/a1')));
  await assertSucceeds(getDoc(doc(as('julien'), 'allies/a1')));
  await assertFails(getDoc(doc(as('zoe'), 'allies/a1/history/h1')));
});

test('suivi : écrit par le conte avec version et historique', async () => {
  await assertSucceeds(saved('lea', 'a2', file({})));
  await assertFails(saved('lea', 'a3', file({}), { history: false }));
  await assertFails(saved('julien', 'a4', file({})));
  await assertFails(saved('zoe', 'a5', file({})));
  await assertFails(saved('lea', 'a6', file({ name: '' })));
  await assertFails(saved('lea', 'a7', file({ secret: 1 })));
  await assertSucceeds(saved('lea', 'a1', file({ version: 2, lastUse: 'Plainte classée.' })));
  await assertFails(saved('lea', 'a1', file({ version: 2 })));
  await assertSucceeds(deleteDoc(doc(as('lea'), 'allies/a1')));
});

test('brouillon du joueur : la clé allies est protégée (Review Focus 3)', async () => {
  await assertSucceeds(updateDoc(doc(as('zoe'), 'characters/d1'), { concept: 'Avocate', version: 2 }));
  await assertFails(updateDoc(doc(as('zoe'), 'characters/d1'), { allies: [{ id: 'd1-a1', name: 'X', level: 5 }], version: 3 }));
});

test('brouillon du joueur : la forme réelle de draftData (clés tardives vides, sans allies) est acceptée', async () => {
  const late = { rituals: [], techniques: [], elderPowers: [], attributeBonus: { physical: 0, social: 0, mental: 0 }, servants: [] };
  await assertSucceeds(updateDoc(doc(as('zoe'), 'characters/d1'), { ...late, concept: 'Avocate', version: 2 }));
  await assertFails(updateDoc(doc(as('zoe'), 'characters/d1'), { ...late, allies: [], concept: 'Juge', version: 3 }));
});
