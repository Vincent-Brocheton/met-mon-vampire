import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import {
  doc, setDoc, getDoc, getDocs, updateDoc, deleteDoc, writeBatch, serverTimestamp, collection, collectionGroup, query, where, Timestamp,
} from 'firebase/firestore';

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

const future = () => Timestamp.fromDate(new Date(Date.now() + 2 * 86400000));
const past = () => Timestamp.fromDate(new Date(Date.now() - 86400000));
const gameDate = Timestamp.fromDate(new Date(2030, 9, 3));

const game = (uid, over = {}) => ({
  date: gameDate, frozenAt: serverTimestamp(), until: future(), liftedAt: null, liftedByUid: null, byUid: uid, sheetIds: ['zoe-pj'], ...over,
});
const snap = (uid, over = {}) => ({ sheet: { name: 'Isaure' }, version: 1, gameDate, at: serverTimestamp(), byUid: uid, reason: null, ...over });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', max: 'principal', julien: 'narrateur', zoe: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await setDoc(doc(db, 'characters/zoe-pj'), char({}));
    await setDoc(doc(db, 'characters/tom-pj'), char({ playerUid: 'tom', playerName: 'Tom' }));
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

/** Gel g0 déjà en place (règles désactivées), avec le pointeur et deux versions figées. */
async function seed(over = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'games/g0'), {
      date: gameDate, frozenAt: Timestamp.now(), until: future(), liftedAt: null, liftedByUid: null, byUid: 'lea', sheetIds: ['zoe-pj'], ...over,
    });
    await setDoc(doc(db, 'chronicle/freeze'), { gameId: 'g0' });
    for (const id of ['zoe-pj', 'tom-pj']) {
      await setDoc(doc(db, `characters/${id}/frozen/g0`), { sheet: { name: id }, version: 1, gameDate, at: Timestamp.now(), byUid: 'lea', reason: null });
    }
  });
}

/** Le lot du gel, comme GamesRepository.freeze. */
function freeze(uid, gid, over = {}, sheets = ['zoe-pj']) {
  const db = as(uid);
  const b = writeBatch(db);
  b.set(doc(db, `games/${gid}`), game(uid, { sheetIds: sheets, ...over }));
  b.set(doc(db, 'chronicle/freeze'), { gameId: gid });
  for (const s of sheets) b.set(doc(db, `characters/${s}/frozen/${gid}`), snap(uid));
  return b.commit();
}

/** Modification tracée de la fiche par Léa (règle staffEdit). */
function edit(cid, change) {
  const db = as('lea');
  const b = writeBatch(db);
  b.update(doc(db, `characters/${cid}`), { ...change, version: 2, lastHistoryId: 'h2' });
  b.set(doc(db, `characters/${cid}/history/h2`), { at: serverTimestamp(), byUid: 'lea', kind: 'edit', reason: 'Motif', summary: [] });
  return b.commit();
}

test('figer : un conteur oui, ni narrateur ni joueur', async () => {
  await assertFails(freeze('zoe', 'g1'));
  await assertFails(freeze('julien', 'g1'));
  await assertSucceeds(freeze('lea', 'g1'));
});

test('figer : le principal aussi', async () => {
  await assertSucceeds(freeze('max', 'g1'));
});

test('figer : heure du serveur, levée future, clés fermées, auteur', async () => {
  await assertFails(freeze('lea', 'g1', { frozenAt: Timestamp.fromDate(new Date()) }));
  await assertFails(freeze('lea', 'g1', { until: past() }));
  await assertFails(freeze('lea', 'g1', { note: 'x' }));
  await assertFails(freeze('lea', 'g1', { byUid: 'max' }));
  await assertFails(freeze('lea', 'g1', { liftedAt: serverTimestamp(), liftedByUid: 'lea' }));
  await assertSucceeds(freeze('lea', 'g1'));
});

test('figer : refusé pendant un gel en cours (Review Focus 1)', async () => {
  await seed();
  await assertFails(freeze('lea', 'g1'));
  await assertFails(freeze('max', 'g1'));
});

test('figer : permis après une levée anticipée', async () => {
  await seed({ liftedAt: Timestamp.now(), liftedByUid: 'lea' });
  await assertSucceeds(freeze('lea', 'g1'));
});

test('figer : permis une fois la levée prévue passée (Review Focus 3)', async () => {
  await seed({ until: past() });
  await assertSucceeds(freeze('lea', 'g1'));
});

test('figer : 45 fiches en un lot (Review Focus 4)', async () => {
  const many = Array.from({ length: 45 }, (_, i) => `s${i}`);
  await assertSucceeds(freeze('lea', 'g1', {}, many));
});

test('figer : la fiche du conteur est figée comme les autres (Review Focus 5)', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), 'characters/lea-pj'), char({ playerUid: 'lea' })));
  await assertSucceeds(freeze('lea', 'g1', {}, ['zoe-pj', 'lea-pj']));
});

test('pointeur et parties : lus par tout connecté ; pointeur jamais écrit seul', async () => {
  await seed({ liftedAt: Timestamp.now(), liftedByUid: 'lea' });
  await assertSucceeds(getDoc(doc(as('zoe'), 'chronicle/freeze')));
  await assertSucceeds(getDocs(collection(as('zoe'), 'games')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'chronicle/freeze')));
  await assertFails(setDoc(doc(as('lea'), 'chronicle/freeze'), { gameId: 'g0' }));
  await assertFails(setDoc(doc(as('lea'), 'chronicle/freeze'), { gameId: 'nouveau' }));
});

test('lever : gel en cours, deux champs, par le conte', async () => {
  await seed();
  const lift = (uid, extra = {}) => updateDoc(doc(as(uid), 'games/g0'), { liftedAt: serverTimestamp(), liftedByUid: uid, ...extra });
  await assertFails(lift('julien'));
  await assertFails(lift('zoe'));
  await assertFails(lift('lea', { until: future() }));
  await assertFails(updateDoc(doc(as('lea'), 'games/g0'), { liftedAt: serverTimestamp(), liftedByUid: 'max' }));
  await assertSucceeds(lift('lea'));
  await assertFails(lift('lea'));
  await assertFails(deleteDoc(doc(as('lea'), 'games/g0')));
});

test('versions figées : lues par le joueur de la fiche et par l’équipe', async () => {
  await seed();
  await assertSucceeds(getDoc(doc(as('zoe'), 'characters/zoe-pj/frozen/g0')));
  await assertFails(getDoc(doc(as('zoe'), 'characters/tom-pj/frozen/g0')));
  await assertSucceeds(getDoc(doc(as('julien'), 'characters/tom-pj/frozen/g0')));
  const q = (uid) => getDocs(query(collectionGroup(as(uid), 'frozen'), where('gameDate', '==', gameDate)));
  await assertSucceeds(q('julien'));
  await assertFails(q('zoe'));
});

test('versions figées : écrites par le conte, corrigées avec un motif, jamais supprimées', async () => {
  await seed();
  const ref = (uid) => doc(as(uid), 'characters/zoe-pj/frozen/g0');
  await assertFails(setDoc(ref('zoe'), snap('zoe', { reason: 'Erreur' })));
  await assertFails(setDoc(ref('julien'), snap('julien', { reason: 'Erreur' })));
  await assertFails(setDoc(ref('lea'), snap('lea')));
  await assertFails(setDoc(ref('lea'), snap('lea', { reason: '' })));
  await assertFails(setDoc(ref('lea'), snap('lea', { reason: 'Erreur', extra: 1 })));
  await assertSucceeds(setDoc(ref('lea'), snap('lea', { reason: 'Erreur de saisie' })));
  await assertFails(deleteDoc(ref('lea')));
  await assertFails(setDoc(doc(as('lea'), 'characters/zoe-pj/frozen/g5'), snap('lea', { reason: 'x' })));
  await assertSucceeds(setDoc(doc(as('lea'), 'characters/zoe-pj/frozen/g5'), snap('lea')));
});

test('verrou : l’XP d’une fiche figée ne change pas, le reste si (Review Focus 2)', async () => {
  await seed();
  await assertFails(edit('zoe-pj', { xpEarned: 3 }));
  await assertFails(edit('zoe-pj', { xpSpent: 3 }));
  await assertSucceeds(edit('zoe-pj', { clan: 'Toreador' }));
});

test('verrou : une fiche hors du gel garde son XP libre', async () => {
  await seed();
  await assertSucceeds(edit('tom-pj', { xpEarned: 3 }));
});

test('verrou : sans aucun gel', async () => {
  await assertSucceeds(edit('zoe-pj', { xpEarned: 3 }));
});

test('verrou : levé par anticipation', async () => {
  await seed({ liftedAt: Timestamp.now(), liftedByUid: 'lea' });
  await assertSucceeds(edit('zoe-pj', { xpEarned: 3 }));
});

test('verrou : levée prévue passée (Review Focus 3)', async () => {
  await seed({ until: past() });
  await assertSucceeds(edit('zoe-pj', { xpEarned: 3 }));
});
