class TestSetting < ActiveRecord::Base
  acts_as_copy_target

  audited
  has_associated_audits

  include Audit
  include TestSettingValidations

  has_enumeration_for :exam_setting_type, with: ExamSettingTypes, create_helpers: true

  has_many :avaliations, dependent: :restrict_with_error
  has_many :tests, class_name: 'TestSettingTest', dependent: :destroy

  accepts_nested_attributes_for :tests, reject_if: :all_blank, allow_destroy: true

  scope :ordered, -> { order(year: :desc) }

  def to_s
    if school_term.nil?
      year
    else
      school_term_humanize
    end
  end

  def school_term_humanize
    case
    when school_term.nil?
      '-'
    when school_term.end_with?(SchoolTermTypes::BIMESTER)
      I18n.t("enumerations.bimesters.#{school_term}")
    when school_term.end_with?(SchoolTermTypes::TRIMESTER)
      I18n.t("enumerations.trimesters.#{school_term}")
    when school_term.end_with?(SchoolTermTypes::SEMESTER)
      I18n.t("enumerations.semesters.#{school_term}")
    end
  end

end
