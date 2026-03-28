const admin = require('firebase-admin');

// Adjusted path to service account relative to functions directory
const serviceAccount = require('../assets/service_account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const auth = admin.auth();
const db = admin.firestore();

const busData = [
  { name: 'Kinchit', ids: ['5919', '6268', '6042', '5847', '6116', '6054'] },
  { name: 'Choitaly', ids: ['6254', '6292', '6124', '7303', '6199', '5793', '6260', '6104'] },
  { name: 'Taranga', ids: ['6088', '5708', '6137', '6254', '6230', '5044', '6071'] },
  { name: 'Basanta', ids: ['5821', '6071', '6116', '5850', '5992', '7303', '6104', '6115', '5817'] },
  { name: 'Boishakhi', ids: ['5900', '5817', '5867', '6231', '6204', '6264', '5866'] },
  { name: 'Khonika', ids: ['6213', '6262', '5731', '5709', '5724', '5849', '6249', '6824', '6230'] },
  { name: 'Hemonto', ids: ['6028', '6130', '6216', '6205'] },
  { name: 'Falguni', ids: ['6051', '6139', '6239', '5916'] },
  { name: 'Wari-Bateshwar', ids: ['112350'] },
  { name: 'Bikrampur', ids: ['5900', '6231'] }
];

async function createDrivers() {
  console.log('Starting bulk driver creation...');
  let totalCreated = 0;
  let totalUpdated = 0;

  for (const route of busData) {
    const busNamePrefix = route.name.toLowerCase().replace(/[^a-z0-9]/g, '');
    for (const id of route.ids) {
      if (!id) continue;
      
      const email = `${busNamePrefix}${id}@du.ac.bd`;
      const password = `${busNamePrefix}${id}`;
      const displayName = `${route.name} Driver ${id}`;

      try {
        let user;
        try {
          user = await auth.getUserByEmail(email);
          console.log(`[EXISTING] ${email}`);
          totalUpdated++;
        } catch (e) {
          user = await auth.createUser({
            email,
            password,
            displayName,
            emailVerified: true
          });
          console.log(`[CREATED]  ${email}`);
          totalCreated++;
        }

        await db.collection('users').doc(user.uid).set({
          uid: user.uid,
          email,
          displayName,
          role: 'driver',
          busId: id,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

      } catch (err) {
        console.error(`[ERROR]     ${email}: ${err.message}`);
      }
    }
  }
  console.log(`Finished. Created: ${totalCreated}, Updated: ${totalUpdated}`);
  process.exit(0);
}

createDrivers();
