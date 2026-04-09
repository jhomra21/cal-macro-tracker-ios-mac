# History / Calendar View Changes

## Summary

This change reworked the History screen to feel closer to Apple's Fitness-style history/calendar experience while staying within the current SwiftUI + `UICalendarView` architecture in this codebase.

## What Changed

### 1. History header was rebuilt

- Replaced the previous navigation-bar title approach with a custom top header.
- Added:
  - a left back button
  - a plain text date title
  - a right calendar button
- Kept the back and calendar buttons visually consistent with the existing app glass treatment.

### 2. Week row replaced the old date navigator

- Removed the old history date navigator row.
- Added a compact week strip that shows:
  - weekday letters
  - the selected day state
  - macro rings for each day
- The selected day now also shows its ring so the row stays visually consistent.

### 3. Calendar expansion stayed inline

- Kept the existing inline calendar concept instead of switching to a modal or overlay.
- The calendar still opens from the history header/calendar area, but now sits under the week row inside the same card.
- Added a persistent divider under the week row so the expanded section has a clear boundary.

### 4. Calendar reveal animation was simplified

- Earlier attempts used a top fade/mask, but that still allowed visible overlap with the weekday row.
- The final implementation uses a simpler reveal under the divider:
  - divider stays fixed
  - calendar appears below it
  - transition uses opacity + slight scale instead of sliding through the top row

### 5. Macro ring rendering was reused instead of duplicated

- The shared ring renderer in `MacroRingView.swift` was made more configurable.
- Added a smaller ring-only variant for the week strip instead of creating a second ring implementation.

### 6. Day/week summary plumbing was extended

- Extended the summary path so the history week strip can compute per-day snapshots from one shared summary layer.
- Reused existing nutrition math and grouping logic instead of creating separate per-day fetch logic in the view.

## How It Was Implemented

### UI structure

- `HistoryScreen.swift`
  - now owns the custom top bar
  - renders the week card
  - keeps the selected date and calendar expansion state

- `HistoryWeekCard`
  - wraps the week strip and expandable calendar section
  - keeps both parts inside the same rounded glass container

- `HistoryWeekStrip`
  - queries the entries for the visible week
  - derives daily snapshots
  - renders one tappable weekday cell per day

- `HistoryWeekdayCell`
  - shows weekday label
  - shows selected-day highlight
  - shows the small reusable ring

### Shared data helpers

- `LogEntryDaySummary.swift`
  - added reusable range-based descriptor support
  - added per-day snapshot grouping for a week

- `ModelSupport.swift`
  - added week/date helpers used by the new week strip and history title formatting

### Ring reuse

- `MacroRingView.swift`
  - extracted flexibility into the shared ring renderer
  - added a compact weekday ring variant with no center text

### List cleanup

- `LogEntryListSection.swift`
  - added the ability to hide the list header on History
  - kept the date context at the top of the screen instead of duplicating it in the list
  - fixed row identity handling during review so list updates stay stable

## Final Behavior

- History has a custom top header instead of relying on the default navigation title layout.
- The week strip is the main date selector.
- The calendar expands inline beneath the divider.
- The selected day and non-selected days all show rings.
- The history layout now feels more cohesive and less like stacked unrelated pieces.

## Follow-up Bug: calendar selection could crash back navigation

### User-visible symptom

- Opening the inline calendar alone was safe.
- But after selecting a different date inside the inline calendar, both:
  - edge-swipe back
  - tapping the back button
    could crash the app when leaving History.

### What caused it

- The iOS History calendar was using a custom `UICalendarView` bridge through `UIViewRepresentable`.
- That bridge introduced a UIKit/SwiftUI lifecycle problem after date selection.
- Once the calendar had been interacted with, popping the History screen could run through an unstable selection/update teardown path.

### Final fix

- Removed the custom iOS `UICalendarView` bridge from `HistoryCalendarView.swift`.
- Replaced it with SwiftUI's graphical `DatePicker` on iOS as well.
- Kept the binding normalized to `startOfDayValue` so History still uses the same day-based date semantics.

### Why this fix was chosen

- The issue was not the History date model or the navigation stack itself.
- The crash was tied specifically to the UIKit calendar bridge after interaction.
- The cleanest root-level fix was to remove the bridge entirely instead of adding more lifecycle workarounds on top of it.

## Main Files Touched

- `cal-macro-tracker/Features/History/HistoryScreen.swift`
- `cal-macro-tracker/Features/History/HistoryCalendarView.swift`
- `cal-macro-tracker/Features/Dashboard/MacroRingView.swift`
- `cal-macro-tracker/Data/Services/LogEntryDaySummary.swift`
- `cal-macro-tracker/Data/Models/ModelSupport.swift`
- `cal-macro-tracker/App/LogEntryListSection.swift`
