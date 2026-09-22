const admin = require("firebase-admin");
const fs = require("fs");

admin.initializeApp({
  projectId: "beach-tennis-216f4"
});
const db = admin.firestore();

function getCategory(name) {
  const upper = name.toUpperCase();
  if (upper.includes('BT 2000') || upper.includes('BT2000')) return 'BT 2000';
  if (upper.includes('BT 1000') || upper.includes('BT1000')) return 'BT 1000';
  if (upper.includes('BT 500') || upper.includes('BT500')) return 'BT 500';
  if (upper.includes('BT 400') || upper.includes('BT400')) return 'BT 400';
  if (upper.includes('BT 250') || upper.includes('BT250')) return 'BT 250';
  if (upper.includes('BT 100') || upper.includes('BT100')) return 'BT 100';
  if (upper.includes('BT 25') || upper.includes('BT25')) return 'BT 25';
  return 'BT 250'; // Default
}

function parseDates(dateLine) {
  const clean = dateLine.trim();
  if (clean.length === 20) {
    const d1 = clean.substring(0, 10);
    const d2 = clean.substring(10, 20);
    if (d1 === d2) return d1;
    return `${d1} au ${d2}`;
  }
  return clean;
}

async function seed() {
  const content = fs.readFileSync('tournaments_data.txt', 'utf-8');
  // Use regex to split on one or more empty lines
  const blocks = content.split(/\n\s*\n/);

  for (const block of blocks) {
    if (!block.trim()) continue;
    
    // Ignore lines that match numbers like '7.' or '8.' or '9.' at the start
    const cleanBlock = block.replace(/^[0-9]+\.\s*/, '');
    const lines = cleanBlock.split('\n').map(l => l.trim()).filter(l => l);
    
    if (lines.length >= 5) {
      let name = lines[0];
      let location = lines[1];
      let club = lines[2];
      let distanceStr = lines[3];
      let datesStr = lines[4];

      const distVal = parseFloat(distanceStr.replace('km', '').replace(',', '.').trim()) || 0.0;
      
      const doc = {
        name: name,
        location: location,
        club: club,
        distance: distVal,
        dateString: parseDates(datesStr),
        category: getCategory(name)
      };
      
      await db.collection('tournaments').add(doc);
      console.log('Added:', name);
    } else {
        console.log('Skipped block due to missing lines:', lines);
    }
  }
  console.log('Done seeding tournaments.');
  process.exit(0);
}

seed().catch(console.error);
