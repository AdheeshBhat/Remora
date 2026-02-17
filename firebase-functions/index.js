const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const MAX_OCCURRENCES = 100;
const DEFAULT_CARETAKER_DELAY_MS = 1800 * 1000; // 30 minutes
const WEEKDAY_MAP = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 0 };

// ============================================================================
// Main Firestore Trigger
// ============================================================================

exports.scheduleReminderNotification = functions.firestore
  .document('users/{userId}/reminders/{reminderId}')
  .onWrite(async (change, context) => {
    const { userId, reminderId } = context.params;
    
    // Cancel notifications if reminder deleted or completed
    if (!change.after.exists || change.after.data()?.isComplete) {
      await cancelScheduledNotifications(reminderId);
      return null;
    }
    
    const reminder = change.after.data();
    const { title, description, date, caretakerAlertDelay, author, repeatSettings } = reminder;
    const repeatType = repeatSettings?.repeat_type || 'None';
    const repeatUntil = repeatSettings?.repeat_until_date || '';
    const repeatIntervals = repeatSettings?.repeatIntervals;
    
    // Cancel old notifications before scheduling new ones
    await cancelScheduledNotifications(reminderId);
    
    // Get user data to determine if caretaker notifications needed
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const userData = userDoc.data();
    
    // Generate all occurrence dates
    const occurrences = generateOccurrences(
      date.toDate(),
      repeatType,
      repeatUntil,
      repeatIntervals
    );
    
    // Schedule notifications for each occurrence
    for (const occurrenceDate of occurrences) {
      const delay = occurrenceDate.getTime() - Date.now();
      if (delay < 0) continue;
      
      // Schedule for senior
      await scheduleNotification(
        userId,
        title,
        description,
        delay,
        reminderId,
        occurrenceDate
      );
      
      // Schedule for caretakers if user is senior
      if (!userData.isCaretaker && userData.LinkedCaretakers) {
        const caretakerDelay = delay + (caretakerAlertDelay || DEFAULT_CARETAKER_DELAY_MS);
        const caretakerTitle = `🚨 ${author || 'Senior'}'s Reminder`;
        const caretakerBody = `"${title}" is not finished yet.`;
        
        for (const caretakerId of userData.LinkedCaretakers) {
          await scheduleNotification(
            caretakerId,
            caretakerTitle,
            caretakerBody,
            caretakerDelay,
            reminderId,
            occurrenceDate
          );
        }
      }
    }
    
    return null;
  });

// ============================================================================
// Occurrence Generation
// ============================================================================

function generateOccurrences(startDate, repeatType, repeatUntil, repeatIntervals) {
  const occurrences = [];
  const now = new Date();
  let currentDate = new Date(startDate);
  
  // Parse end date
  const endDate = parseEndDate(repeatUntil);
  
  // Fast-forward to first future occurrence
  while (currentDate <= now) {
    currentDate = getNextOccurrence(currentDate, repeatType, repeatIntervals);
    if (!currentDate) break;
  }
  
  // Generate up to MAX_OCCURRENCES
  let count = 0;
  while (count < MAX_OCCURRENCES && currentDate) {
    if (endDate && currentDate > endDate) break;
    
    occurrences.push(new Date(currentDate));
    currentDate = getNextOccurrence(currentDate, repeatType, repeatIntervals);
    count++;
  }
  
  return occurrences;
}

function parseEndDate(repeatUntil) {
  if (!repeatUntil || repeatUntil === 'Forever') return null;
  
  const endDate = new Date(repeatUntil);
  endDate.setDate(endDate.getDate() + 1); // Make inclusive
  return endDate;
}

function getNextOccurrence(date, repeatType, repeatIntervals) {
  const next = new Date(date);
  
  switch (repeatType) {
    case 'None':
      return null;
      
    case 'Daily':
      next.setDate(next.getDate() + 1);
      return next;
      
    case 'Weekly':
      next.setDate(next.getDate() + 7);
      return next;
      
    case 'Monthly':
      next.setMonth(next.getMonth() + 1);
      return next;
      
    case 'Yearly':
      next.setFullYear(next.getFullYear() + 1);
      return next;
      
    case 'Custom':
      return repeatIntervals?.days
        ? calculateNextCustomDate(date, repeatIntervals.days)
        : null;
      
    default:
      return null;
  }
}

function calculateNextCustomDate(baseDate, daysString) {
  const patterns = daysString.split(',').map(p => p.trim());
  const hour = baseDate.getHours();
  const minute = baseDate.getMinutes();
  
  let nextDate = null;
  
  for (const pattern of patterns) {
    const candidateDate = findNextPatternOccurrence(pattern, baseDate, hour, minute);
    if (candidateDate && (!nextDate || candidateDate < nextDate)) {
      nextDate = candidateDate;
    }
  }
  
  return nextDate;
}

function findNextPatternOccurrence(pattern, baseDate, hour, minute) {
  const parts = pattern.split(' ');
  if (parts.length !== 2) return null;
  
  const [ordinal, dayName] = parts;
  const weekday = WEEKDAY_MAP[dayName];
  if (weekday === undefined) return null;
  
  const ordinalNum = parseOrdinal(ordinal);
  if (!ordinalNum) return null;
  
  // Search next 12 months for occurrence
  for (let monthOffset = 0; monthOffset < 12; monthOffset++) {
    const occurrence = findNthWeekdayInMonth(
      baseDate,
      monthOffset,
      weekday,
      ordinalNum,
      hour,
      minute
    );
    
    if (occurrence && occurrence > baseDate) {
      return occurrence;
    }
  }
  
  return null;
}

function parseOrdinal(ordinal) {
  if (ordinal.startsWith('1st')) return 1;
  if (ordinal.startsWith('2nd')) return 2;
  if (ordinal.startsWith('3rd')) return 3;
  if (ordinal.startsWith('4th')) return 4;
  return 0;
}

function findNthWeekdayInMonth(baseDate, monthOffset, weekday, ordinalNum, hour, minute) {
  const targetMonth = new Date(baseDate);
  targetMonth.setMonth(targetMonth.getMonth() + monthOffset);
  targetMonth.setDate(1);
  
  let occurrenceCount = 0;
  
  for (let day = 1; day <= 31; day++) {
    const testDate = new Date(targetMonth);
    testDate.setDate(day);
    
    // Stop if we've moved to next month
    if (testDate.getMonth() !== targetMonth.getMonth()) break;
    
    if (testDate.getDay() === weekday) {
      occurrenceCount++;
      if (occurrenceCount === ordinalNum) {
        testDate.setHours(hour, minute, 0, 0);
        return testDate;
      }
    }
  }
  
  return null;
}

// ============================================================================
// Notification Scheduling
// ============================================================================

async function scheduleNotification(userId, title, body, delay, reminderId, occurrenceDate) {
  const userDoc = await admin.firestore().collection('users').doc(userId).get();
  const fcmToken = userDoc.data()?.fcmToken;
  
  if (!fcmToken) return;
  
  await admin.firestore().collection('scheduledNotifications').add({
    userId,
    fcmToken,
    title,
    body,
    reminderId,
    occurrenceDate: admin.firestore.Timestamp.fromDate(occurrenceDate),
    scheduledTime: admin.firestore.Timestamp.fromMillis(Date.now() + delay)
  });
}

async function cancelScheduledNotifications(reminderId) {
  const snapshot = await admin.firestore()
    .collection('scheduledNotifications')
    .where('reminderId', '==', reminderId)
    .get();
  
  const batch = admin.firestore().batch();
  snapshot.docs.forEach(doc => batch.delete(doc.ref));
  await batch.commit();
}

// ============================================================================
// Cron Job: Send Scheduled Notifications
// ============================================================================

exports.sendScheduledNotifications = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    
    const snapshot = await admin.firestore()
      .collection('scheduledNotifications')
      .where('scheduledTime', '<=', now)
      .get();
    
    const batch = admin.firestore().batch();
    
    for (const doc of snapshot.docs) {
      const { fcmToken, title, body, reminderId } = doc.data();
      
      try {
        await admin.messaging().send({
          token: fcmToken,
          notification: { title, body },
          data: { reminderId },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1
              }
            }
          }
        });
      } catch (error) {
        console.error(`Failed to send notification for reminder ${reminderId}:`, error);
      }
      
      batch.delete(doc.ref);
    }
    
    await batch.commit();
    return null;
  });
