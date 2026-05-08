if Rails.env.development? && defined?(ActiveRecordQueryTrace)
  ActiveRecordQueryTrace.enabled = true
end
