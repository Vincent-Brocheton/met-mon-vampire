import { test, before, after, beforeEach } from 'node:test';
import { strictEqual } from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, deleteDoc, collection, query, where, writeBatch } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const bond = (over) => ({
  regnantId: 'oct', regnantName: 'Octave', regnantPlayerUid: null,
  thrallId: 'luc', thrallName: 'Lucie', thrallPlayerUid: 'zoe', ghoul: false, level: 2,
  lastDrink: new Date('2026-09-20T00:00:00'), lastContact: new Date('2026-09-20T00:00:00'),
  known: true, regnantKnows: true, byUid: 'lea', byName: 'lea', createdAt: new Date(), updatedAt: new Date(), ...over,
});
const ev = (over) => ({
  type: 'bond', title: 'Boit le sang de Octave · ●●●', description: '', year: 2026, month: 9, day: 27,
  visibility: 'player', auto: true, byUid: 'lea', byName: 'lea', createdAt: new Date(), updatedAt: new Date(), ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur', max: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await setDoc(doc(db, 'characters/luc'), { name: 'Lucie', kind: 'pj', playerUid: 'zoe', status: 'active', version: 1 });
    await setDoc(doc(db, 'characters/oct'), { name: 'Octave', kind: 'pnj', status: 'active', version: 1 });
    await setDoc(doc(db, 'characters/aga'), { name: 'Agathe', kind: 'pnj', status: 'active', version: 1 });
    await setDoc(doc(db, 'characters/lea1'), { name: 'Léa joue', kind: 'pj', playerUid: 'lea', status: 'active', version: 1 });
    await setDoc(doc(db, 'bonds/oct_luc'), bond({}));
    await setDoc(doc(db, 'bonds/aga_luc'), bond({ regnantId: 'aga', regnantName: 'Agathe', known: false }));
    await setDoc(doc(db, 'bonds/luc_aga'), bond({
      regnantId: 'luc', regnantName: 'Lucie', regnantPlayerUid: 'zoe', thrallId: 'aga', thrallName: 'Agathe', thrallPlayerUid: null,
      regnantKnows: false,
    }));
    await setDoc(doc(db, 'bonds/luc_oct'), bond({
      regnantId: 'luc', regnantName: 'Lucie', regnantPlayerUid: 'zoe', thrallId: 'oct', thrallName: 'Octave', thrallPlayerUid: null,
    }));
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();
const suffered = (db, uid) => query(collection(db, 'bonds'),
  where('thrallId', '==', 'luc'), where('thrallPlayerUid', '==', uid), where('known', '==', true));
const exerted = (db, uid) => query(collection(db, 'bonds'),
  where('regnantId', '==', 'luc'), where('regnantPlayerUid', '==', uid), where('regnantKnows', '==', true));

test('lecture : l’équipe voit tout', async () => {
  await assertSucceeds(getDocs(collection(as('julien'), 'bonds')));
  await assertSucceeds(getDocs(collection(as('lea'), 'bonds')));
});

test('lecture du joueur : liens connus seulement, requête filtrée (Review Focus 3)', async () => {
  const zoe = as('zoe');
  strictEqual((await assertSucceeds(getDocs(suffered(zoe, 'zoe')))).size, 1);
  strictEqual((await assertSucceeds(getDocs(exerted(zoe, 'zoe')))).size, 1);
  await assertSucceeds(getDoc(doc(zoe, 'bonds/oct_luc')));
  await assertFails(getDoc(doc(zoe, 'bonds/aga_luc')));
  await assertFails(getDoc(doc(zoe, 'bonds/luc_aga')));
  await assertFails(getDocs(collection(zoe, 'bonds')));
  await assertFails(getDoc(doc(as('max'), 'bonds/oct_luc')));
});

test('écriture : le conte, champs contrôlés, identifiant imposé', async () => {
  const lea = as('lea');
  await assertSucceeds(setDoc(doc(lea, 'bonds/oct_luc'), bond({ level: 3 })));
  await assertSucceeds(setDoc(doc(lea, 'bonds/aga_oct'), bond({ regnantId: 'aga', thrallId: 'oct', thrallPlayerUid: null })));
  await assertFails(setDoc(doc(lea, 'bonds/autre'), bond({})));
  await assertFails(setDoc(doc(lea, 'bonds/oct_oct'), bond({ thrallId: 'oct', thrallPlayerUid: null })));
  await assertFails(setDoc(doc(lea, 'bonds/oct_luc'), bond({ level: 4 })));
  await assertFails(setDoc(doc(lea, 'bonds/oct_luc'), bond({ level: '2' })));
  await assertFails(setDoc(doc(lea, 'bonds/oct_luc'), bond({ lastDrink: '20/09/2026' })));
  await assertFails(setDoc(doc(lea, 'bonds/oct_luc'), bond({ secret: 1 })));
  await assertFails(setDoc(doc(lea, 'bonds/oct_luc'), bond({ byUid: 'julien' })));
  await assertFails(setDoc(doc(lea, 'bonds/oct_luc'), bond({ thrallPlayerUid: 'max' })));
  await assertFails(setDoc(doc(lea, 'bonds/oct_luc'), bond({ known: 'oui' })));
  await assertFails(setDoc(doc(lea, 'bonds/oct_luc'), bond({ ghoul: 1 })));
});

test('écriture refusée : narrateur, joueur, fiche du conte, suppression', async () => {
  await assertFails(setDoc(doc(as('julien'), 'bonds/oct_luc'), bond({ byUid: 'julien' })));
  await assertFails(setDoc(doc(as('zoe'), 'bonds/oct_luc'), bond({ byUid: 'zoe' })));
  await assertFails(setDoc(doc(as('lea'), 'bonds/oct_lea1'), bond({ thrallId: 'lea1', thrallPlayerUid: 'lea' })));
  await assertFails(setDoc(doc(as('lea'), 'bonds/lea1_oct'), bond({
    regnantId: 'lea1', regnantPlayerUid: 'lea', thrallId: 'oct', thrallPlayerUid: null,
  })));
  await assertFails(deleteDoc(doc(as('lea'), 'bonds/oct_luc')));
});

test('joueur de la fiche changé : le conte met à jour la copie, pas une autre (revue finale)', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'characters/luc'), { name: 'Lucie', kind: 'pj', playerUid: 'max', status: 'active', version: 2 });
  });
  const lea = as('lea');
  const meta = { byUid: 'lea', byName: 'lea', updatedAt: new Date() };
  const ref = doc(lea, 'bonds/oct_luc');
  await assertFails(setDoc(ref, { thrallPlayerUid: 'zoe', ...meta }, { merge: true })); // copie périmée
  await assertFails(setDoc(ref, { thrallPlayerUid: 'julien', ...meta }, { merge: true })); // pas le joueur de la fiche
  await assertSucceeds(setDoc(ref, { thrallPlayerUid: 'max', ...meta }, { merge: true }));
  await assertSucceeds(setDoc(doc(lea, 'bonds/luc_aga'), { regnantPlayerUid: 'max', ...meta }, { merge: true }));
  await assertFails(setDoc(doc(lea, 'bonds/luc_oct'), { regnantPlayerUid: 'julien', ...meta }, { merge: true }));
});

test('gorgée en un lot : lien, lien moindre effacé, événement « Lien de sang »', async () => {
  const lea = as('lea');
  const batch = writeBatch(lea);
  batch.set(doc(lea, 'bonds/oct_luc'), bond({ level: 3 }), { merge: true });
  batch.set(doc(lea, 'bonds/aga_luc'), bond({ regnantId: 'aga', regnantName: 'Agathe', level: 0, known: false }), { merge: true });
  batch.set(doc(lea, 'characters/luc/events/e1'), ev({}));
  await assertSucceeds(batch.commit());
});
