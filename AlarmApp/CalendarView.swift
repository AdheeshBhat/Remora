//
//  CalendarView.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 7/31/25.
//
//

import SwiftUI

struct CalendarReminder: Identifiable {
    let id: UUID
    let title: String
    let date: Date
}

class CalendarHelper {
    let calendar = Calendar.current

    func plusMonth(_ date: Date) -> Date {
        calendar.date(byAdding: .month, value: 1, to: date) ?? date
    }

    func minusMonth(_ date: Date) -> Date {
        calendar.date(byAdding: .month, value: -1, to: date) ?? date
    }

    func getNumberOfDaysInMonth(date: Date) -> Int {
        guard let range = calendar.range(of: .day, in: .month, for: date) else {
            return 0
        }
        return range.count
    }

    func getSpecificDay(day: Int, from date: Date) -> Date {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let maxDays = getNumberOfDaysInMonth(date: startOfMonth)

        let validDay = min(day, maxDays - 1)
        return calendar.date(byAdding: .day, value: validDay, to: startOfMonth)!
    }

    func findOffset(_ date: Date) -> Int {
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        return weekday - 1
    }

    func generateWeekDays(for date: Date) -> [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    func generateCalendarDays(for date: Date) -> [Date?] {
        var days: [Date?] = []
        let helper = CalendarHelper()
        let firstOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date))!
        let numberOfDays = helper.getNumberOfDaysInMonth(date: date)
        let startingOffset = helper.findOffset(date)

        for i in 0..<42 {
            if i < startingOffset || i >= startingOffset + numberOfDays {
                days.append(nil)
            } else {
                days.append(Calendar.current.date(byAdding: .day, value: i - startingOffset, to: firstOfMonth))
            }
        }
        return days
    }
}

func normalizeDate(_ date: Date) -> Date {
    Calendar.current.startOfDay(for: date)
}

class CalendarViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var remindersByDate: [Date: [CalendarReminder]] = [:]

    func remindersOnGivenDay(for date: Date) -> [CalendarReminder] {
        remindersByDate[normalizeDate(date)] ?? []
    }

    func loadReminders(from allReminders: [String: ReminderData]) {
        var grouped: [Date: [CalendarReminder]] = [:]
        
        // Expand repeating reminders for a wide date range (1 year)
        let startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let endDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        
        let expandedReminders = expandRepeatingRemindersForCalendar(userData: allReminders, startDate: startDate, endDate: endDate)

        for (_, reminder) in expandedReminders {
            let dateKey = normalizeDate(reminder.date)
            let simpleReminder = CalendarReminder(id: UUID(), title: reminder.title, date: reminder.date)

            grouped[dateKey, default: []].append(simpleReminder)
        }

        remindersByDate = grouped
    }
}

enum ZoomLevel {
    case day, week, month
}


struct CalendarGrid: View {
    let calendarViewType: String
    let helper: CalendarHelper
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let swipeOffset: Int
    let viewModel: CalendarViewModel
    let zoomScale: CGFloat
    let isReminderViewOn: Bool
    @Binding var cur_screen: Screen
    let firestoreManager: FirestoreManager
    let monthFilteredDay: Date?
    let weekFilteredDay: Date?

    var body: some View {
        if calendarViewType == "month" {
            MonthGrid(
                helper: helper,
                cellWidth: cellWidth,
                cellHeight: cellHeight,
                date: calculateDateFor(),
                viewModel: viewModel,
                zoomScale: zoomScale,
                isReminderViewOn: isReminderViewOn,
                cur_screen: $cur_screen,
                firestoreManager: firestoreManager
            )
        } else {
            WeekGrid(
                helper: helper,
                cellWidth: cellWidth,
                cellHeight: cellHeight,
                date: calculateDateFor(),
                viewModel: viewModel,
                isReminderViewOn: isReminderViewOn,
                cur_screen: $cur_screen,
                firestoreManager: firestoreManager
            )
        }
    }


    private func calculateDateFor() -> Date {
        if calendarViewType == "month" {
            return Calendar.current.date(byAdding: .month, value: swipeOffset, to: Date()) ?? Date()
        } else {
            return Calendar.current.date(byAdding: .weekOfYear, value: swipeOffset, to: Date()) ?? Date()
        }
    }
}


struct CalendarView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var cur_screen: Screen
    @Binding var initialViewType: String

    @StateObject var viewModel = CalendarViewModel()
    let helper = CalendarHelper()
    @State private var calendarViewType: String = "month"
    @State private var isCalendarViewOn: Bool = true
    @State private var isReminderViewOn: Bool = false
    @State private var isEditingMonthYear = false
    @State private var monthFilteredDay: Date? = nil
    @State private var weekFilteredDay: Date? = Date()
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var zoomAnchor: UnitPoint = .center
    @State private var swipeOffset: Int = 0
    @State private var canResetDate: Bool = false
    @State private var isUsingPicker: Bool = false
    let firestoreManager: FirestoreManager

    let minZoom: CGFloat = 1.0
    let maxZoom: CGFloat = 3.0


    private var calendarGesture: AnyGesture<Void> {
        if zoomScale > 1.0 {
            return AnyGesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastZoomScale
                            lastZoomScale = value
                            let newScale = zoomScale * delta
                            zoomScale = min(max(newScale, minZoom), maxZoom)

                            if zoomScale <= 1.0 {
                                offset = .zero
                                lastOffset = .zero
                                zoomAnchor = .center
                            }
                        }
                        .onEnded { _ in
                            lastZoomScale = 1.0
                            if zoomScale <= 1.0 {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    offset = .zero
                                    lastOffset = .zero
                                    zoomAnchor = .center
                                }
                            }
                        },
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                ).map { _ in () }
            )
        } else {
            return AnyGesture(
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / lastZoomScale
                        lastZoomScale = value
                        let newScale = zoomScale * delta
                        zoomScale = min(max(newScale, minZoom), maxZoom)

                        if zoomScale > 1.0 {
                            zoomAnchor = .center
                        }
                    }
                    .onEnded { _ in
                        lastZoomScale = 1.0
                    }
                    .map { _ in () }
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            ZStack {
                HStack {
                    SettingsExperience(
                        cur_screen: $cur_screen,
                        firestoreManager: firestoreManager
                    )
                    Spacer()
                }

                Text("Calendar")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top)

                HStack {
                    Spacer()
                    CreateReminderExperience(
                        cur_screen: $cur_screen,
                        firestoreManager: firestoreManager
                    )
                }
            }
            .padding(.bottom)

            // MARK: Week/Month Toggle
            HStack(spacing: 4) {
                Button(action: { calendarViewType = "week" }) {
                    Text("Week")
                        .font(.headline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(calendarViewType == "week" ? Color.blue : Color.blue.opacity(0.1))
                        .foregroundColor(calendarViewType == "week" ? .white : .blue)
                        .cornerRadius(12)
                }
                Button(action: { calendarViewType = "month" }) {
                    Text("Month")
                        .font(.headline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(calendarViewType == "month" ? Color.blue : Color.blue.opacity(0.1))
                        .foregroundColor(calendarViewType == "month" ? .white : .blue)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)

            // MARK: Month/Year Selector
            HStack(spacing: 8) {
                if calendarViewType == "month" {
                    MonthYearSelector(
                        filteredDay: $monthFilteredDay,
                        isEditingMonthYear: $isEditingMonthYear,
                        currentPeriodText: currentPeriodText,
                        onDone: {
                            isEditingMonthYear = false
                            // Update swipeOffset when picker is used
                            if let monthFilteredDay = monthFilteredDay {
                                let currentDate = Date()
                                let currentMonth = Calendar.current.component(.month, from: currentDate)
                                let currentYear = Calendar.current.component(.year, from: currentDate)
                                let selectedMonth = Calendar.current.component(.month, from: monthFilteredDay)
                                let selectedYear = Calendar.current.component(.year, from: monthFilteredDay)
                                
                                let monthDiff = (selectedYear - currentYear) * 12 + (selectedMonth - currentMonth)
                                swipeOffset = monthDiff
                                canResetDate = monthDiff != 0
                            }
                        }
                    )
                    .onChange(of: isEditingMonthYear) { _, newValue in
                        if newValue {
                            // Set filteredDay to currently displayed month when opening picker
                            monthFilteredDay = Calendar.current.date(byAdding: .month, value: swipeOffset, to: Date())
                        }
                    }
                } else {
                    Text(currentPeriodText)
                        .font(.title)
                        .foregroundColor(.primary)
                }

                if canResetDate {
                    Button(action: {
                        swipeOffset = 0
                        weekFilteredDay = Date.now
                        monthFilteredDay = Date.now
                        canResetDate = false
                    }) {
                        Text("Today")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                }
            }

            // MARK: Calendar Grid
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Day headers
                    HStack(spacing: 0) {
                        ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                            Text(day)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: geometry.size.width / 7, height: 30)
                        }
                    }

                    let cellWidth = geometry.size.width / 7
                    let cellHeight = (geometry.size.height - 30) / (calendarViewType == "month" ? 6 : 1)

                    TabView(selection: $swipeOffset) {
                        ForEach(-60...60, id: \.self) { index in
                            CalendarGrid(
                                calendarViewType: calendarViewType,
                                helper: helper,
                                cellWidth: cellWidth,
                                cellHeight: cellHeight,
                                swipeOffset: index,
                                viewModel: viewModel,
                                zoomScale: zoomScale,
                                isReminderViewOn: isReminderViewOn,
                                cur_screen: $cur_screen,
                                firestoreManager: firestoreManager,
                                monthFilteredDay: monthFilteredDay,
                                weekFilteredDay: weekFilteredDay
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onChange(of: swipeOffset) { _, newValue in
                        // Update monthFilteredDay when swiping (but not when picker is active)
                        if !isEditingMonthYear {
                            monthFilteredDay = Calendar.current.date(byAdding: .month, value: swipeOffset, to: Date())
                        }
                        canResetDate = swipeOffset != 0
                    }


                    if zoomScale > 1.0 {
                        HStack {
                            Spacer()
                            Button("Reset View") {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    zoomScale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                            .padding(8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .padding(.top, 4)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 12).stroke(Color.primary, lineWidth: 2))
                .scaleEffect(zoomScale, anchor: zoomAnchor)
                .offset(offset)
                .animation(.easeOut(duration: 0.1), value: zoomScale)
                .gesture(calendarGesture)
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        zoomScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                }
                .clipped()
            }

            // MARK: Bottom Controls
            VStack(spacing: 12) {
                Toggle(isOn: $isReminderViewOn) {
                    Text("Reminder View")
                        .font(.headline)
                        .fontWeight(.medium)
                }

                Toggle(isOn: $isCalendarViewOn) {
                    Text("Calendar View")
                        .font(.headline)
                        .fontWeight(.medium)
                }
                .onChange(of: isCalendarViewOn) { _, newValue in
                    if !newValue {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .padding(16)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal)
            .padding(.bottom)

            NavigationBarExperience(cur_screen: $cur_screen, firestoreManager: firestoreManager)
        }
        .onAppear {
            calendarViewType = initialViewType
            firestoreManager.getRemindersForUser { fetchedReminders in
                if let fetchedReminders = fetchedReminders {
                    viewModel.loadReminders(from: fetchedReminders)
                }
            }
            weekFilteredDay = viewModel.selectedDate
            cur_screen = .CalendarScreen
        }
        .onChange(of: calendarViewType) { _, newValue in
            initialViewType = newValue
        }
        .onChange(of: viewModel.selectedDate) { _, newValue in
            if calendarViewType == "month" {
                monthFilteredDay = newValue
            } else {
                weekFilteredDay = newValue
            }
        }

    }

    private func updateFilteredDay() {
        if calendarViewType == "month" {
            monthFilteredDay = Calendar.current.date(byAdding: .month, value: swipeOffset, to: Date())
        } else {
            weekFilteredDay = Calendar.current.date(byAdding: .weekOfYear, value: swipeOffset, to: Date())
        }

        if swipeOffset != 0 {
            canResetDate = true
        }
    }

    private var currentPeriodText: String {
        let today: Date
        if calendarViewType == "month" {
            today = Calendar.current.date(byAdding: .month, value: swipeOffset, to: Date()) ?? Date()
            return monthString(today) + " " + yearString(today)
        } else if calendarViewType == "week" {
            today = Calendar.current.date(byAdding: .weekOfYear, value: swipeOffset, to: Date()) ?? Date()
            return weekString(from: today)
        } else {
            return ""
        }
    }
}

