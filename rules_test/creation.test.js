import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, writeBatch, serverTimestamp } from 'firebase/firestore';

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
  name: 'Nikolaï', kind: 'pj', playerUid: 'zoe', playerName: 'Zoé', status: 'draft', clan: null,
  xpBonus: 0, xpInitial: 0, xpEarned: 0, xpSpent: 0, creation, version: 1, lastHistoryId: 'h1', createdAt: new Date(), ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { boss: 'principal', lea: 'conteur', julien: 'narrateur', zoe: 'joueur', max: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: 'x@ex.fr', role });
    await setDoc(doc(db, 'characters/draft'), char({}));
    await setDoc(doc(db, 'characters/review'), char({ status: 'review' }));
    await setDoc(doc(db, 'characters/leareview'), char({ status: 'review', playerUid: 'lea' }));
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();
const save = (uid, id, changes, version = 2) => updateDoc(doc(as(uid), `characters/${id}`), { ...changes, version });

function traced(uid, id, changes, kind, reason = '') {
  const db = as(uid);
  const b = writeBatch(db);
  b.update(doc(db, `characters/${id}`), { ...changes, version: 2, lastHistoryId: 'h2' });
  b.set(doc(db, `characters/${id}/history/h2`), { at: serverTimestamp(), byUid: uid, kind, reason, summary: [] });
  return b.commit();
}

test('le joueur remplit son brouillon, sans toucher aux champs protégés', async () => {
  await assertFails(save('zoe', 'draft', { xpBonus: 10 }));
  await assertFails(save('zoe', 'draft', { status: 'active' }));
  await assertFails(save('zoe', 'draft', { playerUid: 'max' }));
  await assertFails(save('zoe', 'draft', { 'creation.comment': 'ok' }));
  await assertFails(save('max', 'draft', { clan: 'Brujah' }));
  await assertFails(save('zoe', 'review', { clan: 'Brujah' }));
  await assertSucceeds(save('zoe', 'draft', { clan: 'Tremere', xpInitial: 33 }));
});

test('soumettre et retirer, jamais s’activer soi-même', async () => {
  await assertFails(save('zoe', 'draft', { status: 'review' }));
  await assertSucceeds(traced('zoe', 'draft', { status: 'review' }, 'submission'));
  await assertFails(traced('zoe', 'review', { status: 'active' }, 'validation'));
  await assertSucceeds(traced('zoe', 'review', { status: 'draft' }, 'withdrawal'));
});

// Échecs d'abord : chaque réussite fait monter la version du document.
test('bonus du conte sur un brouillon, rien d’autre', async () => {
  await assertFails(traced('lea', 'draft', { xpBonus: 10, clan: 'Tremere' }, 'bonus'));
  await assertFails(traced('julien', 'draft', { xpBonus: 10 }, 'bonus'));
  await assertFails(traced('lea', 'review', { xpBonus: 10 }, 'bonus'));
  await assertSucceeds(traced('lea', 'draft', { xpBonus: 10 }, 'bonus'));
});

test('décisions du conte', async () => {
  await assertSucceeds(traced('lea', 'review', { status: 'active' }, 'validation'));
});

test('corrections et refus exigent un commentaire', async () => {
  await assertFails(traced('lea', 'review', { status: 'draft' }, 'corrections', ''));
  await assertSucceeds(traced('lea', 'review', { status: 'draft' }, 'corrections', 'Précise le sire.'));
});

test('refus commenté ; narrateur et conteur-joueur ne décident pas', async () => {
  await assertSucceeds(traced('boss', 'review', { status: 'rejected' }, 'rejection', 'Hors cadre.'));
  await assertFails(traced('julien', 'leareview', { status: 'active' }, 'validation'));
  await assertFails(traced('lea', 'leareview', { status: 'active' }, 'validation'));
});
