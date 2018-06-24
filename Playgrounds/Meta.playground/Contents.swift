import Foundation
import Result
import ReactiveSwift
@testable import TogglGoals_MacOS
import PlaygroundSupport

let day1 = DayComponents(year: 2018, month: 06, day: 17)
let day2 = DayComponents(year: 2018, month: 06, day: 21)
let day3 = DayComponents(year: 2018, month: 06, day: 24)

let pid = MutableProperty(ProjectID(12))
let goal = MutableProperty(Goal(for: 12, hoursTarget: 40, workWeekdays: .exceptWeekend))
let report = MutableProperty<TwoPartTimeReport?>(
    TwoPartTimeReport(projectId: 12,
                      period: Period(start: day1,
                                     end: day2),
                      workedTimeUntilDayBeforeRequest: 10,
                      workedTimeOnDayOfRequest: 4))
let runningEntry = MutableProperty<RunningEntry?>(nil)
let startGoalDay = MutableProperty(day1)
let endGoalDay = MutableProperty(day3)
let startStrategyDay = MutableProperty(day2)
let currentDate = MutableProperty(Date(timeIntervalSince1970: 1529582400))
let calendar = MutableProperty(Calendar.iso8601)

let gp = GoalProgress()
gp.projectId <~ pid
gp.goal <~ goal
gp.report <~ report
gp.runningEntry <~ runningEntry
gp.startGoalDay <~ startGoalDay
gp.endGoalDay <~ endGoalDay
gp.startStrategyDay <~ startStrategyDay
gp.currentDate <~ currentDate
gp.calendar <~ calendar

let d = gp.dayBaseline.producer.start {
    print ($0)
}

pid.value = 15
goal.value = Goal(for: 15, hoursTarget: 30, workWeekdays: .exceptWeekend)
report.value =
    TwoPartTimeReport(projectId: 12,
                      period: Period(start: day1,
                                     end: day2),
                      workedTimeUntilDayBeforeRequest: 10,
                      workedTimeOnDayOfRequest: 4)


