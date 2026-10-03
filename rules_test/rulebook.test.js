import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, deleteDoc, collectionGroup, query } from 'firebase/firestore';

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
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: 'x@ex.fr', role });
    await setDoc(doc(db, 'rules/merits/ruleEntries/m1'), { name: 'Chanceux', state: 'available', data: { cost: 2 } });
    await setDoc(doc(db, 'rules/merits/ruleEntries/m1/private/note'), { text: 'Secret' });
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();
const entry = (uid, over) => ({ name: 'Volonté de fer', vo: null, state: 'available', source: null, description: '', data: { cost: 3 }, updatedByUid: uid, updatedByName: uid, ...over });

test('le référentiel se lit par tous, s’écrit par les conteurs (Review Focus 5)', async () => {
  await assertSucceeds(getDoc(doc(as('zoe'), 'rules/merits/ruleEntries/m1')));
  await assertSucceeds(getDocs(query(collectionGroup(as('zoe'), 'ruleEntries'))));
  await assertFails(setDoc(doc(as('zoe'), 'rules/merits/ruleEntries/n1'), entry('zoe')));
  await assertFails(setDoc(doc(as('julien'), 'rules/merits/ruleEntries/n1'), entry('julien')));
  await assertSucceeds(setDoc(doc(as('lea'), 'rules/merits/ruleEntries/n1'), entry('lea')));
  await assertSucceeds(deleteDoc(doc(as('lea'), 'rules/merits/ruleEntries/n1')));
  await assertFails(deleteDoc(doc(as('zoe'), 'rules/merits/ruleEntries/m1')));
});

test('élément invalide refusé', async () => {
  await assertFails(setDoc(doc(as('lea'), 'rules/merits/ruleEntries/n2'), entry('lea', { name: '' })));
  await assertFails(setDoc(doc(as('lea'), 'rules/merits/ruleEntries/n2'), entry('lea', { name: 'x'.repeat(81) })));
  await assertFails(setDoc(doc(as('lea'), 'rules/merits/ruleEntries/n2'), entry('lea', { state: 'cosmique' })));
  await assertFails(setDoc(doc(as('lea'), 'rules/merits/ruleEntries/n2'), entry('lea', { data: 'coût 3' })));
  await assertFails(setDoc(doc(as('lea'), 'rules/merits/ruleEntries/n2'), entry('lea', { updatedByUid: 'julien' })));
});

test('note du conte : cachée aux joueurs', async () => {
  await assertFails(getDoc(doc(as('zoe'), 'rules/merits/ruleEntries/m1/private/note')));
  await assertSucceeds(getDoc(doc(as('julien'), 'rules/merits/ruleEntries/m1/private/note')));
  await assertFails(setDoc(doc(as('julien'), 'rules/merits/ruleEntries/m1/private/note'), { text: 'x' }));
  await assertSucceeds(setDoc(doc(as('lea'), 'rules/merits/ruleEntries/m1/private/note'), { text: 'x' }));
});

test('réglages d’une catégorie', async () => {
  await assertFails(setDoc(doc(as('zoe'), 'rules/rituals'), { costPerLevel: 1 }));
  await assertSucceeds(setDoc(doc(as('lea'), 'rules/rituals'), { costPerLevel: 2 }));
  await assertSucceeds(getDoc(doc(as('zoe'), 'rules/rituals')));
});

test('la lecture groupée ne touche que le référentiel (revue)', async () => {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'autre/c1/entries/x'), { name: 'Secret' }));
  await assertFails(getDoc(doc(as('zoe'), 'autre/c1/entries/x')));
});
