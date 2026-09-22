const admin = require("firebase-admin");
const { onCall } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

exports.verifyLicence = onCall({ region: "europe-west1", invoker: "public" }, async (request) => {
  const licenceNumber = request.data.licenceNumber;
  
  if (!licenceNumber) {
    throw new Error("Numéro de licence manquant");
  }

  logger.info(`Vérification de la licence: ${licenceNumber}`);

  try {
    // The FFT PDF files often omit the final letter of the license.
    // E.g., '4008757U' in the PDF is just '4008757'.
    // We strip any trailing non-digit characters to match the DB.
    const searchLicence = licenceNumber.replace(/\D+$/, "");

    // Look up the license in Firestore 'fft_rankings' collection
    const docRef = db.collection("fft_rankings").doc(searchLicence);
    const docSnap = await docRef.get();

    if (!docSnap.exists) {
      throw new Error(`Licence ${licenceNumber} introuvable dans la base de données.`);
    }

    const playerData = docSnap.data();
    
    // Format the response according to what the frontend expects
    const responseData = {
      firstName: playerData.firstName || "Inconnu",
      lastName: playerData.lastName || "Inconnu",
      level: (playerData.level && parseInt(playerData.level) <= 5) ? playerData.level.toString() : "3", 
      elo: playerData.elo ? playerData.elo.toString() : "0",
      club: playerData.club || "Inconnu",
      licenceNumber: licenceNumber,
      ranking: (playerData.ranking || playerData.level || "NC").toString()
    };

    logger.info("Données récupérées avec succès:", responseData);
    return responseData;

  } catch (error) {
    logger.error("Erreur lors de la vérification de la licence", error);
    throw new Error("Impossible de vérifier cette licence pour le moment.");
  }
});

exports.bulkSeedPlayers = require("firebase-functions/v2/https").onRequest(
  { region: "europe-west1", cors: true, invoker: "public" }, 
  async (req, res) => {
    try {
      if (req.method !== 'POST') {
        return res.status(405).send('Method Not Allowed');
      }

      // Verify Firebase ID Token
      const authHeader = req.headers.authorization || '';
      const idToken = authHeader.startsWith('Bearer ') ? authHeader.split('Bearer ')[1] : null;
      if (!idToken) return res.status(401).send('Unauthorized: missing token');
      
      const decodedToken = await admin.auth().verifyIdToken(idToken);
      if (decodedToken.email !== 'moixmb@gmail.com') {
        return res.status(403).send('Forbidden: admin only');
      }
      
      const players = req.body.players;
      if (!Array.isArray(players)) {
        return res.status(400).send('Expected an array of players');
      }

      const batch = db.batch();
      players.forEach(player => {
        if (player.licenceNumber) {
          const docRef = db.collection("fft_rankings").doc(player.licenceNumber);
          batch.set(docRef, player);
        }
      });

      await batch.commit();
      res.send(`Successfully seeded ${players.length} players.`);
    } catch (e) {
      logger.error("Error seeding players", e);
      res.status(500).send(e.toString());
    }
});

exports.bulkSeedCourts = require("firebase-functions/v2/https").onRequest(
  { region: "europe-west1", cors: true, invoker: "public" }, 
  async (req, res) => {
    try {
      if (req.method !== 'POST') {
        return res.status(405).send('Method Not Allowed');
      }

      // Verify Firebase ID Token
      const authHeader = req.headers.authorization || '';
      const idToken = authHeader.startsWith('Bearer ') ? authHeader.split('Bearer ')[1] : null;
      if (!idToken) return res.status(401).send('Unauthorized: missing token');

      const decodedToken = await admin.auth().verifyIdToken(idToken);
      if (decodedToken.email !== 'moixmb@gmail.com') {
        return res.status(403).send('Forbidden: admin only');
      }
      
      const courts = req.body.courts;
      if (!Array.isArray(courts)) {
        return res.status(400).send('Expected an array of courts');
      }

      const batch = db.batch();
      courts.forEach(court => {
        // Generate a random document ID if we don't have one
        const docRef = db.collection("courts").doc();
        batch.set(docRef, {
          name: court.name,
          latitude: court.lat,
          longitude: court.lon,
          city: court.city || "Inconnue",
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
      });

      await batch.commit();
      res.send(`Successfully seeded ${courts.length} courts.`);
    } catch (e) {
      logger.error("Error seeding courts", e);
      res.status(500).send(e.toString());
    }
});

let cachedRankings = null;
let lastCacheTime = 0;

exports.searchPlayers = onCall({ region: "europe-west1", invoker: "public" }, async (request) => {
  const query = (request.data.query || "").trim().toLowerCase();
  if (!query || query.length < 2) {
    return { results: [] };
  }

  try {
    // Cache all players in memory for 10 minutes to make searches instant
    const now = Date.now();
    if (!cachedRankings || now - lastCacheTime > 600000) {
      logger.info("Loading fft_rankings into memory cache...");
      const snapshot = await db.collection("fft_rankings").get();
      cachedRankings = [];
      snapshot.forEach(doc => {
        cachedRankings.push(doc.data());
      });
      lastCacheTime = now;
      logger.info(`Cached ${cachedRankings.length} players.`);
    }

    const isNumericQuery = /\d/.test(query);
    const cleanQuery = query.replace(/\s/g, "");

    const matches = cachedRankings.filter(p => {
      const licence = (p.licenceNumber || "").toLowerCase();
      const firstName = (p.firstName || "").toLowerCase();
      const lastName = (p.lastName || "").toLowerCase();
      const fullName = `${firstName} ${lastName}`;
      const reversedFullName = `${lastName} ${firstName}`;
      const club = (p.club || "").toLowerCase();

      if (isNumericQuery) {
        return licence.includes(cleanQuery) || licence.includes(query);
      }

      return firstName.includes(query) ||
             lastName.includes(query) ||
             fullName.includes(query) ||
             reversedFullName.includes(query) ||
             club.includes(query);
    });

    // Return top 30 matches
    return { results: matches.slice(0, 30) };

  } catch (error) {
    logger.error("Error searching players", error);
    throw new Error("Erreur lors de la recherche.");
  }
});

exports.onNewMessage = onDocumentCreated({
  document: "chats/{chatId}/messages/{messageId}",
  region: "europe-west1"
}, async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    return;
  }
  const messageData = snapshot.data();
  const senderId = messageData.senderId;
  const receiverId = messageData.receiverId;
  const chatId = event.params.chatId;

  let text = messageData.text || "";
  if (!text) {
    if (messageData.imageUrl) text = "📷 Photo";
    else if (messageData.videoUrl) text = "🎥 Vidéo";
    else if (messageData.audioUrl) text = "🎙️ Message vocal";
    else if (messageData.poll) text = `📊 Sondage : ${messageData.poll.question || "Nouveau sondage"}`;
    else text = "Nouveau message";
  }

  try {
    if (receiverId) {
      // 1-on-1 Direct Message
      const receiverDoc = await db.collection("users").doc(receiverId).get();
      if (!receiverDoc.exists) return;

      const receiverData = receiverDoc.data();
      const fcmToken = receiverData.fcmToken;
      if (!fcmToken) return;

      const senderDoc = await db.collection("users").doc(senderId).get();
      const senderName = senderDoc.exists ? (senderDoc.data().displayName || "Nouveau message") : "Nouveau message";

      const payload = {
        token: fcmToken,
        notification: {
          title: senderName,
          body: text,
        },
        data: {
          type: "chat_message",
          chatId: chatId,
          senderId: senderId,
        },
        android: {
          notification: {
            channelId: "beachmatch_high_importance_channel",
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      };

      await admin.messaging().send(payload);
      logger.info(`Notification 1-to-1 envoyée avec succès à ${receiverId}`);
    } else {
      // Group Chat (Club ou Tournoi)
      const senderName = messageData.senderName || "Un joueur";
      let groupName = "Chat de groupe";
      let notifType = "group_chat";
      let clubId = "";
      let tournamentId = "";
      const recipients = new Set();

      const chatDoc = await db.collection("chats").doc(chatId).get();
      if (chatDoc.exists) {
        const cData = chatDoc.data();
        if (cData.groupName) groupName = cData.groupName;
        (cData.users || []).forEach(u => {
          if (u && u !== senderId) recipients.add(u);
        });
      }

      if (chatId.startsWith("club_")) {
        notifType = "club_message";
        clubId = chatId.replace("club_", "");
        const clubDoc = await db.collection("clubs").doc(clubId).get();
        if (clubDoc.exists) {
          const clubData = clubDoc.data();
          if (clubData.name) groupName = `Taverne · ${clubData.name}`;
          (clubData.memberIds || []).forEach(m => {
            if (m && m !== senderId) recipients.add(m);
          });
        }
      } else if (chatId.startsWith("tournament_")) {
        notifType = "tournament_message";
        tournamentId = chatId.replace("tournament_", "");
        const tDoc = await db.collection("tournaments").doc(tournamentId).get();
        if (tDoc.exists) {
          const tData = tDoc.data();
          if (tData.name) groupName = `Tournoi · ${tData.name}`;
          (tData.registeredPlayerIds || tData.participants || []).forEach(p => {
            const pid = typeof p === 'string' ? p : p.id;
            if (pid && pid !== senderId) recipients.add(pid);
          });
        }
      }

      if (recipients.size === 0) return;

      const messages = [];
      for (const uid of recipients) {
        const uDoc = await db.collection("users").doc(uid).get();
        if (uDoc.exists && uDoc.data().fcmToken) {
          messages.push({
            token: uDoc.data().fcmToken,
            notification: {
              title: groupName,
              body: `${senderName} : ${text}`,
            },
            data: {
              type: notifType,
              chatId: chatId,
              clubId: clubId,
              tournamentId: tournamentId,
            },
            android: {
              notification: {
                channelId: "beachmatch_high_importance_channel",
                sound: "default",
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                },
              },
            },
          });
        }
      }

      if (messages.length > 0) {
        const chunkSize = 500;
        for (let i = 0; i < messages.length; i += chunkSize) {
          const chunk = messages.slice(i, i + chunkSize);
          await admin.messaging().sendAll(chunk);
        }
        logger.info(`Notification groupe (${notifType}) envoyée à ${messages.length} joueurs pour ${chatId}`);
      }
    }
  } catch (error) {
    logger.error("Erreur lors de l'envoi de la notification onNewMessage:", error);
  }
});

// ============================================================================
// 1. NOTIFICATION A : RÉPONSE À UNE DEMANDE DE PARTENAIRE (BOURSE AUX TOURNOIS)
// ============================================================================
exports.onPartnerProposalCreated = onDocumentCreated({
  document: "partner_proposals/{proposalId}",
  region: "europe-west1"
}, async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();
  const targetUserId = data.targetUserId;
  const senderName = data.senderName || "Un joueur";
  const tournamentName = data.tournamentName || "le tournoi";

  if (!targetUserId) return;

  try {
    const userDoc = await db.collection("users").doc(targetUserId).get();
    if (!userDoc.exists) return;
    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) return;

    const payload = {
      token: fcmToken,
      notification: {
        title: "Nouvelle proposition d'équipe ! 🎾",
        body: `${senderName} souhaite faire équipe avec vous pour ${tournamentName} !`
      },
      data: {
        type: "partner_proposal",
        proposalId: event.params.proposalId,
        senderId: data.senderId || "",
        tournamentId: data.tournamentId || ""
      },
      android: {
        notification: {
          channelId: "beachmatch_high_importance_channel",
          sound: "default"
        }
      },
      apns: {
        payload: {
          aps: {
            sound: "default"
          }
        }
      }
    };
    await admin.messaging().send(payload);
    logger.info(`Notification de partenariat envoyée avec succès à ${targetUserId}`);
  } catch (error) {
    logger.error("Erreur lors de l'envoi de la notification onPartnerProposalCreated:", error);
  }
});

// ============================================================================
// 2. NOTIFICATION B : ANNONCE OFFICIELLE DU CLUB (DIFFUSION AUX MEMBRES)
// ============================================================================
exports.onClubNotificationCreated = onDocumentCreated({
  document: "notifications/{notificationId}",
  region: "europe-west1"
}, async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const notif = snapshot.data();
  const userId = notif.userId;
  if (!userId) return;

  try {
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) return;
    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) return;

    const payload = {
      token: fcmToken,
      notification: {
        title: notif.title || "Annonce de votre Club 📢",
        body: notif.body || "Une nouvelle annonce officielle a été publiée."
      },
      data: {
        type: notif.type || "club_announcement",
        clubId: notif.clubId || "",
        notificationId: event.params.notificationId
      },
      android: {
        notification: {
          channelId: "beachmatch_high_importance_channel",
          sound: "default"
        }
      },
      apns: {
        payload: {
          aps: {
            sound: "default"
          }
        }
      }
    };
    await admin.messaging().send(payload);
    logger.info(`Push annonce club envoyé avec succès à ${userId}`);
  } catch (error) {
    logger.error("Erreur lors de l'envoi de l'annonce club:", error);
  }
});

// ============================================================================
// 3. NOTIFICATION C : DÉSISTEMENT / NOUVEAU JOUEUR / CARRÉ COMPLET SUR UN MATCH
// ============================================================================
exports.onMatchUpdated = onDocumentUpdated({
  document: "matches/{matchId}",
  region: "europe-west1"
}, async (event) => {
  const beforeData = event.data.before ? event.data.before.data() : null;
  const afterData = event.data.after ? event.data.after.data() : null;
  if (!beforeData || !afterData) return;

  const beforeUsers = beforeData.participantsIds || [];
  const afterUsers = afterData.participantsIds || [];

  // 1. Détection de désistement : le nombre de participants a diminué
  if (beforeUsers.length > afterUsers.length) {
    const leftUserId = beforeUsers.find(u => !afterUsers.includes(u));
    if (!leftUserId) return;

    try {
      const leftUserDoc = await db.collection("users").doc(leftUserId).get();
      const leftUserName = leftUserDoc.exists ? (leftUserDoc.data().displayName || "Un joueur") : "Un joueur";

      // Prévenir tous les participants restants + l'hôte
      const recipients = new Set([...afterUsers, afterData.hostId].filter(id => id && id !== leftUserId));

      for (const recipientId of recipients) {
        const rDoc = await db.collection("users").doc(recipientId).get();
        if (rDoc.exists && rDoc.data().fcmToken) {
          const payload = {
            token: rDoc.data().fcmToken,
            notification: {
              title: "⚠️ Désistement sur votre partie",
              body: `${leftUserName} s'est désisté de la partie. Il manque un joueur pour compléter le carré !`
            },
            data: {
              type: "match_player_left",
              matchId: event.params.matchId
            },
            android: {
              notification: {
                channelId: "beachmatch_high_importance_channel",
                sound: "default"
              }
            },
            apns: {
              payload: {
                aps: {
                  sound: "default"
                }
              }
            }
          };
          await admin.messaging().send(payload);
        }
      }
      logger.info(`Alerte désistement envoyée aux ${recipients.size} joueurs du match ${event.params.matchId}`);
    } catch (error) {
      logger.error("Erreur lors de l'alerte désistement onMatchUpdated:", error);
    }
  }

  // 2. Détection de nouveau joueur inscrit : le nombre de participants a augmenté
  if (afterUsers.length > beforeUsers.length) {
    const joinedUserId = afterUsers.find(u => !beforeUsers.includes(u));
    if (!joinedUserId) return;

    try {
      const joinedUserDoc = await db.collection("users").doc(joinedUserId).get();
      const joinedUserName = joinedUserDoc.exists ? (joinedUserDoc.data().displayName || "Un joueur") : "Un joueur";
      const totalCount = afterUsers.length;

      let courtName = "le terrain";
      if (afterData.courtId) {
        const cDoc = await db.collection("courts").doc(afterData.courtId).get();
        if (cDoc.exists && cDoc.data().name) courtName = cDoc.data().name;
      }

      // Si le carré est complet (4 joueurs)
      if (totalCount >= 4) {
        const allRecipients = new Set([...afterUsers, afterData.hostId].filter(Boolean));
        for (const recipientId of allRecipients) {
          const rDoc = await db.collection("users").doc(recipientId).get();
          if (rDoc.exists && rDoc.data().fcmToken) {
            const payload = {
              token: rDoc.data().fcmToken,
              notification: {
                title: "🔥 Carré complet ! (4/4 joueurs)",
                body: `Vos 4 joueurs sont prêts pour la partie à ${courtName} ! À vos raquettes ! 🎾`
              },
              data: {
                type: "match_full",
                matchId: event.params.matchId
              },
              android: {
                notification: {
                  channelId: "beachmatch_high_importance_channel",
                  sound: "default"
                }
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default"
                  }
                }
              }
            };
            await admin.messaging().send(payload);
          }
        }
        logger.info(`Notification carré complet (4/4) envoyée pour le match ${event.params.matchId}`);
      } else {
        // Alerte à l'hôte qu'un joueur a rejoint
        const hostId = afterData.hostId;
        if (hostId && hostId !== joinedUserId) {
          const hostDoc = await db.collection("users").doc(hostId).get();
          if (hostDoc.exists && hostDoc.data().fcmToken) {
            const payload = {
              token: hostDoc.data().fcmToken,
              notification: {
                title: "🎾 Nouveau joueur inscrit !",
                body: `${joinedUserName} a rejoint votre partie (${totalCount}/4 joueurs inscrits).`
              },
              data: {
                type: "match_joined",
                matchId: event.params.matchId
              },
              android: {
                notification: {
                  channelId: "beachmatch_high_importance_channel",
                  sound: "default"
                }
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default"
                  }
                }
              }
            };
            await admin.messaging().send(payload);
            logger.info(`Notification nouveau joueur envoyée à l'hôte ${hostId}`);
          }
        }
      }
    } catch (error) {
      logger.error("Erreur lors de l'alerte nouveau joueur onMatchUpdated:", error);
    }
  }
});

// ============================================================================
// 4. NOTIFICATION D : RAPPEL H-2 AVANT LE DÉBUT D'UNE PARTIE PROGRAMMÉE
// ============================================================================
exports.reminderScheduledMatches = onSchedule({
  schedule: "every 15 minutes",
  region: "europe-west1"
}, async (event) => {
  try {
    const now = Date.now();
    // Fenêtre de détection : entre 1h45 (105 min) et 2h15 (135 min) avant le match
    const minTime = now + (105 * 60 * 1000);
    const maxTime = now + (135 * 60 * 1000);

    const snapshot = await db.collection("matches")
      .where("status", "==", "scheduled")
      .get();

    for (const doc of snapshot.docs) {
      const data = doc.data();
      if (!data.scheduledTime || data.reminderSent === true) continue;

      let matchTimeMs;
      if (data.scheduledTime.toDate) {
        matchTimeMs = data.scheduledTime.toDate().getTime();
      } else if (typeof data.scheduledTime === 'string') {
        matchTimeMs = new Date(data.scheduledTime).getTime();
      } else {
        continue;
      }

      if (matchTimeMs >= minTime && matchTimeMs <= maxTime) {
        let courtName = "le terrain";
        if (data.courtId) {
          const cDoc = await db.collection("courts").doc(data.courtId).get();
          if (cDoc.exists) courtName = cDoc.data().name || courtName;
        }

        const recipients = new Set([...(data.participantsIds || []), data.hostId].filter(Boolean));
        for (const recipientId of recipients) {
          const rDoc = await db.collection("users").doc(recipientId).get();
          if (rDoc.exists && rDoc.data().fcmToken) {
            const payload = {
              token: rDoc.data().fcmToken,
              notification: {
                title: "🏖️ Votre partie débute dans 2h !",
                body: `Rendez-vous à ${courtName}. Vos partenaires sont prêts, n'oubliez pas vos raquettes !`
              },
              data: {
                type: "match_reminder",
                matchId: doc.id
              },
              android: {
                notification: {
                  channelId: "beachmatch_high_importance_channel",
                  sound: "default"
                }
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default"
                  }
                }
              }
            };
            try {
              await admin.messaging().send(payload);
            } catch (e) {
              logger.error(`Erreur push rappel H-2 vers ${recipientId}:`, e);
            }
          }
        }

        await doc.ref.update({ reminderSent: true });
        logger.info(`Rappel H-2 envoyé pour le match ${doc.id}`);
      }
    }
  } catch (error) {
    logger.error("Erreur dans reminderScheduledMatches:", error);
  }
});

// ============================================================================
// 5. NOTIFICATION E : ALERTE DIRECT VIDÉO BEACHSCORE EN DIRECT
// ============================================================================
exports.onProMatchLive = onDocumentUpdated({
  document: "pro_matches/{matchId}",
  region: "europe-west1"
}, async (event) => {
  const before = event.data.before ? event.data.before.data() : null;
  const after = event.data.after ? event.data.after.data() : null;
  if (!before || !after) return;

  // Détection du passage en direct
  if (before.status !== "LIVE" && after.status === "LIVE") {
    try {
      const topic = "beachscore_live";
      const payload = {
        notification: {
          title: "🔴 Match en Direct Vidéo !",
          body: `${after.team1} vs ${after.team2} est en direct sur ${after.court || "le Court Central"} (${after.round}) !`
        },
        data: {
          type: "pro_match_live",
          matchId: event.params.matchId,
          streamUrl: after.streamUrl || "https://www.youtube.com/@ITFBeachTennisTour"
        },
        topic: topic,
        android: {
          notification: {
            channelId: "beachmatch_high_importance_channel",
            sound: "default"
          }
        },
        apns: {
          payload: {
            aps: {
              sound: "default"
            }
          }
        }
      };

      await admin.messaging().send(payload);
      logger.info(`Alerte Direct Vidéo BeachScore envoyée au topic ${topic} pour ${event.params.matchId}`);
    } catch (error) {
      logger.error("Erreur lors de l'alerte onProMatchLive:", error);
    }
  }
});

exports.confirmMatchScore = onCall({ region: "europe-west1" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new Error("Vous devez être connecté pour valider un match.");
  }

  const { matchId, presentUserIds } = request.data;
  if (!matchId || !Array.isArray(presentUserIds)) {
    throw new Error("Paramètres invalides.");
  }

  const matchRef = db.collection("matches").doc(matchId);
  const matchDoc = await matchRef.get();

  if (!matchDoc.exists) {
    throw new Error("Le match n'existe pas.");
  }

  const matchData = matchDoc.data();
  
  if (matchData.hostId !== uid) {
    throw new Error("Seul le créateur du match peut valider les scores.");
  }

  if (matchData.status === "completed") {
    throw new Error("Ce match a déjà été validé.");
  }

  const batch = db.batch();
  
  // Update match status
  batch.update(matchRef, {
    status: "completed",
    presentParticipants: presentUserIds
  });

  // Award points and update totalMatches
  for (const participantId of presentUserIds) {
    const userRef = db.collection("users").doc(participantId);
    batch.update(userRef, {
      eloScore: admin.firestore.FieldValue.increment(40),
      totalMatches: admin.firestore.FieldValue.increment(1)
    });
  }

  await batch.commit();
  logger.info(`Match ${matchId} validé par ${uid}. Points distribués à ${presentUserIds.length} joueurs.`);

  // Notification Push à tous les joueurs présents
  for (const participantId of presentUserIds) {
    try {
      const pDoc = await db.collection("users").doc(participantId).get();
      if (pDoc.exists && pDoc.data().fcmToken) {
        await admin.messaging().send({
          token: pDoc.data().fcmToken,
          notification: {
            title: "🏆 Match validé !",
            body: "Votre partie a été validée ! Vous remportez +40 points ELO et progressez au classement !",
          },
          data: {
            type: "score_confirmed",
            matchId: matchId,
          },
          android: {
            notification: {
              channelId: "beachmatch_high_importance_channel",
              sound: "default",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
        });
      }
    } catch (e) {
      logger.error(`Erreur push score confirm pour ${participantId}:`, e);
    }
  }
  
  return { success: true };
});

exports.onMatchCreated = onDocumentCreated({
  document: "matches/{matchId}",
  region: "europe-west1"
}, async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    return;
  }
  const matchData = snapshot.data();
  const courtId = matchData.courtId;
  const hostId = matchData.hostId;
  const targetLevel = matchData.targetLevel || "NC";

  if (!courtId) return;

  try {
    // Get host name
    const hostDoc = await db.collection("users").doc(hostId).get();
    const hostName = hostDoc.exists ? hostDoc.data().displayName : "Un joueur";

    // Get court name
    const courtDoc = await db.collection("courts").doc(courtId).get();
    const courtName = courtDoc.exists ? courtDoc.data().name : "un terrain";

    const topic = `court_${courtId}`;

    const payload = {
      notification: {
        title: "Nouvelle partie de Beach Tennis !",
        body: `${hostName} a créé une partie de niveau ${targetLevel} à ${courtName}. Rejoignez-la vite !`
      },
      data: {
        type: "new_match",
        matchId: event.params.matchId
      },
      topic: topic,
      android: {
        notification: {
          channelId: "beachmatch_high_importance_channel",
          sound: "default"
        }
      },
      apns: {
        payload: {
          aps: {
            sound: "default"
          }
        }
      }
    };

    const response = await admin.messaging().send(payload);
    logger.info(`Notification envoyée au topic ${topic}:`, response);
  } catch (error) {
    logger.error("Erreur lors de l'envoi de la notification de nouveau match:", error);
  }
});

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
          },
          android: {
            notification: {
              channelId: "beachmatch_high_importance_channel",
              sound: "default"
            }
          },
          apns: {
            payload: {
              aps: {
                sound: "default"
              }
            }
          }
        });
      }
    });

    if (messages.length > 0) {
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
    
    const dbBatch = db.batch();
    const pushMessages = [];

    for (const doc of usersSnapshot.docs) {
      const userData = doc.data();
      const licence = userData.licenceNumber;
      if (!licence) continue;

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
          rankingProgression = oldRankInt - newRankInt;
          if (rankingProgression > 0) {
            progressionMsg = ` (+${rankingProgression} places ! 🚀)`;
          } else if (rankingProgression < 0) {
            progressionMsg = ` (${rankingProgression} places 📉)`;
          }
        } else if (oldRankingRaw === "NC" && !isNaN(newRankInt)) {
          progressionMsg = ` (Classé ! 🎉)`;
          rankingProgression = newRankInt;
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
            },
            android: {
              notification: {
                channelId: "beachmatch_high_importance_channel",
                sound: "default"
              }
            },
            apns: {
              payload: {
                aps: {
                  sound: "default"
                }
              }
            }
          });
        }

        if (updatedCount >= 490) {
          await dbBatch.commit();
          break;
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
