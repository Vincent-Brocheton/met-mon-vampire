import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, updateDoc, writeBatch, serverTimestamp, collectionGroup, query, where } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const creation = { purchases: [], step: 1, submittedAt: null, decidedAt: null, decidedByUid: null, comment: null };
const char = (over) => ({
  name: 'Isaure', kind: 'pj', playerUid: 'zoe', playerName: 'Zoé', status: 'active', clan: null,
  xpEarned: 0, xpSpent: 0, creation, version: 1, lastHistoryId: 'h1', createdAt: new Date(), ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: 'x@ex.fr', role });
    await setDoc(doc(db, 'characters/zoe-pj'), char({}));
    await setDoc(doc(db, 'characters/zoe-draft'), char({ status: 'draft' }));
    await setDoc(doc(db, 'characters/lea-pj'), char({ playerUid: 'lea' }));
    await setDoc(doc(db, 'characters/zoe-pj/history/c1'), { at: new Date(), byUid: 'lea', kind: 'correction', reason: 'Coût', summary: [] });
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();
const settings = { monthlyEnabled: true, gainSince: '2026-10', tiers: [{ months: null, xp: 1, every: 1 }] };

function gain(uid, cid, through) {
  const db = as(uid);
  const b = writeBatch(db);
  b.update(doc(db, `characters/${cid}`), { xpEarned: 3, gainedThrough: through, version: 2, lastHistoryId: 'h2' });
  b.set(doc(db, `characters/${cid}/history/h2`), { at: serverTimestamp(), byUid: uid, kind: 'gain', reason: 'Gain mensuel · oct. 2026', summary: [] });
  return b.commit();
}

test('paramètres d’XP : lus par tous, écrits par les conteurs', async () => {
  await assertFails(setDoc(doc(as('zoe'), 'chronicle/xp'), settings));
  await assertFails(setDoc(doc(as('julien'), 'chronicle/xp'), settings));
  await assertSucceeds(setDoc(doc(as('lea'), 'chronicle/xp'), settings));
  await assertSucceeds(getDoc(doc(as('zoe'), 'chronicle/xp')));
});

test('corrections de toute la chronique : lues par l’équipe seulement', async () => {
  const q = (uid) => getDocs(query(collectionGroup(as(uid), 'history'), where('kind', '==', 'correction')));
  await assertFails(q('zoe'));
  await assertSucceeds(q('julien'));
  await assertSucceeds(q('lea'));
});

test('gain mensuel : versé par un conteur, jamais sur sa fiche', async () => {
  await assertFails(gain('lea', 'lea-pj', '2026-10'));
  await assertFails(gain('julien', 'zoe-pj', '2026-10'));
  await assertSucceeds(gain('lea', 'zoe-pj', '2026-10'));
});

test('le joueur n’écrit pas gainedThrough sur son brouillon (Review Focus 5)', async () => {
  await assertFails(updateDoc(doc(as('zoe'), 'characters/zoe-draft'), { gainedThrough: '2030-01', version: 2 }));
  await assertSucceeds(updateDoc(doc(as('zoe'), 'characters/zoe-draft'), { clan: 'Tremere', version: 2 }));
});
