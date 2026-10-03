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

const char = (over) => ({
  name: 'Isaure', kind: 'pj', playerUid: 'zoe', playerName: 'Zoé', status: 'active',
  xpEarned: 0, xpSpent: 0, version: 1, lastHistoryId: 'h1', createdAt: new Date(), ...over,
});
const req = (over) => ({
  characterId: 'zoe-pj', characterName: 'Isaure', playerUid: 'zoe', playerName: 'Zoé', status: 'pending',
  items: [], total: 4, justification: 'Leçons', thread: [], version: 1, ...over,
});
const msg = (byUid, text) => ({ byUid, byName: byUid, atMs: 1, text });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { boss: 'principal', lea: 'conteur', julien: 'narrateur', zoe: 'joueur', max: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: 'x@ex.fr', role });
    await setDoc(doc(db, 'characters/zoe-pj'), char({}));
    await setDoc(doc(db, 'characters/zoe-draft'), char({ status: 'draft' }));
    await setDoc(doc(db, 'characters/max-pj'), char({ playerUid: 'max' }));
    await setDoc(doc(db, 'characters/lea-pj'), char({ playerUid: 'lea' }));
    await setDoc(doc(db, 'requests/r1'), req({}));
    await setDoc(doc(db, 'requests/r-changes'), req({ status: 'changes', thread: [msg('lea', 'Précise.')] }));
    await setDoc(doc(db, 'requests/r-lea'), req({ characterId: 'lea-pj', playerUid: 'lea' }));
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();
const create = (uid, id, data) => setDoc(doc(as(uid), `requests/${id}`), data);
const edit = (uid, id, changes) => updateDoc(doc(as(uid), `requests/${id}`), { version: 2, ...changes });

function decide(uid, id, cid, status, thread, withCharacter) {
  const db = as(uid);
  const b = writeBatch(db);
  b.update(doc(db, `requests/${id}`), { status, thread, version: 2, decidedAt: serverTimestamp(), decidedByUid: uid });
  if (withCharacter) {
    b.update(doc(db, `characters/${cid}`), { xpSpent: 4, version: 2, lastHistoryId: 'h2' });
    b.set(doc(db, `characters/${cid}/history/h2`), { at: serverTimestamp(), byUid: uid, kind: 'xp', reason: 'Demande validée', summary: [] });
  }
  return b.commit();
}

test('le joueur crée une demande pour sa fiche active seulement', async () => {
  await assertSucceeds(create('zoe', 'n1', req({ status: 'draft' })));
  await assertFails(create('zoe', 'n2', req({ characterId: 'max-pj' })));
  await assertFails(create('zoe', 'n3', req({ characterId: 'zoe-draft' })));
  await assertFails(create('zoe', 'n4', req({ status: 'accepted' })));
  await assertFails(create('max', 'n5', req({ characterId: 'max-pj' })));
  await assertFails(create('zoe', 'n6', req({ thread: [msg('lea', 'Validé')] })));
});

test('le joueur renvoie et annule ; jamais de décision ni de fil effacé (Review Focus 3)', async () => {
  await assertFails(edit('zoe', 'r1', { status: 'accepted' }));
  await assertFails(edit('zoe', 'r1', { characterId: 'max-pj' }));
  await assertFails(edit('max', 'r1', { justification: 'x' }));
  await assertFails(edit('zoe', 'r-changes', { thread: [], status: 'pending' }));
  await assertFails(edit('zoe', 'r-changes', { thread: [msg('lea', 'Précise.'), msg('lea', 'Validé')], status: 'pending' }));
  await assertSucceeds(edit('zoe', 'r-changes', { thread: [msg('lea', 'Précise.'), msg('zoe', 'Voilà.')], status: 'pending' }));
  await assertSucceeds(edit('zoe', 'r1', { status: 'cancelled' }));
});

test('validation : la fiche change dans le même lot (Review Focus 4)', async () => {
  await assertFails(decide('lea', 'r1', 'zoe-pj', 'accepted', [], false));
  await assertFails(decide('julien', 'r1', 'zoe-pj', 'accepted', [], true));
  await assertFails(decide('lea', 'r-lea', 'lea-pj', 'accepted', [], true));
  await assertFails(decide('zoe', 'r1', 'zoe-pj', 'accepted', [], true));
  await assertSucceeds(decide('lea', 'r1', 'zoe-pj', 'accepted', [], true));
});

test('compléments et refus : un message du conte', async () => {
  await assertFails(decide('lea', 'r1', 'zoe-pj', 'changes', [], false));
  await assertFails(decide('lea', 'r1', 'zoe-pj', 'changes', [msg('zoe', 'Faux.')], false));
  await assertFails(decide('lea', 'r-changes', 'zoe-pj', 'rejected', [msg('lea', 'Précise.'), msg('lea', 'Non.')], false));
  await assertSucceeds(decide('boss', 'r1', 'zoe-pj', 'rejected', [msg('boss', 'Hors récit.')], false));
});

test('bonus sur une fiche : motif obligatoire', async () => {
  const award = (reason) => {
    const db = as('lea');
    const b = writeBatch(db);
    b.update(doc(db, 'characters/zoe-pj'), { xpEarned: 2, version: 2, lastHistoryId: 'h2' });
    b.set(doc(db, 'characters/zoe-pj/history/h2'), { at: serverTimestamp(), byUid: 'lea', kind: 'award', reason, summary: [] });
    return b.commit();
  };
  await assertFails(award(''));
  await assertSucceeds(award('Scène de la Cour'));
});
