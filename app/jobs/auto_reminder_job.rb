class AutoReminderJob < ApplicationJob
  queue_as :default
  
  def perform
    result = AutoReminderService.send_reminders
    Rails.logger.info "AutoReminderJob completed: Sent #{result[:admin]} admin, #{result[:user]} user reminders"
  end
end