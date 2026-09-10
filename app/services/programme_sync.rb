# Upserts screenings from the upstream API, use external_id rather than title/name as key.

class ProgrammeSync
  class ApiError < StandardError; end

  def initialize(generation: 1)
    @generation = generation
    @run = SyncRun.create!(started_at: Time.current, generation: generation)
  end

  def call
    page = 1

    loop do
      body = fetch_page(page)
      body.fetch("screenings").each { |record| sync_screening(record) }

      total_pages = body.fetch("total_pages")
      break if page >= total_pages

      page += 1
    end

    finish!(@run.failed_count.zero? ? :succeeded : :partial)
  rescue ApiError => e
    @run.record_error(external_id: nil, message: e.message)

    # API failure stops pagination but keeps whatever already synced.
    anything_synced = @run.created_count.positive? || @run.updated_count.positive?
    finish!(anything_synced ? :partial : :failed)
  end

  private

  def fetch_page(page)
    response = connection.get("/mock_api/screenings", { generation: @generation, page: page })
    raise ApiError, "upstream request failed at page #{page}: HTTP #{response.status}" unless response.success?

    response.body
  rescue Faraday::Error => e
    raise ApiError, "upstream request failed at page #{page}: #{e.message}"
  end

  def connection
    @connection ||= Faraday.new(url: ENV.fetch("FESTIVAL_API_URL", "http://localhost:3000")) do |f|
      f.response :json
      f.adapter Faraday.default_adapter
    end
  end

  def sync_screening(record)
    external_id = record["id"]

    ActiveRecord::Base.transaction do
      film  = upsert_film(record["film"] || {})
      venue = upsert_venue(record["venue"] || {})

      screening = Screening.find_or_initialize_by(external_id: external_id)
      created = screening.new_record?

      screening.assign_attributes(
        film: film,
        venue: venue,
        starts_at: record["starts_at"],
        status: record["status"]
      )
      screening.save!

      if created
        @run.increment!(:created_count)
      elsif screening.saved_changes?
        @run.increment!(:updated_count)
      end
    end
  rescue StandardError => e
    @run.increment!(:failed_count)
    @run.record_error(external_id: external_id, message: e.message)
    @run.save!
  end

  def upsert_film(attrs)
    film = Film.find_or_initialize_by(external_id: attrs["id"])
    film.assign_attributes(
      title:    attrs["title"],
      synopsis: attrs["synopsis"],
      runtime:  attrs["runtime"],
      year:     attrs["year"]
    )
    film.save!
    film
  end

  def upsert_venue(attrs)
    venue = Venue.find_or_initialize_by(external_id: attrs["id"])
    venue.assign_attributes(
      name:     attrs["name"],
      address:  attrs["address"],
      capacity: attrs["capacity"]
    )
    venue.save!
    venue
  end

  def finish!(status)
    @run.update!(status: status, finished_at: Time.current)
    @run
  end
end
