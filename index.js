const { setGlobalOptions } = require("firebase-functions");
const { onValueCreated } = require("firebase-functions/v2/database");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

setGlobalOptions({
  maxInstances: 10,
  region: "asia-southeast1",
});

const db = admin.firestore();
const messaging = admin.messaging();
const rtdb = admin.database();

// ============================================================
// HELPERS
// ============================================================

function normalizeEvent(data) {
  const eventType = String(data.eventType || data.type || "").toUpperCase();
  const levelValue = Number(data.level || 0);

  const isLevel2 =
    levelValue >= 2 ||
    eventType.includes("ACCIDENT") ||
    eventType.includes("EMERGENCY") ||
    eventType === "BUZZER_LEVEL2";

  const isLevel1 =
    levelValue === 1 ||
    eventType.includes("SUSPICIOUS") ||
    eventType.includes("MOVEMENT") ||
    eventType === "MOTION_DETECTED" ||
    eventType === "BUZZER_LEVEL1";

  if (!isLevel1 && !isLevel2) return null;

  if (isLevel2) {
    return {
      eventType,
      level: 2,
      title: "MotoGuard Emergency Alert",
      body:
        "Possible accident or strong impact detected. " +
        "Please check your motorcycle and GPS location.",
      channelId: "motoguard_level2",
    };
  }

  return {
    eventType,
    level: 1,
    title: "MotoGuard Security Alert",
    body: "Suspicious movement detected on your motorcycle.",
    channelId: "motoguard_level1",
  };
}

function getEventTimestamp(data) {
  const raw = data.timestampMs ?? data.timestamp ?? data.createdAt;

  if (typeof raw === "number" && Number.isFinite(raw)) {
    const milliseconds = raw > 0 && raw < 100000000000 ? raw * 1000 : raw;
    const date = new Date(milliseconds);
    if (!Number.isNaN(date.getTime())) return date;
  }

  if (typeof raw === "string") {
    const date = new Date(raw);
    if (!Number.isNaN(date.getTime())) return date;
  }

  // Walang timestamp sa event (deviceUptimeMs lang) -> gamitin ang oras ngayon.
  return new Date();
}

// Kunin ang location mula sa event; kung wala, sa gps/{deviceId}.
async function resolveLocation(deviceId, eventData) {
  const evLat = eventData.latitude ?? eventData.lat;
  const evLon = eventData.longitude ?? eventData.lon ?? eventData.lng;

  if (
    typeof evLat === "number" &&
    typeof evLon === "number" &&
    (evLat !== 0 || evLon !== 0)
  ) {
    return { latitude: evLat, longitude: evLon };
  }

  try {
    const snap = await rtdb.ref(`gps/${deviceId}`).get();
    const gps = snap.val();

    if (gps && typeof gps === "object") {
      const lat = gps.latitude ?? gps.lat;
      const lon = gps.longitude ?? gps.lon ?? gps.lng;

      if (
        typeof lat === "number" &&
        typeof lon === "number" &&
        (lat !== 0 || lon !== 0)
      ) {
        return { latitude: lat, longitude: lon };
      }
    }
  } catch (error) {
    logger.warn("GPS fallback read failed.", {
      deviceId,
      errorMessage: error.message || String(error),
    });
  }

  return { latitude: null, longitude: null };
}

// Kolektahin ang lahat ng token ng user (subcollection + legacy field).
async function collectTokens(userRef, userData) {
  const tokens = new Set();

  const tokenSnap = await userRef.collection("fcmTokens").get();
  tokenSnap.forEach((doc) => {
    const t = doc.data()?.token || doc.id;
    if (typeof t === "string" && t.trim()) tokens.add(t.trim());
  });

  const legacy = userData?.fcmToken;
  if (typeof legacy === "string" && legacy.trim()) {
    tokens.add(legacy.trim());
  }

  return Array.from(tokens);
}

const STALE_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

// ============================================================
// REALTIME DATABASE EVENT TRIGGER
//
// RTDB path:
// /sensorEvents/{deviceId}/{eventId}
//
// Firestore device:
// iotDevices/{deviceId}
//
// User notification history:
// users/{uid}/notifications/{eventId}
//
// FCM tokens:
// users/{uid}/fcmTokens/{token}  (+ legacy users/{uid}.fcmToken)
// ============================================================

exports.sendMotoGuardNotification = onValueCreated(
  {
    ref: "/sensorEvents/{deviceId}/{eventId}",
    region: "asia-southeast1",
    instance: "seretei8-default-rtdb",
  },
  async (event) => {
    const deviceId = String(event.params.deviceId);
    const eventId = String(event.params.eventId);
    const eventData = event.data.val();

    if (
      !eventData ||
      typeof eventData !== "object" ||
      Array.isArray(eventData)
    ) {
      logger.info("Empty or invalid event; skipped.", { deviceId, eventId });
      return;
    }

    // Ignore events explicitly marked as disarmed.
    if (eventData.systemArmed === false) {
      logger.info("Device is disarmed; event skipped.", { deviceId, eventId });
      return;
    }

    const normalized = normalizeEvent(eventData);

    if (!normalized) {
      logger.info("Unrecognized event; skipped.", {
        deviceId,
        eventId,
        eventType: eventData.eventType || eventData.type || "",
        level: eventData.level ?? "",
      });
      return;
    }

    try {
      // ------------------------------------------------------
      // 1. Verify the registered device and owner.
      // ------------------------------------------------------

      const deviceSnapshot = await db
        .collection("iotDevices")
        .doc(deviceId)
        .get();

      if (!deviceSnapshot.exists) {
        logger.warn("Device is not registered.", { deviceId });
        return;
      }

      const device = deviceSnapshot.data() || {};
      const ownerUid = String(device.connectedUserId || "");

      if (!ownerUid || device.status !== "connected") {
        logger.warn("Device has no connected owner.", {
          deviceId,
          status: device.status || "",
        });
        return;
      }

      // ------------------------------------------------------
      // 2. Resolve location, then save history (no duplicates).
      // ------------------------------------------------------

      const { latitude, longitude } = await resolveLocation(
        deviceId,
        eventData,
      );

      const userRef = db.collection("users").doc(ownerUid);
      const notificationRef = userRef.collection("notifications").doc(eventId);

      const shouldSend = await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(notificationRef);
        if (existing.exists) return false;

        const eventDate = getEventTimestamp(eventData);

        transaction.set(notificationRef, {
          userId: ownerUid,
          deviceId,
          eventId,
          title: normalized.title,
          message: normalized.body,
          type: normalized.eventType || "DEVICE_STATUS",
          level: normalized.level,
          timestamp: admin.firestore.Timestamp.fromDate(eventDate),
          latitude,
          longitude,
          motionValue: eventData.motionValue ?? null,
          deviceUptimeMs: eventData.deviceUptimeMs ?? null,
          systemArmed: eventData.systemArmed ?? null,
          read: false,
        });

        return true;
      });

      if (!shouldSend) {
        logger.info("Duplicate event; push skipped.", {
          deviceId,
          ownerUid,
          eventId,
        });
        return;
      }

      logger.info("Notification history saved.", {
        deviceId,
        ownerUid,
        eventId,
        level: normalized.level,
        hasLocation: latitude !== null,
      });

      // ------------------------------------------------------
      // 3. Collect FCM tokens of this owner only.
      // ------------------------------------------------------

      const userSnapshot = await userRef.get();
      const tokens = await collectTokens(userRef, userSnapshot.data());

      if (tokens.length === 0) {
        logger.warn("Owner has no FCM tokens.", { deviceId, ownerUid });
        return;
      }

      // ------------------------------------------------------
      // 4. Send push to all of the owner's devices.
      // ------------------------------------------------------

      const isLevel2 = normalized.level >= 2;

      const response = await messaging.sendEachForMulticast({
        tokens,

        notification: {
          title: normalized.title,
          body: normalized.body,
        },

        data: {
          deviceId,
          eventId,
          type: normalized.eventType,
          eventType: normalized.eventType,
          level: String(normalized.level),
          motionValue: String(eventData.motionValue ?? ""),
          eventTime: new Date().toISOString(),
          ...(latitude !== null
            ? { latitude: String(latitude), longitude: String(longitude) }
            : {}),
        },

        android: {
          priority: "high",
          notification: {
            channelId: normalized.channelId,
            ...(isLevel2 ? { sound: "default" } : {}),
          },
        },

        apns: {
          payload: { aps: isLevel2 ? { sound: "default" } : {} },
        },
      });

      logger.info("MotoGuard push result.", {
        deviceId,
        ownerUid,
        eventId,
        level: normalized.level,
        success: response.successCount,
        failure: response.failureCount,
      });

      // ------------------------------------------------------
      // 5. Remove invalid tokens.
      // ------------------------------------------------------

      const cleanup = [];

      response.responses.forEach((r, i) => {
        if (r.success) return;

        const code = r.error?.code || "";

        logger.error("FCM push failed for a token.", {
          deviceId,
          ownerUid,
          eventId,
          errorCode: code,
          errorMessage: r.error?.message || "",
        });

        if (STALE_CODES.has(code)) {
          const bad = tokens[i];

          cleanup.push(userRef.collection("fcmTokens").doc(bad).delete());

          if (userSnapshot.data()?.fcmToken === bad) {
            cleanup.push(
              userRef.set(
                {
                  fcmToken: admin.firestore.FieldValue.delete(),
                  fcmTokenUpdatedAt:
                    admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true },
              ),
            );
          }
        }
      });

      if (cleanup.length > 0) await Promise.all(cleanup);
    } catch (error) {
      // Walang rethrow: kapag nag-retry, makikita ng transaction na
      // existing na ang history doc at i-skip ang push, kaya walang silbi.
      logger.error("MotoGuard event processing failed.", {
        deviceId,
        eventId,
        errorCode: error.code || "",
        errorMessage: error.message || String(error),
      });
    }
  },
);