import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, deleteDoc, serverTimestamp, Timestamp } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const future = () => Timestamp.fromDate(new Date(Date.now() + 2 * 86400000));
const longAgo = () => Timestamp.fromDate(new Date(2020, 0, 1));
const gameDate = Timestamp.fromDate(new Date(2030, 9, 3));

const night = (uid, over = {}) => ({
  blood: 3, willpower: 1, health: [1, 0, 0], notes: [{ text: 'Inès Morel', at: Timestamp.now() }], byUid: uid, at: serverTimestamp(), ...over,
});
const device = (over = {}) => ({ name: 'Navigateur · Windows', web: true, lastSeen: serverTimestamp(), ...over });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur', tom: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    const chars = { 'zoe-pj': 'zoe', 'zoe-goule': 'zoe', 'tom-pj': 'tom' };
    for (const [id, uid] of Object.entries(chars)) {
      await setDoc(doc(db, `characters/${id}`), { name: id, kind: 'pj', playerUid: uid, status: 'active', version: 1 });
    }
    // Partie g0 : Isaure et la goule de Zoé sont figées ; la version figée de Bastien existe mais il n'est pas dans la partie.
    await setDoc(doc(db, 'games/g0'), {
      date: gameDate, frozenAt: Timestamp.now(), until: future(), liftedAt: null, liftedByUid: null, byUid: 'lea', sheetIds: ['zoe-pj', 'zoe-goule'],
    });
    const sheets = {
      'zoe-pj': { name: 'Isaure', blood: 12, willpower: 6 },
      'zoe-goule': { name: 'Mila', blood: 0, willpower: 3, ghoul: { domitorId: 'zoe-pj' } },
      'tom-pj': { name: 'Bastien', blood: 12, willpower: 6 },
    };
    for (const [id, sheet] of Object.entries(sheets)) {
      await setDoc(doc(db, `characters/${id}/frozen/g0`), { sheet, version: 1, gameDate, at: Timestamp.now(), byUid: 'lea', reason: null });
    }
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();
const nightOf = (uid, cid, gid = 'g0') => doc(as(uid), `characters/${cid}/night/${gid}`);
const dev = (uid, owner = uid, id = 'd1') => doc(as(uid), `users/${owner}/devices/${id}`);

test('suivi : le joueur écrit le sien ; un autre joueur non ; l’équipe lit sans écrire', async () => {
  await assertSucceeds(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe')));
  await assertSucceeds(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe', { blood: 4 })));
  await assertSucceeds(getDoc(nightOf('zoe', 'zoe-pj')));
  await assertFails(setDoc(nightOf('tom', 'zoe-pj'), night('tom')));
  await assertFails(getDoc(nightOf('tom', 'zoe-pj')));
  await assertSucceeds(getDoc(nightOf('lea', 'zoe-pj')));
  await assertSucceeds(getDoc(nightOf('julien', 'zoe-pj')));
  await assertFails(setDoc(nightOf('lea', 'zoe-pj'), night('lea')));
});

test('suivi : fiche hors de la partie, bornes de la version figée, heure, auteur, clés', async () => {
  await assertFails(setDoc(nightOf('tom', 'tom-pj'), night('tom')));
  await assertFails(setDoc(nightOf('zoe', 'zoe-pj', 'g9'), night('zoe')));
  await assertFails(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe', { blood: 13 })));
  await assertFails(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe', { blood: -1 })));
  await assertFails(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe', { willpower: 7 })));
  await assertFails(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe', { health: [21, 0, 0] })));
  await assertFails(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe', { health: [1, 0] })));
  await assertFails(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe', { notes: Array.from({ length: 101 }, () => ({ text: 'x' })) })));
  await assertFails(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe', { at: longAgo() })));
  await assertFails(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe', { byUid: 'tom' })));
  await assertFails(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe', { extra: 1 })));
});

test('suivi : goule bornée à 5 de Vitae', async () => {
  await assertSucceeds(setDoc(nightOf('zoe', 'zoe-goule'), night('zoe', { blood: 5 })));
  await assertFails(setDoc(nightOf('zoe', 'zoe-goule'), night('zoe', { blood: 6 })));
});

test('suivi : accepté après la levée du gel (Review Focus 1) ; jamais supprimé', async () => {
  await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), 'games/g0'), { liftedAt: Timestamp.now(), liftedByUid: 'lea' }));
  await assertSucceeds(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe')));
  await assertFails(deleteDoc(nightOf('zoe', 'zoe-pj')));
  await assertFails(deleteDoc(nightOf('lea', 'zoe-pj')));
});

test('appareils : chacun les siens, personne d’autre, conte compris', async () => {
  await assertSucceeds(setDoc(dev('zoe'), device(), { merge: true }));
  await assertSucceeds(getDoc(dev('zoe')));
  await assertFails(getDoc(dev('tom', 'zoe')));
  await assertFails(getDoc(dev('lea', 'zoe')));
  await assertFails(setDoc(dev('lea', 'zoe', 'd2'), device(), { merge: true }));
  await assertFails(updateDoc(dev('tom', 'zoe'), { revokedAt: serverTimestamp() }));
  await assertFails(deleteDoc(dev('lea', 'zoe')));
  await assertSucceeds(updateDoc(dev('zoe'), { gameId: 'g0', preparedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(dev('zoe'), { revokedAt: serverTimestamp() }));
  await assertSucceeds(setDoc(dev('zoe'), device(), { merge: true }));
  await assertSucceeds(deleteDoc(dev('zoe')));
});

test('appareils : heures du serveur, nom, types, clés', async () => {
  await assertFails(setDoc(dev('zoe'), device({ lastSeen: longAgo() })));
  await assertFails(setDoc(dev('zoe'), device({ name: '' })));
  await assertFails(setDoc(dev('zoe'), device({ web: 'oui' })));
  await assertFails(setDoc(dev('zoe'), device({ extra: 1 })));
  await assertFails(setDoc(dev('zoe'), { name: 'Android', web: false }));
  await assertSucceeds(setDoc(dev('zoe'), device()));
  await assertFails(updateDoc(dev('zoe'), { revokedAt: longAgo() }));
  await assertFails(updateDoc(dev('zoe'), { preparedAt: longAgo() }));
  await assertFails(updateDoc(dev('zoe'), { gameId: 3 }));
});
