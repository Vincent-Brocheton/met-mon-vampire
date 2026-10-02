import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, writeBatch, getDocs, collection, query, where } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

async function seed(data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [path, value] of Object.entries(data)) await setDoc(doc(db, path), value);
  });
}
const user = (uid, role, email = `${uid}@ex.fr`) =>
  ({ displayName: uid, email, role, createdAt: new Date(), lastLoginAt: new Date() });
const as = (uid, email = `${uid}@ex.fr`, verified = true) =>
  env.authenticatedContext(uid, { email, email_verified: verified }).firestore();
const CONFIG = { name: 'Paris by Night', associationName: 'Asso', defaultSect: 'Camarilla', ownerUid: 'boss', createdAt: new Date() };

test('premier compte : devient principal en créant la config dans le même batch', async () => {
  const db = as('alice');
  const b = writeBatch(db);
  b.set(doc(db, 'users/alice'), user('alice', 'principal'));
  b.set(doc(db, 'chronicle/config'), { ...CONFIG, name: '', ownerUid: 'alice' });
  await assertSucceeds(b.commit());
});

test('second « premier principal » refusé quand la config existe', async () => {
  await seed({ 'chronicle/config': CONFIG, 'users/boss': user('boss', 'principal') });
  const db = as('eve');
  const b = writeBatch(db);
  b.set(doc(db, 'users/eve'), user('eve', 'principal'));
  b.set(doc(db, 'chronicle/config'), { ...CONFIG, ownerUid: 'eve' });
  await assertFails(b.commit());
});

test('principal sans création de la config : refusé', async () => {
  await assertFails(setDoc(doc(as('eve'), 'users/eve'), user('eve', 'principal')));
});

test('demande d’accès : pending autorisé, joueur refusé, e-mail étranger refusé', async () => {
  await seed({ 'chronicle/config': CONFIG });
  await assertSucceeds(setDoc(doc(as('zoe'), 'users/zoe'), user('zoe', 'pending')));
  await assertFails(setDoc(doc(as('max'), 'users/max'), user('max', 'joueur')));
  await assertFails(setDoc(doc(as('kim'), 'users/kim'), user('kim', 'pending', 'autre@ex.fr')));
});

test('on ne peut pas élever son propre rôle', async () => {
  await seed({ 'chronicle/config': CONFIG, 'users/zoe': user('zoe', 'pending') });
  await assertFails(updateDoc(doc(as('zoe'), 'users/zoe'), { role: 'conteur' }));
});

test('nom affiché : modifiable par soi-même, jamais vide', async () => {
  await seed({ 'users/zoe': user('zoe', 'joueur') });
  await assertSucceeds(updateDoc(doc(as('zoe'), 'users/zoe'), { displayName: 'Zoé A.' }));
  await assertFails(updateDoc(doc(as('zoe'), 'users/zoe'), { displayName: '' }));
});

test('invitation : e-mail vérifié requis, casse ignorée, rôle exact', async () => {
  await seed({
    'users/lea': user('lea', 'pending', 'Lea.G@Ex.fr'),
    'invitations/lea.g@ex.fr': { role: 'conteur', invitedBy: 'boss', createdAt: new Date() },
  });
  await assertFails(updateDoc(doc(as('lea', 'Lea.G@Ex.fr', false), 'users/lea'), { role: 'conteur' }));
  await assertFails(updateDoc(doc(as('lea', 'Lea.G@Ex.fr', true), 'users/lea'), { role: 'principal' }));
  await assertSucceeds(updateDoc(doc(as('lea', 'Lea.G@Ex.fr', true), 'users/lea'), { role: 'conteur' }));
});

test('conteur : seules les transitions de C7 sont permises', async () => {
  await seed({
    'users/lea': user('lea', 'conteur'), 'users/zoe': user('zoe', 'pending'),
    'users/max': user('max', 'joueur'), 'users/boss': user('boss', 'principal'),
  });
  const db = as('lea');
  await assertSucceeds(updateDoc(doc(db, 'users/zoe'), { role: 'joueur' }));
  await assertSucceeds(updateDoc(doc(db, 'users/max'), { role: 'disabled' }));
  await assertSucceeds(updateDoc(doc(db, 'users/max'), { role: 'joueur' }));
  await assertFails(updateDoc(doc(db, 'users/max'), { role: 'conteur' }));
  await assertFails(updateDoc(doc(db, 'users/boss'), { role: 'disabled' }));
  await assertFails(updateDoc(doc(db, 'users/max'), { displayName: 'X' }));
});

test('principal : nomme les autres, jamais lui-même, rôles connus seulement', async () => {
  await seed({ 'users/boss': user('boss', 'principal'), 'users/lea': user('lea', 'joueur') });
  const db = as('boss');
  await assertSucceeds(updateDoc(doc(db, 'users/lea'), { role: 'conteur' }));
  await assertFails(updateDoc(doc(db, 'users/boss'), { role: 'conteur' }));
  await assertFails(updateDoc(doc(db, 'users/lea'), { role: 'roi' }));
});

test('lecture des comptes : soi-même, ou conteur / principal ; pas le narrateur', async () => {
  await seed({
    'users/lea': user('lea', 'conteur'), 'users/julien': user('julien', 'narrateur'),
    'users/max': user('max', 'joueur'), 'users/zoe': user('zoe', 'pending'),
  });
  await assertSucceeds(getDoc(doc(as('max'), 'users/max')));
  await assertFails(getDoc(doc(as('max'), 'users/zoe')));
  await assertFails(getDocs(collection(as('julien'), 'users')));
  await assertSucceeds(getDocs(query(collection(as('lea'), 'users'), where('role', '==', 'pending'))));
});

test('config : lecture publique, écriture par le principal, ownerUid figé', async () => {
  await seed({ 'chronicle/config': CONFIG, 'users/boss': user('boss', 'principal'), 'users/lea': user('lea', 'conteur') });
  await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'chronicle/config')));
  await assertFails(updateDoc(doc(as('lea'), 'chronicle/config'), { name: 'X' }));
  await assertSucceeds(updateDoc(doc(as('boss'), 'chronicle/config'), { name: 'Lyon by Night' }));
  await assertFails(updateDoc(doc(as('boss'), 'chronicle/config'), { ownerUid: 'lea' }));
});

test('invitations : gérées par le principal, lisibles par l’invité', async () => {
  await seed({
    'users/boss': user('boss', 'principal'), 'users/lea': user('lea', 'conteur'),
    'invitations/zoe@ex.fr': { role: 'joueur', invitedBy: 'boss', createdAt: new Date() },
  });
  const inv = { role: 'conteur', invitedBy: 'boss', createdAt: new Date() };
  await assertFails(setDoc(doc(as('lea'), 'invitations/x@ex.fr'), inv));
  await assertSucceeds(setDoc(doc(as('boss'), 'invitations/x@ex.fr'), inv));
  await assertFails(setDoc(doc(as('boss'), 'invitations/y@ex.fr'), { ...inv, role: 'principal' }));
  await assertSucceeds(getDoc(doc(as('zoe'), 'invitations/zoe@ex.fr')));
  await assertFails(getDoc(doc(as('zoe'), 'invitations/x@ex.fr')));
});
