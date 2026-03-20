namespace :auto do
  desc "Send auto reminders (admin + user) for matches starting in 12 hours"
  task send_reminders: :environment do
    result = AutoReminderService.send_reminders
    puts "Sent #{result[:admin]} admin reminders, #{result[:user]} user reminders"
  end
  
  desc "Test reminder for a specific booking"
  task :test_reminder, [:booking_id] => :environment do |t, args|
    booking = Booking.find(args[:booking_id])
    puts "=== ADMIN MESSAGE ==="
    puts AutoReminderService.send(:build_admin_message, booking)
    puts "\n=== USER MESSAGE ==="
    puts AutoReminderService.send(:build_user_message, booking)
  end
end