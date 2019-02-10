require 'minitest/autorun'

def split(string)
  string.scan(/(?:\<[^>]+\>|(?:[^<>& ]+ *)|(?:&[^ ]+;))/)
end

def tag_piece(piece)
  type = case piece[0]
         when '<' then :tag
         when '&' then :entity
         else :word
         end
  { type: type, value: piece }
end

def tag_pieces(pieces)
  pieces.map { |piece| tag_piece(piece) }
end

def select_slicing_spot(tagged_pieces, length)
  temp = ''
  tagged_pieces.each_with_index { |piece, index|
    next if piece[:type] != :word
    return index - 1 unless temp.length < length

    temp << piece[:value]
  }

  -1
end

def closing_tag_of?(tag1, tag2)
  return false unless tag1 && tag1[:value][0] == '<'
  return false unless tag2 && tag2[:value][0] == '<'
  tag2[:value].gsub('<', '</') == tag1[:value]
end

def opened_tags(pieces)
  pieces.each_with_object([]) { |piece, obj|
    next unless piece[:type] == :tag

    closing_tag_of?(piece, obj.last) ? obj.pop : obj.push(piece)
  }
end

def closing_tag_piece(piece)
  { type: :tag, value: piece[:value].gsub('<', '</') }
end

def slice(pieces, spot)
  return [pieces, []] if spot < 0

  result = [pieces[0..spot], Array(pieces[spot.next..-1])]

  opened_tags(result.first)
    .each_with_object(result) { |tag, (left, right)|
      left.push(closing_tag_piece(tag))
      right.unshift(tag)
    }
end

def trunc(string, length)
  pieces = tag_pieces(split(string))
  spot = select_slicing_spot(pieces, length)
  slices = slice(pieces, spot)
  value_slices = [
    slices.first.map { |i| i[:value] },
    slices.last.map { |i| i[:value] }
  ]

  [value_slices.first.join, value_slices.last.join]
end

# ------------------------------------------------------------------------------

describe 'Truncation' do
  def piece(type, value)
    { type: type, value: value }
  end

  describe 'split' do
    let(:simple) { 'this is a simple string' }
    let(:wrapping_tags) { '<p>this is a paragraph</p>' }
    let(:with_tags_in_the_middle) { '<p>this <b>is a</b> paragraph</p>' }
    let(:with_singleton_tags) { '<p>this <b>is a</b><br/>paragraph</p>' }
    let(:with_html_entities) { '<p>this is a&nbsp;paragraph</p>' }

    it 'splits bare words' do
      split(simple)
        .must_equal(['this ', 'is ', 'a ', 'simple ', 'string'])
    end

    it 'identifies html tags' do
      split(with_tags_in_the_middle)
        .must_equal(['<p>', 'this ', '<b>', 'is ', 'a', '</b>', 'paragraph', '</p>'])
    end

    it 'identifies singleton tags' do
      split(with_singleton_tags)
        .must_equal(['<p>', 'this ', '<b>', 'is ', 'a', '</b>', '<br/>', 'paragraph', '</p>'])
    end

    it 'handles html entities' do
      split(with_html_entities)
        .must_equal(['<p>', 'this ', 'is ', 'a', '&nbsp;', 'paragraph', '</p>'])
    end
  end

  describe 'tag_piece' do
    let(:word) { 'word' }
    let(:html_starting_tag) { '<p>' }
    let(:html_ending_tag) { '</p>' }
    let(:html_singleton_tag) { '<br />' }
    let(:html_entity_tag) { '&nbsp;' }

    it do
      result = tag_piece(word)
      result[:type].must_equal(:word)
      result[:value].must_equal(word)
    end

    it do
      result = tag_piece(html_starting_tag)
      result[:type].must_equal(:tag)
      result[:value].must_equal(html_starting_tag)
    end

    it { tag_piece(html_ending_tag)[:type].must_equal(:tag) }
    it { tag_piece(html_singleton_tag)[:type].must_equal(:tag) }

    it do
      result = tag_piece(html_entity_tag)
      result[:type].must_equal(:entity)
      result[:value].must_equal(html_entity_tag)
    end
  end

  describe 'tag_pieces' do
    let(:pieces) { ['<p>', 'this', '&nbsp;', '</p>'] }

    it '' do
      tagged_pieces = tag_pieces(pieces)
      tags = tagged_pieces.map { |p| p[:type] }
      values = tagged_pieces.map { |p| p[:value] }
      tags.must_equal([:tag, :word, :entity, :tag])
      values.must_equal(pieces)
    end
  end

  describe 'select_slicing_spot' do
    let(:tagged_pieces) {
      [
        piece(:tag, '<p>'),
        piece(:word, 'this'),
        piece(:word, 'is'),
        piece(:word, 'a'),
        piece(:entity, '&nbsp;'),
        piece(:word, 'paragraph'),
        piece(:tag, '</p>')
      ]
    }

    it '' do
      select_slicing_spot(tagged_pieces, 4)
        .must_equal(1)
      select_slicing_spot(tagged_pieces, 5)
        .must_equal(2)
    end

    it '' do
      select_slicing_spot(tagged_pieces, 6)
        .must_equal(2)
    end

    it '' do
      select_slicing_spot([], 10).must_equal(-1)
    end

    it '' do
      select_slicing_spot([piece(:tag, '<p>'), piece(:entity, '&nbsp;'), piece(:tag, '</p>')], 2)
        .must_equal(-1)
    end
  end

  describe 'slice' do
    let(:tagged_pieces) { [
      piece(:tag, '<p>'),
      piece(:word, 'this'),
      piece(:word, 'is'),
      piece(:word, 'a'),
      piece(:entity, '&nbsp;'),
      piece(:word, 'paragraph'),
      piece(:tag, '</p>')
    ] }

    let(:sliced_at_2) {
      [
        [
          piece(:tag, '<p>'),
          piece(:word, 'this'),
          piece(:word, 'is'),
          piece(:tag, '</p>')
        ],
        [
          piece(:tag, '<p>'),
          piece(:word, 'a'),
          piece(:entity, '&nbsp;'),
          piece(:word, 'paragraph'),
          piece(:tag, '</p>')
        ]
      ]
    }

    it '' do
      slice(tagged_pieces, 2)
        .must_equal(sliced_at_2)
    end

    it '' do
      slice(tagged_pieces, -1)
        .must_equal([tagged_pieces, []])
    end

    it '' do
      slice(tagged_pieces, 20)
        .must_equal([tagged_pieces, []])
    end
  end

  describe 'trunc' do
    let(:string) { '<p>this is a&nbsp;paragraph</p>' }
    let(:visible) { '<p>this is </p>' }
    let(:hidden) { '<p>a&nbsp;paragraph</p>' }

    it '' do
      truncated = trunc(string, 6)
      truncated.first.must_equal(visible)
      truncated.last.must_equal(hidden)
    end
  end
end
