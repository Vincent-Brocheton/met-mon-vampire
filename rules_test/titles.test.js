import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, updateDoc, deleteDoc, collection, Timestamp } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const entry = (over) => ({ name: 'Lucie Arnaud', title: 'Harpie', sect: 'Camarilla', under: 'Sénéchal', since: Timestamp.fromDate(new Date(2026, 2, 1)), ...over });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await setDoc(doc(db, 'court/luc'), entry({}));
    await setDoc(doc(db, 'characters/d1'), { name: 'Brouillon', playerUid: 'zoe', kind: 'pj', status: 'draft', version: 1, creation: {} });
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

test('Cour : lue par tout connecté, écrite par le conte seul (Review Focus 3)', async () => {
  await assertSucceeds(getDoc(doc(as('zoe'), 'court/luc')));
  await assertSucceeds(getDocs(collection(as('zoe'), 'court')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'court/luc')));
  await assertFails(setDoc(doc(as('zoe'), 'court/zz'), entry({})));
  await assertFails(setDoc(doc(as('julien'), 'court/zz'), entry({})));
  await assertSucceeds(setDoc(doc(as('lea'), 'court/zz'), entry({})));
  await assertSucceeds(setDoc(doc(as('lea'), 'court/zy'), entry({ since: null, under: '' })));
  await assertFails(deleteDoc(doc(as('zoe'), 'court/luc')));
  await assertSucceeds(deleteDoc(doc(as('lea'), 'court/luc')));
});

test('Cour : clés et longueurs', async () => {
  await assertFails(setDoc(doc(as('lea'), 'court/a'), entry({ secret: true })));
  await assertFails(setDoc(doc(as('lea'), 'court/b'), entry({ name: '' })));
  await assertFails(setDoc(doc(as('lea'), 'court/c'), entry({ title: 'x'.repeat(81) })));
  await assertFails(setDoc(doc(as('lea'), 'court/d'), entry({ since: 'mars' })));
});

test('brouillon du joueur : titre et date protégés (Review Focus 5)', async () => {
  await assertSucceeds(updateDoc(doc(as('zoe'), 'characters/d1'), { concept: 'Avocate', version: 2 }));
  await assertFails(updateDoc(doc(as('zoe'), 'characters/d1'), { title: 'Prince', version: 2 }));
  await assertFails(updateDoc(doc(as('zoe'), 'characters/d1'), { titleSince: Timestamp.fromDate(new Date(2026, 2, 1)), version: 2 }));
});
