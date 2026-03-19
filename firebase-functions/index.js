const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const MAX_OCCURRENCES = 100;
const DEFAULT_CARETAKER_DELAY_MS = 1800 * 1000; // 30 minutes

const WEEKDAY_MAP = {
  Mon: 1,
  Tue: 2,
  Wed: 3,
  Thu: 4,
  Fri: 5,
  Sat: 6,
  Sun: 0,
};

// ============================================================================
// Main Firestore Trigger
// ============================================================================

exports.scheduleReminderNotification =
    functions.firestore
        .document("users/{userId}/reminders/{reminderId}")
        .onWrite(async (change, context) => {
          const {userId, reminderId} = context.params;

            //reminder does NOT exist after the change OR it's complete -> cancel it
          if (!change.after.exists ||
              change.after.data().isComplete) {
            await cancelScheduledNotifications(userId, reminderId);
            return null;
          }

            // If the reminder existed before this write, it means the reminder is being edited. Cancel any previously scheduled notifications
            if (change.before.exists && change.after.exists) {
              await cancelScheduledNotifications(userId, reminderId);
            }

            
          const reminder = change.after.data();

          const {
            title,
            description,
            date,
            caretakerAlertDelay,
            author,
            repeatSettings,
          } = reminder;

          const repeatType =
              repeatSettings.repeat_type || "None";
          const repeatUntil =
              repeatSettings.repeat_until_date || "";
          const repeatIntervals =
              repeatSettings.repeatIntervals;

          const deletedInstances =
              (reminder.deletedInstances || []).map(ts => ts.toDate ? ts.toDate() : new Date(ts));
          const completedInstances =
              (reminder.completedInstances || []).map(ts => ts.toDate ? ts.toDate() : new Date(ts));

          const isSameDay = (d1, d2) => {
            return d1.getFullYear() === d2.getFullYear() &&
                   d1.getMonth() === d2.getMonth() &&
                   d1.getDate() === d2.getDate();
          };

          const userDoc = await admin.firestore()
              .collection("users")
              .doc(userId)
              .get();

          const userData = userDoc.data();

          // If this document belongs to a caretaker,
          // do NOT schedule notifications from here.
          // Senior documents handle scheduling for both senior + caretakers.
          if (userData.isCaretaker) {
            return null;
          }

          const occurrences = generateOccurrences(
              date.toDate(),
              repeatType,
              repeatUntil,
              repeatIntervals,
          );

          for (const occurrenceDate of occurrences) {
            const delay =
                occurrenceDate.getTime() - Date.now();

            if (delay < 0) continue;

            // Skip deleted or completed instances
            const isDeleted = deletedInstances.some(d => isSameDay(d, occurrenceDate));
            const isCompleted = completedInstances.some(d => isSameDay(d, occurrenceDate));

            if (isDeleted || isCompleted) {
              console.log("⏭️ Skipping instance:", occurrenceDate.toISOString(), 
                          isDeleted ? "DELETED" : "COMPLETED");
              continue;
            }

              // for delay and occurrenceDate, drop the second
              // Force notifications to trigger exactly at :00 seconds
              occurrenceDate.setSeconds(0);
              occurrenceDate.setMilliseconds(0);
              
              // Schedule senior reminder
              if (!userData.isCaretaker) {
                  await scheduleNotification(
                      userId,
                      title,
                      description,
                      delay,
                      reminderId,
                      occurrenceDate,
                  );
                  
                  // Schedule follow-up notification for the senior
                  const followUpDelay = delay +
                      ((caretakerAlertDelay || (DEFAULT_CARETAKER_DELAY_MS / 1000)) * 1000) / 2;

                  const followUpTitle = `Reminder: "${title}"`;

                  const delaySeconds =
                      caretakerAlertDelay ||
                      (DEFAULT_CARETAKER_DELAY_MS / 1000);

                  const minutesRemaining =
                      Math.round(delaySeconds / 120); // (delay / 2) converted to minutes

                  const followUpBody =
                      `Make sure to mark "${title}" as done! Caretaker alert in ${minutesRemaining} min`;

                  await scheduleNotification(
                      userId,
                      followUpTitle,
                      followUpBody,
                      followUpDelay,
                      `${reminderId}-follow-up`,
                      occurrenceDate,
                  );
                  
              }
        
              // If this user is a senior and has linked caretakers,
              // schedule delayed notifications for each linked caretaker
              if (!userData.isCaretaker &&
                  Array.isArray(userData.LinkedCaretakers) &&
                  userData.LinkedCaretakers.length > 0) {

                const caretakerDelay =
                    delay +
                    ((caretakerAlertDelay || 0) * 1000 ||
                     DEFAULT_CARETAKER_DELAY_MS);

                const caretakerTitle =
                    `🚨 ${author || "Senior"}'s Reminder`;

                const caretakerBody =
                    `"${title}" is not finished yet.`;

                for (const caretakerId of userData.LinkedCaretakers) {
                  await scheduleNotification(
                      caretakerId,
                      caretakerTitle,
                      caretakerBody,
                      caretakerDelay,
                      reminderId,
                      occurrenceDate,
                  );
                }
              }
              
          }

          return null;
        });

// ============================================================================
// Occurrence Generation
// ============================================================================

/**
 * Generates future reminder occurrences.
 */
function generateOccurrences(
    startDate,
    repeatType,
    repeatUntil,
    repeatIntervals,
) {
    const occurrences = [];
    const now = new Date();
    now.setSeconds(0);
    now.setMilliseconds(0);
    startDate.setSeconds(0);
    startDate.setMilliseconds(0);
    
    let currentDate = new Date(startDate);
    const endDate = parseEndDate(repeatUntil);

    while (currentDate <= now) {
        currentDate = getNextOccurrence(
            currentDate,
            repeatType,
            repeatIntervals,
        );
        if (!currentDate) break;
    }

  let count = 0;

  while (count < MAX_OCCURRENCES &&
      currentDate) {
    if (endDate && currentDate > endDate) break;
      console.log("📅 Occurrence generated:", currentDate.toISOString());
    occurrences.push(new Date(currentDate));

    currentDate = getNextOccurrence(
        currentDate,
        repeatType,
        repeatIntervals,
    );

    count++;
  }

  return occurrences;
}

/**
 * Parses repeat-until date.
 */
function parseEndDate(repeatUntil) {
  if (!repeatUntil ||
      repeatUntil === "Forever") {
    return null;
  }
    const [year,month,day] = repeatUntil.split("-").map(Number)
  const endDate = new Date(year, (month - 1), day, 23, 59, 59, 999);
    //console.log(endDate);
  return endDate;
}

/**
 * Returns next occurrence date.
 */
function getNextOccurrence(
    date,
    repeatType,
    repeatIntervals,
) {
    const next = new Date(date);
    next.setSeconds(0);
    next.setMilliseconds(0);
    switch (repeatType) {
        case "None":
            return null;

        case "Daily":
            next.setDate(next.getDate() + 1);
            return next;

        case "Weekly":
            next.setDate(next.getDate() + 7);
            return next;

        case "Monthly":
            next.setMonth(next.getMonth() + 1);
            return next;

        case "Yearly":
            next.setFullYear(next.getFullYear() + 1);
            return next;

        case "Custom":
            if (!repeatIntervals ||
                !repeatIntervals.days) {
                return null;
            }

            return calculateNextCustomDate(
                date,
                repeatIntervals.days,
            );

        default:
            return null;
    }
}

/**
 * Calculates next custom repeat date.
 */
function calculateNextCustomDate(
    baseDate,
    daysString,
) {
  const patterns =
      daysString.split(",")
          .map((p) => p.trim());

  const hour = baseDate.getHours();
  const minute = baseDate.getMinutes();

  let nextDate = null;

  for (const pattern of patterns) {
    const candidate =
        findNextPatternOccurrence(
            pattern,
            baseDate,
            hour,
            minute,
        );

    if (candidate &&
        (!nextDate || candidate < nextDate)) {
      nextDate = candidate;
    }
  }

  return nextDate;
}

/**
 * Finds next ordinal weekday occurrence.
 */
function findNextPatternOccurrence(
    pattern,
    baseDate,
    hour,
    minute,
) {
    baseDate.setSeconds(0);
    baseDate.setMilliseconds(0);
  const parts = pattern.split(" ");
  if (parts.length !== 2) return null;

  const ordinal = parts[0];
  const dayName = parts[1];

  const weekday = WEEKDAY_MAP[dayName];
  if (weekday === undefined) return null;

  const ordinalNum = parseOrdinal(ordinal);
  if (!ordinalNum) return null;

  for (let monthOffset = 0;
    monthOffset < 12;
    monthOffset++) {
    const occurrence =
        findNthWeekdayInMonth(
            baseDate,
            monthOffset,
            weekday,
            ordinalNum,
            hour,
            minute,
        );

    if (occurrence &&
        occurrence > baseDate) {
      return occurrence;
    }
  }

  return null;
}

/**
 * Parses ordinal string.
 */
function parseOrdinal(ordinal) {
  if (ordinal.startsWith("1st")) return 1;
  if (ordinal.startsWith("2nd")) return 2;
  if (ordinal.startsWith("3rd")) return 3;
  if (ordinal.startsWith("4th")) return 4;
  return 0;
}

/**
 * Finds nth weekday in month.
 */
function findNthWeekdayInMonth(
    baseDate,
    monthOffset,
    weekday,
    ordinalNum,
    hour,
    minute,
) {
    baseDate.setSeconds(0);
    baseDate.setMilliseconds(0);
  const targetMonth = new Date(baseDate);
  targetMonth.setMonth(
      targetMonth.getMonth() +
      monthOffset,
  );
  targetMonth.setDate(1);

  let count = 0;

  for (let day = 1;
    day <= 31;
    day++) {
    const testDate =
        new Date(targetMonth);
    testDate.setDate(day);

    if (testDate.getMonth() !==
        targetMonth.getMonth()) {
      break;
    }

    if (testDate.getDay() ===
        weekday) {
      count++;
      if (count === ordinalNum) {
        testDate.setHours(
            hour,
            minute,
            0,
            0,
        );
        return testDate;
      }
    }
  }

  return null;
}

// ============================================================================
// Notification Scheduling
// ============================================================================

async function scheduleNotification(
    userId,
    title,
    body,
    delay,
    reminderId,
    occurrenceDate,
) {
  const userDoc = await admin.firestore()
      .collection("users")
      .doc(userId)
      .get();

  const fcmToken = userDoc.data().fcmToken;

  if (!fcmToken) return;

  const rawScheduled = Date.now() + delay;
  const roundedScheduled = Math.floor(rawScheduled / 60000) * 60000;

  await admin.firestore()
      .collection("scheduledNotifications")
      .add({
        userId,
        fcmToken,
        title,
        body,
        reminderId,
        occurrenceDate:
            admin.firestore.Timestamp
                .fromDate(occurrenceDate),
        scheduledTime:
            admin.firestore.Timestamp
                .fromMillis(roundedScheduled),
      });
}

/**
 * Cancels scheduled notifications.
 */
async function cancelScheduledNotifications(
    userId,
    reminderId,
) {
    
    // Cancel the follow-up reminder for seniors here with new identifier "reminderId-follow-up"
  const snapshot = await admin.firestore()
      .collection("scheduledNotifications")
      .where("userId", "==", userId)
      .get();

  const docsToDelete = snapshot.docs.filter((doc) => {
    const rid = doc.data().reminderId;
    return rid === reminderId || rid === `${reminderId}-follow-up`;
  });

  const batch =
      admin.firestore().batch();

  docsToDelete.forEach((doc) => {
    batch.delete(doc.ref);
  });

  await batch.commit();
}

// ============================================================================
// Cron Job
// ============================================================================

/**
 * Sends scheduled notifications.
 */
exports.sendScheduledNotifications =
    functions.pubsub
        .schedule("every 1 minutes")
        .onRun(async () => {
          const now =
              admin.firestore.Timestamp
                  .now();

          const snapshot =
              await admin.firestore()
                  .collection(
                      "scheduledNotifications",
                  )
                  .where(
                      "scheduledTime",
                      "<=",
                      now,
                  )
                  .get();

          const batch =
              admin.firestore().batch();

          for (const doc of
            snapshot.docs) {
            const {
              fcmToken,
              title,
              body,
              reminderId,
            } = doc.data();

            try {
              await admin.messaging()
                  .send({
                    token: fcmToken,
                    notification: {
                      title,
                      body,
                    },
                    data: {
                      reminderId,
                    },
                    apns: {
                      payload: {
                        aps: {
                          sound: "default",
                          badge: 1,
                        },
                      },
                    },
                  });
            } catch (error) {
              console.error(
                  "Failed to send notification for reminder:",
                  reminderId,
                  error,
              );
            }

            batch.delete(doc.ref);
          }

          await batch.commit();
          return null;
        });
