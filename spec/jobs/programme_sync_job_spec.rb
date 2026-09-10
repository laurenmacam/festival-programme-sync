require "rails_helper"

RSpec.describe ProgrammeSyncJob do
  def stub_run(status)
    run = instance_double(SyncRun, status: status, failed?: status == "failed", id: 1, error_details: [])
    allow(ProgrammeSync).to receive(:new).and_return(instance_double(ProgrammeSync, call: run))
    run
  end

  before { Sidekiq.redis { |c| c.call("DEL", ProgrammeSyncJob::LOCK_KEY) } }
  after  { Sidekiq.redis { |c| c.call("DEL", ProgrammeSyncJob::LOCK_KEY) } }

  it "runs ProgrammeSync with the given generation" do
    stub_run("succeeded")

    described_class.new.perform(2)

    expect(ProgrammeSync).to have_received(:new).with(generation: 2)
  end

  it "does not raise when the run succeeds" do
    stub_run("succeeded")

    expect { described_class.new.perform(1) }.not_to raise_error
  end

  it "does not raise when the run is only partial" do
    stub_run("partial")

    expect { described_class.new.perform(1) }.not_to raise_error
  end

  it "raises when the run fails outright, so Sidekiq retries it" do
    stub_run("failed")

    expect { described_class.new.perform(1) }.to raise_error(/failed/)
  end

  it "releases the lock even when the run raises" do
    stub_run("failed")

    described_class.new.perform(1) rescue nil

    lock = Sidekiq.redis { |c| c.call("GET", ProgrammeSyncJob::LOCK_KEY) }
    expect(lock).to be_nil
  end

  it "does not start a second sync while one is already in progress" do
    Sidekiq.redis { |c| c.call("SET", ProgrammeSyncJob::LOCK_KEY, "1", "EX", 60) }
    stub_run("succeeded")

    described_class.new.perform(1)

    expect(ProgrammeSync).not_to have_received(:new)
  end
end
