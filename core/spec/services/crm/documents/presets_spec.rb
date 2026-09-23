require 'rails_helper'

# Os presets são YAML escritos à mão. Em mapeamento `{ ... }`, vírgula sem
# aspas corta o valor e cria chave solta — já cortou o rótulo "Tem alguma data
# marcada? (audiência, perícia, prazo)" no formulário jurídico.
RSpec.describe Crm::Documents::Presets do
  def blank_keys(node, path = '')
    case node
    when Hash then node.flat_map { |key, value| (value.nil? ? ["#{path}/#{key}"] : []) + blank_keys(value, "#{path}/#{key}") }
    when Array then node.each_with_index.flat_map { |value, index| blank_keys(value, "#{path}[#{index}]") }
    else []
    end
  end

  described_class.slugs.each do |slug|
    it "#{slug}: nenhuma chave sem valor (vírgula sem aspas no YAML)" do
      expect(blank_keys(described_class.fetch(slug))).to eq([])
    end
  end
end
