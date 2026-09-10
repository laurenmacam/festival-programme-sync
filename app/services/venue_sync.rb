# Keeps our local venue records in step with the upstream festival system.
#
# Inherited from the previous programming integration. Given an array of venue
# hashes from the API, it upserts each one into our venues table.
#
#   VenueSync.new(venues_payload).call
#
# where each entry looks like:
#   { "id" => "VEN-01", "name" => "Grand Cinema", "address" => "...", "capacity" => 320 }
class VenueSync
  Failure = Struct.new(:external_id, :message)

  attr_reader :failures

  def initialize(venues)
    @venues = venues
    @failures = []
  end

  def call
    @venues.each do |attrs|
      venue = Venue.find_or_initialize_by(external_id: attrs.fetch("id"))
      venue.name     = attrs["name"]
      venue.address  = attrs["address"]
      venue.capacity = attrs["capacity"]
      venue.save!
    rescue StandardError => e
      @failures << Failure.new(attrs["id"], e.message)
    end
  end
end
