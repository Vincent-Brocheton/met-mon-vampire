import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, updateDoc, collectionGroup, query, where } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const ev = (over) => ({
  type: 'intrigue', title: 'Arrivée du sire', description: '', year: 2026, month: 2, day: 3,
  visibility: 'public', auto: false, byUid: 'lea', byName: 'lea', createdAt: new Date(), updatedAt: new Date(), ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', zoe: 'joueur', max: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await setDoc(doc(db, 'characters/c1'), { name: 'Lucie', kind: 'pj', playerUid: 'zoe', status: 'active', version: 1 });
    await setDoc(doc(db, 'characters/c2'), { name: 'Bastien', kind: 'pj', playerUid: 'max', status: 'active', version: 1 });
    await setDoc(doc(db, 'characters/c1/events/pub'), ev({ charName: 'Lucie' }));
    await setDoc(doc(db, 'characters/c1/events/pl'), ev({ visibility: 'player' }));
    await setDoc(doc(db, 'characters/c2/events/st'), ev({ visibility: 'staff' }));
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

test('chronologie publique : tout compte lit les événements « Public » de toutes les fiches (Review Focus 4)', async () => {
  const max = as('max');
  await assertSucceeds(getDocs(query(collectionGroup(max, 'events'), where('visibility', '==', 'public'))));
  await assertSucceeds(getDoc(doc(max, 'characters/c1/events/pub')));
  await assertFails(getDoc(doc(max, 'characters/c1/events/pl')));
  await assertFails(getDocs(collectionGroup(max, 'events')));
  await assertFails(getDocs(query(collectionGroup(max, 'events'), where('visibility', 'in', ['public', 'player']))));
  await assertFails(getDocs(query(collectionGroup(env.unauthenticatedContext().firestore(), 'events'), where('visibility', '==', 'public'))));
});

test('événements : nom du personnage facultatif, chaîne de 80 caractères au plus', async () => {
  const lea = as('lea');
  await assertSucceeds(setDoc(doc(lea, 'characters/c1/events/n1'), ev({ charName: 'Lucie' })));
  await assertSucceeds(setDoc(doc(lea, 'characters/c1/events/n2'), ev({})));
  await assertFails(setDoc(doc(lea, 'characters/c1/events/n3'), ev({ charName: 'x'.repeat(81) })));
  await assertFails(setDoc(doc(lea, 'characters/c1/events/n4'), ev({ charName: 3 })));
  await assertSucceeds(updateDoc(doc(lea, 'characters/c1/events/pl'), { charName: 'Lucie', byUid: 'lea', updatedAt: new Date() }));
});
