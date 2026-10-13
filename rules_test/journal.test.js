import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import {
  doc, setDoc, getDoc, updateDoc, deleteDoc, writeBatch, collection, collectionGroup, getDocs, query, where, orderBy,
  serverTimestamp, Timestamp,
} from 'firebase/firestore';

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
    const users = { marc: 'principal', lea: 'conteur', julien: 'narrateur', zoe: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await setDoc(doc(db, 'journal/x'), { cat: 'rules', action: 'Référentiel', target: 'T', detail: 'Créée', byUid: 'lea', byName: 'lea', at: Timestamp.now() });
    await setDoc(doc(db, 'wiki/p1/versions/1'), { title: 'Présence', note: '', byUid: 'lea', byName: 'lea', at: Timestamp.now() });
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

const entry = (uid, extra = {}) => ({
  cat: 'accounts', action: 'Rôle', target: 'zoe', detail: 'Joueur → Désactivé', link: '/conteur/comptes',
  byUid: uid, byName: uid, at: serverTimestamp(), ...extra,
});

test('journal : créé par un conteur ou le principal, à son nom et à l’heure du serveur', async () => {
  await assertSucceeds(setDoc(doc(as('lea'), 'journal/a'), entry('lea')));
  const { link, ...noLink } = entry('marc', { cat: 'rules' });
  await assertSucceeds(setDoc(doc(as('marc'), 'journal/b'), noLink));
  // Suppression d’un lieu, d’un objet ou d’un serviteur (revue) : catégorie « Fiches ».
  await assertSucceeds(setDoc(doc(as('lea'), 'journal/k'), entry('lea', { cat: 'sheets', action: 'Lieu', detail: 'Supprimé', link: null })));
  await assertFails(setDoc(doc(as('julien'), 'journal/c'), entry('julien')));
  await assertFails(setDoc(doc(as('zoe'), 'journal/d'), entry('zoe')));
  await assertFails(setDoc(doc(as('lea'), 'journal/e'), entry('marc')));
  await assertFails(setDoc(doc(as('lea'), 'journal/f'), entry('lea', { at: Timestamp.fromDate(new Date(2020, 0, 1)) })));
  await assertFails(setDoc(doc(as('lea'), 'journal/g'), entry('lea', { extra: 1 })));
  await assertFails(setDoc(doc(as('lea'), 'journal/h'), entry('lea', { cat: 'xp' })));
  await assertFails(setDoc(doc(as('lea'), 'journal/i'), entry('lea', { action: '' })));
  await assertFails(setDoc(doc(as('lea'), 'journal/j'), entry('lea', { detail: 'x'.repeat(301) })));
});

test('journal : ni modifié ni effacé ; lu par le conteur et le principal seulement (Review Focus 4)', async () => {
  await assertFails(updateDoc(doc(as('marc'), 'journal/x'), { detail: 'Autre' }));
  await assertFails(setDoc(doc(as('marc'), 'journal/x'), entry('marc')));
  await assertFails(deleteDoc(doc(as('marc'), 'journal/x')));
  await assertSucceeds(getDoc(doc(as('lea'), 'journal/x')));
  await assertSucceeds(getDocs(query(collection(as('marc'), 'journal'), orderBy('at', 'desc'))));
  await assertFails(getDoc(doc(as('julien'), 'journal/x')));
  await assertFails(getDoc(doc(as('zoe'), 'journal/x')));
});

test('changement de rôle et sa ligne de journal dans le même lot', async () => {
  const db = as('lea');
  const b = writeBatch(db);
  b.update(doc(db, 'users/zoe'), { role: 'disabled' });
  b.set(doc(db, 'journal/r'), entry('lea'));
  await assertSucceeds(b.commit());
});

test('lectures groupées du journal : versions du wiki et historiques, pour l’équipe', async () => {
  const since = Timestamp.fromDate(new Date(2026, 0, 1));
  await assertSucceeds(getDocs(query(collectionGroup(as('lea'), 'versions'), where('at', '>=', since), orderBy('at', 'desc'))));
  await assertSucceeds(getDocs(query(collectionGroup(as('julien'), 'versions'), orderBy('at', 'desc'))));
  await assertFails(getDocs(query(collectionGroup(as('zoe'), 'versions'), orderBy('at', 'desc'))));
  await assertSucceeds(getDocs(query(collectionGroup(as('lea'), 'history'), where('at', '>=', since), orderBy('at', 'desc'))));
});
