import fs from "node:fs";
import assert from "node:assert/strict";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {
  doc,
  getDoc,
  writeBatch,
  deleteDoc,
} from "firebase/firestore";

const PROJECT_ID = "guardian-rules-claim-delete";

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync("../firestore.rules", "utf8"),
    },
  });

  try {
    // Seed a caregiver-created pair + pending pairing code as admin.
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      const pairRef = doc(adminDb, "pairs/pair-1");
      const codeRef = doc(adminDb, "pairing/ABC234");
      const batch = writeBatch(adminDb);
      batch.set(pairRef, {
        pair_id: "pair-1",
        caregiver_uid: "caregiver-uid-1",
        parent_uid: null,
        caregiver_device_id: "caregiver-device-1",
        parent_device_id: null,
        created_at_ms: 1700000000000,
        updated_at_ms: 1700000000000,
        settings: { emergency_disabled: false },
      });
      batch.set(codeRef, {
        code: "ABC234",
        pair_id: "pair-1",
        caregiver_device_id: "caregiver-device-1",
        created_at_ms: 1700000000000,
        expires_at_ms: 1700003600000,
        claimed_at_ms: null,
        claimed_by_device_id: null,
        status: "pending",
      });
      await batch.commit();
    });

    const parentDb = testEnv.authenticatedContext("parent-uid-9").firestore();
    const pairRef = doc(parentDb, "pairs/pair-1");
    const codeRef = doc(parentDb, "pairing/ABC234");

    // Allowed: parent links pair + deletes pairing code in one batch.
    const claimBatch = writeBatch(parentDb);
    claimBatch.update(pairRef, {
      parent_uid: "parent-uid-9",
      parent_device_id: "parent-device-9",
      updated_at_ms: 1700000001000,
    });
    claimBatch.delete(codeRef);
    await assertSucceeds(claimBatch.commit());

    const codeSnapshot = await getDoc(codeRef);
    assert.equal(codeSnapshot.exists(), false);

    // Reset state for deny-path checks.
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      const pairResetRef = doc(adminDb, "pairs/pair-1");
      const codeResetRef = doc(adminDb, "pairing/ABC234");
      const resetBatch = writeBatch(adminDb);
      resetBatch.set(
        pairResetRef,
        {
          parent_uid: null,
          parent_device_id: null,
          updated_at_ms: 1700000002000,
        },
        { merge: true },
      );
      resetBatch.set(codeResetRef, {
        code: "ABC234",
        pair_id: "pair-1",
        caregiver_device_id: "caregiver-device-1",
        created_at_ms: 1700000000000,
        expires_at_ms: 1700003600000,
        claimed_at_ms: null,
        claimed_by_device_id: null,
        status: "pending",
      });
      await resetBatch.commit();
    });

    // Denied: delete pairing code without parent-link update.
    await assertFails(deleteDoc(codeRef));

    // Denied: caregiver cannot perform parent-link delete batch.
    const caregiverDb = testEnv
      .authenticatedContext("caregiver-uid-1")
      .firestore();
    const caregiverPairRef = doc(caregiverDb, "pairs/pair-1");
    const caregiverCodeRef = doc(caregiverDb, "pairing/ABC234");
    const caregiverBatch = writeBatch(caregiverDb);
    caregiverBatch.update(caregiverPairRef, {
      parent_uid: "not-the-request-uid",
      parent_device_id: "caregiver-device-1",
      updated_at_ms: 1700000003000,
    });
    caregiverBatch.delete(caregiverCodeRef);
    await assertFails(caregiverBatch.commit());
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
