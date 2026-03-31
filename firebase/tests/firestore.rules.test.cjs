const fs = require("fs");
const path = require("path");
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds
} = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc, updateDoc, deleteDoc } = require("firebase/firestore");

const projectId = "timberline-trail-app-rules";
const rules = fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8");

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules }
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test("unauthenticated user cannot read trail", async () => {
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, "trails/trail-1")));
});

test("owner can read and write own profile doc", async () => {
  const db = testEnv.authenticatedContext("u1", { email: "u1@example.com" }).firestore();
  await assertSucceeds(setDoc(doc(db, "users/u1/data/profile"), { name: "U1" }));
  await assertSucceeds(getDoc(doc(db, "users/u1/data/profile")));
});

test("user cannot read another user's profile", async () => {
  const db = testEnv.authenticatedContext("u1", { email: "u1@example.com" }).firestore();
  await assertFails(getDoc(doc(db, "users/u2/data/profile")));
});

test("non-admin cannot write trail root metadata", async () => {
  const db = testEnv.authenticatedContext("u1", { email: "u1@example.com" }).firestore();
  await assertFails(setDoc(doc(db, "trails/trail-1"), { name: "Trail 1" }));
});

test("admin can write trail root metadata", async () => {
  const db = testEnv.authenticatedContext("admin-uid", { email: "mdankanich@slovo.org" }).firestore();
  await assertSucceeds(setDoc(doc(db, "trails/trail-1"), { name: "Trail 1", updatedByUID: "admin-uid" }));
});

test("signed-in user can create waypoint with valid shape", async () => {
  const db = testEnv.authenticatedContext("u1", { email: "u1@example.com" }).firestore();
  await assertSucceeds(
    setDoc(doc(db, "trails/trail-1/waypoints/wp-1"), {
      trailId: "trail-1",
      name: "Water Crossing",
      type: "crossing",
      dangerLevel: "high",
      summary: "Fast current",
      distanceFromStart: 10.2,
      latitude: 45.1234,
      longitude: -121.4567,
      seasonTag: "Spring",
      isDeleted: false,
      deletedAt: null,
      deletedBy: null,
      updatedAt: new Date(),
      updatedByUID: "u1",
      updatedByEmail: "u1@example.com"
    })
  );
});

test("signed-in user cannot hard-delete waypoint doc", async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "trails/trail-1/waypoints/wp-delete"), {
      trailId: "trail-1",
      name: "Delete Test",
      type: "waypoint",
      dangerLevel: null,
      summary: null,
      distanceFromStart: 1.1,
      latitude: 45.1,
      longitude: -121.1,
      seasonTag: null,
      isDeleted: false,
      deletedAt: null,
      deletedBy: null,
      updatedAt: new Date(),
      updatedByUID: "seed",
      updatedByEmail: "seed@example.com"
    });
  });

  const db = testEnv.authenticatedContext("u1", { email: "u1@example.com" }).firestore();
  await assertFails(deleteDoc(doc(db, "trails/trail-1/waypoints/wp-delete")));
});

test("changes log is append-only", async () => {
  const db = testEnv.authenticatedContext("u1", { email: "u1@example.com" }).firestore();
  const changeRef = doc(db, "trails/trail-1/changes/change-1");
  await assertSucceeds(
    setDoc(changeRef, {
      trailId: "trail-1",
      waypointId: "wp-1",
      action: "edit",
      actorUID: "u1",
      changedAt: new Date()
    })
  );
  await assertFails(updateDoc(changeRef, { action: "add" }));
});

test("invalid waypoint payload is denied", async () => {
  const db = testEnv.authenticatedContext("u1", { email: "u1@example.com" }).firestore();
  await assertFails(
    setDoc(doc(db, "trails/trail-1/waypoints/wp-invalid"), {
      trailId: "another-trail",
      name: "Bad",
      type: "waypoint",
      distanceFromStart: 1.0,
      latitude: 1.0,
      longitude: 1.0,
      isDeleted: false,
      updatedByUID: "u1"
    })
  );
});

test("rules test harness sanity", () => {
  assert.ok(testEnv);
});
