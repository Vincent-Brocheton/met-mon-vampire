import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, updateDoc, collection, query, where, serverTimestamp, Timestamp } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const day = 24 * 3600 * 1000;
const loan = (over) => ({
  characterId: 'n1', characterName: 'Octave', playerUid: 'zoe', playerName: 'Zoé',
  from: Timestamp.fromMillis(Date.now() - day), until: Timestamp.fromMillis(Date.now() + 10 * day),
  mode: 'full', allowNotes: true, personality: '', goals: '', limits: '', sheetAt: null, revokedAt: null,
  playerNotes: '', notesAt: null, version: 1, ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur', max: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await setDoc(doc(db, 'npcLoans/now'), loan({}));
    await setDoc(doc(db, 'npcLoans/now/sheet/copy'), { sheet: { name: 'Octave' } });
    await setDoc(doc(db, 'npcLoans/past'), loan({ until: Timestamp.fromMillis(Date.now() - day / 2) }));
    await setDoc(doc(db, 'npcLoans/past/sheet/copy'), { sheet: { name: 'Octave' } });
    await setDoc(doc(db, 'npcLoans/revoked'), loan({ revokedAt: Timestamp.fromMillis(Date.now() - 1000) }));
    await setDoc(doc(db, 'npcLoans/revoked/sheet/copy'), { sheet: { name: 'Octave' } });
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

test('le joueur liste ses prêts et lit la copie pendant la période seulement (Review Focus 1 et 2)', async () => {
  await assertSucceeds(getDocs(query(collection(as('zoe'), 'npcLoans'), where('playerUid', '==', 'zoe'))));
  await assertFails(getDocs(collection(as('zoe'), 'npcLoans')));
  await assertSucceeds(getDoc(doc(as('zoe'), 'npcLoans/now/sheet/copy')));
  await assertFails(getDoc(doc(as('zoe'), 'npcLoans/past/sheet/copy')));
  await assertFails(getDoc(doc(as('zoe'), 'npcLoans/revoked/sheet/copy')));
  await assertFails(getDoc(doc(as('max'), 'npcLoans/now')));
  await assertFails(getDoc(doc(as('max'), 'npcLoans/now/sheet/copy')));
  await assertSucceeds(getDoc(doc(as('julien'), 'npcLoans/now/sheet/copy')));
});

test('notes du joueur : seulement elles, pendant la période, si autorisées (Review Focus 1 et 3)', async () => {
  const notes = (id, extra = {}) => updateDoc(doc(as('zoe'), `npcLoans/${id}`), { playerNotes: 'Promis une faveur', notesAt: serverTimestamp(), ...extra });
  await assertSucceeds(notes('now'));
  await assertFails(notes('now', { limits: 'aucune' }));
  await assertFails(notes('now', { notesAt: Timestamp.fromMillis(Date.now() - day) }));
  await assertFails(notes('now', { playerNotes: { a: 1 } }));
  await assertFails(notes('now', { playerNotes: 'x'.repeat(5001) }));
  await assertFails(notes('past'));
  await assertFails(notes('revoked'));
  await assertFails(updateDoc(doc(as('max'), 'npcLoans/now'), { playerNotes: 'x', notesAt: serverTimestamp() }));
  await env.withSecurityRulesDisabled(async (ctx) => updateDoc(doc(ctx.firestore(), 'npcLoans/now'), { allowNotes: false }));
  await assertFails(notes('now'));
});

test('le conte écrit avec la version ; fin avant début refusée (Review Focus 5)', async () => {
  const lea = as('lea');
  await assertSucceeds(updateDoc(doc(lea, 'npcLoans/now'), { limits: 'aucune', version: 2 }));
  await assertFails(updateDoc(doc(lea, 'npcLoans/now'), { limits: 'x', version: 2 }));
  await assertFails(setDoc(doc(as('julien'), 'npcLoans/n2'), loan({})));
  await assertFails(setDoc(doc(lea, 'npcLoans/n2'), loan({ until: Timestamp.fromMillis(Date.now() - 2 * day) })));
  await assertSucceeds(setDoc(doc(lea, 'npcLoans/n2'), loan({})));
  await assertSucceeds(setDoc(doc(lea, 'npcLoans/n2/sheet/copy'), { sheet: {} }));
  await assertFails(setDoc(doc(as('zoe'), 'npcLoans/n2/sheet/copy'), { sheet: {} }));
});
