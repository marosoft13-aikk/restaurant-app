const functions = require('firebase-functions');
const admin = require('firebase-admin');
const geofire = require('geofire-common');

admin.initializeApp();
const firestore = admin.firestore();

const DRIVERS_COLLECTION = 'drivers';
const ORDERS_COLLECTION = 'orders';
const RESTAURANTS_COLLECTION = 'restaurants';

// إعدادات
const SEARCH_RADIUS_KM = 3; // نصف القطر بالكم
const NOTIFY_TOP_N = 3; // عدد السائقين لإرسال الإشعار لهم

// عند إنشاء order: عوّض إحداثيات المطعم من restaurants/{restaurantId} إن وُجدت
exports.populateOrderCoords = functions
  .region('us-central1')
  .firestore.document(`${ORDERS_COLLECTION}/{orderId}`)
  .onCreate(async (snap, ctx) => {
    const data = snap.data() || {};
    if (data.restaurantLat && data.restaurantLng) {
      return null;
    }

    const restId = data.restaurantId || data.restaurant_id;
    if (!restId) return null;

    try {
      const restDoc = await firestore.collection(RESTAURANTS_COLLECTION).doc(String(restId)).get();
      const rest = restDoc.data();
      if (!rest) return null;

      // قراءة الحقول الشائعة بدون استعمال ?. أو ??
      let lat = null;
      let lng = null;

      if (rest.lat !== undefined && rest.lat !== null) {
        lat = rest.lat;
      } else if (rest.location && rest.location.lat !== undefined && rest.location.lat !== null) {
        lat = rest.location.lat;
      } else if (rest.coordinates && rest.coordinates.lat !== undefined && rest.coordinates.lat !== null) {
        lat = rest.coordinates.lat;
      }

      if (rest.lng !== undefined && rest.lng !== null) {
        lng = rest.lng;
      } else if (rest.location && rest.location.lng !== undefined && rest.location.lng !== null) {
        lng = rest.location.lng;
      } else if (rest.coordinates && rest.coordinates.lng !== undefined && rest.coordinates.lng !== null) {
        lng = rest.coordinates.lng;
      }

      if (lat == null || lng == null) return null;

      await snap.ref.set({
        restaurantLat: Number(lat),
        restaurantLng: Number(lng),
      }, { merge: true });

      console.log(`Populated coords for order ${ctx.params.orderId} from restaurant ${restId}`);
      return null;
    } catch (err) {
      console.error('populateOrderCoords error:', err);
      return null;
    }
  });

// عند تغيير حالة الطلب إلى 'ready' — ابحث عن أقرب سائقين وأرسل إشعارات FCM
exports.onOrderReadyDispatch = functions
  .region('us-central1')
  .firestore.document(`${ORDERS_COLLECTION}/{orderId}`)
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (!after) return null;

    const prevStatus = (before && before.status) ? String(before.status).toLowerCase() : '';
    const newStatus = after.status ? String(after.status).toLowerCase() : '';

    if (newStatus !== 'ready' || prevStatus === 'ready') {
      return null;
    }

    if (after.notifiedDrivers && Array.isArray(after.notifiedDrivers) && after.notifiedDrivers.length > 0) {
      console.log('Order already notified:', context.params.orderId);
      return null;
    }

    const rLat = Number(after.restaurantLat || after.lat || 0);
    const rLng = Number(after.restaurantLng || after.lng || 0);
    if (!rLat || !rLng) {
      console.log('Order missing restaurant coordinates; abort dispatch:', context.params.orderId);
      return null;
    }

    const center = [rLat, rLng];
    const bounds = geofire.geohashQueryBounds(center, SEARCH_RADIUS_KM);
    const queries = [];

    for (const b of bounds) {
      const q = firestore.collection(DRIVERS_COLLECTION)
        .where('status', '==', 'available')
        .where('geohash', '>=', b[0])
        .where('geohash', '<=', b[1])
        .limit(50);
      queries.push(q.get());
    }

    const snaps = await Promise.all(queries);
    const matching = [];

    for (const snap of snaps) {
      snap.forEach(doc => {
        const d = doc.data();
        const lat = Number(d.lat);
        const lng = Number(d.lng);
        if (isNaN(lat) || isNaN(lng)) return;
        const distance = geofire.distanceBetween(center, [lat, lng]); // km
        if (distance <= SEARCH_RADIUS_KM) {
          matching.push({ id: doc.id, data: d, distanceKm: distance });
        }
      });
    }

    if (matching.length === 0) {
      console.log('No available drivers found within radius for order:', context.params.orderId);
      await firestore.collection(ORDERS_COLLECTION).doc(context.params.orderId).set({
        notifiedDrivers: [],
        dispatchTriedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      return null;
    }

    matching.sort((a, b) => a.distanceKm - b.distanceKm);
    const selected = matching.slice(0, NOTIFY_TOP_N);

    const tokens = [];
    const driverIds = [];
    for (const s of selected) {
      if (s.data && s.data.fcmToken) tokens.push(s.data.fcmToken);
      driverIds.push(s.id);
    }

    await firestore.collection(ORDERS_COLLECTION).doc(context.params.orderId).set({
      notifiedDrivers: driverIds,
      notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    if (tokens.length === 0) {
      console.log('No FCM tokens for selected drivers.');
      return null;
    }

    const payload = {
      tokens,
      notification: {
        title: 'طلب توصيل جاهز بالقرب منك',
        body: `طلب رقم ${context.params.orderId} جاهز. افتح التطبيق للاطلاع والقبول.`,
      },
      data: {
        type: 'order_ready',
        orderId: context.params.orderId,
      },
    };

    try {
      const resp = await admin.messaging().sendMulticast(payload);
      console.log(`FCM sent: success=${resp.successCount} failure=${resp.failureCount}`);
      if (resp.failureCount > 0) {
        resp.responses.forEach((r, idx) => {
          if (!r.success) {
            console.log('Token failed:', tokens[idx], r.error);
          }
        });
      }
    } catch (err) {
      console.error('FCM send error:', err);
    }

    return null;
  });