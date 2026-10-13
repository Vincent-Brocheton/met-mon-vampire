import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, serverTimestamp, Timestamp } from 'firebase/firestore';

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
    const users = { lea: 'conteur', zoe: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

test('notifSeenAt : écrit par le titulaire seul, à l’heure du serveur, sans autre champ (Review Focus 4)', async () => {
  await assertSucceeds(updateDoc(doc(as('zoe'), 'users/zoe'), { notifSeenAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(doc(as('lea'), 'users/lea'), { notifSeenAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(as('zoe'), 'users/zoe'), { notifSeenAt: Timestamp.fromDate(new Date(2020, 0, 1)) }));
  await assertFails(updateDoc(doc(as('lea'), 'users/zoe'), { notifSeenAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(as('zoe'), 'users/zoe'), { notifSeenAt: serverTimestamp(), role: 'conteur' }));
  await assertFails(updateDoc(doc(as('zoe'), 'users/zoe'), { notifSeenAt: serverTimestamp(), displayName: 'Zoé' }));
});
