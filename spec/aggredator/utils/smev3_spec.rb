RSpec.describe Aggredator::Smev3 do

  it 'build attachment id' do
    value = SecureRandom.hex
    expect(described_class.build_attachment_id(value)).to eq "@{#{value.to_s}}"
  end

  context 'build incoming type' do
  
    it 'kinnalru example' do
      name = 'output'
      href = 'urn://x-artifacts-mcx-ru/ais-subsidii/rs-rpz/1.0.0'
      expect(described_class.build_incoming_type(name, href)).to eq 'output_urn-x-artifacts-mcx-ru-ais-subsidii-rs-rpz-1-0-0'
    end

    it 'smev3 get request example' do
      name = 'DataRequest'
      href = 'urn://x-artefacts-smev-gov-ru/services/message-exchange/types/1.2'
      expect(described_class.build_incoming_type(name, href)).to eq 'DataRequest_urn-x-artefacts-smev-gov-ru-services-message-exchange-types-1-2'
    end

    it 'transliterate russian' do
      name = 'Запрос'
      href = 'urn://x-artefacts-smev-gov-ru/services/message-exchange/types/1.2'
      expect(described_class.build_incoming_type(name, href)).to eq 'Zapros_urn-x-artefacts-smev-gov-ru-services-message-exchange-types-1-2'
    end

  end

  it 'build mtom attachment id' do
    id = described_class.build_mtom_attachment_id
    expect(described_class::MTOM_ID_FIRST_LETTERS).to include(id[0])
  end

end