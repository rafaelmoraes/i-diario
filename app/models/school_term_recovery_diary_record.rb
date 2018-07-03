class SchoolTermRecoveryDiaryRecord < ActiveRecord::Base
  include Audit
  include Filterable

  acts_as_copy_target

  audited
  has_associated_audits

  belongs_to :recovery_diary_record, dependent: :destroy
  belongs_to :school_calendar_step, -> { includes(:school_calendar) }
  belongs_to :school_calendar_classroom_step

  accepts_nested_attributes_for :recovery_diary_record

  scope :by_unity_id, lambda { |unity_id| joins(:recovery_diary_record).where(recovery_diary_records: { unity_id: unity_id }) }
  scope :by_teacher_id, lambda { |teacher_id| by_teacher_id_query(teacher_id) }
  scope :by_classroom_id, lambda { |classroom_id| joins(:recovery_diary_record).where(recovery_diary_records: { classroom_id: classroom_id }) }
  scope :by_discipline_id, lambda { |discipline_id| joins(:recovery_diary_record).where(recovery_diary_records: { discipline_id: discipline_id }) }
  scope :by_school_calendar_step_id, lambda { |school_calendar_step_id| where(school_calendar_step_id: school_calendar_step_id) }
  scope :by_school_calendar_classroom_step_id, lambda { |school_calendar_classroom_step_id| where(school_calendar_classroom_step_id: school_calendar_classroom_step_id)   }
  scope :by_recorded_at, lambda { |recorded_at| joins(:recovery_diary_record).where(recovery_diary_records: { recorded_at: recorded_at }) }

  scope :ordered, -> { joins(:recovery_diary_record).order(RecoveryDiaryRecord.arel_table[:recorded_at].desc) }

  validates :recovery_diary_record, presence: true
  validates :school_calendar_step, presence: true, unless: :school_calendar_classroom_step
  validates :school_calendar_classroom_step, presence: true, unless: :school_calendar_step

  validate :uniqueness_of_school_term_recovery_diary_record
  validate :recovery_type_must_allow_recovery_for_classroom
  validate :recovery_type_must_allow_recovery_for_school_calendar_step
  validate :recorded_at_must_be_school_calendar_step_day, unless: :school_calendar_classroom_step
  validate :recorded_at_must_be_school_calendar_classroom_step_day, unless: :school_calendar_step

  delegate :classroom_id, :discipline_id, :recorded_at, to: :recovery_diary_record

  def school_calendar_steps_ids
    school_calendar_steps = RecoverySchoolCalendarStepsFetcher.new(
      school_calendar_step_id,
      recovery_diary_record.classroom_id
      )
      .fetch

    school_calendar_steps.map(&:id)
  end

  def school_calendar_classroom_steps_ids
    school_calendar_classroom_steps = RecoverySchoolCalendarClassroomStepsFetcher.new(
      school_calendar_step_id,
      recovery_diary_record.classroom_id
    ).fetch

    school_calendar_classroom_steps.map(&:id)
  end

  def step
    self.school_calendar_classroom_step || self.school_calendar_step
  end

  def recorded_at
    recovery_diary_record.recorded_at
  end

  private

  def self.by_teacher_id_query(teacher_id)
    joins(
      :recovery_diary_record,
      arel_table.join(TeacherDisciplineClassroom.arel_table, Arel::Nodes::OuterJoin)
        .on(
          TeacherDisciplineClassroom.arel_table[:classroom_id]
            .eq(RecoveryDiaryRecord.arel_table[:classroom_id])
            .and(
              TeacherDisciplineClassroom.arel_table[:discipline_id]
                .eq(RecoveryDiaryRecord.arel_table[:discipline_id])
            )
        )
        .join_sources
      )
      .where(TeacherDisciplineClassroom.arel_table[:teacher_id].eq(teacher_id)
      .and(TeacherDisciplineClassroom.arel_table[:active].eq('t')))
  end

  def uniqueness_of_school_term_recovery_diary_record
    return unless recovery_diary_record

    relation = SchoolTermRecoveryDiaryRecord.by_classroom_id(recovery_diary_record.classroom_id)
                                            .by_discipline_id(recovery_diary_record.discipline_id)
                                            .by_school_calendar_step_id(school_calendar_step_id)
                                            .by_school_calendar_classroom_step_id(school_calendar_classroom_step_id)

    relation = relation.where.not(id: id) if persisted?

    if relation.any?
      errors.add(:school_calendar_step, :uniqueness_of_school_term_recovery_diary_record) if school_calendar_step_id.present?
      errors.add(:school_calendar_classroom_step, :uniqueness_of_school_term_recovery_diary_record) if school_calendar_classroom_step_id.present?
    end
  end

  def recovery_type_must_allow_recovery_for_classroom
    classroom_present = recovery_diary_record && recovery_diary_record.classroom

    if classroom_present && recovery_diary_record.classroom.exam_rule.recovery_type == RecoveryTypes::DONT_USE
      errors.add(:recovery_diary_record, :recovery_type_must_allow_recovery_for_classroom)
      recovery_diary_record.errors.add(:classroom, :recovery_type_must_allow_recovery_for_classroom)
    end
  end

  def recovery_type_must_allow_recovery_for_school_calendar_step
    classroom_present = recovery_diary_record && recovery_diary_record.classroom
    return unless classroom_present && school_calendar_step && recovery_diary_record.classroom.exam_rule.recovery_type == RecoveryTypes::SPECIFIC

    if recovery_diary_record.classroom.exam_rule.recovery_exam_rules.none? { |r| r.steps.include?(school_calendar_step.to_number) }
      errors.add(:school_calendar_step, :recovery_type_must_allow_recovery_for_school_calendar_step)
    end
  end

  def recorded_at_must_be_school_calendar_step_day
    return unless recovery_diary_record && recovery_diary_record.recorded_at && school_calendar_step

    unless school_calendar_step == school_calendar_step.school_calendar.step(recovery_diary_record.recorded_at)
      errors.add(:recovery_diary_record, :recorded_at_must_be_school_calendar_step_day)
      recovery_diary_record.errors.add(:recorded_at, :recorded_at_must_be_school_calendar_step_day)
    end
  end

  def recorded_at_must_be_school_calendar_classroom_step_day
    return unless recovery_diary_record && recovery_diary_record.recorded_at && school_calendar_classroom_step

    unless school_calendar_classroom_step == school_calendar_classroom_step.school_calendar_classroom.classroom_step(recovery_diary_record.recorded_at)
      errors.add(:recovery_diary_record, :recorded_at_must_be_school_calendar_step_day)
      recovery_diary_record.errors.add(:recorded_at, :recorded_at_must_be_school_calendar_step_day)
    end
  end
end
