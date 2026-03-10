namespace :slots do
  desc "Generate slots for all grounds for the next 30 days"
  task generate_daily: :environment do
    grounds = Ground.all
    today = Date.today

    (0..29).each do |i|
      date = today + i
      slot_date = date.to_s

      holidays = [
        "2026-01-01",
        "2026-01-26",
        "2026-08-15"
      ]

      is_weekend = date.saturday? || date.sunday?
      is_holiday = holidays.include?(slot_date)

      slot_definitions =
        if is_weekend || is_holiday
          [
            { start_time: "06:30", end_time: "09:30", price: 4000 },
            { start_time: "09:30", end_time: "12:30", price: 3500 },
            { start_time: "13:00", end_time: "18:00", price: 3000 }
          ]
        else
          [
            { start_time: "06:30", end_time: "09:30", price: 2500 },
            { start_time: "09:30", end_time: "12:30", price: 2500 },
            { start_time: "13:00", end_time: "18:00", price: 2500 }
          ]
        end

      grounds.each do |ground|
        slot_definitions.each do |slot_data|
          slot = Slot.find_or_initialize_by(
            ground_id: ground.id,
            slot_date: slot_date,
            start_time: slot_data[:start_time],
            end_time: slot_data[:end_time]
          )

          # Only update price and defaults if new record
          if slot.new_record?
            slot.price = slot_data[:price]
            slot.status = "available"
            slot.max_teams = 2
            slot.teams_booked_count = 0
            slot.save!
            puts "Created slot for #{ground.name} on #{slot_date} #{slot_data[:start_time]}-#{slot_data[:end_time]}"
          end
        end
      end
    end

    puts "Done! Slots generated for all grounds for next 30 days."
  end
end