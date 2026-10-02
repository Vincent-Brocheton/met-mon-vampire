import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc, writeBatch, collection, serverTimestamp } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await seed({
    'users/boss': user('principal'), 'users/lea': user('conteur'), 'users/julien': user('narrateur'),
    'users/max': user('joueur'), 'users/zoe': user('joueur'),
    'characters/isaure': char({ playerUid: 'max' }),
    'characters/isaure/history/h1': entry('boss', 'creation'),
    'characters/isaure/private/notes': { text: 'Secret' },
    'characters/elie': char({ playerUid: 'lea', name: 'Élie' }),
    'characters/brouillon': char({ playerUid: 'zoe', status: 'draft' }),
  });
});

async function seed(data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    for (const [path, value] of Object.entries(data)) await setDoc(doc(ctx.firestore(), path), value);
  });
}
const user = (role) => ({ displayName: role, email: 'x@ex.fr', role });
const char = (over) => ({ name: 'Isaure', kind: 'pj', playerUid: 'max', playerName: 'Max', status: 'active', version: 1, lastHistoryId: 'h1', createdAt: new Date(), ...over });
const entry = (byUid, kind, reason = '') => ({ at: new Date(), byUid, kind, reason, summary: [] });
const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

function create(uid, id, data) {
  const db = as(uid);
  const b = writeBatch(db);
  b.set(doc(db, `characters/${id}`), { ...data, version: 1, lastHistoryId: 'h1' });
  b.set(doc(db, `characters/${id}/history/h1`), { at: serverTimestamp(), byUid: uid, kind: 'creation', reason: '', summary: [] });
  return b.commit();
}

function edit(uid, id, fromVersion, changes, { reason = 'Correction', withEntry = true, version } = {}) {
  const db = as(uid);
  const hid = `h${fromVersion + 1}`;
  const b = writeBatch(db);
  b.update(doc(db, `characters/${id}`), { ...changes, version: version ?? fromVersion + 1, lastHistoryId: withEntry ? hid : 'h1' });
  if (withEntry) b.set(doc(db, `characters/${id}/history/${hid}`), { at: serverTimestamp(), byUid: uid, kind: 'edit', reason, summary: [] });
  return b.commit();
}

test('création : amorce de PJ en brouillon, PNJ actif, toujours avec historique', async () => {
  await assertSucceeds(create('lea', 'a1', { name: 'Nikolaï', kind: 'pj', playerUid: 'zoe', playerName: 'Zoé', status: 'draft' }));
  await assertSucceeds(create('lea', 'a2', { name: 'Sœur Agathe', kind: 'pnj', playerUid: null, playerName: null, status: 'active' }));
  await assertFails(create('lea', 'a3', { name: 'X', kind: 'pj', playerUid: 'zoe', status: 'active' }));
  await assertFails(create('lea', 'a4', { name: 'X', kind: 'pj', playerUid: 'lea', status: 'draft' }));
  await assertFails(create('julien', 'a5', { name: 'X', kind: 'pnj', playerUid: null, status: 'active' }));
  await assertFails(setDoc(doc(as('lea'), 'characters/a6'), { name: 'X', kind: 'pnj', playerUid: null, status: 'active', version: 1, lastHistoryId: 'h1' }));
});

test('lecture : le joueur ses fiches, l’équipe toutes', async () => {
  await assertSucceeds(getDoc(doc(as('max'), 'characters/isaure')));
  await assertFails(getDoc(doc(as('zoe'), 'characters/isaure')));
  await assertSucceeds(getDoc(doc(as('julien'), 'characters/isaure')));
  await assertSucceeds(getDocs(collection(as('max'), 'characters/isaure/history')));
  await assertFails(getDocs(collection(as('zoe'), 'characters/isaure/history')));
});

test('modification d’une fiche active : tracée, motivée, versionnée', async () => {
  await assertSucceeds(edit('lea', 'isaure', 1, { humanity: 4 }));
  await assertFails(edit('lea', 'isaure', 2, { humanity: 3 }, { reason: '' }));
  await assertFails(edit('lea', 'isaure', 2, { humanity: 3 }, { withEntry: false }));
  await assertFails(edit('lea', 'isaure', 2, { humanity: 3 }, { version: 2 }));
  await assertFails(edit('julien', 'isaure', 2, { humanity: 3 }));
  await assertFails(edit('max', 'isaure', 2, { humanity: 3 }));
});

test('le conteur ne remplit pas un PJ en brouillon', async () => {
  await assertFails(edit('lea', 'brouillon', 1, { clan: 'Tremere' }));
});

test('conteur qui joue : ni modification ni notes sur sa fiche', async () => {
  await assertSucceeds(getDoc(doc(as('lea'), 'characters/elie')));
  await assertFails(edit('lea', 'elie', 1, { humanity: 4 }));
  await assertSucceeds(edit('boss', 'elie', 1, { humanity: 4 }));
  await assertFails(getDoc(doc(as('lea'), 'characters/elie/private/notes')));
  await assertSucceeds(getDoc(doc(as('lea'), 'characters/isaure/private/notes')));
});

test('historique immuable, notes réservées au conte', async () => {
  await assertFails(updateDoc(doc(as('boss'), 'characters/isaure/history/h1'), { reason: 'x' }));
  await assertFails(deleteDoc(doc(as('boss'), 'characters/isaure/history/h1')));
  await assertFails(deleteDoc(doc(as('boss'), 'characters/isaure')));
  await assertFails(getDoc(doc(as('max'), 'characters/isaure/private/notes')));
  await assertFails(getDoc(doc(as('julien'), 'characters/isaure/private/notes')));
});
