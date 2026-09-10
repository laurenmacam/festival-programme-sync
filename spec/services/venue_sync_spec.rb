require "rails_helper"

RSpec.describe VenueSync do
  describe "#call" do
    it "creates a venue that doesn't exist yet" do
      payload = [
        { "id" => "VEN-01", "name" => "Grand Cinema", "address" => "12 Main Street", "capacity" => 320 }
      ]

      expect { VenueSync.new(payload).call }.to change(Venue, :count).by(1)

      venue = Venue.find_by(external_id: "VEN-01")
      expect(venue).to have_attributes(
        name: "Grand Cinema",
        address: "12 Main Street",
        capacity: 320
      )
    end

    it "updates a venue that was renamed" do
      existing = create(:venue, external_id: "VEN-03", name: "City Gallery Screening Room")

      payload = [
        { "id" => "VEN-03", "name" => "City Gallery Auditorium", "address" => "1 Museum Square", "capacity" => 90 }
      ]

      expect { VenueSync.new(payload).call }.not_to change(Venue, :count)

      expect(existing.reload).to have_attributes(
        external_id: "VEN-03",
        name: "City Gallery Auditorium",
        address: "1 Museum Square",
        capacity: 90
      )
    end

    it "ignores a bad record and processes the rest of the batch" do
      payload = [
        { "id" => "VEN-01", "name" => nil, "address" => "12 Main Street", "capacity" => 320 },
        { "id" => "VEN-02", "name" => "Riverside Cinema", "address" => "4 Quay Road", "capacity" => 180 }
      ]

      sync = VenueSync.new(payload)

      expect { sync.call }.to change(Venue, :count).by(1)
      expect(Venue.find_by(external_id: "VEN-02")).to be_present
      expect(sync.failures.map(&:external_id)).to eq([ "VEN-01" ])
    end
  end
end
