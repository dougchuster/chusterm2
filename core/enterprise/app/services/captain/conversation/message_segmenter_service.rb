# Divide a resposta da IA em mensagens curtas, para o atendimento chegar em
# partes no WhatsApp em vez de um bloco único.
#
# Duas fontes de corte, nesta ordem:
#   1. Quebras que o próprio modelo escreveu (linha em branco entre blocos).
#   2. Corte por frase, quando um bloco ainda ficar longo demais.
#
# A política é dividir sempre que der e só mandar bloco maior quando não houver
# como separar sem quebrar o sentido — uma frase longa sozinha, por exemplo,
# não tem onde ser cortada e sai inteira.
#
# Segmentar antes também evita que o filtro de brevidade precise descartar
# frases do meio do texto, que era o que transformava respostas corretas em
# frases sem sentido.
class Captain::Conversation::MessageSegmenterService
  MAX_PARTS = 5
  MAX_SENTENCES_PER_PART = 2

  # Teto duro de uma parte. Acima disso nunca juntamos duas frases.
  MAX_CHARACTERS_PER_PART = 240

  # Duas frases só viajam juntas se o resultado continuar curto. Acima disso
  # cada uma vira uma mensagem.
  COMBINE_CHARACTERS_LIMIT = 130

  # Aberturas curtas ("Olá!", "Entendi.", "Certo.") não viram mensagem sozinhas:
  # grudam na frase seguinte, como alguém digitaria no WhatsApp.
  LEAD_IN_CHARACTERS = 30

  pattr_initialize [:text!]

  def perform
    partes = authored_blocks.flat_map { |bloco| split_long_block(bloco) }.compact_blank
    return [text.to_s.strip].compact_blank if partes.blank?

    limit_parts(partes)
  end

  private

  # Blocos separados por linha em branco: onde o modelo decidiu quebrar.
  def authored_blocks
    text.to_s.split(/\n[ \t]*\n+/).map(&:strip).compact_blank
  end

  def split_long_block(bloco)
    frases = split_sentences(bloco)
    return [bloco] if frases.size <= 1

    frases.each_with_object([]) do |frase, partes|
      atual = partes.last

      if atual.nil? || !fits?(atual, frase)
        partes << frase
      else
        partes[-1] = "#{atual} #{frase}"
      end
    end
  end

  # Regras de junção, da mais forte para a mais fraca.
  def fits?(atual, frase)
    combinado = "#{atual} #{frase}"

    return false if sentence_count(atual) >= MAX_SENTENCES_PER_PART
    return false if combinado.length > MAX_CHARACTERS_PER_PART
    # Uma pergunta encerra a mensagem: nada entra depois dela.
    return false if atual.rstrip.end_with?('?')
    # Abertura curta sempre acompanha a frase seguinte.
    return true if atual.length <= LEAD_IN_CHARACTERS
    # Fora esse caso, a pergunta vai sozinha, para não virar bloco com pedido no fim.
    return false if frase.include?('?')

    combinado.length <= COMBINE_CHARACTERS_LIMIT
  end

  # Se passar do teto de mensagens, junta o excedente na última parte em vez de
  # descartar conteúdo. O filtro de brevidade cuida do resto, como antes.
  def limit_parts(partes)
    return partes if partes.size <= MAX_PARTS

    mantidas = partes.first(MAX_PARTS - 1)
    mantidas << partes.drop(MAX_PARTS - 1).join(' ')
    mantidas
  end

  def sentence_count(trecho)
    split_sentences(trecho).size
  end

  def split_sentences(trecho)
    protegido = trecho.to_s.gsub(/\b(Dra|Dr|Sra|Sr|Prof|Profa)\./i, '\1__ABBR_DOT__')
    # Ponto no meio de palavra nao termina frase: gov.br, art.29, 1.500.
    protegido = protegido.gsub(/(?<=\w)\.(?=\w)/, '__INNER_DOT__')
    protegido
      .scan(/[^.!?\n]+[.!?]*/)
      .map { |frase| frase.gsub('__ABBR_DOT__', '.').gsub('__INNER_DOT__', '.').strip }
      .compact_blank
  end
end
