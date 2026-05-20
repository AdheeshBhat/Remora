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
// Timezone Helper Functions
// ============================================================================

function toDate(value) {
  return value && value.toDate ? value.toDate() : new Date(value);
}

function getUserTimezone(userData) {
  return userData.timezone || "America/Los_Angeles";
}

function getZonedParts(date, timezone) {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    weekday: "short",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  });

  const parts = Object.fromEntries(
      formatter.formatToParts(date).map(part => [part.type, part.value]),
  );

  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour: Number(parts.hour),
    minute: Number(parts.minute),
    second: Number(parts.second),
    weekday: WEEKDAY_MAP[parts.weekday],
  };
}

function makeDateInTimezone(year, monthIndex, day, hour, minute, timezone) {
  const targetUTC = Date.UTC(year, monthIndex, day, hour, minute, 0, 0);
  let guess = new Date(targetUTC);

  for (let i = 0; i < 2; i++) {
    const parts = getZonedParts(guess, timezone);
    const actualUTC = Date.UTC(
        parts.year,
        parts.month - 1,
        parts.day,
        parts.hour,
        parts.minute,
        parts.second,
        0,
    );

    guess = new Date(guess.getTime() - (actualUTC - targetUTC));
  }

  return guess;
}

function normalizeMinute(date) {
  const normalized = new Date(date.getTime());
  normalized.setSeconds(0);
  normalized.setMilliseconds(0);
  return normalized;
}

function sameZonedDay(d1, d2, timezone) {
  const p1 = getZonedParts(d1, timezone);
  const p2 = getZonedParts(d2, timezone);

  return p1.year === p2.year &&
         p1.month === p2.month &&
         p1.day === p2.day;
}

function lastDayOfZonedMonth(year, monthIndex) {
  return new Date(Date.UTC(year, monthIndex + 1, 0)).getUTCDate();
}

// ============================================================================
// Main Firestore Trigger
// ============================================================================

exports.scheduleReminderNotification =
    functions.firestore
        .document("users/{userId}/reminders/{reminderId}")
        .onWrite(async (change, context) => {
          const {userId, reminderId} = context.params;

          // Fetch userData
          const userDocEarly = await admin.firestore()
              .collection("users")
              .doc(userId)
              .get();

          const userData = userDocEarly.data();
          const userTimezone = getUserTimezone(userData || {});

            //reminder does NOT exist after the change OR it's complete -> cancel it
            // deleting a reminder fully
          if (!change.after.exists ||
              change.after.data().isComplete) {
            await cancelScheduledNotifications(userId, reminderId);
            return null;
          }

            
            // HANDLING COMPLETE/UNCOMPLETE/DELETE INSTANCE CASES (before full edit wipe)
            if (change.before.exists && change.after.exists) {
              const beforeData = change.before.data();
              const afterData = change.after.data();

              const beforeDeleted = (beforeData.deletedInstances || []).map(toDate);
              const afterDeleted = (afterData.deletedInstances || []).map(toDate);

              const beforeCompleted = (beforeData.completedInstances || []).map(toDate);
              const afterCompleted = (afterData.completedInstances || []).map(toDate);

              const findAdded = (beforeArr, afterArr) => {
                return afterArr.find(a =>
                  !beforeArr.some(b => b.getTime() === a.getTime())
                );
              };

              const findRemoved = (beforeArr, afterArr) => {
                return beforeArr.find(b =>
                  !afterArr.some(a => a.getTime() === b.getTime())
                );
              };

              // CASE 1: Deleted instance
              const deletedInstance = findAdded(beforeDeleted, afterDeleted);
              if (deletedInstance) {
                console.log("🗑️ Deleting instance:", deletedInstance.toISOString());
                await cancelSingleInstance(userId, reminderId, deletedInstance, userTimezone);
                return null;
              }

              // CASE 2: Completed instance
              const completedInstance = findAdded(beforeCompleted, afterCompleted);
              if (completedInstance) {
                console.log("✅ Completing instance:", completedInstance.toISOString());
                await cancelSingleInstance(userId, reminderId, completedInstance, userTimezone);
                return null;
              }

              // CASE 3: Un-completing instance
              const uncompletedInstance = findRemoved(beforeCompleted, afterCompleted);
              if (uncompletedInstance) {
                console.log("🔁 Un-completing instance:", uncompletedInstance.toISOString());

                const reminder = change.after.data();

                // Normalize time to match stored occurrences
                const normalizedUncompletedInstance = normalizeMinute(uncompletedInstance);

                const delay = normalizedUncompletedInstance.getTime() - Date.now();

                if (delay > 0 && !userData.isCaretaker) {
                  // Schedule main notification
                  await scheduleNotification(
                    userId,
                    reminder.title,
                    reminder.description,
                    delay,
                    reminderId,
                    normalizedUncompletedInstance,
                    {seniorId: userId, timezone: userTimezone}
                  );

                  // Follow-up
                  const caretakerAlertDelay =
                    reminder.caretakerAlertDelay ||
                    (DEFAULT_CARETAKER_DELAY_MS / 1000);

                  const followUpDelay =
                    delay + (caretakerAlertDelay * 1000) / 2;

                  await scheduleNotification(
                    userId,
                    `Reminder: "${reminder.title}"`,
                    `Make sure to mark "${reminder.title}" as done!`,
                    followUpDelay,
                    `${reminderId}-follow-up`,
                    normalizedUncompletedInstance,
                    {seniorId: userId, timezone: userTimezone}
                  );

                  // Caretaker notification
                  if (Array.isArray(userData.LinkedCaretakers)) {
                    const caretakerDelay =
                      delay + (caretakerAlertDelay * 1000);

                    for (const caretakerId of userData.LinkedCaretakers) {
                      await scheduleNotification(
                        caretakerId,
                        `🚨 ${reminder.author || "Senior"}'s Reminder`,
                        `"${reminder.title}" is not finished yet.`,
                        caretakerDelay,
                        reminderId,
                        normalizedUncompletedInstance,
                        {seniorId: userId, caretakerId, timezone: userTimezone}
                      );
                    }
                  }
                }

                return null;
              }

              // FALLBACK: full edit → wipe + rebuild
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
              (reminder.deletedInstances || []).map(toDate);
          const completedInstances =
              (reminder.completedInstances || []).map(toDate);


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
              userTimezone,
          );

          for (const occurrenceDate of occurrences) {
            const delay =
                occurrenceDate.getTime() - Date.now();

            if (delay < 0) continue;

            // Skip deleted or completed instances
            const isDeleted = deletedInstances.some(d => sameZonedDay(d, occurrenceDate, userTimezone));
            const isCompleted = completedInstances.some(d => sameZonedDay(d, occurrenceDate, userTimezone));

            if (isDeleted || isCompleted) {
              console.log("⏭️ Skipping instance:", occurrenceDate.toISOString(),
                          isDeleted ? "DELETED" : "COMPLETED");
              continue;
            }

              // for delay and occurrenceDate, drop the second
              // Force notifications to trigger exactly at :00 seconds
              const normalizedOccurrenceDate = normalizeMinute(occurrenceDate);
              
              // Schedule senior reminder
              if (!userData.isCaretaker) {
                  await scheduleNotification(
                      userId,
                      title,
                      description,
                      delay,
                      reminderId,
                      normalizedOccurrenceDate,
                      {seniorId: userId, timezone: userTimezone},
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
                      normalizedOccurrenceDate,
                      {seniorId: userId, timezone: userTimezone},
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
                      normalizedOccurrenceDate,
                      {seniorId: userId, caretakerId, timezone: userTimezone},
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
    timezone,
) {
    const occurrences = [];
    const now = normalizeMinute(new Date());
    const normalizedStartDate = normalizeMinute(startDate);

    let currentDate = new Date(normalizedStartDate);
    const endDate = parseEndDate(repeatUntil, timezone);

    // Capture the intended local day-of-month once from the original start date.
    // This keeps "31st of each month" as 31, then clamps only when needed.
    const originalParts = getZonedParts(normalizedStartDate, timezone);
    const originalDay = originalParts.day;

    while (currentDate < now) {
        currentDate = getNextOccurrence(
            currentDate,
            repeatType,
            repeatIntervals,
            originalDay,
            timezone,
        );
        if (!currentDate) break;
    }

    let count = 0;

    while (count < MAX_OCCURRENCES && currentDate) {
        if (endDate && currentDate > endDate) break;
        console.log("📅 Occurrence generated:", currentDate.toISOString());
        occurrences.push(new Date(currentDate));

        currentDate = getNextOccurrence(
            currentDate,
            repeatType,
            repeatIntervals,
            originalDay,
            timezone,
        );

        count++;
    }

    return occurrences;
}

/**
 * Parses repeat-until date.
 */
function parseEndDate(repeatUntil, timezone) {
  if (!repeatUntil ||
      repeatUntil === "Forever") {
    return null;
  }

  const [year, month, day] = repeatUntil.split("-").map(Number);
  return makeDateInTimezone(year, month - 1, day, 23, 59, timezone);
}

/**
 * Returns next occurrence date.
 */
function getNextOccurrence(
    date,
    repeatType,
    repeatIntervals,
    originalDay = null,
    timezone,
) {
    const next = normalizeMinute(date);
    const parts = getZonedParts(next, timezone);

    switch (repeatType) {
        case "None":
            return null;

        case "Daily":
            return makeDateInTimezone(
                parts.year,
                parts.month - 1,
                parts.day + 1,
                parts.hour,
                parts.minute,
                timezone,
            );

        case "Weekly":
            return makeDateInTimezone(
                parts.year,
                parts.month - 1,
                parts.day + 7,
                parts.hour,
                parts.minute,
                timezone,
            );

        case "Monthly": {
            const intendedDay = originalDay ?? parts.day;
            let targetYear = parts.year;
            let targetMonthIndex = parts.month;

            if (targetMonthIndex > 11) {
                targetMonthIndex = 0;
                targetYear += 1;
            }

            const lastDayOfTargetMonth =
                lastDayOfZonedMonth(targetYear, targetMonthIndex);
            const clampedDay = Math.min(intendedDay, lastDayOfTargetMonth);

            return makeDateInTimezone(
                targetYear,
                targetMonthIndex,
                clampedDay,
                parts.hour,
                parts.minute,
                timezone,
            );
        }

        case "Yearly":
            return makeDateInTimezone(
                parts.year + 1,
                parts.month - 1,
                parts.day,
                parts.hour,
                parts.minute,
                timezone,
            );

        case "Custom":
            if (!repeatIntervals || !repeatIntervals.days) {
                return null;
            }
            return calculateNextCustomDate(date, repeatIntervals.days, timezone);

        default:
            return null;
    }
}

function isNumeric(str) {
  return /^\d+$/.test(str);
}

/**
 * Calculates next custom repeat date.
 * Supports both:
 *  - numeric day-of-month patterns (ex. "1", "7", "31")
 *  - legacy ordinal weekday patterns (ex. "1st Mon")
 */
function calculateNextCustomDate(baseDate, daysString, timezone) {
  const patterns = daysString
    .split(",")
    .map(p => p.trim())
    .filter(p => p.length > 0);

  const normalizeDayOfMonth = (p) => {
    if (!p) return p;
    return p.toLowerCase().replace(/(st|nd|rd|th)$/g, '');
  };

  const baseParts = getZonedParts(baseDate, timezone);
  const hour = baseParts.hour;
  const minute = baseParts.minute;

  let nextDate = null;

  for (let monthOffset = 0; monthOffset < 12; monthOffset++) {
    let year = baseParts.year;
    let month = (baseParts.month - 1) + monthOffset;

    while (month > 11) {
      month -= 12;
      year += 1;
    }

    const lastDayOfMonth = lastDayOfZonedMonth(year, month);
    for (const pattern of patterns) {
      const normalizedPattern = normalizeDayOfMonth(pattern);

      if (isNumeric(normalizedPattern)) {
        const requestedDay = parseInt(normalizedPattern);
        const clampedDay = Math.min(requestedDay, lastDayOfMonth);

        const candidate = makeDateInTimezone(
          year,
          month,
          clampedDay,
          hour,
          minute,
          timezone,
        );

        if (
          candidate > baseDate &&
          (!nextDate || candidate < nextDate)
        ) {
          nextDate = candidate;
        }

        continue;
      }

      // Legacy ordinal weekday pattern — unchanged
      const candidate = findNextPatternOccurrence(
        pattern,
        baseDate,
        hour,
        minute,
        timezone,
      );

      if (
        candidate &&
        (!nextDate || candidate < nextDate)
      ) {
        nextDate = candidate;
      }
    }
  }
  return nextDate;
}


// Finds next ordinal weekday occurrence.
function findNextPatternOccurrence(
    pattern,
    baseDate,
    hour,
    minute,
    timezone,
  ) {
  const normalizedBaseDate = normalizeMinute(baseDate);
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
            normalizedBaseDate,
            monthOffset,
            weekday,
            ordinalNum,
            hour,
            minute,
            timezone,
        );

    if (occurrence &&
        occurrence > normalizedBaseDate) {
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
    timezone,
) {
  const normalizedBaseDate = normalizeMinute(baseDate);
  const baseParts = getZonedParts(normalizedBaseDate, timezone);

  let targetYear = baseParts.year;
  let targetMonthIndex = (baseParts.month - 1) + monthOffset;

  while (targetMonthIndex > 11) {
    targetMonthIndex -= 12;
    targetYear += 1;
  }

  const lastDay = lastDayOfZonedMonth(targetYear, targetMonthIndex);
  let count = 0;

  for (let day = 1; day <= lastDay; day++) {
    const testDate = makeDateInTimezone(
        targetYear,
        targetMonthIndex,
        day,
        hour,
        minute,
        timezone,
    );

    const testParts = getZonedParts(testDate, timezone);

    if (testParts.weekday === weekday) {
      count++;
      if (count === ordinalNum &&
          testParts.month === targetMonthIndex + 1) {
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
    metadata = {},
) {
  const userDoc = await admin.firestore()
      .collection("users")
      .doc(userId)
      .get();

  const scheduledUserData = userDoc.data() || {};
  const fcmToken = scheduledUserData.fcmToken;

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
        seniorId: metadata.seniorId || "",
        caretakerId: metadata.caretakerId || "",
        timezone: metadata.timezone || scheduledUserData.timezone || "America/Los_Angeles",
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
// Cancels notifications for ONE specific occurrence

async function cancelSingleInstance(userId, reminderId, occurrenceDate, timezone) {
  const snapshot = await admin.firestore()
    .collection("scheduledNotifications")
    .where("userId", "==", userId)
    .get();

  const docsToDelete = snapshot.docs.filter((doc) => {
    const data = doc.data();
    const rid = data.reminderId;

    if (rid !== reminderId && rid !== `${reminderId}-follow-up`) {
      return false;
    }

    if (!data.occurrenceDate) return false;

    const occDate = data.occurrenceDate.toDate();

    return sameZonedDay(occDate, occurrenceDate, timezone);
  });

  const batch = admin.firestore().batch();

  docsToDelete.forEach((doc) => {
    batch.delete(doc.ref);
  });

  console.log("🧹 Cancelled", docsToDelete.length, "notifications for one instance");

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
              seniorId,
              caretakerId,
              timezone,
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
                      title: title || "",
                      body: body || "",
                      seniorId: seniorId || "",
                      caretakerId: caretakerId || "",
                      timezone: timezone || "America/Los_Angeles",
                    },
                    apns: {
                      payload: {
                        aps: {
                          sound: "default",
                          badge: 0,
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
