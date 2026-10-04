import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, updateDoc, deleteDoc, writeBatch, serverTimestamp, collection, query, where, Timestamp } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const item = (over) => ({
  name: 'Canne-épée', category: 'melee', grade: 'normal', qualities: ['Dissimulable'], extraQuality: null,
  characterId: 'c1', characterName: 'Isaure', playerUid: 'zoe', state: 'active', description: '', origin: '', refusal: '',
  version: 1, ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur', max: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await setDoc(doc(db, 'characters/c1'), { name: 'Isaure', playerUid: 'zoe', kind: 'pj', status: 'active' });
    await setDoc(doc(db, 'characters/c3'), { name: 'Octave', playerUid: 'zoe', kind: 'pj', status: 'dead' });
    await setDoc(doc(db, 'characters/c2'), { name: 'Rafael', playerUid: 'max', kind: 'pj', status: 'active' });
    await setDoc(doc(db, 'items/i1'), item({ lastHistoryId: 'h1' }));
    await setDoc(doc(db, 'items/i1/private/note'), { text: 'Secret' });
    await setDoc(doc(db, 'items/i1/history/h1'), { at: new Date(), byUid: 'lea', byName: 'lea', summary: ['Objet créé'], reason: '' });
    await setDoc(doc(db, 'items/r1'), item({ state: 'requested' }));
    await setDoc(doc(db, 'items/f1'), item({ state: 'refused', refusal: 'Trop cher.' }));
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

/// Objet et son entrée d'historique dans un même lot.
function saved(uid, id, data, { history = true } = {}) {
  const db = as(uid);
  const b = writeBatch(db);
  b.set(doc(db, `items/${id}`), { ...data, lastHistoryId: 'hx' });
  if (history) b.set(doc(db, `items/${id}/history/hx`), { at: serverTimestamp(), byUid: uid, byName: uid, summary: [], reason: '' });
  return b.commit();
}

const request = (over) => item({ state: 'requested', createdAt: serverTimestamp(), updatedAt: serverTimestamp(), updatedByName: 'zoe', ...over });

test('lecture : le joueur de l’objet et l’équipe ; note et historique à l’équipe', async () => {
  await assertSucceeds(getDoc(doc(as('zoe'), 'items/i1')));
  await assertSucceeds(getDocs(query(collection(as('zoe'), 'items'), where('playerUid', '==', 'zoe'))));
  await assertFails(getDoc(doc(as('max'), 'items/i1')));
  await assertSucceeds(getDoc(doc(as('julien'), 'items/i1')));
  await assertFails(getDoc(doc(as('zoe'), 'items/i1/private/note')));
  await assertFails(getDoc(doc(as('zoe'), 'items/i1/history/h1')));
  await assertSucceeds(getDoc(doc(as('julien'), 'items/i1/history/h1')));
});

test('demande du joueur : pour son personnage, en son nom (Review Focus 1)', async () => {
  await assertSucceeds(setDoc(doc(as('zoe'), 'items/n1'), request({})));
  await assertFails(setDoc(doc(as('zoe'), 'items/n2'), request({ characterId: 'c2' })));
  await assertFails(setDoc(doc(as('zoe'), 'items/n3'), request({ playerUid: 'max' })));
  await assertFails(setDoc(doc(as('max'), 'items/n4'), request({ playerUid: 'max' })));
  await assertFails(setDoc(doc(as('zoe'), 'items/n5'), request({ characterId: 'absent' })));
  await assertFails(setDoc(doc(as('zoe'), 'items/n6'), request({ characterId: 'c3', characterName: 'Octave' })));
  await assertFails(setDoc(doc(as('zoe'), 'items/n7'), request({ updatedByName: 'Léa (conteur)' })));
  await assertFails(setDoc(doc(as('zoe'), 'items/n8'), request({ createdAt: Timestamp.fromMillis(0) })));
  await assertFails(setDoc(doc(as('zoe'), 'items/n9'), request({ characterName: 'Autre' })));
});

test('demande du joueur : rien au-delà d’une demande (Review Focus 2)', async () => {
  await assertFails(setDoc(doc(as('zoe'), 'items/n1'), request({ state: 'active' })));
  await assertFails(setDoc(doc(as('zoe'), 'items/n2'), request({ extraQuality: 'Chef-d’œuvre' })));
  await assertFails(setDoc(doc(as('zoe'), 'items/n3'), request({ qualities: ['A', 'B', 'C'] })));
  await assertFails(setDoc(doc(as('zoe'), 'items/n4'), request({ refusal: 'x' })));
  await assertFails(setDoc(doc(as('zoe'), 'items/n5'), request({ secret: true })));
  await assertFails(setDoc(doc(as('zoe'), 'items/n6'), request({ name: '' })));
  await assertFails(setDoc(doc(as('zoe'), 'items/n7'), request({ version: 2 })));
  await assertFails(updateDoc(doc(as('zoe'), 'items/r1'), { name: 'Autre' }));
});

test('suppression par le joueur : demandes en attente ou refusées seulement (Review Focus 3)', async () => {
  await assertFails(deleteDoc(doc(as('max'), 'items/r1')));
  await assertSucceeds(deleteDoc(doc(as('zoe'), 'items/r1')));
  await assertSucceeds(deleteDoc(doc(as('zoe'), 'items/f1')));
  await assertFails(deleteDoc(doc(as('zoe'), 'items/i1')));
});

test('le conte écrit avec version et historique ; le narrateur lit seulement', async () => {
  await assertSucceeds(saved('lea', 'n1', item({})));
  await assertFails(saved('lea', 'n2', item({}), { history: false }));
  await assertFails(saved('julien', 'n3', item({})));
  await assertFails(saved('lea', 'n4', item({ name: 'x'.repeat(81) })));
  await assertFails(saved('lea', 'n5', item({ state: 'perdu' })));
  await assertSucceeds(saved('lea', 'i1', item({ state: 'confiscated', version: 2 })));
  await assertFails(saved('lea', 'r1', item({ state: 'active', version: 1 })));
  await assertSucceeds(saved('lea', 'r1', item({ state: 'active', version: 2 })));
  await assertFails(deleteDoc(doc(as('julien'), 'items/i1')));
  await assertSucceeds(deleteDoc(doc(as('lea'), 'items/i1')));
});
