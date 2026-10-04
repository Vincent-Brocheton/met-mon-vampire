import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, writeBatch, serverTimestamp, deleteField } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const creation = { purchases: [], step: 1, submittedAt: null, decidedAt: null, decidedByUid: null, comment: null };
const ghoul = { domitorId: 'c1', domitorName: 'Isaure', domitorClan: 'Toreador', domitorDisciplines: [], bond: 0, vitae: 0, lastDrink: null };
const embrace = { sireId: 'c1', sireName: 'Isaure', clan: 'Toreador', genNumber: 11 };
const char = (over) => ({
  name: 'Mila', kind: 'pj', playerUid: 'zoe', playerName: 'Zoé', status: 'active', clan: null,
  xpBonus: 0, xpInitial: 0, xpEarned: 0, xpSpent: 0, creation, version: 1, lastHistoryId: 'h1', createdAt: new Date(), ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', zoe: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: 'x@ex.fr', role });
    await setDoc(doc(db, 'characters/g'), char({ ghoul }));
    await setDoc(doc(db, 'characters/d'), char({ name: 'Paul', status: 'draft', clan: 'Toreador', embrace }));
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

test('le conte étreint une goule : clé ghoul supprimée, historique embrace (Review Focus 1)', async () => {
  const db = as('lea');
  const b = writeBatch(db);
  b.update(doc(db, 'characters/g'), { ghoul: deleteField(), clan: 'Toreador', version: 2, lastHistoryId: 'h2' });
  b.set(doc(db, 'characters/g/history/h2'), { at: serverTimestamp(), byUid: 'lea', kind: 'embrace', reason: 'Étreinte', summary: [] });
  await assertSucceeds(b.commit());
});

test('amorce étreinte : le joueur ne touche pas à embrace (Review Focus 4)', async () => {
  const save = (changes) => updateDoc(doc(as('zoe'), 'characters/d'), { ...changes, version: 2 });
  await assertFails(save({ 'embrace.clan': 'Brujah' }));
  await assertFails(save({ embrace: deleteField() }));
  await assertSucceeds(save({ concept: 'Musicien', embrace }));
});
