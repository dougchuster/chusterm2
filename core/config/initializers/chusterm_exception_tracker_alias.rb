require Rails.root.join('lib/chatwoot_exception_tracker')

ChusteRMExceptionTracker = ChatwootExceptionTracker unless defined?(ChusteRMExceptionTracker)
ChatwootExceptionTracker = ChusteRMExceptionTracker unless defined?(ChatwootExceptionTracker)
