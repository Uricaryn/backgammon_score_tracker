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
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

// Firebase Admin SDK'yı initialize et
admin.initializeApp();

// Firestore ve Messaging referansları
const db = admin.firestore();
const messaging = admin.messaging();

// Firebase Admin SDK initialized successfully

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
            
            try {
                // messaging.send() API'sini kullan - tek tek gönder
                let successCount = 0;
                let failureCount = 0;
                const failedTokens = [];
                
                for (let j = 0; j < tokenBatch.length; j++) {
                    const token = tokenBatch[j];
                    const singleMessage = {
                        ...message,
                        token: token
                    };
                    
                    // Topic'i kaldır
                    delete singleMessage.topic;
                    
                    try {
                        const response = await messaging.send(singleMessage);
                        console.log(`Successfully sent to token ${token}: ${response}`);
                        successCount++;
                    } catch (error) {
                        console.log(`Failed to send to token ${token}: ${error.message}`);
                        failureCount++;
                        failedTokens.push(token);
                        
                        // Geçersiz token'ı temizle
                        if (error.code === 'messaging/registration-token-not-registered' || 
                            error.code === 'messaging/invalid-registration-token') {
                            const userId = userBatch[j];
                            if (userId) {
                                try {
                                    await db.collection('users').doc(userId).update({
                                        fcmToken: admin.firestore.FieldValue.delete(),
                                        tokenInvalidAt: admin.firestore.FieldValue.serverTimestamp()
                                    });
                                    console.log(`Cleaned up invalid token for user ${userId}`);
                                } catch (cleanupError) {
                                    console.error(`Error cleaning up token for user ${userId}:`, cleanupError);
                                }
                            }
                        }
                    }
                }
                
                console.log(`Successfully sent to ${successCount} devices out of ${tokenBatch.length}`);
                
                // Başarısız token'ları toplu temizle
                if (failedTokens.length > 0) {
                    await cleanupInvalidTokens(failedTokens, userBatch);
                }
                
            } catch (error) {
                console.error('Error sending messages:', error);
                // Detaylı hata bilgisi
                if (error.details) {
                    console.error('Error details:', error.details);
                }
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
        version: '2.0.0',
        functions: [
            'sendUpdateNotificationToBetaUsers',
            'testUpdateNotification',
            'getBetaUserStats',
            'sendGeneralNotification',
            'scheduleNotification',
            'getScheduledNotifications',
            'cancelScheduledNotification',
            'processScheduledNotifications'
        ],
        lastDeployed: new Date().toISOString()
    });
});

/**
 * Tüm kullanıcılara genel bildirim gönderen HTTP fonksiyonu
 * Sadece admin kullanıcıları çağırabilir
 */
exports.sendGeneralNotification = onCall(async (request) => {
    // Authentication kontrolü
    if (!request.auth) {
        throw new Error('User must be authenticated');
    }

    const uid = request.auth.uid;
    const { title, message, targetAudience } = request.data;
    
    // Admin kontrolü
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists || !userDoc.data().isAdmin) {
        throw new Error('User must be admin');
    }

    // Validation
    if (!title || !message) {
        throw new Error('Title and message are required');
    }

    try {
        // Bildirimi Firestore'a kaydet
        const notificationDoc = await db.collection('general_notifications').add({
            type: 'general_notification',
            title: title,
            message: message,
            targetAudience: targetAudience || 'all_users',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: uid,
            status: 'pending',
            totalSent: 0,
            totalFailed: 0
        });

        // Kullanıcıları al ve bildirim gönder
        let usersQuery = db.collection('users');
        
        console.log(`Searching for users with targetAudience: ${targetAudience}`);
        
        // Hedef kitleye göre filtreleme
        if (targetAudience === 'active_users') {
            // Sadece aktif kullanıcıları al - isActive field'ı olan ve true olanlar
            usersQuery = usersQuery.where('isActive', '==', true);
            console.log('Filtering for active users only');
        } else if (targetAudience === 'beta_users') {
            // Beta kullanıcıları al
            usersQuery = usersQuery.where('isBetaUser', '==', true);
            console.log('Filtering for beta users only');
        } else {
            // all_users - hiç filtreleme yapma, tüm kullanıcıları al
            console.log('Getting all users (no filtering)');
        }

        const usersSnapshot = await usersQuery.get();
        console.log(`Found ${usersSnapshot.size} users in database`);
        
        if (usersSnapshot.empty) {
            // Daha detaylı hata mesajı
            const totalUsersSnapshot = await db.collection('users').get();
            const totalUsers = totalUsersSnapshot.size;
            console.log(`Total users in database: ${totalUsers}`);
            
            if (totalUsers === 0) {
                throw new Error('No users found in database. Please ensure users are registered.');
            } else {
                const userType = targetAudience === 'all_users' ? '' : `${targetAudience} `;
                throw new Error(`No ${userType}users found. Total users: ${totalUsers}`);
            }
        }

        const tokens = [];
        const userIds = [];
        let usersWithoutToken = 0;

        // FCM token'larını topla
        usersSnapshot.forEach(doc => {
            const userData = doc.data();
            if (userData.fcmToken) {
                tokens.push(userData.fcmToken);
                userIds.push(doc.id);
            } else {
                usersWithoutToken++;
            }
        });

        console.log(`Users with FCM tokens: ${tokens.length}`);
        console.log(`Users without FCM tokens: ${usersWithoutToken}`);

        if (tokens.length === 0) {
            throw new Error(`No FCM tokens found. Total users: ${usersSnapshot.size}, Users without tokens: ${usersWithoutToken}`);
        }

        // FCM mesajı oluştur
        const fcmMessage = {
            notification: {
                title: title,
                body: message
            },
            data: {
                type: 'general_notification',
                title: title,
                message: message,
                timestamp: new Date().toISOString(),
                notificationId: notificationDoc.id
            },
            android: {
                notification: {
                    channelId: 'backgammon_channel',
                    priority: 'high',
                    defaultSound: true,
                    defaultVibrateTimings: true
                }
            },
            apns: {
                payload: {
                    aps: {
                        alert: {
                            title: title,
                            body: message
                        },
                        badge: 1,
                        sound: 'default'
                    }
                }
            }
        };

        // Batch'ler halinde gönder
        let totalSent = 0;
        let totalFailed = 0;
        const batchSize = 500;
        const successfulUserIds = []; // Başarıyla bildirim gönderilen kullanıcılar

        for (let i = 0; i < tokens.length; i += batchSize) {
            const tokenBatch = tokens.slice(i, i + batchSize);
            const userBatch = userIds.slice(i, i + batchSize);
            
            // Tek tek token'lara gönder (multicast sorunu için)
            for (let j = 0; j < tokenBatch.length; j++) {
                const token = tokenBatch[j];
                const userId = userBatch[j];
                const singleMessage = {
                    ...fcmMessage,
                    token: token
                };

                try {
                    const response = await messaging.send(singleMessage);
                    console.log(`Successfully sent to token ${token}: ${response}`);
                    totalSent++;
                    successfulUserIds.push(userId); // Başarılı kullanıcıyı kaydet
                } catch (error) {
                    console.log(`Failed to send to token ${token}: ${error.message}`);
                    totalFailed++;
                    
                    // Geçersiz token'ı temizle
                    if (error.code === 'messaging/registration-token-not-registered' || 
                        error.code === 'messaging/invalid-registration-token') {
                        if (userId) {
                            try {
                                await db.collection('users').doc(userId).update({
                                    fcmToken: admin.firestore.FieldValue.delete(),
                                    tokenInvalidAt: admin.firestore.FieldValue.serverTimestamp()
                                });
                                console.log(`Cleaned up invalid token for user ${userId}`);
                            } catch (cleanupError) {
                                console.error(`Error cleaning up token for user ${userId}:`, cleanupError);
                            }
                        }
                    }
                }
            }
        }

        // Her kullanıcının notifications koleksiyonuna bildirim kaydı ekle
        console.log(`Saving notification records for ${successfulUserIds.length} users...`);
        let savedNotifications = 0;
        let failedNotifications = 0;

        // Batch işlemi ile verimli kaydetme
        const notificationBatchSize = 500;
        for (let i = 0; i < successfulUserIds.length; i += notificationBatchSize) {
            const userBatch = successfulUserIds.slice(i, i + notificationBatchSize);
            
            // Her kullanıcı için ayrı kayıt oluştur
            for (const userId of userBatch) {
                try {
                    await db.collection('notifications').add({
                        userId: userId,
                        title: title,
                        body: message,
                        type: 'general',
                        timestamp: admin.firestore.FieldValue.serverTimestamp(),
                        isRead: false,
                        data: {
                            source: 'admin_notification',
                            notificationId: notificationDoc.id,
                            targetAudience: targetAudience,
                            timestamp: new Date().toISOString()
                        }
                    });
                    savedNotifications++;
                } catch (error) {
                    console.error(`Failed to save notification for user ${userId}:`, error);
                    failedNotifications++;
                }
            }
        }

        console.log(`Notification records saved: ${savedNotifications}, failed: ${failedNotifications}`);

        // Bildirim durumunu güncelle
        await notificationDoc.update({
            status: 'sent',
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            totalSent: totalSent,
            totalFailed: totalFailed,
            savedNotifications: savedNotifications,
            failedNotifications: failedNotifications
        });

        return {
            success: true,
            notificationId: notificationDoc.id,
            totalSent: totalSent,
            totalFailed: totalFailed,
            message: `Notification sent to ${totalSent} users successfully`
        };

    } catch (error) {
        console.error('Error sending general notification:', error);
        throw new Error('Failed to send general notification');
    }
});

/**
 * Zamanlanmış bildirim oluşturan HTTP fonksiyonu
 * Sadece admin kullanıcıları çağırabilir
 */
exports.scheduleNotification = onCall(async (request) => {
    // Authentication kontrolü
    if (!request.auth) {
        throw new Error('User must be authenticated');
    }

    const uid = request.auth.uid;
    const { title, message, scheduledTime, targetAudience } = request.data;
    
    // Admin kontrolü
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists || !userDoc.data().isAdmin) {
        throw new Error('User must be admin');
    }

    // Validation
    if (!title || !message || !scheduledTime) {
        throw new Error('Title, message, and scheduled time are required');
    }

    const scheduledDate = new Date(scheduledTime);
    if (scheduledDate <= new Date()) {
        throw new Error('Scheduled time must be in the future');
    }

    try {
        // Zamanlanmış bildirimi Firestore'a kaydet
        const scheduledDoc = await db.collection('scheduled_notifications').add({
            type: 'scheduled_notification',
            title: title,
            message: message,
            scheduledTime: admin.firestore.Timestamp.fromDate(scheduledDate),
            targetAudience: targetAudience || 'all_users',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: uid,
            status: 'scheduled',
            processed: false
        });

        return {
            success: true,
            notificationId: scheduledDoc.id,
            scheduledTime: scheduledDate.toISOString(),
            message: 'Notification scheduled successfully'
        };

    } catch (error) {
        console.error('Error scheduling notification:', error);
        throw new Error('Failed to schedule notification');
    }
});

/**
 * Zamanlanmış bildirimleri listeleyen HTTP fonksiyonu
 * Sadece admin kullanıcıları çağırabilir
 */
exports.getScheduledNotifications = onCall(async (request) => {
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
        const scheduledSnapshot = await db.collection('scheduled_notifications')
            .where('processed', '==', false)
            .orderBy('scheduledTime', 'asc')
            .limit(50)
            .get();

        const notifications = [];
        scheduledSnapshot.forEach(doc => {
            const data = doc.data();
            notifications.push({
                id: doc.id,
                title: data.title,
                message: data.message,
                scheduledTime: data.scheduledTime.toDate().toISOString(),
                targetAudience: data.targetAudience,
                status: data.status,
                createdAt: data.createdAt.toDate().toISOString()
            });
        });

        return {
            success: true,
            notifications: notifications,
            count: notifications.length
        };

    } catch (error) {
        console.error('Error getting scheduled notifications:', error);
        
        // If collection doesn't exist or index is not ready, return empty array
        if (error.message.includes('index') || error.message.includes('not found')) {
            console.log('Collection or index not ready yet, returning empty array');
            return {
                success: true,
                notifications: [],
                count: 0
            };
        }
        
        throw new Error('Failed to get scheduled notifications');
    }
});

/**
 * Zamanlanmış bildirimi iptal eden HTTP fonksiyonu
 * Sadece admin kullanıcıları çağırabilir
 */
exports.cancelScheduledNotification = onCall(async (request) => {
    // Authentication kontrolü
    if (!request.auth) {
        throw new Error('User must be authenticated');
    }

    const uid = request.auth.uid;
    const { notificationId } = request.data;
    
    // Admin kontrolü
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists || !userDoc.data().isAdmin) {
        throw new Error('User must be admin');
    }

    if (!notificationId) {
        throw new Error('Notification ID is required');
    }

    try {
        const notificationRef = db.collection('scheduled_notifications').doc(notificationId);
        const notificationDoc = await notificationRef.get();

        if (!notificationDoc.exists) {
            throw new Error('Notification not found');
        }

        await notificationRef.update({
            status: 'cancelled',
            processed: true,
            cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
            cancelledBy: uid
        });

        return {
            success: true,
            message: 'Scheduled notification cancelled successfully'
        };

    } catch (error) {
        console.error('Error cancelling scheduled notification:', error);
        throw new Error('Failed to cancel scheduled notification');
    }
});

/**
 * Zamanlanmış bildirimleri işleyen scheduler fonksiyonu
 * Her 5 dakikada bir çalışır
 */
exports.processScheduledNotifications = onSchedule('*/5 * * * *', async (event) => {
    try {
        const now = new Date();
        const scheduledSnapshot = await db.collection('scheduled_notifications')
            .where('processed', '==', false)
            .where('scheduledTime', '<=', admin.firestore.Timestamp.fromDate(now))
            .limit(10)
            .get();

        if (scheduledSnapshot.empty) {
            console.log('No scheduled notifications to process');
            return;
        }

        console.log(`Processing ${scheduledSnapshot.size} scheduled notifications`);

        const promises = [];
        scheduledSnapshot.forEach(doc => {
            const data = doc.data();
            
            // Bildirimi işle
            const promise = processScheduledNotification(doc.id, data);
            promises.push(promise);
        });

        await Promise.all(promises);
        console.log('All scheduled notifications processed');

    } catch (error) {
        console.error('Error processing scheduled notifications:', error);
    }
});

/**
 * Tek bir zamanlanmış bildirimi işle
 */
async function processScheduledNotification(notificationId, data) {
    try {
        // Bildirimi gönder
        const result = await sendScheduledNotificationToUsers(data);
        
        // Durumu güncelle
        await db.collection('scheduled_notifications').doc(notificationId).update({
            status: 'sent',
            processed: true,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            totalSent: result.totalSent,
            totalFailed: result.totalFailed,
            savedNotifications: result.savedNotifications,
            failedNotifications: result.failedNotifications
        });

        console.log(`Scheduled notification ${notificationId} processed successfully`);

    } catch (error) {
        console.error(`Error processing scheduled notification ${notificationId}:`, error);
        
        // Hata durumunu kaydet
        await db.collection('scheduled_notifications').doc(notificationId).update({
            status: 'failed',
            processed: true,
            failedAt: admin.firestore.FieldValue.serverTimestamp(),
            error: error.message
        });
    }
}

/**
 * Zamanlanmış bildirimi kullanıcılara gönder
 */
async function sendScheduledNotificationToUsers(data) {
    const { title, message, targetAudience } = data;
    
    // Kullanıcıları al
    let usersQuery = db.collection('users');
    
    if (targetAudience === 'beta_users') {
        usersQuery = usersQuery.where('isBetaUser', '==', true);
    } else if (targetAudience === 'active_users') {
        usersQuery = usersQuery.where('isActive', '==', true);
    }

    const usersSnapshot = await usersQuery.get();
    
    if (usersSnapshot.empty) {
        throw new Error('No users found for scheduled notification');
    }

    const tokens = [];
    const userIds = [];

    // FCM token'larını topla
    usersSnapshot.forEach(doc => {
        const userData = doc.data();
        if (userData.fcmToken) {
            tokens.push(userData.fcmToken);
            userIds.push(doc.id);
        }
    });

    if (tokens.length === 0) {
        throw new Error('No FCM tokens found for scheduled notification');
    }

    // FCM mesajı oluştur
    const fcmMessage = {
        notification: {
            title: title,
            body: message
        },
        data: {
            type: 'scheduled_notification',
            title: title,
            message: message,
            timestamp: new Date().toISOString()
        },
        android: {
            notification: {
                channelId: 'backgammon_channel',
                priority: 'high',
                defaultSound: true,
                defaultVibrateTimings: true
            }
        },
        apns: {
            payload: {
                aps: {
                    alert: {
                        title: title,
                        body: message
                    },
                    badge: 1,
                    sound: 'default'
                }
            }
        }
    };

    // Batch'ler halinde gönder
    let totalSent = 0;
    let totalFailed = 0;
    const batchSize = 500;
    const successfulUserIds = []; // Başarıyla bildirim gönderilen kullanıcılar

    for (let i = 0; i < tokens.length; i += batchSize) {
        const tokenBatch = tokens.slice(i, i + batchSize);
        const userBatch = userIds.slice(i, i + batchSize);
        
        // Tek tek token'lara gönder (multicast sorunu için)
        for (let j = 0; j < tokenBatch.length; j++) {
            const token = tokenBatch[j];
            const userId = userBatch[j];
            const singleMessage = {
                ...fcmMessage,
                token: token
            };

            try {
                const response = await messaging.send(singleMessage);
                console.log(`Successfully sent to token ${token}: ${response}`);
                totalSent++;
                successfulUserIds.push(userId); // Başarılı kullanıcıyı kaydet
            } catch (error) {
                console.log(`Failed to send to token ${token}: ${error.message}`);
                totalFailed++;
                
                // Geçersiz token'ı temizle
                if (error.code === 'messaging/registration-token-not-registered' || 
                    error.code === 'messaging/invalid-registration-token') {
                    if (userId) {
                        try {
                            await db.collection('users').doc(userId).update({
                                fcmToken: admin.firestore.FieldValue.delete(),
                                tokenInvalidAt: admin.firestore.FieldValue.serverTimestamp()
                            });
                            console.log(`Cleaned up invalid token for user ${userId}`);
                        } catch (cleanupError) {
                            console.error(`Error cleaning up token for user ${userId}:`, cleanupError);
                        }
                    }
                }
            }
        }
    }

    // Her kullanıcının notifications koleksiyonuna bildirim kaydı ekle
    console.log(`Saving scheduled notification records for ${successfulUserIds.length} users...`);
    let savedNotifications = 0;
    let failedNotifications = 0;

    // Batch işlemi ile verimli kaydetme
    const notificationBatchSize = 500;
    for (let i = 0; i < successfulUserIds.length; i += notificationBatchSize) {
        const userBatch = successfulUserIds.slice(i, i + notificationBatchSize);
        
        // Her kullanıcı için ayrı kayıt oluştur
        for (const userId of userBatch) {
            try {
                await db.collection('notifications').add({
                    userId: userId,
                    title: title,
                    body: message,
                    type: 'general',
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    isRead: false,
                    data: {
                        source: 'scheduled_notification',
                        targetAudience: targetAudience,
                        timestamp: new Date().toISOString()
                    }
                });
                savedNotifications++;
            } catch (error) {
                console.error(`Failed to save scheduled notification for user ${userId}:`, error);
                failedNotifications++;
            }
        }
    }

    console.log(`Scheduled notification records saved: ${savedNotifications}, failed: ${failedNotifications}`);

    return { 
        totalSent, 
        totalFailed, 
        savedNotifications, 
        failedNotifications 
    };
}

/**
 * Migration fonksiyonu: Kullanıcılara eksik isActive field'ını ekler
 * Sadece admin kullanıcıları çağırabilir
 */
exports.migrateUserActiveField = onCall(async (request) => {
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
        // isActive field'ı olmayan kullanıcıları bul
        const usersSnapshot = await db.collection('users').get();
        let updatedCount = 0;
        let totalCount = usersSnapshot.size;

        const batch = db.batch();
        
        usersSnapshot.forEach(doc => {
            const userData = doc.data();
            if (userData.isActive === undefined) {
                // isActive field'ı yoksa ekle (varsayılan true)
                batch.update(doc.ref, { 
                    isActive: true,
                    migrationDate: admin.firestore.FieldValue.serverTimestamp()
                });
                updatedCount++;
            }
        });

        if (updatedCount > 0) {
            await batch.commit();
        }

        return {
            success: true,
            message: `Migration completed. ${updatedCount} out of ${totalCount} users updated.`,
            totalUsers: totalCount,
            updatedUsers: updatedCount
        };

    } catch (error) {
        console.error('Error during migration:', error);
        throw new Error('Migration failed');
    }
});
