import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, writeBatch } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const sin = (over) => ({
  date: new Date('2026-10-03T00:00:00'), level: 2, what: 'Témoin rendu fou', remorse: 'success', lossApplied: false,
  byUid: 'lea', byName: 'lea', createdAt: new Date(), updatedAt: new Date(), ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await setDoc(doc(db, 'characters/c1'), { name: 'Lucie', kind: 'pj', playerUid: 'zoe', status: 'active', version: 1 });
    await setDoc(doc(db, 'characters/c1/sins/a'), sin({ byUid: 'marc', byName: 'Marc' }));
    await setDoc(doc(db, 'characters/c1/sins/b'), sin({}));
    await setDoc(doc(db, 'characters/c1/sins/locked'), sin({ lossApplied: true }));
    await setDoc(doc(db, 'users/lea/devices/d1'), {
      name: 'Navigateur · Windows', web: true, lastSeen: new Date('2026-10-03T17:00:00'), gameId: 'g2', preparedAt: new Date('2026-10-03T17:30:00'), revokedAt: null,
    });
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();
const mark = () => ({ distinct: true, byUid: 'lea', byName: 'lea', updatedAt: new Date() });

test('« distinct » : accepté à la création et en lot sur deux péchés', async () => {
  const lea = as('lea');
  await assertSucceeds(setDoc(doc(lea, 'characters/c1/sins/n1'), sin({ distinct: true })));
  const b = writeBatch(lea);
  b.update(doc(lea, 'characters/c1/sins/a'), mark());
  b.update(doc(lea, 'characters/c1/sins/b'), mark());
  await assertSucceeds(b.commit());
});

test('« distinct » : booléen seulement ; ni joueur, ni narrateur, ni péché verrouillé', async () => {
  await assertFails(setDoc(doc(as('lea'), 'characters/c1/sins/n2'), sin({ distinct: 'oui' })));
  await assertFails(updateDoc(doc(as('zoe'), 'characters/c1/sins/a'), { ...mark(), byUid: 'zoe' }));
  await assertFails(updateDoc(doc(as('julien'), 'characters/c1/sins/a'), { ...mark(), byUid: 'julien' }));
  await assertFails(updateDoc(doc(as('lea'), 'characters/c1/sins/locked'), mark()));
});

test('appareil : la partie préparée peut être oubliée, pas antidatée', async () => {
  const lea = as('lea');
  await assertSucceeds(updateDoc(doc(lea, 'users/lea/devices/d1'), { gameId: null, preparedAt: null }));
  await assertFails(updateDoc(doc(lea, 'users/lea/devices/d1'), { gameId: 'g2', preparedAt: new Date('2020-01-01T00:00:00') }));
  await assertFails(updateDoc(doc(as('zoe'), 'users/lea/devices/d1'), { gameId: null, preparedAt: null }));
});
