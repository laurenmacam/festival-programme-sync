require "rails_helper"

RSpec.describe ProgrammeSync do
  # Builds a fake HTTP client backed directly by MockApi::Dataset, so specs
  # never depend on another process/container actually serving /mock_api.
  def stubbed_connection(generation:, fail_on_page: nil)
    stubs = Faraday::Adapter::Test::Stubs.new
    all = MockApi::Dataset.records(generation: generation)
    total_pages = (all.size.to_f / MockApi::Dataset::PER_PAGE).ceil

    stubs.get("/mock_api/screenings") do |env|
      page = env.params["page"].to_i

      if fail_on_page && page == fail_on_page
        [ 500, {}, { error: "Upstream festival system unavailable" }.to_json ]
      else
        offset = (page - 1) * MockApi::Dataset::PER_PAGE
        slice  = all[offset, MockApi::Dataset::PER_PAGE] || []
        body = { page: page, per_page: MockApi::Dataset::PER_PAGE, total_pages: total_pages,
                 total_count: all.size, screenings: slice }
        [ 200, { "Content-Type" => "application/json" }, body.to_json ]
      end
    end

    Faraday.new { |f| f.response :json; f.adapter :test, stubs }
  end

  def sync(generation:, fail_on_page: nil)
    client = stubbed_connection(generation: generation, fail_on_page: fail_on_page)
    ProgrammeSync.new(generation: generation, http_client: client).call
  end

  describe "idempotency" do
    it "does not create duplicate screenings when run twice" do
      sync(generation: 1)

      expect { sync(generation: 1) }.not_to change(Screening, :count)
    end

    it "reports nothing created or updated on a no-op rerun" do
      sync(generation: 1)
      run = sync(generation: 1)

      expect(run.created_count).to eq(0)
      expect(run.updated_count).to eq(0)
    end

    it "updates the retitled film in place instead of creating a duplicate" do
      sync(generation: 1)
      sync(generation: 2)

      expect(Film.where(external_id: "FILM-005").count).to eq(1)
      expect(Film.find_by(external_id: "FILM-005").title).to eq("Autumn in Trieste (Director's Cut)")
    end

    it "updates the renamed venue in place instead of creating a duplicate" do
      sync(generation: 1)
      sync(generation: 2)

      expect(Venue.where(external_id: "VEN-03").count).to eq(1)
      expect(Venue.find_by(external_id: "VEN-03").name).to eq("City Gallery Auditorium")
    end
  end

  describe "generation 2 changes" do
    before { sync(generation: 1) }

    it "updates screenings that moved venue" do
      sync(generation: 2)

      expect(Screening.find_by(external_id: "SCR-0001").venue.external_id).to eq("VEN-06")
    end

    it "marks cancelled screenings as cancelled" do
      sync(generation: 2)

      expect(Screening.find_by(external_id: "SCR-0010")).to be_cancelled
    end

    it "creates newly added screenings" do
      sync(generation: 2)

      expect(Screening.exists?(external_id: "SCR-0061")).to eq(true)
      expect(Screening.exists?(external_id: "SCR-0062")).to eq(true)
    end

    it "does not delete a screening removed upstream" do
      sync(generation: 2)

      expect(Screening.exists?(external_id: "SCR-0060")).to eq(true)
    end
  end

  describe "partial failure" do
    it "commits earlier pages and marks the run partial when a later page fails" do
      run = sync(generation: 1, fail_on_page: 2)

      expect(run).to be_partial
      expect(run.created_count).to eq(MockApi::Dataset::PER_PAGE)
      expect(Screening.count).to eq(MockApi::Dataset::PER_PAGE)
      expect(run.error_details.first["message"]).to include("page 2")
    end

    it "marks the run failed when nothing synced at all" do
      run = sync(generation: 1, fail_on_page: 1)

      expect(run).to be_failed
      expect(Screening.count).to eq(0)
    end

    it "loses nothing and completes cleanly on a subsequent run" do
      sync(generation: 1, fail_on_page: 2)
      sync(generation: 1)

      expect(Screening.count).to eq(60)
    end

    it "isolates a single bad record without losing the rest of its page" do
      records = MockApi::Dataset.generation_one.first(3)
      records[1] = records[1].merge("film" => nil)

      stubs = Faraday::Adapter::Test::Stubs.new
      stubs.get("/mock_api/screenings") do
        body = { page: 1, per_page: 25, total_pages: 1, total_count: 3, screenings: records }
        [ 200, { "Content-Type" => "application/json" }, body.to_json ]
      end
      client = Faraday.new { |f| f.response :json; f.adapter :test, stubs }

      run = ProgrammeSync.new(generation: 1, http_client: client).call

      expect(run).to be_partial
      expect(run.created_count).to eq(2)
      expect(run.failed_count).to eq(1)
      expect(Screening.count).to eq(2)
      expect(run.error_details.first["external_id"]).to eq(records[1]["id"])
    end
  end
end
