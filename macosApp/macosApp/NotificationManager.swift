import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    func checkPermissionStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
    
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🧪 通知测试成功！"
        content.body = "如果你看到这条消息，说明通知功能正常工作。"
        content.sound = .default
        // Fire after 5 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "test_notification_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Test notification error: \(error)")
            }
        }
    }
    
    func listPendingNotifications(completion: @escaping ([String]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let descriptions = requests.map { req in
                if let trigger = req.trigger as? UNCalendarNotificationTrigger,
                   let h = trigger.dateComponents.hour,
                   let m = trigger.dateComponents.minute {
                    return "\(req.content.title) @ \(String(format: "%02d:%02d", h, m))"
                }
                return "\(req.content.title)"
            }
            DispatchQueue.main.async {
                completion(descriptions)
            }
        }
    }
    
    func scheduleReminders(config: WorkConfig) {
        let center = UNUserNotificationCenter.current()
        
        // Clear existing notifications
        center.removeAllPendingNotificationRequests()
        
        // Setup Lunch Break Notification
        var lunchComponents = DateComponents()
        lunchComponents.hour = config.lunchStartHour
        lunchComponents.minute = config.lunchStartMinute
        lunchComponents.second = 0
        
        let lunchContent = UNMutableNotificationContent()
        lunchContent.title = "午休时间到！"
        lunchContent.body = "吃点好的，好好休息！"
        lunchContent.sound = .default
        
        let lunchTrigger = UNCalendarNotificationTrigger(dateMatching: lunchComponents, repeats: true)
        let lunchRequest = UNNotificationRequest(identifier: "lunch_reminder", content: lunchContent, trigger: lunchTrigger)
        
        // Setup Work End Notification
        var workEndComponents = DateComponents()
        workEndComponents.hour = config.workEndHour
        workEndComponents.minute = config.workEndMinute
        workEndComponents.second = 0
        
        let workEndContent = UNMutableNotificationContent()
        workEndContent.title = "下班啦！"
        workEndContent.body = "别卷了，快溜！"
        workEndContent.sound = .default
        
        let workEndTrigger = UNCalendarNotificationTrigger(dateMatching: workEndComponents, repeats: true)
        let workEndRequest = UNNotificationRequest(identifier: "work_end_reminder", content: workEndContent, trigger: workEndTrigger)
        
        // Add to center
        center.add(lunchRequest) { error in
            if let error = error {
                print("Failed to schedule lunch reminder: \(error)")
            }
        }
        
        center.add(workEndRequest) { error in
            if let error = error {
                print("Failed to schedule work end reminder: \(error)")
            }
        }
    }
}
