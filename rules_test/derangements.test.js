import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc } from 'firebase/firestore';

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
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/zoe'), { displayName: 'zoe', email: 'zoe@ex.fr', role: 'joueur' });
    await setDoc(doc(db, 'characters/d1'), { name: 'Brouillon', kind: 'pj', playerUid: 'zoe', status: 'draft', version: 1, creation: {} });
  });
});

const zoe = () => env.authenticatedContext('zoe', { email: 'zoe@ex.fr', email_verified: true }).firestore();

test('brouillon du joueur : derangements et derangementTraits protégés (Review Focus 1)', async () => {
  await assertSucceeds(updateDoc(doc(zoe(), 'characters/d1'), { concept: 'Avocate', version: 2 }));
  await assertFails(updateDoc(doc(zoe(), 'characters/d1'), { derangements: [{ id: 'd1-d1', name: 'Peur du feu' }], version: 3 }));
  await assertFails(updateDoc(doc(zoe(), 'characters/d1'), { derangementTraits: 2, version: 3 }));
});
