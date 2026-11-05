// Run with the emulator: firebase emulators:exec --only firestore "npm --prefix firebase-tests test"
import { readFileSync } from "node:fs";
import { after, before, beforeEach, test } from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from "firebase/firestore";

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "onpurpose-440e1",
    firestore: { rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8") },
  });
});

after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const nick = () => env.authenticatedContext("nick").firestore();
const stranger = () => env.unauthenticatedContext().firestore();

function newPurpose(ownerUid = "nick") {
  return {
    ownerUid,
    senderName: "Nick",
    recipientName: "Dave",
    phrase: "touch grass",
    replyWindowMinutes: 180,
    createdAt: serverTimestamp(),
    dueAt: Timestamp.fromMillis(Date.now() + 3 * 3600 * 1000),
    purposedBackAt: null,
    reply: null,
  };
}

async function seed(id = "p1") {
  await setDoc(doc(nick(), "purposes", id), newPurpose());
}

test("signed-in app can create its own purpose", async () => {
  await assertSucceeds(setDoc(doc(nick(), "purposes", "p1"), newPurpose()));
});

test("can't create without signing in, or as someone else", async () => {
  await assertFails(setDoc(doc(stranger(), "purposes", "p1"), newPurpose()));
  await assertFails(setDoc(doc(nick(), "purposes", "p1"), newPurpose("someone-else")));
});

test("can't create with junk fields or an already-answered purpose", async () => {
  await assertFails(setDoc(doc(nick(), "purposes", "p1"), { ...newPurpose(), admin: true }));
  await assertFails(setDoc(doc(nick(), "purposes", "p1"), { ...newPurpose(), reply: "lol" }));
  await assertFails(setDoc(doc(nick(), "purposes", "p1"), { ...newPurpose(), phrase: "x".repeat(81) }));
});

test("anyone with the link can read that purpose", async () => {
  await seed();
  await assertSucceeds(getDoc(doc(stranger(), "purposes", "p1")));
});

test("strangers can't list purposes; owners can list their own", async () => {
  await seed();
  await assertFails(getDocs(collection(stranger(), "purposes")));
  await assertFails(getDocs(query(collection(nick(), "purposes"))));
  await assertSucceeds(getDocs(query(collection(nick(), "purposes"), where("ownerUid", "==", "nick"))));
});

test("anyone with the link can purpose back once", async () => {
  await seed();
  const ref = doc(stranger(), "purposes", "p1");
  await assertSucceeds(updateDoc(ref, { purposedBackAt: serverTimestamp(), reply: "Consider me purposed ✋" }));
  await assertFails(updateDoc(ref, { purposedBackAt: serverTimestamp(), reply: "again" }));
});

test("purposing back can't change anything else", async () => {
  await seed();
  const ref = doc(stranger(), "purposes", "p1");
  await assertFails(updateDoc(ref, { purposedBackAt: serverTimestamp(), reply: "hi", senderName: "Evil" }));
  await assertFails(updateDoc(ref, { phrase: "send me money" }));
  await assertFails(updateDoc(ref, { purposedBackAt: Timestamp.fromMillis(0), reply: "backdated" }));
});

test("only the owner can delete", async () => {
  await seed();
  await assertFails(deleteDoc(doc(stranger(), "purposes", "p1")));
  await assertSucceeds(deleteDoc(doc(nick(), "purposes", "p1")));
});
