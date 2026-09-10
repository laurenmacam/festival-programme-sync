# Runs ProgrammeSync as a background job.
#
# A Redis lock stops two syncs from running at the same time.
#
# We only raise an error (which makes Sidekiq retry) when the whole run
# fails. A single bad record doesn't need a retry: ProgrammeSync already 
# logged it, and the next scheduled run will try again anyway.
class ProgrammeSyncJob
  include Sidekiq::Job

  sidekiq_options retry: 5

  LOCK_KEY = "programme_sync:lock"
  LOCK_TTL = 15.minutes.to_i

  def perform(generation = 1)
    return unless acquire_lock

    begin
      run = ProgrammeSync.new(generation: generation).call
      raise "ProgrammeSync run #{run.id} failed: #{run.error_details}" if run.failed?
    ensure
      release_lock
    end
  end

  private

  def acquire_lock
    Sidekiq.redis { |conn| conn.call("SET", LOCK_KEY, "1", "NX", "EX", LOCK_TTL) }
  end

  def release_lock
    Sidekiq.redis { |conn| conn.call("DEL", LOCK_KEY) }
  end
end
