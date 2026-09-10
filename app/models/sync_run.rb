class SyncRun < ApplicationRecord
  enum :status, { running: "running", succeeded: "succeeded", partial: "partial", failed: "failed" },
       default: "running"

  validates :started_at, presence: true

  def record_error(external_id:, message:)
    # Building new array and reassigning it, better for jsonb
    self.error_details = error_details + [ { "external_id" => external_id, "message" => message, "at" => Time.current.iso8601 } ]
  end

  def duration
    return nil unless finished_at

    finished_at - started_at
  end
end
