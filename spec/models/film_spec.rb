require "rails_helper"

RSpec.describe Film do
  it "is valid with a title and a unique external_id" do
    expect(build(:film)).to be_valid
  end

  it "requires an external_id" do
    expect(build(:film, external_id: nil)).not_to be_valid
  end

  it "requires a unique external_id" do
    create(:film, external_id: "FILM-001")

    expect(build(:film, external_id: "FILM-001")).not_to be_valid
  end

  it "requires a title" do
    expect(build(:film, title: nil)).not_to be_valid
  end

  it "destroys its screenings when destroyed" do
    film = create(:film)
    create(:screening, film: film)

    expect { film.destroy }.to change(Screening, :count).by(-1)
  end
end
