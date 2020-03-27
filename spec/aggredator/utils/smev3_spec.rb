RSpec.describe Aggredator::Smev3 do

  it 'build attachment id' do
    value = SecureRandom.hex
    expect(described_class.build_attachment_id(value)).to eq "@{#{value.to_s}}"
  end

end