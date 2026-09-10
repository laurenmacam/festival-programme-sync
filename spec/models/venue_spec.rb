require "rails_helper"

RSpec.describe Venue do
  it "is valid with a name and a unique external_id" do
    expect(build(:venue)).to be_valid
  end

  it "requires an external_id" do
    expect(build(:venue, external_id: nil)).not_to be_valid
  end

  it "requires a unique external_id" do
    create(:venue, external_id: "VEN-01")

    expect(build(:venue, external_id: "VEN-01")).not_to be_valid
  end

  it "requires a name" do
    expect(build(:venue, name: nil)).not_to be_valid
  end

  it "destroys its screenings when destroyed" do
    venue = create(:venue)
    create(:screening, venue: venue)

    expect { venue.destroy }.to change(Screening, :count).by(-1)
  end
end
