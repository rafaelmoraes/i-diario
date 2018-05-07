require 'rails_helper'

RSpec.describe DailyFrequenciesCreator, type: :service do
  let(:discipline) { create(:discipline) }
  let(:classroom) { create(:classroom) }
  let(:frequency_start_at) { Date.parse("#{school_calendar.year}-01-01") }
  let(:student_enrollment) { create(:student_enrollment) }
  let(:school_calendar) do
    create(:school_calendar_with_one_step, unity: classroom.unity, year: Date.current.year)
  end

  before do
    classroom.student_enrollments << student_enrollment
  end

  it 'allows to create frequencies to current date when frequency_date argument is null' do
    student_enrollment_classroom = classroom.student_enrollment_classrooms.first
    student_enrollment_classroom.update_attribute(:joined_at, frequency_start_at)

    creator = described_class.new({
      unity: classroom.unity,
      classroom_id: classroom.id,
      school_calendar: school_calendar
    })

    expect { creator.find_or_create! }.to change { DailyFrequency.count }.to(1)
  end

  it 'does not create frequencies when frequency_date argument is not a valid one' do
    student_enrollment_classroom = classroom.student_enrollment_classrooms.first
    student_enrollment_classroom.update_attribute(:joined_at, frequency_start_at - 1.day)

    creator = described_class.new({
      unity: classroom.unity,
      classroom_id: classroom.id,
      school_calendar: school_calendar,
      frequency_date: frequency_start_at - 1.day
    })

    expect { creator.find_or_create! }.to_not change { DailyFrequency.count }
  end

  it 'allows to create frequencies custom class number in the params' do
    student_enrollment_classroom = classroom.student_enrollment_classrooms.first
    student_enrollment_classroom.update_attribute(:joined_at, frequency_start_at)

    creator = described_class.new({
      unity: classroom.unity,
      classroom_id: classroom.id,
      school_calendar: school_calendar,
      class_number: '1',
      discipline_id: discipline.id
    })

    creator.find_or_create!
    daily_frequency = DailyFrequency.last

    expect(daily_frequency.class_number).to eq 1
  end

  it 'allows to create frequencies custom class number in the second argument' do
    student_enrollment_classroom = classroom.student_enrollment_classrooms.first
    student_enrollment_classroom.update_attribute(:joined_at, frequency_start_at)

    creator = described_class.new({
      unity: classroom.unity,
      classroom_id: classroom.id,
      school_calendar: school_calendar,
      discipline_id: discipline.id
    }, [1])

    creator.find_or_create!
    daily_frequency = DailyFrequency.last

    expect(daily_frequency.class_number).to eq 1
  end

end
