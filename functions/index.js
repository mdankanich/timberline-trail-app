const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const ADMIN_EMAIL = "mdankanich@slovo.org";
const EARTH_RADIUS_METERS = 6371000;
const MAX_ON_TRAIL_DISTANCE_METERS = 120;
const ROUTE_POINT_DISTANCE_GRACE_METERS = 80;

function asString(value, field) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `Invalid ${field}`);
  }
  return value.trim();
}

function asOptionalString(value) {
  if (value == null) return null;
  if (typeof value !== "string") throw new HttpsError("invalid-argument", "Invalid optional string");
  const trimmed = value.trim();
  return trimmed.length ? trimmed : null;
}

function asNumber(value, field) {
  if (typeof value !== "number" || Number.isNaN(value)) {
    throw new HttpsError("invalid-argument", `Invalid ${field}`);
  }
  return value;
}

function validateWaypointPayload(payload, trailId) {
  if (!payload || typeof payload !== "object") {
    throw new HttpsError("invalid-argument", "Missing waypoint payload");
  }

  const resolvedTrailId = asString(payload.trailId, "trailId");
  if (resolvedTrailId !== trailId) {
    throw new HttpsError("invalid-argument", "Waypoint trailId mismatch");
  }

  const type = asString(payload.type, "type");
  const allowedTypes = new Set(["trailhead", "campsite", "water", "viewpoint", "junction", "crossing", "shelter", "waypoint"]);
  if (!allowedTypes.has(type)) {
    throw new HttpsError("invalid-argument", "Invalid waypoint type");
  }

  return {
    trailId: resolvedTrailId,
    name: asString(payload.name, "name"),
    type,
    dangerLevel: asOptionalString(payload.dangerLevel),
    summary: asOptionalString(payload.summary),
    distanceFromStart: asNumber(payload.distanceFromStart, "distanceFromStart"),
    latitude: asNumber(payload.latitude, "latitude"),
    longitude: asNumber(payload.longitude, "longitude"),
    seasonTag: asOptionalString(payload.seasonTag),
    isDeleted: Boolean(payload.isDeleted)
  };
}

function toRadians(value) {
  return value * Math.PI / 180;
}

function haversineMeters(lat1, lon1, lat2, lon2) {
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_METERS * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function nearestDistanceMeters(routePoints, latitude, longitude) {
  let best = Number.POSITIVE_INFINITY;
  for (const point of routePoints) {
    const d = haversineMeters(latitude, longitude, point.latitude, point.longitude);
    if (d < best) best = d;
  }
  return best;
}

exports.submitWaypointMutation = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required");
  }

  const uid = auth.uid;
  const email = auth.token.email || null;
  const isAdmin = email === ADMIN_EMAIL;
  const data = request.data || {};
  const action = asString(data.action, "action");
  const allowedActions = new Set(["add", "edit", "softDelete"]);
  if (!allowedActions.has(action)) {
    throw new HttpsError("invalid-argument", "Invalid action");
  }

  const trailId = asString(data.trailId, "trailId");
  const waypointId = asString(data.waypointId, "waypointId");

  const trailRef = db.collection("trails").doc(trailId);
  const trailSnap = await trailRef.get();
  if (!trailSnap.exists) {
    throw new HttpsError("not-found", "Trail not found");
  }
  const trailData = trailSnap.data() || {};
  const routePoints = Array.isArray(trailData.routePoints) ? trailData.routePoints : [];

  const waypointRef = trailRef.collection("waypoints").doc(waypointId);
  const existingSnap = await waypointRef.get();
  const previousValue = existingSnap.exists ? existingSnap.data() : null;

  let mutation;
  if (action === "softDelete") {
    if (!isAdmin) {
      throw new HttpsError("permission-denied", "Only admin can delete waypoints");
    }
    if (!existingSnap.exists) {
      throw new HttpsError("not-found", "Waypoint not found");
    }
    mutation = {
      ...previousValue,
      isDeleted: true,
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      deletedBy: email || uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedByUID: uid,
      updatedByEmail: email
    };
  } else {
    mutation = validateWaypointPayload(data.waypoint, trailId);
    mutation.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    mutation.updatedByUID = uid;
    mutation.updatedByEmail = email;
    mutation.isDeleted = false;

    if (!isAdmin) {
      const clientLocation = data.clientLocation || {};
      const lat = asNumber(clientLocation.latitude, "clientLocation.latitude");
      const lon = asNumber(clientLocation.longitude, "clientLocation.longitude");
      if (!routePoints.length) {
        throw new HttpsError("failed-precondition", "Trail route points unavailable for server-side validation");
      }
      const nearest = nearestDistanceMeters(routePoints, lat, lon);
      if (nearest > MAX_ON_TRAIL_DISTANCE_METERS + ROUTE_POINT_DISTANCE_GRACE_METERS) {
        throw new HttpsError("permission-denied", "Waypoint updates are only allowed while on trail");
      }
    }
  }

  const changeId = "chg_" + db.collection("_").doc().id.slice(0, 14);
  const changeRef = trailRef.collection("changes").doc(changeId);

  await db.runTransaction(async (tx) => {
    tx.set(waypointRef, mutation, { merge: true });
    tx.set(changeRef, {
      trailId,
      waypointId,
      action,
      actorUID: uid,
      actorEmail: email,
      changedAt: admin.firestore.FieldValue.serverTimestamp(),
      clientTimestamp: data.clientTimestamp ? new Date(data.clientTimestamp) : null,
      previousValue: previousValue,
      newValue: mutation
    }, { merge: false });
    tx.set(trailRef, {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedByUID: uid,
      updatedByEmail: email,
      lastSyncedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
  });

  return {
    ok: true,
    trailId,
    waypointId,
    action,
    changeId
  };
});
