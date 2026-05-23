const admin = require("firebase-admin");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");

admin.initializeApp();

exports.pushEmergencyDisableUpdate = onDocumentUpdated(
  "pairs/{pairId}",
  async (event) => {
    const beforeSettings = event.data?.before?.data()?.settings || {};
    const afterSettings = event.data?.after?.data()?.settings || {};
    const beforeValue = !!beforeSettings.emergency_disabled;
    const afterValue = !!afterSettings.emergency_disabled;

    if (beforeValue === afterValue) {
      return;
    }

    const pairId = event.params.pairId;
    const devicesSnapshot = await admin
      .firestore()
      .collection("pairs")
      .doc(pairId)
      .collection("devices")
      .where("role", "==", "parent")
      .get();

    const tokens = devicesSnapshot.docs
      .map((doc) => String(doc.get("fcm_token") || "").trim())
      .filter((token) => token.length > 0);

    if (tokens.length === 0) {
      return;
    }

    await admin.messaging().sendEachForMulticast({
      tokens,
      data: {
        event_type: "emergency_disable_changed",
        pair_id: pairId,
        emergency_disabled: afterValue ? "true" : "false",
      },
      android: {
        priority: "high",
      },
    });
  },
);
