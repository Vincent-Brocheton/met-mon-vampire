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
const ghoul = { domitorId: 'c1', domitorName: 'Isaure', domitorClan: 'Toreador', domitorDisciplines: [{ name: 'Auspex', level: 3 }], bond: 0, vitae: 0, lastDrink: null };
const char = (over) => ({
  name: 'Mila', kind: 'pj', playerUid: 'zoe', playerName: 'Zoé', status: 'draft', clan: null,
  xpBonus: 0, xpInitial: 0, xpEarned: 0, xpSpent: 0, creation, version: 1, lastHistoryId: 'h1', createdAt: new Date(), ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', zoe: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: 'x@ex.fr', role });
    await setDoc(doc(db, 'characters/g'), char({ ghoul }));
    await setDoc(doc(db, 'characters/v'), char({ name: 'Nikolaï' }));
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();
const save = (uid, id, changes) => updateDoc(doc(as(uid), `characters/${id}`), { ...changes, version: 2 });

test('brouillon de goule : le joueur remplit sa fiche, sans toucher à la copie du domitor (Review Focus 1 et 2)', async () => {
  await assertFails(save('zoe', 'g', { 'ghoul.domitorDisciplines': [{ name: 'Auspex', level: 5 }] }));
  await assertFails(save('zoe', 'g', { 'ghoul.vitae': 5 }));
  await assertFails(save('zoe', 'v', { ghoul }));
  await assertSucceeds(save('zoe', 'g', { sect: 'Camarilla', ghoul }));
});

test('le conte crée une fiche de goule', async () => {
  const db = as('lea');
  const b = writeBatch(db);
  b.set(doc(db, 'characters/new'), char({ ghoul }));
  b.set(doc(db, 'characters/new/history/h1'), { at: serverTimestamp(), byUid: 'lea', kind: 'creation', reason: '', summary: [] });
  await assertSucceeds(b.commit());
});
