require "rails_helper"

RSpec.describe Screening do
  it "is valid with a film, venue, starts_at and a unique external_id" do
    expect(build(:screening)).to be_valid
  end

  it "requires an external_id" do
    expect(build(:screening, external_id: nil)).not_to be_valid
  end

  it "requires a unique external_id" do
    create(:screening, external_id: "SCR-0001")

    expect(build(:screening, external_id: "SCR-0001")).not_to be_valid
  end

  it "requires starts_at" do
    expect(build(:screening, starts_at: nil)).not_to be_valid
  end

  it "requires a film" do
    expect(build(:screening, film: nil)).not_to be_valid
  end

  it "requires a venue" do
    expect(build(:screening, venue: nil)).not_to be_valid
  end

  it "defaults to scheduled status" do
    expect(Screening.new.status).to eq("scheduled")
  end
end
