/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onCall, onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

// Firebase Admin SDK'yı initialize et
admin.initializeApp();

// Firestore ve Messaging referansları
const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Beta kullanıcılarına güncelleme bildirimi gönderen Cloud Function
 * Bu fonksiyon Firestore'da admin_notifications koleksiyonuna yeni bir belge eklendiğinde tetiklenir
 */
exports.sendUpdateNotificationToBetaUsers = onDocumentCreated(
    'admin_notifications/{notificationId}',
    async (event) => {
        try {
            const snap = event.data;
            const notificationData = snap.data();
            
            // Sadece app_update türündeki bildirimleri işle
            if (notificationData.type !== 'app_update') {
                console.log('Notification type is not app_update, skipping...');
                return null;
            }

            // Bildirim verilerini al
            const {
                data: updateData,
                topic,
                targetAudience
            } = notificationData;

            const {
                new_version,
                update_message,
                download_url,
                force_update
            } = updateData;

            // Bildirim mesajını oluştur
            const message = {
                notification: {
                    title: '🚀 Yeni Güncelleme Mevcut!',
                    body: `Sürüm ${new_version} • ${update_message}`
                },
                data: {
                    type: 'app_update',
                    new_version: new_version,
                    update_message: update_message,
                    download_url: download_url,
                    force_update: force_update ? 'true' : 'false',
                    timestamp: new Date().toISOString()
                },
                android: {
                    notification: {
                        channelId: 'update_notifications',
                        priority: 'high',
                        defaultSound: true,
                        defaultVibrateTimings: true,
                        icon: 'ic_notification',
                        color: '#FF6B35'
                    },
                    data: {
                        type: 'app_update',
                        new_version: new_version,
                        update_message: update_message,
                        download_url: download_url,
                        force_update: force_update ? 'true' : 'false'
                    }
                },
                apns: {
                    payload: {
                        aps: {
                            alert: {
                                title: '🚀 Yeni Güncelleme Mevcut!',
                                body: `Sürüm ${new_version} • ${update_message}`
                            },
                            badge: 1,
                            sound: 'default',
                            category: 'UPDATE_NOTIFICATION'
                        }
                    }
                }
            };

            // Topic'e bildirim gönder
            if (topic) {
                message.topic = topic;
                const response = await messaging.send(message);
                console.log('Successfully sent message to topic:', response);
                
                // Bildirim durumunu güncelle
                await snap.ref.update({
                    status: 'sent',
                    sentAt: admin.firestore.FieldValue.serverTimestamp(),
                    response: response
                });
            }

            // Ayrıca beta kullanıcılarına direkt token ile gönder (yedek)
            if (targetAudience === 'beta_users') {
                await sendToBetaUsersDirectly(message, updateData);
            }

            return null;

        } catch (error) {
            console.error('Error sending update notification:', error);
            
            // Hata durumunu güncelle
            await event.data.ref.update({
                status: 'error',
                error: error.message,
                errorAt: admin.firestore.FieldValue.serverTimestamp()
            });
            
            throw error;
        }
    }
);

/**
 * Beta kullanıcılarına direkt token ile bildirim gönder
 * Topic subscription çalışmadığı durumlar için yedek
 */
async function sendToBetaUsersDirectly(message, updateData) {
    try {
        // Beta kullanıcılarını al
        const betaUsersSnapshot = await db.collection('users')
            .where('isBetaUser', '==', true)
            .where('subscribedToUpdates', '==', true)
            .get();

        if (betaUsersSnapshot.empty) {
            console.log('No beta users found');
            return;
        }

        const tokens = [];
        const userIds = [];

        // FCM token'larını topla
        betaUsersSnapshot.forEach(doc => {
            const userData = doc.data();
            if (userData.fcmToken) {
                tokens.push(userData.fcmToken);
                userIds.push(doc.id);
            }
        });

        if (tokens.length === 0) {
            console.log('No FCM tokens found for beta users');
            return;
        }

        console.log(`Found ${tokens.length} beta users with FCM tokens`);

        // Maksimum 500 token'lık gruplar halinde gönder
        const batchSize = 500;
        for (let i = 0; i < tokens.length; i += batchSize) {
            const tokenBatch = tokens.slice(i, i + batchSize);
            const userBatch = userIds.slice(i, i + batchSize);
            
            const multicastMessage = {
                ...message,
                tokens: tokenBatch
            };

            delete multicastMessage.topic; // Topic'i kaldır

            try {
                const response = await messaging.sendMulticast(multicastMessage);
                console.log(`Successfully sent to ${response.successCount} devices out of ${tokenBatch.length}`);
                
                // Başarısız token'ları temizle
                if (response.failureCount > 0) {
                    const failedTokens = [];
                    response.responses.forEach((resp, idx) => {
                        if (!resp.success) {
                            failedTokens.push(tokenBatch[idx]);
                            console.log('Failed token:', tokenBatch[idx], 'Error:', resp.error);
                        }
                    });
                    
                    // Geçersiz token'ları temizle
                    await cleanupInvalidTokens(failedTokens, userBatch);
                }
                
            } catch (error) {
                console.error('Error sending multicast message:', error);
            }
        }

    } catch (error) {
        console.error('Error in sendToBetaUsersDirectly:', error);
    }
}

/**
 * Geçersiz FCM token'larını temizle
 */
async function cleanupInvalidTokens(failedTokens, userIds) {
    const batch = db.batch();
    
    for (let i = 0; i < failedTokens.length && i < userIds.length; i++) {
        const userRef = db.collection('users').doc(userIds[i]);
        batch.update(userRef, {
            fcmToken: admin.firestore.FieldValue.delete(),
            tokenInvalidAt: admin.firestore.FieldValue.serverTimestamp()
        });
    }
    
    try {
        await batch.commit();
        console.log(`Cleaned up ${failedTokens.length} invalid tokens`);
    } catch (error) {
        console.error('Error cleaning up invalid tokens:', error);
    }
}

/**
 * Test amaçlı güncelleme bildirimi gönderen HTTP fonksiyonu
 * Sadece admin kullanıcıları çağırabilir
 */
exports.testUpdateNotification = onCall(async (request) => {
    // Authentication kontrolü
    if (!request.auth) {
        throw new Error('User must be authenticated');
    }

    const uid = request.auth.uid;
    const { new_version, update_message, download_url, force_update } = request.data;
    
    // Admin kontrolü
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists || !userDoc.data().isAdmin) {
        throw new Error('User must be admin');
    }

    // Validation
    if (!new_version || !update_message || !download_url) {
        throw new Error('Missing required fields');
    }

    try {
        // Test bildirimi oluştur
        const testNotification = {
            type: 'app_update',
            targetAudience: 'beta_users',
            data: {
                new_version,
                update_message,
                download_url,
                force_update: force_update || false
            },
            topic: 'app_updates_beta',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            status: 'pending',
            createdBy: uid,
            isTest: true
        };

        const docRef = await db.collection('admin_notifications').add(testNotification);
        
        return {
            success: true,
            notificationId: docRef.id,
            message: 'Test update notification queued successfully'
        };

    } catch (error) {
        console.error('Error creating test notification:', error);
        throw new Error('Failed to create test notification');
    }
});

/**
 * Beta kullanıcı istatistiklerini döndüren HTTP fonksiyonu
 */
exports.getBetaUserStats = onCall(async (request) => {
    // Authentication kontrolü
    if (!request.auth) {
        throw new Error('User must be authenticated');
    }

    const uid = request.auth.uid;
    
    // Admin kontrolü
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists || !userDoc.data().isAdmin) {
        throw new Error('User must be admin');
    }

    try {
        const betaUsersSnapshot = await db.collection('users')
            .where('isBetaUser', '==', true)
            .get();

        let totalBetaUsers = 0;
        let subscribedUsers = 0;
        let usersWithTokens = 0;

        betaUsersSnapshot.forEach(doc => {
            const userData = doc.data();
            totalBetaUsers++;
            
            if (userData.subscribedToUpdates) {
                subscribedUsers++;
            }
            
            if (userData.fcmToken) {
                usersWithTokens++;
            }
        });

        return {
            totalBetaUsers,
            subscribedUsers,
            usersWithTokens,
            timestamp: new Date().toISOString()
        };

    } catch (error) {
        console.error('Error getting beta user stats:', error);
        throw new Error('Failed to get beta user stats');
    }
});

/**
 * Cloud Functions deployment notlarını al
 */
exports.getDeploymentInfo = onRequest((req, res) => {
    res.json({
        service: 'Update Notification Service',
        version: '1.0.0',
        functions: [
            'sendUpdateNotificationToBetaUsers',
            'testUpdateNotification',
            'getBetaUserStats'
        ],
        lastDeployed: new Date().toISOString()
    });
});
