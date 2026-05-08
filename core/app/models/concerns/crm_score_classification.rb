module CrmScoreClassification
  DEFAULT_THRESHOLDS = {
    'prioridade_alta' => 80,
    'qualificado' => 60,
    'medio_potencial' => 40,
    'baixo_potencial' => 0
  }.freeze

  module_function

  def classify(score, thresholds = DEFAULT_THRESHOLDS)
    normalized_score = score.to_i.clamp(0, 100)
    normalized_thresholds = DEFAULT_THRESHOLDS.merge(
      (thresholds || {}).to_h.slice(*DEFAULT_THRESHOLDS.keys)
    ).transform_values(&:to_i)

    normalized_thresholds.sort_by { |_label, threshold| -threshold }.each do |label, threshold|
      return label if normalized_score >= threshold
    end

    'baixo_potencial'
  end
end
