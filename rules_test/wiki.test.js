import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, updateDoc, deleteDoc, collection, query, where, writeBatch, serverTimestamp } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const content = (over = {}) => ({ title: 'Présence', rubric: 'disciplines', audience: 'all', body: 'Texte', source: '', cat: 'disciplines', entryId: 'pre', ...over });
const free = (over = {}) => {
  const c = content({ rubric: 'chronique', ...over });
  delete c.cat;
  delete c.entryId;
  return c;
};
const stored = (c) => ({ ...c, version: 1, updatedByUid: 'lea', updatedByName: 'lea' });
const page = (uid, version, over = {}) => ({ ...content(over), version, updatedAt: serverTimestamp(), updatedByUid: uid, updatedByName: uid });
const copy = (uid, over = {}) => ({ ...content(over), note: '', byUid: uid, byName: uid, at: serverTimestamp() });
const draft = (uid, over = {}) => ({ ...content(over), baseVersion: 0, updatedAt: serverTimestamp(), updatedByUid: uid, updatedByName: uid });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur', max: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await updateDoc(doc(db, 'users/zoe'), { wikiAudiences: ['clan:toreador', 'sect:camarilla'] });
    await setDoc(doc(db, 'wiki/ouverte'), stored(content()));
    await setDoc(doc(db, 'wiki/opera'), stored(free({ title: 'Le salon de l’Opéra', audience: 'clan:toreador' })));
    await setDoc(doc(db, 'wiki/rue'), stored(free({ title: 'La rue', audience: 'clan:brujah' })));
    await setDoc(doc(db, 'wiki/secret'), stored(free({ title: 'Secret', audience: 'staff' })));
    await setDoc(doc(db, 'wiki/ouverte/versions/1'), { ...content(), note: '', byUid: 'lea', byName: 'lea' });
    await setDoc(doc(db, 'wikiDrafts/ouverte'), { ...content({ body: 'Brouillon' }), baseVersion: 1, updatedByUid: 'lea', updatedByName: 'lea' });
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

const publish = (uid, id, version, over = {}, withCopy = true) => {
  const db = as(uid);
  const b = writeBatch(db);
  b.set(doc(db, `wiki/${id}`), page(uid, version, over));
  if (withCopy) b.set(doc(db, `wiki/${id}/versions/${version}`), copy(uid, over));
  b.delete(doc(db, `wikiDrafts/${id}`));
  return b.commit();
};

test('lecture : un joueur ne voit que les pages de ses audiences (Review Focus 1)', async () => {
  const zoe = as('zoe');
  await assertSucceeds(getDocs(query(collection(zoe, 'wiki'), where('audience', 'in', ['all', 'clan:toreador', 'sect:camarilla']))));
  await assertSucceeds(getDoc(doc(zoe, 'wiki/ouverte')));
  await assertSucceeds(getDoc(doc(zoe, 'wiki/opera')));
  await assertFails(getDoc(doc(zoe, 'wiki/rue')));
  await assertFails(getDoc(doc(zoe, 'wiki/secret')));
  await assertFails(getDocs(collection(zoe, 'wiki')));
  await assertFails(getDocs(query(collection(zoe, 'wiki'), where('audience', 'in', ['all', 'clan:brujah']))));
  await assertSucceeds(getDocs(query(collection(as('max'), 'wiki'), where('audience', 'in', ['all']))));
  await assertFails(getDoc(doc(as('max'), 'wiki/opera')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'wiki/ouverte')));
});

test('lecture : l’équipe voit tout ; brouillons et versions réservés à l’équipe', async () => {
  await assertSucceeds(getDocs(collection(as('julien'), 'wiki')));
  await assertSucceeds(getDoc(doc(as('julien'), 'wiki/secret')));
  await assertSucceeds(getDocs(collection(as('julien'), 'wikiDrafts')));
  await assertSucceeds(getDoc(doc(as('julien'), 'wiki/ouverte/versions/1')));
  await assertFails(getDoc(doc(as('zoe'), 'wikiDrafts/ouverte')));
  await assertFails(getDocs(collection(as('zoe'), 'wikiDrafts')));
  await assertFails(getDoc(doc(as('zoe'), 'wiki/ouverte/versions/1')));
});

test('publication : version + 1 et copie dans le même lot (Review Focus 2, 4)', async () => {
  await assertSucceeds(publish('lea', 'ouverte', 2));
  await assertFails(publish('lea', 'ouverte', 2));
  await assertFails(publish('lea', 'neuve', 2));
  await assertFails(publish('lea', 'neuve', 1, {}, false));
  await assertSucceeds(publish('lea', 'neuve', 1));
  await assertFails(publish('julien', 'autre', 1));
  await assertFails(publish('zoe', 'autre', 1));
});

test('publication : clés, audience, longueurs, auteur', async () => {
  await assertFails(publish('lea', 'a', 1, { secret: true }));
  await assertFails(publish('lea', 'b', 1, { title: '' }));
  await assertFails(publish('lea', 'c', 1, { audience: 'tous' }));
  await assertFails(publish('lea', 'd', 1, { body: 'x'.repeat(50001) }));
  await assertSucceeds(publish('lea', 'e', 1, { audience: 'sect:camarilla' }));
  await assertSucceeds(publish('lea', 'f', 1, { audience: 'staff' }));
  const db = as('lea');
  const b = writeBatch(db);
  b.set(doc(db, 'wiki/g'), { ...page('lea', 1), updatedByUid: 'zoe' });
  b.set(doc(db, 'wiki/g/versions/1'), copy('lea'));
  await assertFails(b.commit());
  await assertFails(updateDoc(doc(as('lea'), 'wiki/ouverte/versions/1'), { note: 'x' }));
});

test('brouillons et suppression : le conte seul (Review Focus 4)', async () => {
  await assertSucceeds(setDoc(doc(as('lea'), 'wikiDrafts/n'), draft('lea')));
  await assertFails(setDoc(doc(as('julien'), 'wikiDrafts/n2'), draft('julien')));
  await assertFails(setDoc(doc(as('zoe'), 'wikiDrafts/n3'), draft('zoe')));
  await assertFails(setDoc(doc(as('lea'), 'wikiDrafts/n4'), { ...draft('lea'), baseVersion: '1' }));
  await assertFails(setDoc(doc(as('lea'), 'wikiDrafts/n5'), { ...draft('lea'), version: 1 }));
  await assertFails(deleteDoc(doc(as('julien'), 'wikiDrafts/ouverte')));
  await assertSucceeds(deleteDoc(doc(as('lea'), 'wikiDrafts/ouverte')));
  await assertFails(deleteDoc(doc(as('zoe'), 'wiki/ouverte')));
  await assertFails(deleteDoc(doc(as('julien'), 'wiki/ouverte')));
  await assertSucceeds(deleteDoc(doc(as('lea'), 'wiki/ouverte')));
});

test('accès : wikiAudiences écrit par conteur et principal seulement (Review Focus 3)', async () => {
  await assertSucceeds(updateDoc(doc(as('lea'), 'users/max'), { wikiAudiences: ['clan:brujah'] }));
  await assertFails(updateDoc(doc(as('zoe'), 'users/zoe'), { wikiAudiences: ['clan:brujah'] }));
  await assertFails(updateDoc(doc(as('julien'), 'users/max'), { wikiAudiences: [] }));
  await assertFails(updateDoc(doc(as('lea'), 'users/max'), { wikiAudiences: Array.from({ length: 30 }, (_, i) => `clan:c${i}`) }));
  await assertFails(updateDoc(doc(as('lea'), 'users/max'), { wikiAudiences: [], role: 'narrateur' }));
  await assertSucceeds(updateDoc(doc(as('zoe'), 'users/zoe'), { displayName: 'Zoé' }));
});
