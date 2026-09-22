
exports.onTournamentCreated = onDocumentCreated({
  document: "tournaments/{tournamentId}",
  region: "europe-west1"
}, async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const tournamentData = snapshot.data();
  const location = tournamentData.location || tournamentData.club || "Inconnue";
  const name = tournamentData.name || "Nouveau Tournoi";
  const category = tournamentData.category || "BT";

  try {
    const usersSnapshot = await db.collection("users").where("tournamentAlertsEnabled", "==", true).get();
    
    const messages = [];
    usersSnapshot.forEach(doc => {
      const userData = doc.data();
      const fcmToken = userData.fcmToken;
      if (!fcmToken) return;

      const userRegion = userData.alertRegion;
      let shouldSend = false;

      if (!userRegion) {
        shouldSend = true;
      } else if (location.toLowerCase().includes(userRegion.toLowerCase())) {
        shouldSend = true;
      }

      if (shouldSend) {
        messages.push({
          token: fcmToken,
          notification: {
            title: `Nouveau Tournoi : ${category}`,
            body: `${name} à ${location} ! Allez voir les détails sur l'application.`
          },
          data: {
            type: "new_tournament",
            tournamentId: event.params.tournamentId
          }
        });
      }
    });

    if (messages.length > 0) {
      // Send all messages in chunks of 500 (FCM limit)
      const maxTokens = 500;
      for (let i = 0; i < messages.length; i += maxTokens) {
        const chunk = messages.slice(i, i + maxTokens);
        await admin.messaging().sendAll(chunk);
      }
      logger.info(`Notification de nouveau tournoi envoyée à ${messages.length} joueurs.`);
    }
  } catch (error) {
    logger.error("Erreur lors de l'envoi de la notification onTournamentCreated:", error);
  }
});

exports.syncAndNotifyRankings = onCall({ region: "europe-west1" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new Error("Non autorisé.");
  }

  // Ensure admin
  const userDoc = await db.collection("users").doc(uid).get();
  if (!userDoc.exists || !userDoc.data().isAdmin) {
    throw new Error("Seul un admin peut déclencher cette synchronisation.");
  }

  try {
    const usersSnapshot = await db.collection("users").where("licenceNumber", "!=", null).get();
    let updatedCount = 0;
    let notificationCount = 0;
    
    // We can't batch more than 500 writes, and sending pushes can be batched too
    const dbBatch = db.batch();
    const pushMessages = [];

    for (const doc of usersSnapshot.docs) {
      const userData = doc.data();
      const licence = userData.licenceNumber;
      if (!licence) continue;

      // Clean licence string (remove letter at end if needed)
      const searchLicence = licence.replace(/\D+$/, "");
      
      const fftDoc = await db.collection("fft_rankings").doc(searchLicence).get();
      if (!fftDoc.exists) continue;

      const fftData = fftDoc.data();
      const newRankingRaw = fftData.ranking || fftData.level || "NC";
      const oldRankingRaw = userData.ranking || "NC";

      if (newRankingRaw.toString() !== oldRankingRaw.toString()) {
        let progressionMsg = "";
        let rankingProgression = 0;

        const newRankInt = parseInt(newRankingRaw);
        const oldRankInt = parseInt(oldRankingRaw);

        if (!isNaN(newRankInt) && !isNaN(oldRankInt)) {
          // Si on passe de la place 100 à 50, on a GAGNÉ 50 places.
          // progression = 100 - 50 = +50
          rankingProgression = oldRankInt - newRankInt;
          if (rankingProgression > 0) {
            progressionMsg = ` (+${rankingProgression} places ! 🚀)`;
          } else if (rankingProgression < 0) {
            progressionMsg = ` (${rankingProgression} places 📉)`;
          }
        } else if (oldRankingRaw === "NC" && !isNaN(newRankInt)) {
          progressionMsg = ` (Classé ! 🎉)`;
          rankingProgression = newRankInt; // arbitrary positive value to indicate entry
        }

        dbBatch.update(doc.ref, {
          ranking: newRankingRaw.toString(),
          rankingProgression: rankingProgression
        });
        updatedCount++;

        if (userData.fcmToken) {
          pushMessages.push({
            token: userData.fcmToken,
            notification: {
              title: "Votre classement FFT a été mis à jour !",
              body: `Félicitations, vous êtes maintenant ${newRankingRaw}ème${progressionMsg}`
            },
            data: {
              type: "ranking_update"
            }
          });
        }

        if (updatedCount >= 490) {
          // Prevent batch limits
          await dbBatch.commit();
          break; // For safety we only do 490 at a time, you can loop better in prod
        }
      }
    }

    if (updatedCount > 0) {
      await dbBatch.commit();
    }

    if (pushMessages.length > 0) {
      for (let i = 0; i < pushMessages.length; i += 500) {
        const chunk = pushMessages.slice(i, i + 500);
        await admin.messaging().sendAll(chunk);
      }
      notificationCount = pushMessages.length;
    }

    logger.info(`Rankings synched: ${updatedCount} users updated, ${notificationCount} pushes sent.`);
    return { success: true, updatedCount, notificationCount };

  } catch (error) {
    logger.error("Error in syncAndNotifyRankings", error);
    throw new Error("Erreur de synchronisation.");
  }
});
